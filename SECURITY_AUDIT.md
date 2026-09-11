# Security & Code-Quality Audit — ChusteRM Microservices
**Scope:** `services/crm-service`, `services/identity-bridge`, `services/orchestrator` (read-only audit, every `.ts` source file + package.json, tsconfig.json, drizzle.config.ts, Dockerfiles, `.env.example`, `.env.prod.example`)
**Method:** Manual review against OWASP Top 10 (2021) + production-readiness criteria. No files modified.

---

## Executive Summary

**Verdict: NOT production-ready.** Two CRITICAL access-control failures mean the multi-tenant CRM data and the service-auth token system are effectively unprotected against any network-reachable caller.

| # | Finding | Service | Severity |
|---|---------|---------|----------|
| 1 | **No authentication/authorization on ANY route** — `@fastify/jwt` registered but `jwtVerify` never called; tenant `accountId` taken from client input | crm-service | CRITICAL |
| 2 | **Unauthenticated JWT minting** — `POST /auth/token` issues tokens for any `userId`/`accountId`/`role` with no credential check | identity-bridge | CRITICAL |
| 3 | **No auth on skill-execution and knowledge routes** — unauthenticated callers can burn OpenRouter LLM spend and read/write knowledge base | orchestrator | HIGH |
| 4 | **IDOR on every single-record endpoint** — fetch/update/delete by `:id` with no account scoping | crm-service, orchestrator | HIGH |
| 5 | **Hardcoded JWT dev secret + empty-string prod fallback** | crm-service | HIGH |
| 6 | **JWT verify ignores issuer/audience** | identity-bridge | HIGH |
| 7 | **Prompt-injection exposure in LLM skills** (partially mitigated in agent route, unmitigated in skills) | orchestrator | HIGH |
| 8 | **Mass-assignment in PATCH schemas** (score, leadProfileId, isSystem, chatwootContactId) | crm-service | HIGH |
| 9 | **Cross-account pipeline-stage creation** | crm-service | HIGH |
| 10 | No rate limiting / no security headers anywhere | all | MEDIUM |
| 11 | Webhook secret compared via `===` and accepted in URL query (logged) | orchestrator | MEDIUM |
| 12 | Migration failure swallowed at startup | crm-service | MEDIUM |
| 13 | BullMQ worker without `error` handler (process crash risk) | crm-service | MEDIUM |
| 14 | Deal state machine bugs (reopen keeps `closedAt`; create-with-loss-reason closes open deal) | crm-service | MEDIUM |
| 15 | Race condition in score-model provisioning | crm-service | MEDIUM |
| 16 | Committed dev DB credentials in source/config fallbacks | crm-service, orchestrator | MEDIUM |
| 17 | `.env.example` declares crm-service retired while the code requires its env vars | repo | MEDIUM |

**Positive observations (verified):** all Drizzle queries are parameterized — **no SQL injection found**; every `sql` template interpolates only column identifiers, never user input. Zod validation exists on most routes with pagination capped at 100. The agent webhook fails closed when the secret is unset. LLM responses pass through a strict normalizer (length caps, identity repair, credential redaction, refusal-stripping). The orchestrator aborts startup on migration failure. Services return JSON only — no server-side XSS surface.

---

## SERVICE 1: crm-service

### CRM-C1 — No authentication or authorization on any route — **CRITICAL**
- **Files:** `src/app.ts:22-24`, `src/routes/index.ts:11-20`, all route files
- **Code:**
  ```ts
  // app.ts:22
  app.register(jwt, {
    secret: process.env.SERVICE_JWT_SECRET ?? (isDev ? 'dev-secret-key-for-local-testing-only' : ''),
  })
  ```
  JWT is registered, but **no route, hook, or plugin ever calls `request.jwtVerify()`**. `registerRoutes` mounts all 8 route plugins with zero `preHandler`/auth guard.
- **Why exploitable:** Any HTTP client that can reach port 4000 can read/create/modify/delete every tenant's leads, deals, activities, pipelines, labels, loss reasons, and audit events. Combined with CRM-C2 this is full unauthenticated multi-tenant access (OWASP A01/A07).
- **Fix:** Add a global `app.addHook('onRequest', ...)` (exempting `/health`) that verifies the Bearer JWT via `@fastify/jwt`, rejects with 401, and attaches `request.user.accountId`. The identity-bridge already exists for minting/validating these tokens — wire it in.

### CRM-C2 — Tenant ID (`accountId`) trusted from client input — **CRITICAL**
- **Files:** `src/routes/deals.ts:10,30`, `src/routes/leadProfiles.ts:10,33`, `src/routes/activities.ts:11,31`, `src/routes/pipelines.ts:8,18,29`, `src/routes/labels.ts:9,15,26,32`, `src/routes/lossReasons.ts:9,18`, `src/routes/auditEvents.ts:8`
- **Code:** `accountId: z.number().int().positive()` inside request body/query schemas — e.g. `deals.ts:176 eq(deals.accountId, accountId)` where `accountId` comes straight from `request.query`.
- **Why exploitable:** Even after adding JWT auth (CRM-C1), an authenticated user of account A can pass `accountId=B` and read/write account B's data. Classic IDOR / broken object-level authorization (OWASP A01).
- **Fix:** Remove `accountId` from all client schemas; derive it exclusively from the verified JWT claim. Reject requests where a client-supplied accountId disagrees with the token.

### CRM-H1 — IDOR on single-record endpoints (no account scoping) — **HIGH**
- **Files/lines:** `deals.ts:229` (GET), `deals.ts:295` (PATCH), `deals.ts:372` (DELETE); `leadProfiles.ts:213,350,414`; `pipelines.ts:54,91,123`; `lossReasons.ts:82,122`; `labels.ts:206`
- **Code:** `const { id } = request.params as { id: string }` then `where(and(eq(deals.id, id), isNull(deals.deletedAt)))` — no `accountId` predicate.
- **Why exploitable:** UUIDs are unguessable but leak via referrers, logs, screenshots, and the list endpoints; once known, any caller (or any authenticated tenant, post-C1-fix) can read/alter another tenant's record.
- **Fix:** Add `eq(table.accountId, request.user.accountId)` to every by-id query; return 404 (not 403) on mismatch.

### CRM-H2 — Hardcoded JWT secret fallback — **HIGH**
- **File:** `src/app.ts:23`
- **Code:** `secret: process.env.SERVICE_JWT_SECRET ?? (isDev ? 'dev-secret-key-for-local-testing-only' : '')`
- **Why exploitable:** A committed, publicly known signing secret is used whenever `NODE_ENV !== 'production'` (staging, misconfigured prod). Anyone can forge tokens. In prod, an unset env yields `''`, which either crashes at register time or signs with an empty secret — both fail-unsafe.
- **Fix:** No secret fallback. Fail fast at startup if `SERVICE_JWT_SECRET` is missing/short (<32 bytes), in every environment; read dev secrets from local untracked env files.

### CRM-H3 — Mass assignment in PATCH schemas — **HIGH**
- **Files:**
  - `src/routes/deals.ts:25` — `updateSchema = createSchema.partial().omit({ accountId: true })` still allows `leadProfileId` (re-point a deal to **any** contact, including another tenant's) and `score` (client-set arbitrary score).
  - `src/routes/leadProfiles.ts:30` — PATCH allows `chatwootContactId`, `score`, `stage`, `lifecycleStage`, `relationshipStatus` with no field-level authorization.
  - `src/routes/labels.ts:22` — `isSystem: z.boolean().optional()` lets any caller create "system" labels.
  - `src/routes/activities.ts:22-28` — PATCH allows re-pointing `leadProfileId`/`dealId`.
- **Fix:** Build explicit update schemas listing only user-editable fields; keep `score`, `isSystem`, foreign keys, and lifecycle fields server-controlled.

### CRM-H4 — Cross-account pipeline stage creation — **HIGH**
- **File:** `src/routes/pipelines.ts:175-199`
- **Code:**
  ```ts
  // :id pipeline is loaded WITHOUT account check (line 179-183), then:
  const [created] = await db.insert(pipelineStages)
    .values({ ...body.data, pipelineId: id })   // body.data.accountId is attacker-chosen
  ```
- **Why exploitable:** Caller creates a stage under tenant A's pipeline while stamping it with tenant B's `accountId` (or vice versa) — cross-tenant data pollution; the stage then appears in A's pipeline listing but is scored/validated as B's in `hydrateStage` (`deals.ts:51-55`).
- **Fix:** Load the pipeline with an account predicate and force `accountId` from the authenticated tenant, ignoring the body's value.

### CRM-M1 — No rate limiting, no security headers — **MEDIUM**
- **File:** `src/app.ts` (whole file)
- Only `@fastify/cors` and `@fastify/jwt` are registered. No `@fastify/helmet`, no `@fastify/rate-limit`. Unauthenticated write endpoints + no throttling = trivial data-flooding/DoS.
- **Fix:** Register `@fastify/helmet` and `@fastify/rate-limit` (e.g. 100 req/min per IP globally, stricter on POST/PATCH/DELETE).

### CRM-M2 — Migration failure swallowed at startup — **MEDIUM**
- **File:** `src/server.ts:14-16`
- **Code:** `catch (err) { app.log.warn({ err }, 'Migrations skipped or failed — continuing startup') }`
- **Why wrong:** Service starts against a possibly incompatible schema → runtime 500s, silent data corruption. Compare orchestrator `server.ts:16-19`, which correctly aborts.
- **Fix:** `process.exit(1)` on migration failure (migrations are idempotent; crash-loop is the safe behavior).

### CRM-M3 — DB URL non-null assertion; silent fallback to localhost — **MEDIUM**
- **Files:** `src/db/client.ts:5`, `src/db/migrate.ts:10`
- **Code:** `postgres(process.env.CRM_DB_URL!, { max: 10 })`
- **Why wrong:** If `CRM_DB_URL` is unset, `postgres(undefined)` silently connects with driver defaults (localhost, OS user) instead of crashing — in production this can connect to the wrong database or hang mysteriously. Also no `ssl` option for managed Postgres.
- **Fix:** Fail fast: `if (!process.env.CRM_DB_URL) throw new Error('CRM_DB_URL is required')`; add `ssl: 'require'` behind an env flag.

### CRM-M4 — BullMQ worker without `error` handler; failure logging via `console.error` — **MEDIUM**
- **File:** `src/jobs/leadScoring.ts:181-194`
- **Code:** only `worker.on('failed', ...)` is registered, logging with `console.error` (bypasses pino, loses correlation IDs).
- **Why wrong:** BullMQ `Worker` is an EventEmitter; Redis connection errors are re-emitted as `'error'` events — with no listener, Node throws and **crashes the process**.
- **Fix:** `worker.on('error', err => app.log.error({ err }, 'lead-scoring worker error'))`; pass the app logger into the worker.

### CRM-M5 — Unvalidated `:id` path params → 500 on non-UUID input — **MEDIUM**
- **Files:** all routes, e.g. `deals.ts:229`, `leadProfiles.ts:213`, `pipelines.ts:54`
- **Code:** `request.params as { id: string }` — the unsafe cast is never validated; `eq(deals.id, 'garbage')` against a `uuid` column raises Postgres `22P02` → 500.
- **Fix:** Validate params with `z.string().uuid()` (orchestrator's knowledge route does this correctly at `knowledge.ts:195-201`) and return 400.

### CRM-M6 — Deal state-machine bugs — **MEDIUM**
- **File:** `src/routes/deals.ts`
  - **Line 273:** `closedAt: isClosedStage(hydratedPayload.stage) || hydratedPayload.lossReasonId ? new Date() : undefined` — creating a deal that merely *has* a loss reason (even in an open stage) immediately closes it.
  - **Lines 331-339:** `shouldClose` only ever *sets* `closedAt`; moving a closed deal back to an open stage never clears `closedAt` → deal is simultaneously "open stage" and "closed", corrupting funnel metrics (`leadScoring.ts:61` counts `closedAt is null` as active).
  - **Race:** PATCH does read-modify-write with no optimistic locking (`deals.ts:302-341`); two concurrent PATCHes silently lose one transition while both write audit events.
- **Fix:** Drive `closedAt` strictly from closed-stage membership (closed stage ⇒ set, otherwise `null`); only accept `lossReasonId` when the target stage is a lost-stage; add optimistic concurrency or a transaction.

### CRM-M7 — Race in score-model provisioning — **MEDIUM**
- **File:** `src/jobs/leadScoring.ts:113-134` (`ensureActiveModel`), schema `src/db/schema.ts:194-203`
- Check-then-insert with no unique constraint on `score_models.account_id`; with `concurrency: 5` (`leadScoring.ts:185`), first jobs for a new account insert duplicate "active" models, and subsequent `select ... limit(1)` picks an arbitrary one.
- **Fix:** Unique partial index `ON score_models(account_id) WHERE status='active'` + `ON CONFLICT DO NOTHING ... RETURNING` with re-select.

### CRM-L1 — Committed dev DB credentials — **LOW**
- `drizzle.config.ts:8`: fallback `postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_crm`. Dev-only, but normalizes credentials-in-code. Remove fallback; require env.

### CRM-L2 — Verbose zod messages echoed to clients — **LOW**
- Every route returns `query.error.message` / `body.error.message` (e.g. `deals.ts:157`). Leaks schema internals. Return a generic message + field paths only.

### CRM-L3 — Unbounded `IN (...)` lists — **LOW**
- `deals.ts:79-94` (`contactIdsForLabel`) and `leadProfiles.ts:51-66` can produce thousands of IDs in one `inArray`. Cap or use a JOIN/EXISTS subquery.

### CRM-L4 — Dockerfile hardening — **LOW**
- `Dockerfile`: no `USER node` (runs as root); dev stage `COPY . .` (line 7) bakes any local `.env` into the image if `.dockerignore` misses it; no `HEALTHCHECK`. Production stage is otherwise clean (`npm ci --omit=dev`).

### CRM-L5 — Graceful shutdown leaks the Postgres pool — **LOW**
- `src/server.ts:20-25` closes worker + app but never `sql.end()`; `shutdown()` also has no timeout guard before `process.exit(0)`.

### Env vars actually required by crm-service
`CRM_DB_URL` (required, no fallback), `CRM_REDIS_URL` (default `redis://localhost:6379/1`), `CRM_PORT` (default 4000), `SERVICE_JWT_SECRET` (insecure dev fallback), `CORS_ORIGIN`, `LOG_LEVEL`, `NODE_ENV`.

---

## SERVICE 2: identity-bridge

### IB-C1 — Unauthenticated service-token minting — **CRITICAL**
- **File:** `src/routes/auth.ts:89-131`
- **Code:**
  ```ts
  app.post('/auth/token', async (request, reply) => {
    const parseResult = tokenBodySchema.safeParse(request.body)   // { userId, accountId, role }
    ...
    const token = jwt.sign({ userId, accountId, role }, secret, signOptions)
  ```
- **Why exploitable:** Anyone who can reach port 4002 can mint a valid JWT claiming **any user, any account, any role** (e.g. `role: "admin"`). If any service ever trusts these tokens (the stated purpose of this bridge), this is a complete authentication bypass and full tenant impersonation (OWASP A07/A04). The endpoint is also unthrottled and unaudited.
- **Fix:** Require a caller credential: a per-caller shared `x-service-key` header (rotatable), mTLS on the internal network, or a one-time bootstrap token exchanged by the Core. Restrict `role` to an allowlist, log every issuance with caller identity, and add rate limiting.

### IB-H1 — `jwt.verify` does not enforce issuer/audience — **HIGH**
- **File:** `src/routes/auth.ts:71` (`/auth/validate`), `auth.ts:161` (`/auth/me`)
- Tokens are *signed* with `issuer: 'chusterm:identity-bridge'`, `audience: 'chusterm:internal'` (lines 117-118) but verified with bare `jwt.verify(token, secret)` — any token signed with the shared secret (e.g. issued by another component for a different purpose) is accepted.
- **Fix:** `jwt.verify(token, secret, { algorithms: ['HS256'], issuer: 'chusterm:identity-bridge', audience: 'chusterm:internal' })` — pin the algorithm explicitly too.

### IB-H2 — No rate limiting on auth endpoints — **HIGH**
- **File:** `src/app.ts` (no rate-limit plugin), routes `auth.ts:47,89,139`
- `/auth/validate` and `/auth/me` can be used for online token grinding/timing probes; `/auth/token` for unlimited minting.
- **Fix:** `@fastify/rate-limit` with a small budget (e.g. 30/min/IP) on all three endpoints.

### IB-M1 — `role` is a free-form client string — **MEDIUM**
- `auth.ts:14`: `role: z.string().min(1)` — no enum/allowlist. Fix: `z.enum(['agent','admin','service', ...])`.

### IB-M2 — Missing secret only detected per-request — **MEDIUM**
- `auth.ts:19-25`: `getSecret()` throws inside handlers; a misconfigured deployment starts "healthy" (`/health` returns ok) and fails only on real traffic. Fix: validate env at startup in `server.ts` and refuse to listen.

### IB-M3 — No audit trail for token issuance — **MEDIUM**
- Nothing logs who requested which `userId/accountId/role`. Fix: structured log line per issuance (and per validation failure) for forensics.

### IB-L1 — Dockerfile issues — **LOW**
- `Dockerfile:21,36`: builder/production use `npm install` instead of `npm ci` (non-reproducible builds — OWASP A08); no `USER node`; no `HEALTHCHECK`.

### IB-L2 — No graceful shutdown — **LOW**
- `src/server.ts` has no SIGTERM/SIGINT handlers (unlike the other two services).

### Env vars actually required by identity-bridge
`SERVICE_JWT_SECRET` (required, per-request throw), `SERVICE_JWT_EXPIRY` (default `15m`), `IDENTITY_BRIDGE_PORT` (default 4002), `CORS_ORIGIN`, `LOG_LEVEL`.

---

## SERVICE 3: orchestrator

### ORC-H1 — No authentication on `/skills/:slug/run` and `/knowledge/*` — **HIGH**
- **Files:** `src/routes/skills.ts:170`, `src/routes/knowledge.ts:31,61,87,139,192`; contrast with the protected `agent.ts:298-308`.
- **Code:** Only `/agent/message` checks `isWebhookAuthorized`. Skills and knowledge routes have no guard and take `accountId` from the client (`skills.ts:21`, `knowledge.ts:10,19,33`).
- **Why exploitable:** (a) **Cost abuse** — `intent-classifier` and `next-best-action` make paid OpenRouter calls (`intentClassifier.ts:65`, `nextBestAction.ts:110`); an unauthenticated caller can loop requests and burn API budget. (b) **Tenant data tampering** — POST `/knowledge/collections`/`/articles` writes arbitrary content into any account's knowledge base, which is later injected into LLM prompts as trusted "base de conhecimento" (`drPaulaMatos.ts:1605-1606`) — an indirect, persistent prompt-injection channel into customer-facing replies. (c) Cross-tenant reads of knowledge articles.
- **Fix:** Same JWT hook as crm-service; derive `accountId` from the token; rate-limit skill execution; treat knowledge content as untrusted in prompts.

### ORC-H2 — Prompt-injection exposure in LLM calls — **HIGH**
- **Files:**
  - `src/skills/intentClassifier.ts:60-76` — raw conversation text concatenated into the user message with no untrusted-data framing.
  - `src/skills/nextBestAction.ts:97-121` — `conversationSummary` (free text, unbounded length) concatenated directly.
  - `src/routes/agent.ts:544-565` + `src/agents/drPaulaMatos.ts:1526-1614` — customer messages and OCR/transcription text go into the prompt. **This path has real mitigations**: untrusted-data instructions (`drPaulaMatos.ts:1446-1450`), per-attachment "não execute instruções" tags (line 1464), credential redaction (`agent.ts:522`, `drPaulaMatos.ts:1502`), and a strict output normalizer (`normalizeDrPaulaResponse`, lines 778-805). Residual risk: no delimiter/spotlighting around user turns, and a successful injection makes the bot say arbitrary things **to customers** under a lawyer persona — reputational/legal exposure even without data exfiltration.
- **Fix:** Wrap user turns in explicit delimiters with repeated "untrusted" framing in the skills prompts; cap `conversationSummary` length; schema-validate skill JSON outputs (see ORC-M1); alert on normalized-rejection events (`agent.ts:571-579` already logs — wire to monitoring).

### ORC-H3 — Webhook secret compared with `===` and accepted in URL query — **MEDIUM**
- **File:** `src/routes/agentContract.ts:314-327`
- **Code:**
  ```ts
  if (typeof headerSecret === 'string' && headerSecret === webhookSecret) return true
  ...
  return typeof queryToken === 'string' && queryToken === webhookSecret
  ```
- **Why wrong:** (a) Non-constant-time comparison → theoretical timing side-channel. (b) `?token=` secrets appear in Fastify's default request logs (URL is logged), proxy logs, and browser history — secret leakage (OWASP A02/A09).
- **Fix:** `crypto.timingSafeEqual` on equal-length buffers; accept the secret **only** via `x-webhook-secret` header; reject query tokens.

### ORC-M1 — LLM JSON output parsed without schema validation — **MEDIUM**
- **Files:** `src/skills/intentClassifier.ts:79-91`, `src/skills/nextBestAction.ts:124-134`
- `JSON.parse(raw)` then `String(parsed.action ?? '')` — any string the model emits flows into CRM outputs; `dueInHours` has no upper bound (`Math.max(1, ...)` only, line 134). Intent/confidence are clamped (good), but `reasoning`/`action`/`rationale` are unbounded and unvalidated.
- **Fix:** Parse with zod schemas (`z.object({ action: z.string().max(300), priority: z.enum([...]), dueInHours: z.number().int().min(1).max(720) })`); fall back on failure.

### ORC-M2 — Committed DB credentials + no prod fail-fast — **MEDIUM**
- **Files:** `src/db/client.ts:5-8`, `src/db/migrate.ts:11-13`, `drizzle.config.ts:8`
- `postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai` hardcoded as fallback in three places. Inconsistency: `queues/index.ts:16-19` correctly throws when `ORCHESTRATOR_REDIS_URL` is missing in production, but the DB client silently falls back.
- **Fix:** Remove fallbacks; throw when unset (mirror the Redis guard).

### ORC-M3 — No retry on Chatwoot reply posting; message loss — **MEDIUM**
- **File:** `src/routes/agent.ts:260-289` (`postReply`), error path `722-725`
- A transient Chatwoot 5xx/timeout after LLM generation returns 500 and drops the customer reply; redelivery depends on Chatwoot webhook retry behavior, which is not guaranteed. History fetch (`fetchConversationHistory`, line 228) has a 10s timeout (good) but also no retry.
- **Fix:** 2-3 retries with exponential backoff + jitter on `postReply`; on final failure, persist the unsent response (memory status) so a later event can recover.

### ORC-M4 — In-memory dedupe/serialization breaks with >1 replica — **MEDIUM**
- **File:** `src/routes/agent.ts:73-75` (`activeConversations`, `recentWebhookEvents` Maps)
- Correct for a single process, but with 2+ replicas the same conversation can be processed concurrently on different pods → duplicate customer replies. Also `recentWebhookEvents` TTL sweep only runs when an event **with** an id arrives (lines 341-353).
- **Fix:** Move dedupe/locking to Redis (`SET NX PX` on `accountId:messageId`, plus a per-conversation lock) — Redis is already a dependency; or document and enforce `replicas: 1`.

### ORC-M5 — Unbounded knowledge-article listing — **MEDIUM**
- **File:** `src/routes/knowledge.ts:122-127` — no `limit`/`offset`; `q` search scans and returns all matching articles. Add pagination (cap 100) like crm-service.

### ORC-M6 — Dead BullMQ queue + leaked connections — **LOW**
- **File:** `src/queues/index.ts:28-39` — `asyncSkillQueue` is created but nothing enqueues to it and no worker consumes it (comment admits "a separate worker process ... would consume"). The `Queue` still holds a Redis connection for the process lifetime, and `server.ts:30-40` shutdown never closes it or the pg pool.
- **Fix:** Delete the queue until a worker exists, or wire the worker; close queue + `pgClient` in the shutdown handler.

### ORC-L1 — LLM client edge cases — **LOW**
- `src/llm/client.ts:11`: `apiKey: process.env.LLM_API_KEY ?? ''` — empty key passes construction and fails only at call time (mitigated by `isLlmConfigured`, line 35). `client.ts:6`: hostname check allows `http://openrouter.ai` (plaintext) — require `https:` too. `client.ts:16-27`: default model slugs should be validated against the OpenRouter catalog at deploy time — an invalid slug silently degrades every skill to its fallback.

### ORC-L2 — `skillRuns` row written before slug validation — **LOW**
- `src/routes/skills.ts:190-204` — unknown slugs still insert a DB row (later marked failed). Validate slug against the registry first.

### ORC-L3 — Dockerfile — **LOW**
- No `USER node`; dev stage `COPY . .` (line 10) can bake `.env`; otherwise good (`npm ci`, multi-stage, `NODE_ENV=production`).

### ORC-L4 — Redis URL parser ignores username — **LOW**
- `src/queues/index.ts:4-12` and crm-service `lib/redis.ts:3-14` drop `parsed.username` — Redis ACL users unsupported. Add `username` when present.

### Env vars actually required by orchestrator
`ORCHESTRATOR_DB_URL` (insecure fallback), `ORCHESTRATOR_REDIS_URL` (required in prod — enforced), `ORCHESTRATOR_WEBHOOK_SECRET` (required for `/agent/message`, fail-closed), `CHATWOOT_BOT_TOKEN` (required for agent replies), `CHATWOOT_BASE_URL` (default `http://core:3000`), `LLM_API_KEY` (optional → deterministic fallbacks), `LLM_BASE_URL`, `LLM_MODEL`, `ORCHESTRATOR_DRA_LETICIA_LLM_MODEL` / legacy `ORCHESTRATOR_DR_PAULA_LLM_MODEL`, `LLM_ATTENDANCE_TEST_MODEL`, `LLM_CODING_TEST_MODEL`, `LLM_MAX_TOKENS_PER_SESSION`, `LLM_TIMEOUT_MS`, `ORCHESTRATOR_PORT`, `CORS_ORIGIN`, `LOG_LEVEL`, `NODE_ENV`, `ACCOUNT_ID` (seed script only).

---

## Test coverage assessment — `services/orchestrator/test/orchestrator.test.ts` (859 lines)

**Covers well:** webhook authorization (empty secret fail-closed, header/query accept, wrong-secret reject); payload schema incl. attachment-only webhooks; text normalization; human-intervention pause heuristics; attachment normalization/readability; triage extraction incl. negation handling; lead scoring; response normalization (JSON unwrap, format-error hiding, length/question caps, identity repair, credential redaction/removal); near-duplicate detection; new-lead closing state machine; CRM relationship resolution; `/health`.

**Missing for critical flows:**
1. **No end-to-end `/agent/message` test** with mocked `fetch` (Chatwoot history/post) and mocked LLM — the ~400-line orchestration core (queueing, dedupe, takeover guards, memory upsert, reply posting) is untested.
2. No test for the **503 HISTORY_UNAVAILABLE** abort path (`agent.ts:376-384, 627-636`) or the **reply_already_created / newer_incoming_exists** race guards.
3. No test that a **paused conversation** (`human_intervention_requested`) stays silent, or resumes.
4. **Skills route** (`/skills/:slug/run`) — zero tests: success, unknown slug 404, validation 422, LLM failure fallback, DB-failure paths.
5. **Knowledge routes** — zero tests (incl. the cross-account collection check at `knowledge.ts:148-166`).
6. **crm-service and identity-bridge have no test files at all** — no coverage for deal state transitions, loss-reason validation, label dedupe, token mint/validate/me.
7. No load/DoS test surface (rate limiting absent), no auth tests (auth absent).

---

## Env-file mismatches (`.env.example` / `.env.prod.example` vs. code)

1. **crm-service disowned but alive — MEDIUM.** `.env.example:40-41` states "crm-service aposentado — variáveis CRM_SERVICE_INTERNAL_URL/CRM_PORT/CRM_DB_URL/CRM_REDIS_URL removidas", yet `services/crm-service` exists, is audit-scoped, and **requires** `CRM_DB_URL` (`db/client.ts:5`), `CRM_REDIS_URL` (`lib/redis.ts:17`), `CRM_PORT` (`server.ts:5`). Either delete the service or restore + document the vars; as-is, a deploy following the examples cannot run it, and nobody maintains its env contract.
2. **`CHATWOOT_WEBHOOK_SECRET` is documented but never read by any code** (`.env.example:53`, `.env.prod.example`) — the agent route uses `ORCHESTRATOR_WEBHOOK_SECRET` (`agent.ts:52`). Dead/misleading var; remove or wire.
3. **`CORS_ORIGIN` and `LOG_LEVEL`** are read by all three services but documented in neither example.
4. **`IDENTITY_BRIDGE_PORT`** missing from `.env.example` (present in `.env.prod.example`); defaults to 4002 so dev works, but undocumented.
5. **`ORCHESTRATOR_DR_PAULA_LLM_MODEL`** (legacy fallback read at `llm/client.ts:20`) undocumented.
6. **`LLM_PROVIDER`** documented but unused by any audited code.
7. **`.env.example:90` ships a default-looking `EVOLUTION_API_KEY=evo_chusterm_secret_key`** — replace with a `PREENCHER_...` placeholder like the prod example does.
8. Prod example correctly requires `SERVICE_JWT_SECRET` generation — but **no code enforces its presence at boot** in crm-service (empty-string fallback) or identity-bridge (per-request throw).

---

## Prioritized remediation plan

1. **(CRITICAL)** Add JWT verification hook + token-derived `accountId` to crm-service and orchestrator skills/knowledge routes; remove `accountId` from all request schemas.
2. **(CRITICAL)** Gate `POST /auth/token` behind a service credential; allowlist roles; log issuance.
3. **(HIGH)** Account-scope every by-id query; fix pipeline-stage cross-account bug; lock down PATCH mass-assignment.
4. **(HIGH)** Remove hardcoded secret fallbacks (crm JWT secret, orchestrator DB URL); fail fast on missing env at boot in all three services.
5. **(HIGH)** Enforce `algorithms`/`issuer`/`audience` on JWT verify; rate-limit auth + webhook + skill endpoints; add `@fastify/helmet`.
6. **(MEDIUM)** Fix deal state machine (`closedAt` set/clear rules), score-model race (unique index), BullMQ `error` handlers, migration swallow.
7. **(MEDIUM)** Harden webhook secret handling (header-only, `timingSafeEqual`); add retries to Chatwoot posting; Redis-backed dedupe for multi-replica.
8. **(MEDIUM)** Validate LLM JSON with zod; bound `conversationSummary`; zod-validate all `:id` params.
9. **(LOW)** Dockerfiles: `USER node`, `npm ci` everywhere, `HEALTHCHECK`, confirm `.dockerignore` excludes `.env*`; add graceful pool/queue shutdown.
10. **(TESTS)** Add e2e agent-route tests with mocked fetch/LLM; skills + knowledge route tests; first test suites for crm-service and identity-bridge (auth, IDOR, state transitions).

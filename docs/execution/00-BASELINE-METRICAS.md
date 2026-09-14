# Fase 0 — Baseline de Métricas — ChusteRM

**Data:** 2026-09-14 · **Ambiente:** docker-compose dev (core :8086, orchestrator :4001) · **Método:** curl no host + inspeção no container

## 1. Bundle JS (`/app/public/vite` no container `chusterm-core-1`)

| Métrica | Valor |
|---|---|
| Total do diretório vite | 53,7 MB |
| Arquivos `.js` | 79 |
| Maior chunk | `DashboardIcon-4knYqnfy.js` — **11,0 MB** ⚠️ |
| Chunk dashboard | `dashboard-Dol9EAxI.js` — **3,0 MB** |
| `v3app` (login/onboarding) | 268 KB |
| `AnalyticsCenter`/`AutomationRules` (lazy CRM) | ~200 KB cada — ok |

**Leitura:** páginas CRM são lazy (PERF-03 aplicado). O problema é o payload inicial: um único chunk de 11 MB chamado `DashboardIcon` sugere sprite/fonte dados inline em JS. Investigar `app/javascript/dashboard/components-next/icon` ou equivalente na Fase 4 (card CRM-010).

## 2. Endpoints (host → :8086, sem sessão)

| Endpoint | HTTP | Tempo |
|---|---|---|
| `/health` | 200 | 7 ms |
| `/app` | 200 | 68 ms |
| `/app/login` | 200 | 65 ms |
| `/api/v1/profile` | 401 | 6 ms |
| `/api/v1/accounts/1/crm/pipelines` | 401 | 7 ms |
| `/api/v1/accounts/1/crm/deals` | 401 | 6 ms |
| `/api/v1/accounts/1/crm/dashboard` | 401 | 9 ms |
| `/api/v1/accounts/1/conversations` | 401 | 7 ms |
| `/api/v1/accounts/1/crm/activities` | 401 | 6 ms |

> Limitação: 401 para na autenticação — não mede query real. **Ação pendente (card CRM-012):** medir autenticado via `qa/bench` ou runner Playwright com storage state, coletando p95 e contagem de queries (bullet já está no Gemfile).

## 3. Testes

| Suíte | Quantidade | Como rodar |
|---|---|---|
| RSpec (`core/spec`) | 742 arquivos | `bundle exec rspec` — bundle satisfeito no host (Ruby 3.4.4), DB em :5436 |
| Vitest (`core/app/javascript`) | 404 specs | `pnpm test` em `core/` |
| Playwright (`qa/e2e`) | 8 specs | `qa/e2e/playwright.config.ts`, storage states por persona |
| E2E no CI | **não localizado** | gap (D-13) |

## 4. Banco (dev)

16 contas · 47 users · 2.888 contatos · 34 conversas · 690 mensagens · **2.851 deals** · 19 pipelines · 14 inboxes · 112 tabelas no schema (15 `crm_*`).

## 5. Infra

| Item | Estado |
|---|---|
| Containers saudáveis | core, sidekiq, orchestrator, evolution-api, postgres, redis, mailhog |
| `docker compose config` | válido (F0-BASELINE) |
| `core-vite` watch | opt-in (`--profile frontend-watch`) |
| Node local vs alvo | 25.2.1 vs 24 ⚠️ |

## 6. Metas do orçamento (Fase 5.4) vs baseline

| Métrica | Alvo | Baseline | Status |
|---|---|---|---|
| LCP telas principais | < 2,5 s | não medido (precisa browser autenticado) | ⬜ pendente — com 11 MB de chunk, risco real |
| Abrir conversa | < 400 ms | não medido | ⬜ |
| p95 endpoints principais | < 300 ms | boundary 401 ≈ 6-9 ms (não representativo) | ⬜ |
| N+1 telas críticas | 0 | bullet no Gemfile, ativação a confirmar | ⬜ |
| Bundle JS inicial | ≤ baseline+10% | **14 MB nos 2 maiores chunks** = este é o baseline | ⚠️ medido |

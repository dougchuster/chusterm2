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

## 7. Baseline autenticado (CRM-011, 2026-09-15)

Conta 115 (2.000 deals, pipeline 37, ~2.000 activities), token de API gerado
em runtime no container. 12 requests por endpoint via curl → `time_total` em
segundos. Ambiente: container `chusterm-core-1` em `RAILS_ENV=production`,
Postgres/Redis no Docker Desktop/Windows.

| Endpoint | mediana | pior | leitura |
|---|---|---|---|
| `crm/pipelines/37/board` | ~0,040 s | 0,105 s | ok — board de 2.000 deals |
| `crm/deals` (index) | ~0,051 s | 0,066 s | ok |
| `crm/deals/283` | ~0,016 s | 0,036 s | ok |
| **`crm/activities`** | **~0,53 s** | **0,66 s** | **outlier 10-50×** — ver abaixo |
| `crm/agenda_events` | ~0,010 s | 0,017 s | ok |
| `crm/dashboard` | ~0,020 s | 0,036 s | ok |
| `crm/options` | ~0,008 s | 0,009 s | ok |
| `conversations` | ~0,055 s | 0,106 s | ok |
| `contacts` | ~0,036 s | 0,042 s | ok |
| `crm/audit-events` | ~0,010 s | 0,020 s | ok |

Queries por request (replay do `filtered_activities` com subscriber
`sql.active_record`, 200 registros, eager load completo): **7 queries** — sem
N+1. Os ~0,53 s de `crm/activities` são custo de serialização/CPU (200
registros × ~25 campos + `calendar_links` + nested contact/deal/conversation),
não de banco. Candidato a paginação menor ou serializer enxuto — backlog
perf, não bug de query.

### Bundle (pós-CRM-010)

| Chunk | antes | depois |
|---|---|---|
| `i18n-locales` (todos os idiomas no load inicial) | 10,9-14,6 MB | **eliminado** — 51 chunks assíncronos ~250-440 kB |
| `dashboard` (entry) | 2,97 MB | 2,97 MB |
| `DashboardIcon` (compartilhado, contém en+pt_BR) | 0,44 MB | 1,02 MB |
| JS inicial total (grafo estático) | ~14,9 MB | **~4,5 MB (−70%)** |

p95-alvo (<300 ms): todos os endpoints medidos exceto `crm/activities` já
cumprem; activities excede — registrado como débito de serialização.

## 8. QA do épico E2 (CRM-013, re-medição 2026-09-15)

Rebuild de produção pós-CRM-030/004: entry `dashboard` 2.974 kB,
`DashboardIcon` 1.024 kB (en+pt_BR estáticos), 51 chunks de idioma
assíncronos (~250-440 kB) — orçamento de bundle mantido (nenhum chunk
inicial novo >1 MB; `dashboard`/`DashboardIcon` já estavam no baseline
pós-CRM-010 e não cresceram).

- `crm/activities` (~530 ms p95): débito de serialização conhecido — 200
  registros × ~25 campos; não é N+1 (7 queries medidas). Reduzir exige
  paginação menor ou serializer enxuto — fica como follow-up de produto
  (decisão de quantos itens a tela precisa), não de QA.
- LCP das 5 telas principais: exige sessão de browser autenticada com
  dados reais — pendente de passagem manual documentada (ver
  `02-KANBAN.md`, CRM-025 cobre a passagem visual completa).

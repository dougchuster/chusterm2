# Fase 0 — Diagnóstico e Inventário — ChusteRM

**Data:** 2026-09-14 · **Base:** `main` @ `f2401f3a` · **Leitura:** docker-compose dev ativo (localhost:8086)

> Consolida audits existentes (`docs/audit/*`, `docs/execution/F0-*`, `CORE_AUDIT.md`, `SECURITY_AUDIT.md`, `PLANO-KANBAN-CRM-2026.md`) com **revalidação no código atual de `main`**. Findings antigos já corrigidos estão marcados ✅ — o documento reflete o estado presente, não o histórico.
>
> *Nota de localização: `docs/*` está no `.gitignore` (apenas `audit/`, `execution/`, `qa/` são versionados); por isso os entregáveis deste programa vivem em `docs/execution/`.*

---

## 0. Contexto do projeto (seção 0 do prompt — preenchida com dados reais)

| Campo | Valor |
|---|---|
| Produto | ChusteRM — atendimento multicanal + CRM conversacional sobre fork do Chatwoot CE |
| Stack | Ruby **3.4.4** · Rails **7.2.3.1** · Vue **3.5** · Postgres **15** (pgvector) · Redis **7** · Sidekiq · Tailwind **3.4** · Vite **6.4.3** · Orchestrator: Node ≥20 / Fastify 5 / Drizzle / BullMQ / OpenRouter · Evolution API v2.3.0 (Baileys) |
| Repositório | `C:\Users\dougc\Documents\Projetos\ChusteRM` · origin `github.com/dougchuster/chuterm` · upstream `github.com/chatwoot/chatwoot` |
| Volume atual (dev DB) | **16** contas · **47** usuários · **2.888** contatos · **34** conversas · **690** mensagens · **2.851** deals · **19** pipelines · **14** inboxes |
| Canais ativos | Evolution WhatsApp (Baileys — principal), WhatsApp Cloud API, Instagram, Messenger, e-mail, webchat, Telegram, Twilio, Line, TikTok (herdados do upstream) |
| Merge do upstream | **Sim** — sync auditado v4.12.1 → v4.17.1 (756 commits, 4.365 arquivos, 65 migrations). `core/VERSION_CW` = 4.12.1 |
| Ambientes | dev (`docker-compose.yml` + override → :8086) · prod (`docker-compose.prod.yml` + `infra/nginx` + `chusterm-host.conf`) |
| Time | 1 dev + agentes de IA; revisão pelo dono do produto |
| Restrições inegociáveis | MIT-only (`enterprise/` proibido — clean-room) · sem signup público · LGPD (`lgpd_basis`, `consent_*`, `data_retention_until` no schema) · API pública v1 estável · multi-tenant account-scoped · design system Obsidian+Mineral · segredos sem default em compose |

---

## 1. Arquitetura real

```
evolution-api :8085 (Baileys) ──webhooks──→ core (IncomingMessageEvolutionService)
core :8086  Rails 7.2 + Vue 3 SPA + Sidekiq + ActionCable
  ├── upstream: conversas, contatos, inboxes, Captain, relatórios
  ├── /api/v1/accounts/:id/crm/*  → 15 tabelas crm_*  (CRM nativo, fonte da verdade)
  └── agent_bot webhook → POST orchestrator:4001/agent/message
orchestrator :4001  Fastify + Drizzle + BullMQ
  └── LLM via OpenRouter (claude-sonnet-5 agente · gemini-3.7-flash skills)
postgres :5436 (pgvector) · redis :6382 · mailhog :8025
```

**Serviços mortos versionados:** `services/crm-service` e `services/identity-bridge` (aposentados — ARQ-02/ARQ-03 — sem consumidores, mas código, `Dockerfile`, `dist/` e `node_modules/` continuam no repo). O orchestrator ainda aceita JWT no formato do identity-bridge.

## 2. O que já existe (não reimplementar)

**CRM no Rails:** pipelines/stages com soft-delete+restore · deals com `position`/`stage_entered_at` · board de 1 request · move/mark_won/mark_lost/reopen/archive/discard · bulk_action · export CSV assíncrono por e-mail · activities + agenda + Google Calendar sync · cadences (enrollments/steps) · loss_reasons · board_views · automation_rules por etapa · checklist_templates · audit_events (admin-only) · lead_scores + recompute · analista determinístico · métricas · triage/from_conversation · lifecycle de contato · LGPD · realtime `crm_deal.*` → ActionCable.

**IA:** Captain (upstream) + orchestrator "Dra. Letícia" (triagem previdenciária determinística + scoring + RAG + LLM + guards de takeover) + 5 skills.

**Frontend CRM:** 17 páginas lazy + ~25 componentes — Kanban DnD, chat drawer no card, score badge, funnel, visões salvas, AI center, analytics, galeria de templates.

**QA:** Playwright em `qa/e2e` (8 specs: health, smoke 8 personas, axe a11y, kanban baseline/realtime, redesign CRM/Captain/shell, templates). **742** specs Ruby + **404** specs JS.

## 3. Risco de conflito com upstream

| Área | Risco | Motivo |
|---|---|---|
| `app/**/crm*`, `javascript/**/crm/*`, 15 migrations `crm_*`, `services/orchestrator` | 🟢 | Namespace próprio; só `schema.rb` por timestamp |
| `config/routes.rb` · `Evolution*` (channel/controller/webhook/service) · sidebar `components-next` · `featureFlags.js` · routes index | 🟡 | Arquivos que o upstream edita com frequência |
| `v3/views/login` · `dashboard/index.html.erb` · branding (`useBranding`, favicon) · `tailwind.config.js`/`theme/`/`_design-tokens.scss` | 🟡 | Rebrand/design sobre arquivos upstream |
| `contact.rb` · `conversation.rb` · `message.rb` · `inbox.rb` (hooks crm_owner/lifecycle/captain) · `Gemfile`/`package.json`/lockfiles | 🔴 | Modelos-núcleo alterados nas duas linhas; upstream tocou exatamente neles em v4.13–4.17 |
| `enterprise/` | — | Proibido; não mergear |

## 4. Inventário de telas

Fonte: `docs/audit/INVENTARIO-ROTAS.md` — **877 rotas Rails**, **161 rotas Vue nomeadas** (149 dashboard + 6 auth + 6 widget); CRM = 16 rotas SPA. Já migradas ao padrão Obsidian+Mineral: dashboard, login, super login, Kanban, inbox, shell. Pendente: expansão aos módulos CRM secundários + auditoria visual completa das 161 rotas.

## 5. Débito técnico (verificado em `main`)

| ID | Item | Evidência |
|---|---|---|
| D-01 | Chunk `DashboardIcon-*.js` **11,0 MB** + `dashboard` **3,0 MB** | `ls -S /app/public/vite/assets` no container — sprite/fonte provavelmente embutida como módulo JS |
| D-02 | Componentes gigantes | `CRMKanbanChatDrawer.vue` 2.198 · `ContactsIndex.vue` 2.183 · `inbox/Settings.vue` 1.861 · `Sidebar.vue` 1.528 · `ReplyBox.vue` 1.467 · `AnalyticsCenter.vue` 1.327 · `ActivitiesOperational.vue` 1.255 · `v3/login/Index.vue` 1.155 · `Cadences.vue` 1.122 linhas |
| D-03 | `deals_controller.rb` 877 linhas (bulk actions + serialização inline) | controller |
| D-04 | **B-01:** "atribuir dono" triplicado com efeitos divergentes (origem do bug A-03) | `contact_owner_router.rb:48-54` só `deal.owner_id` · `deals_controller.rb:756-758` owner+assignee+`contact.crm_owner` · `stage_automation.rb:155-172` owner+assignee condicional sem contact |
| D-05 | **B-03:** automação loga `automation_executed_*` mesmo em no-op | `stage_automation.rb:37-43` log incondicional pós-`case` (só `assign_owner` corrigido) |
| D-06 | Sem `crm_automation_runs` (F3.8) — sem status/erro por execução | ausente em `db/schema.rb` |
| D-07 | `crm-service`/`identity-bridge` mortos com `dist/`+`node_modules/` versionados | raiz do repo |
| D-08 | Orchestrator single-instance: `activeConversations`/`recentWebhookEvents` em `Map` | `agent.ts:73-75` — dedupe/serialização quebram com >1 réplica |
| D-09 | Agente hardcoded `dr-paula-matos`/"Dra. Letícia" apesar de `profile_slug` na tabela | `agent.ts` + `drPaulaMatos.ts` — sem segundo perfil de IA sem refactor |
| D-10 | `llm/client.ts` exige `openrouter.ai` (throw caso contrário) | `llm/client.ts:8-10` |
| D-11 | Node local 25.2.1 vs alvo Node 24 | F0-BASELINE |
| D-12 | `time_in_stage`/`stale_deals`: audit apontou action-name mismatch + N+1 | `metrics_service.rb:47,179` — revalidar na Fase 5 |
| D-13 | QA pendente: TENANCY-P0, CRM-201-01, E2E-P0-00, VISUAL-F0, INTEGRATIONS-F0 | `docs/qa/MATRIZ-COBERTURA.md` |
| D-14 | `bullet` no Gemfile (dev/test) — confirmar ativação em dev | `Gemfile:225` |
| D-15 | `core-vite` watch fora do perfil padrão — assets só em rebuild | compose perfil `frontend-watch` |

## 6. Bugs perceptíveis por leitura (estado atual)

| Bug | Evidência | Sev. |
|---|---|---|
| Auditoria de automação diz "executado" em no-op (B-03) | `stage_automation.rb` — `create_activity` retorna cedo e ainda loga sucesso | S3 |
| Divergência owner/assignee entre os 3 caminhos (B-01) | call sites em D-04 | S2 |
| Audit histórico de `assign_owner` falso pré-hotfix (B-02) | sem correção retroativa — registrar data de corte | S4 |
| Dedupe/serialização do orchestrator não sobrevive a multi-réplica (D-08) | `Map` em memória | S2* |
| Redelivery de webhook 5xx **verificado ok** — dedupe é removido em erro (`agent.ts:727-729`) | — | — |

## 7. Findings do CORE_AUDIT já corrigidos ✅

| Finding | Estado em `main` |
|---|---|
| CSV formula injection no export | ✅ `csv_value` prefixa `'` em `=+-@\t` |
| Metrics sem `authorize` | ✅ `before_action -> { authorize CrmDeal, :index? }` |
| Audit events para todo agente | ✅ policy admin-only |
| `javascript:` em URL de anexo | ✅ `safeAttachmentUrl()` |
| `custom_fields` steer de scoring | ✅ verificar residual na Fase 5 |

## 8. As 10 dores (por impacto no usuário)

1. **Bundle de entrada pesado** — 11 MB + 3 MB de chunks (D-01) penalizam o primeiro load do operador.
2. **Confiança da automação** — auditoria diz "executado" em no-op (B-03) e owner diverge por caminho (B-01): o usuário não pode confiar no que lê.
3. **Chat drawer de 2.198 linhas** concentra chat+anexos+ações — toda mudança no card é arriscada (D-02).
4. **Sem visibilidade de execução de automação** — falta `crm_automation_runs` para "por que aconteceu" e retry (D-06).
5. **Orchestrator não escala nem multi-perfila** — estado em memória + agente único hardcoded (D-08/D-09).
6. **Mortos pesados no repo** — `crm-service`/`identity-bridge` com `node_modules` versionados inflam clone e confundem agentes (D-07).
7. **Tenancy não provada** — invariante cross-account sem teste executado na matriz (D-13).
8. **Sem E2E de fluxos críticos** — jornada Inbox→IA→CRM e grandes volumes sem passagem (D-13).
9. **Design system parcial** — módulos CRM secundários e estados (vazio/erro/offline/densidade) não auditados nas 161 rotas.
10. **Sync upstream é projeto, não rotina** — 756 commits de uma vez; falta cadência e playbook de regressão.

## Dúvidas

1. Sync v4.12.1→v4.17.1 já mergeado em `main` ou segue em branch de entrega? (`VERSION_CW` ainda = 4.12.1.)
2. Existe produção real no host `chusterm-host.conf`? Quantas contas ativas? (muda a prioridade de D-08.)
3. `crm-service`/`identity-bridge` podem ser deletados ou há rotina antiga viva?
4. Teto de gasto de IA por conta tem decisão? (diferencial citado no plano.)
5. Multi-nicho (F5.2) é requisito de venda atual ou o produto segue jurídico-first?

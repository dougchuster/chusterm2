# PLANO — Área de Marketing ChusteRM (Ads, MCPs, IA)

> **Status do projeto**: `FASE 0 — Fundação concluída (este documento)`
> **Última atualização**: 2026-09-16
> **Commit base**: `746c8533aa` (fix overlay kanban)
> **Como usar**: este arquivo é o estado-fonte do projeto. Cada fase tem um
> **Protocolo de Auto-Diagnóstico** — comandos executáveis que provam se a fase
> está completa. Antes de codar qualquer fase, rode o diagnóstico da anterior.
> Ao terminar uma fase, atualize o cabeçalho `Status do projeto` e marque os
> checkboxes `[x]`. Nunca pule uma fase com diagnóstico vermelho.

---

## 1. Visão

Criar dentro do ChusteRM uma **área de Marketing** de primeira classe que:

1. **Conecta contas de anúncios** — Meta Ads (Facebook/Instagram), Google Ads,
   GA4 — via OAuth, reutilizando `CrmExternalConnection` (tokens encriptados,
   provider `google_workspace` já funciona).
2. **Sincroniza dados de patrocinados** — campanhas, ad sets, anúncios, spend,
   impressões, cliques, CPL, conversões — em tabelas próprias, atualizadas por
   jobs Sidekiq. Dados viram cidadãos do CRM (filtros, métricas, drill-down).
3. **Captura leads de anúncios** — Meta Lead Ads via webhook `leadgen` em tempo
   real → cria `Contact` + `CrmDeal` no pipeline certo, com `meta_lead_id`
   persistido (pré-requisito da Conversions API).
4. **Devolve conversões às plataformas** — Meta Conversions API (eventos
   `system_generated` por estágio do funil) e Google Ads offline conversions —
   ensina o algoritmo de leilão com o que fecha de verdade no CRM.
5. **Expõe tudo à IA** — MCP servers (Meta Ads MCP, Google Ads MCP, GA4 MCP)
   conectados via `ruby_llm-mcp` ao RubyLLM que o Captain já usa → o agente
   responde "qual campanha tem melhor CPL?" e executa ações governadas.
6. **Mantém a linguagem** — páginas Vue 3 com `BoardPageTemplate`/`Ds*`,
   tokens `ui-*`/`ds-*`, i18n, feature flag, testes em todas as camadas.

---

## 2. Mapa do sistema atual (o que já existe — NÃO recriar)

### 2.1 Backend (Rails, `core/`)

| Peça | Arquivo | Reuso no Marketing |
|---|---|---|
| Conexão OAuth externa | `app/models/crm_external_connection.rb` | **Estender `PROVIDERS`** com `meta_ads`, `google_ads`, `ga4`. Já encripta `access_token`/`refresh_token`, tem `token_expired?` |
| OAuth Google (funciona) | `app/controllers/api/v1/accounts/crm/google_authorizations_controller.rb` | Mesmo fluxo para Google Ads/GA4 (scopes extras) |
| Integrações legadas | `app/models/integrations/hook.rb`, `integrations/app.rb` | Alternativa para apps simples; preferir `CrmExternalConnection` para OAuth |
| Campanhas broadcast | `app/models/campaign.rb` + `Campaigns::AudienceResolver` + `DeliveryTracker` | Campanhas **outbound** (WhatsApp). NÃO confundir com campanhas de ads |
| Tool HTTP do Captain | `enterprise/app/models/captain/custom_tool.rb` | O Captain já chama endpoints HTTP com auth — fallback quando MCP não servir |
| Tools built-in | `Concerns::Toolable` + `Assistant.built_in_agent_tools` | Registrar tools nativas de marketing (ex: `marketing_spend_summary`) |
| Fila de jobs | Sidekiq (`queue_as :low` para sync pesado) | Sync incremental de métricas |
| Multi-gateway LLM | RubyLLM 1.9.2 + OpenRouter (`LLM_PROVIDER`) | `ruby_llm-mcp` pluga direto |
| Auditoria CRM | `crm_audit_events` | Logar toda escrita em plataforma de ads |

### 2.2 Frontend (Vue 3, `core/app/javascript/dashboard/`)

| Peça | Arquivo | Padrão a seguir |
|---|---|---|
| Rotas CRM | `routes/dashboard/crm/crm.routes.js` | Lazy import + `meta: { featureFlag, permissions }` |
| Sidebar | `components-next/sidebar/Sidebar.vue` (blocos: Atendimento / Vendas-CRM / Automação-IA) | Novo bloco ou item "Marketing" dentro de Vendas |
| Shell de página | `design-system/templates/BoardPageTemplate.vue` | Reusar para lista/detalhe |
| Primitivos | `DsDropdown`, `DsTooltip`, `DsDrawer`, `DsModal`, `DsTable`, `DsDataGrid`, `DsBadge`, `DsEmptyState`, `DsSkeleton` | Obrigatório — sem CSS custom |
| Feature flags | `app/javascript/dashboard/featureFlags.js` (`FEATURE_FLAGS.CRM`, `CRM_V2`) | Adicionar `MARKETING` |
| i18n | `en.json` + `pt_BR` | Sem bare strings |

### 2.3 Infra e QA

- Docker compose (`core` + `sidekiq` + `orchestrator` Node + postgres + redis + evolution-api)
- Deploy: release dir `/opt/chusterm-releases/<tag>/source` + symlink `chusterm-current` + `docker build` + `compose up -d --force-recreate core sidekiq` (atenção: em prod o sidekiq precisa da tag `chusterm-sidekiq:latest`)
- Testes: RSpec, Vitest, Playwright (7 projetos), axe a11y, visual-sweep
- **Regra**: frontend muda → `pnpm exec vite build` → `docker cp` bundle → E2E

---

## 3. Estudo de ferramentas (pesquisa executada em 2026-09)

### 3.1 MCP servers de marketing disponíveis

| Ferramenta | Escopo | Modo | Notas |
|---|---|---|---|
| **`googleads/google-ads-mcp`** (oficial Google) | Google Ads API via GAQL | **Read-only**, stdio, Python | `search`, `list_accessible_customers`, metadata. Hosting em Cloud Run possível. Ideal p/ leitura segura |
| **`googleanalytics/google-analytics-mcp`** (oficial) | GA4 Admin + Data API | stdio, Python | `run_report`, `run_funnel_report`, realtime, custom dims |
| **GA4 remote MCP** (`analyticsdata.googleapis.com/mcp/v1`) | GA4 Data API | **HTTP remoto** — sem processo local | OAuth; o caminho mais simples p/ GA4 |
| **`meta-ads-mcp`** (mikusnuz) | Meta Marketing API v26 | stdio, 135 tools | Campaigns, adsets, ads, creatives, audiences, insights, Ad Library, async reports |
| **`meta-mcp`** (serkanhaslak) | Meta Marketing API | stdio, 77 tools/24 módulos | + Pixel, Conversions API, audit log |
| **`mcp-google-ads`** (mharnett) | Google Ads | stdio, 36 tools | **Write com safeguards** — tudo nasce PAUSED, approval workflow, circuit breaker |
| **`ga4-mcp-server`** (burhan29ee) | GA4 read+write | stdio | Audiences, key events, Measurement Protocol |
| **Composio Rube** (`rube.app/mcp`) | Agregador: Google Ads, Meta, Instantly, Apollo… | HTTP remoto, OAuth gerenciado | Menos controle, mais rápido; avaliar custo/lgpd |

**Decisão**: MCPs são a **camada de IA** (o Captain pergunta/responde/age).
O **sync de dados** para tabelas próprias usa as **APIs diretas** (Graph API,
Google Ads API, GA4 Data API) via services Ruby — mais barato, paginável,
testável, e não depende de processo stdio vivo.

### 3.2 APIs diretas (trilho de dados)

| API | Uso | Auth | Custo de impl. |
|---|---|---|---|
| Meta Marketing API (Graph v25+) | Insights, campanhas, adsets, ads, async reports | `access_token` long-lived (60d) + refresh | Médio — gem `koala` ou Faraday puro |
| Meta Lead Ads webhook `leadgen` | Lead em tempo real | Page token + `leads_retrieval`, `pages_manage_metadata`, `ads_management` | Médio — endpoint + verify token + subscribe |
| Meta Conversions API | Upload de eventos do CRM (funil) | Dataset ID + access token | Baixo — POST de eventos |
| Google Ads API | GAQL queries, métricas, campanhas | Developer token + OAuth `adwords` scope | Alto — protobuf/GAQL; avaliar gem `google-ads-googleads` |
| GA4 Data API | Relatórios de propriedade | Service account ou OAuth | Baixo — REST JSON |

### 3.3 MCP client para o backend

| Opção | Encaixe |
|---|---|
| **`ruby_llm-mcp`** ✅ | Ecossistema RubyLLM (que já usamos). `RubyLLM::MCP.client(transport_type: :stdio/:sse/:streamable)`, `chat.with_tools(*client.tools)`. **Escolhido** |
| `mcp` (ruby-sdk oficial) | `MCP::Client` + transports Stdio/HTTP — alternativa madura |
| `ruby-mcp-client` | Auto-detect de transport — fallback |
| `@modelcontextprotocol/sdk` (Node) | Se MCPs rodarem dentro do orchestrator Node |

---

## 4. Arquitetura alvo

```
┌─────────────────────────── ChusteRM ───────────────────────────┐
│                                                                │
│  Vue "Marketing" (rotas /accounts/:id/marketing/*)             │
│   ├─ Overview (KPIs: spend, leads, CPL, ROAS por provider)     │
│   ├─ Campanhas (lista unificada Meta+Google)                   │
│   ├─ Anúncios/Criativos                                        │
│   ├─ Leads de Ads (leadgen → converter em deal)                │
│   ├─ Conexões (OAuth, status, último sync)                     │
│   └─ Insights IA (Captain analisa / alerta)                    │
│                          │                                     │
│  Rails API  /api/v1/accounts/:id/marketing/*                   │
│   ├─ MarketingAccountsController (conexões)                    │
│   ├─ MarketingCampaignsController / InsightsController         │
│   ├─ MarketingLeadsController                                  │
│   └─ Webhooks::MetaLeadgenController (verify + receive)        │
│                          │                                     │
│  Models: MarketingAccount(≈CrmExternalConnection)              │
│          MarketingCampaign, MarketingMetricSnapshot            │
│          MarketingLead, MarketingEvent                         │
│                          │                                     │
│  Services: Meta::MarketingApi, Google::AdsApi, Ga4::DataApi    │
│  Jobs:     Marketing::SyncMetricsJob (cron, :low)              │
│            Marketing::LeadgenIngestJob, CapiDispatchJob        │
│                          │                                     │
└──────────────┬───────────────────────────────┬─────────────────┘
               │ APIs diretas (sync)           │ MCP (IA)
               ▼                               ▼
        Meta Graph API ────────────► meta-ads-mcp ─┐
        Google Ads API ────────────► google-ads-mcp ├─► ruby_llm-mcp
        GA4 Data API ──────────────► GA4 remote MCP ┘    │
                                              Captain::Assistant
                                              (marketing tools)
```

**Regras de ouro**
1. Nada de dados de ads **só no LLM** — o que alimenta tela entra em tabela.
2. Toda **escrita** em plataforma de ads passa por aprovação (padrão do
   `mcp-google-ads`: criar PAUSED → humano habilita) + `crm_audit_events`.
3. `meta_lead_id` é persistido no `Contact`/`CrmDeal` — sem ele a CAPI não fecha o loop.
4. OAuth por **conta** (multi-tenant): `MarketingAccount` isola tokens/dados.
5. LGPD: dados de lead entram já com `lead_source=meta_lead_ad`, respeitam
   export/erasure existentes; CAPI envia apenas parâmetros hash (SHA-256).

---

## 5. Modelo de dados (migrations novas)

```ruby
marketing_connections        # provider, external_account_id, status,
                             # access_token(enc), refresh_token(enc),
                             # expires_at, scopes[], last_synced_at, sync_error
marketing_campaigns          # connection_id, external_id, provider,
                             # name, status, objective, daily_budget_cents,
                             # currency, raw jsonb, synced_at
marketing_metric_snapshots   # connection_id, campaign_id(FK marketing_),
                             # level(campaign|adset|ad), external_id,
                             # date, spend_cents, impressions, clicks,
                             # conversions, cpl_cents, ctr, cpc, cpm,
                             # raw jsonb  → índice único (conn, level, ext_id, date)
marketing_leads              # account_id, connection_id, meta_lead_id,
                             # contact_id, deal_id, form_id, campaign_ext_id,
                             # field_data jsonb, status(new|converted|discarded)
marketing_events             # direction(in|out), provider, event_name,
                             # payload jsonb, status(sent|failed), external_ref
```

`Contact`/`CrmDeal` ganham `meta_lead_id` (string, index) + `utm jsonb`.

---

## 6. Fases

### FASE 0 — Fundação ✅ (concluída)
Estudo + este documento + inventário do sistema.

**Auto-diagnóstico**: arquivo existe e você está lendo.

---

### FASE 1 — Conexões OAuth (`marketing_connections`) `2-3 dias` ✅ `e9b9e06a`

**Entregáveis**
- Migration `marketing_connections` + model `Marketing::Connection`
  (reusar lógica de `CrmExternalConnection`: `encrypts`, `token_expired?`)
- `PROVIDERS = %w[google_workspace meta_ads google_ads ga4]`
- `Api::V1::Accounts::Marketing::ConnectionsController` (index/create/destroy/sync_now)
- OAuth Meta: `meta_authorizations_controller` (espelho do google_authorizations)
  — scopes: `ads_read`, `ads_management`, `leads_retrieval`, `pages_manage_metadata`,
  `pages_show_list`, `pages_read_engagement`, `business_management`
- OAuth Google estendido: scopes `adwords` + `analytics.readonly`
- Refresh job `Marketing::RefreshTokensJob` (diário, troca expiring)
- Página **Marketing > Conexões**: cards por provider, botão "Conectar",
  status (ativo/erro/expirando), "Sincronizar agora"
- Feature flag `marketing` (sidebar + rotas gated)

**Auto-diagnóstico**
```bash
docker exec chusterm-core-1 bundle exec rails runner "puts Marketing::Connection.count"          # roda sem erro = migration ok
curl -s http://localhost:8086/api/v1/accounts/55/marketing/connections -H "api_access_token: $T" | jq .   # 200 + []
# UI: sidebar mostra "Marketing" → Conexões; fluxo OAuth retorna com status=active
bundle exec rspec spec/models/marketing spec/requests/api/v1/accounts/marketing  # verde
```

**Riscos**: app Meta precisa de App Review p/ `leads_retrieval` em produção
(modo dev funciona com admins do app). Google Ads precisa **developer token**
(aplicar cedo — leva dias).

---

### FASE 2 — Sync de campanhas e métricas `3-4 dias` ✅ `6597cccf`

**Entregáveis**
- `Marketing::Meta::GraphClient` (Faraday, paginação cursored, rate-limit backoff)
- `Marketing::GoogleAds::Client` (GAQL mínimo: campanhas + métricas)
- `Marketing::Sync::CampaignsService` → upsert `marketing_campaigns`
- `Marketing::Sync::MetricsService` → upsert `marketing_metric_snapshots`
  (insights level=campaign/adset/ad, `date_preset` + range diário)
- `Marketing::SyncAccountJob` por conexão; `Marketing::SyncAllJob` a cada 6h
- Idempotência: unique index `(connection_id, level, external_id, date)`
- Página **Marketing > Campanhas**: DsDataGrid unificado (provider badge,
  status, spend, impressões, CTR, CPC, leads, CPL), filtro por período/
  provider/status; drill-down → adsets/ads
- Página **Overview**: cards KPI + série temporal (spend × leads)

**Auto-diagnóstico**
```bash
docker exec chusterm-core-1 bundle exec rails runner "
  c = Marketing::Connection.active.first
  Marketing::SyncAccountJob.perform_now(c.id)
  puts MarketingCampaign.where(marketing_connection_id: c.id).count"   # > 0
# UI: /marketing/campaigns lista campanhas reais; trocar período recarrega
pnpm exec vitest run app/javascript/dashboard/routes/dashboard/marketing  # verde
```

**Riscos**: Google Ads API exige developer token aprovado; sem ele, FASE 2
entrega só Meta (não bloquear — marcar Google como "pendente credencial").

---

### FASE 3 — Lead Ads → CRM (o coração) `3-4 dias`

**Entregáveis**
- `Webhooks::MetaLeadgenController`:
  - `GET` verify (`hub.mode`, `hub.verify_token`, `hub.challenge`)
  - `POST` recebe `entry[].changes[field=leadgen]` → enfileira
    `Marketing::LeadgenIngestJob` (nunca processa inline)
- Job busca o lead na Graph API (`/{leadgen_id}`) → normaliza field_data
  → cria/atualiza `Contact` (telefone/email) + `MarketingLead` +
  `CrmDeal` no pipeline configurado por formulário (`form_mappings`)
- `meta_lead_id` no Contact/Deal + dedup por `leadgen_id`
- Página **Marketing > Leads de Ads**: lista leads, origem (campanha/form),
  status, ação "Converter em negócio"/"Vincular contato"
- Toast/realtime quando lead chega (ActionCable, mesmo canal do kanban)
- Opcional: auto-iniciar conversa WhatsApp (Evolution) — **flag off por
  padrão** (consentimento LGPD)

**Auto-diagnóstico**
```bash
# Simular webhook local:
curl -X POST localhost:8086/webhooks/meta/leadgen -d @spec/fixtures/leadgen.json
docker exec chusterm-core-1 bundle exec rails runner "puts MarketingLead.count"  # +1
# Meta: POST /{page-id}/subscribed_apps com subscribed_fields=leadgen — 200
# UI: lead aparece em segundos; converter cria deal na coluna certa do kanban
```

**Riscos**: webhook exige HTTPS público → configurar no app Meta com o domínio
de prod; testar local com túnel (ngrok/cloudflared) ou fixture.

---

### FASE 4 — Conversions API (fechar o loop) `2-3 dias`

**Entregáveis**
- `Marketing::Meta::CapiService` — POST `/datasets/{id}/events`:
  - `event_name` = estágio do funil (`lead`, `qualified`, `won`, `lost`)
  - `action_source: 'system_generated'`, `event_time`, `lead_event_source`,
    `user_data` com **SHA-256** de phone/email + `meta_lead_id`
- Hook em `CrmDeal` (stage_changed) → `Marketing::CapiDispatchJob`
- Dedup por `event_id` (deal_id + stage + timestamp)
- Google Ads offline conversions (upload click/conversion quando existir
  `gclid`/`wbraid` no contato) — pode virar FASE 4b se credencial atrasar
- Página: **Conexões > Aba "Eventos"** — log `marketing_events` com status
  sent/failed + retry

**Auto-diagnóstico**
```bash
# Mover um deal de estágio e conferir:
docker exec chusterm-core-1 bundle exec rails runner \
  "puts MarketingEvent.outbound.sent.where(provider: 'meta').count"     # > 0
# Meta Events Manager → dataset mostra eventos "system_generated"
bundle exec rspec spec/services/marketing/meta/capi_service_spec.rb
```

**Riscos**: Meta exige ~200 leads/mês p/ learning efetivo; eventos antigos
>7 dias são rejeitados (só enviar em tempo real).

---

### FASE 5 — MCPs + Captain (camada de IA) `3-4 dias`

**Entregáveis**
- Gem `ruby_llm-mcp` + `config/initializers/mcp_marketing.rb`:
  registry por conta de servers ativos (streamable-http preferido;
  stdio apenas em dev)
- **Self-host `meta-ads-mcp`** como serviço (container `mcp-meta-ads`)
  com `META_ACCESS_TOKEN` da conexão — expõe streamable-http interno
- GA4 via **remote MCP** `analyticsdata.googleapis.com/mcp/v1` (OAuth)
- Google Ads MCP (`googleads-mcp`, read-only) em container próprio
- `Captain::MarketingTools` built-ins (padrão `Concerns::Toolable`):
  - `marketing_spend_summary(period, provider)`
  - `marketing_top_campaigns(metric, limit)`
  - `marketing_lead_funnel(pipeline_id)`
  → leem as **tabelas locais** (rápido, sem rate-limit), não os MCPs
- MCPs reservados a perguntas ad-hoc ("breakdown por idade", "search terms")
  que as tabelas não cobrem
- Página **Marketing > Insights IA**: chat scoped ao contexto de marketing
  (reusa componente do Captain Playground) + cards de alertas automáticos
  (anomalia de CPL, campanha sem impressões, budget estourando)

**Auto-diagnóstico**
```bash
docker exec chusterm-core-1 bundle exec rails runner "
  RubyLLM::MCP.establish_connection do |c|
    puts c.tools.map(&:name).grep(/insight|campaign/).count
  end"                                                              # > 0
# Captain playground: "quanto gastamos no Meta essa semana?" → resposta
# com números reais das tabelas/MCP
```

**Riscos**: MCPs stdio em container são frágeis — preferir streamable-http;
se `ruby_llm-mcp` conflitar com a versão do RubyLLM, isolar em serviço Node
(orchestrator já é Node — `@modelcontextprotocol/sdk` lá dentro).

---

### FASE 6 — Automação e governança `2-3 dias`

**Entregáveis**
- Automações CRM novas (reusa `crm_automation_rules`):
  - gatilho `marketing_lead.created` → atribuir responsável, cadência, score
  - gatilho `campaign.cpl_above_threshold` → notificar + sugerir pausa
- Pausar/retomar campanha pela UI = **escrita MCP/API gated**:
  sempre PAUSED→review, log em `crm_audit_events`, confirmação no DsModal
- Relatório semanal automático (job → conversa WhatsApp/email do gestor)
- LGPD: CAPI só envia dados com consent flag; export/erasure cobrem
  `marketing_leads`

**Auto-diagnóstico**
```bash
bundle exec rspec spec/models/crm_automation_rule  # novos gatilhos verdes
# Pausar campanha na UI → confere audit event + estado PAUSED na Meta
```

---

### FASE 7 — Hardening + deploy `1-2 dias`

- Suite completa: RSpec novos + Vitest + Playwright `marketing-*.spec.ts`
  (conexões, campanhas, leads, overlay regressions) nos 7 projetos
- axe a11y nas páginas novas + visual-sweep light/dark
- Rate-limit guards + circuit breaker nos clients de API
- Deploy staging → prod (release dir + backup + `--force-recreate`)
- Rollback: flag `marketing` off + rollback tag de imagem

---

## 7. Protocolo de progressão (como o agente usa este arquivo)

1. **Antes de codar**: leia o cabeçalho `Status do projeto` → encontre a
   primeira fase não-marcada `[x]` → rode o **Auto-diagnóstico** da fase
   anterior. Se falhar, a fase anterior não terminou — volte nela.
2. **Durante**: trabalhe só nos entregáveis da fase atual. Descobriu bug
   fora do escopo? Anote em `§8 Débitos` e continue.
3. **Ao terminar**: rode o auto-diagnóstico da fase → só marque `[x]` com
   TODOS os itens verdes → atualize o cabeçalho `Status do projeto` com
   `FASE N concluída @ <data> (<commit>)` → commite com
   `feat(marketing): ...` → prossiga.
4. **Nunca** proclame fase completa sem evidência do diagnóstico.
5. Credenciais externas faltando (developer token Google, app Meta
   aprovado)? Registre em `§9 Bloqueios externos` e siga a parte da fase
   que não depende delas.

## 8. Débitos conhecidos

- `docker-compose.prod.yml` de prod referencia `crm-service`/`identity-bridge`
  (serviços removidos do repo) e `build.context: ./core` aponta para source
  antigo em `/opt/chusterm` — padronizar `image:` + contexto do release.
- `public/vite` acumula assets entre builds (sem `emptyOutDir`) — limpar no CI.

## 9. Bloqueios externos (credenciais)

| Credencial | Onde obter | Bloqueia |
|---|---|---|
| Meta App + App Review (`leads_retrieval`) | developers.facebook.com | FASE 3 prod (dev funciona sem) |
| Google Ads developer token | Google Ads API Center | FASE 2 Google (Meta não) |
| GA4 service account / OAuth | Google Cloud Console | FASE 2/5 GA4 |
| Domínio HTTPS p/ webhook Meta | nginx prod | FASE 3 prod |

## 10. Apêndice — comandos úteis

```bash
# build + sync frontend local p/ testes E2E
cd core && pnpm exec vite build
MSYS_NO_PATHCONV=1 docker exec chusterm-core-1 sh -c 'find /app/public/vite -mindepth 1 -delete'
docker cp 'C:/Users/dougc/Documents/Projetos/ChusteRM/core/public/vite/.' chusterm-core-1:/app/public/vite/

# E2E marketing (quando existir)
cd qa/e2e && QA_FIXTURE_PASSWORD='QaFixture#2026!' QA_ACCOUNT_ID=55 \
  pnpm exec playwright test tests/marketing-*.spec.ts --project=chromium-desktop

# SSH produção usa chave explícita
ssh -i ~/.ssh/root_kvm4_ed25519 root@187.77.255.211
```

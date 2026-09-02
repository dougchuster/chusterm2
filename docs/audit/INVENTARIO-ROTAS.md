# Inventário estático de telas e rotas — Fase 0

Data da leitura: **2026-07-09**. Fonte: worktree atual de `core/`, incluindo alterações ainda não commitadas. Este documento inventaria superfícies endereçáveis; modais, drawers e estados internos sem URL precisam de um inventário de componentes separado na auditoria visual/funcional.

## Método, legenda e números

Fontes canônicas inspecionadas:

- Rails: `core/config/routes.rb`, tabela carregada por `bundle exec rails routes`, controllers e views dos endpoints HTML.
- Dashboard Vue: `core/app/javascript/dashboard/routes/index.js` e 34 arquivos `routes.js`/`*.routes.js` agregados por `dashboard.routes.js`.
- Autenticação Vue: `core/app/javascript/v3/views/routes.js`.
- Widget Vue: `core/app/javascript/widget/router.js`.

Legenda de acesso (as permissões de uma lista são avaliadas como **OU**, não como E):

| Código | Significado |
|---|---|
| `P-CONV` | `administrator`, `agent`, `conversation_manage`, `conversation_unassigned_manage` ou `conversation_participating_manage` |
| `P-ALL` | `administrator`, `agent` ou `custom_role` |
| `P-CRM` | `administrator`, `agent` ou `contact_manage` |
| `P-REPORT` | `administrator` ou `report_manage` |
| `P-KB` | `administrator`, `agent` ou `knowledge_base_manage` |
| `P-KB-ADMIN` | `administrator` ou `knowledge_base_manage` |
| `P-ADMIN` | somente `administrator` |
| `F:x` | metadado `featureFlag: x` |
| `I:x` | instalação declarada em `installationTypes` |
| `VA-A` | **exige auditoria visual autenticada** na aplicação/conta |
| `VA-SA` | **exige auditoria visual autenticada como super-admin** |
| `VA-P` | auditoria visual pública ou pré-login |
| `VA-C` | auditoria visual condicional/transitória |

Resumo reproduzível:

| Superfície | Arquivos | Declarações `path` | Rotas nomeadas efetivas | Observação |
|---|---:|---:|---:|---|
| Dashboard Vue | 34 | 197 | 149 | 143 renderizam componente; 6 são redirects nomeados |
| Auth Vue v3 | 1 | 6 | 6 | pré-login |
| Widget Vue | 1 | 7 | 6 | 1 wrapper sem nome + 6 destinos hash |
| **Total Vue** | **36** | **210** | **161** | 155 destinos nomeados com componente |
| Rails | 1 fonte principal | **877 route records** | n/a | inclui APIs, webhooks, engines e rotas HTML |

Distribuição dos 877 registros Rails pelo prefixo da URL (categorias mutuamente exclusivas usadas nesta leitura):

| Grupo | Registros |
|---|---:|
| `/api/*` | 598 |
| `/enterprise/api/*` | 13 |
| `/platform/api/*` | 24 |
| `/public/api/*` | 25 |
| `/webhooks/*` | 15 |
| `/super_admin*` | 74 |
| `/app*` | 22 |
| `/auth*` e `/omniauth*` | 28 |
| `/rails/*` | 30 |
| Outros (HTML público, callbacks, monitoramento etc.) | 48 |

Comandos de reprodução (PowerShell, a partir da raiz do repositório):

```powershell
$routeFiles = Get-ChildItem core/app/javascript -Recurse -File |
  Where-Object { $_.Name -match '(^routes\.js$|\.routes\.js$|router\.js$)' }
$pathCount = ($routeFiles | ForEach-Object {
  ([regex]::Matches((Get-Content -Raw $_.FullName), '(?m)^\s*path:\s*')).Count
} | Measure-Object -Sum).Sum
"files=$($routeFiles.Count) path_declarations=$pathCount"

Set-Location core
bundle exec rails runner "require 'json'; r=Rails.application.routes.routes; g=r.group_by{|x| p=x.path.spec.to_s; p.start_with?('/api/') ? 'api' : p.start_with?('/enterprise/api/') ? 'enterprise_api' : p.start_with?('/platform/api/') ? 'platform_api' : p.start_with?('/public/api/') ? 'public_api' : p.start_with?('/webhooks/') ? 'webhooks' : p.start_with?('/super_admin') ? 'super_admin' : p.start_with?('/rails/') ? 'rails_internal' : p.start_with?('/app') ? 'app_shell' : p.start_with?('/auth') || p.start_with?('/omniauth') ? 'auth' : 'other'}; puts JSON.pretty_generate(total:r.size,groups:g.transform_values(&:size))"
```

> Nota sobre gates: o `beforeEach` global do dashboard valida login, associação à conta, status da conta e `meta.permissions`. `featureFlag` e `installationTypes` são usados por `usePolicy`/sidebar para visibilidade, mas não são bloqueios globais de acesso direto à URL. Por isso os metadados abaixo devem ser testados tanto pela navegação quanto por deep link.

## Rotas Rails que entregam UI

### Shell, autenticação, widget e páginas públicas

| Rota Rails | Entrypoint/controller | Propósito inferível | Acesso / auditoria |
|---|---|---|---|
| `GET /` | `DashboardController#index` → `app/views/dashboard/index.html.erb` | Entrada principal; dashboard ou onboarding | sessão decidida no Vue; `VA-P` e `VA-A` |
| `GET /app` | mesmo shell | Entrada explícita da SPA | `VA-A` |
| `GET /app/*params` | mesmo shell | Fallback de history mode para todas as rotas Vue | `VA-A` (ou pré-login em `/app/login`/`auth/*`) |
| `GET /app/accounts/:account_id/settings/inboxes/new/{twitter,microsoft,instagram,tiktok}` | `DashboardController#index` | Helpers de deep link/OAuth de canais; o wildcard anterior já entrega o mesmo shell | `VA-A`, admin |
| `GET /app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents` (4 helpers com o mesmo padrão) | `DashboardController#index` | Retorno das criações Twitter/e-mail/Instagram/TikTok para seleção de agentes | `VA-A`, admin |
| `GET /app/accounts/:account_id/settings/inboxes/:inbox_id` (3 helpers com o mesmo padrão) | `DashboardController#index` | Retorno às configurações de Instagram/TikTok/e-mail | `VA-A`, admin |
| `GET /manager/login` | `EvoManagerController#login` → `evo_manager/login.html.erb` | Login próprio do gerenciador Evolution | credencial de super-admin; `VA-P` |
| `POST /manager/login` | `EvoManagerController#authenticate` → `evo_manager/bridge.html.erb` | Valida super-admin e cria bridge para Evolution Manager | credencial válida; `VA-C` |
| `GET /widget` | `WidgetsController#show` → `widgets/show.html.erb` | Shell do chat web incorporável | público com `website_token`; `VA-P` |
| `GET /survey/responses/:id` | `Survey::ResponsesController#show` → `survey/responses/show.html.erb` | Página pública de CSAT | id/token de pesquisa; `VA-P` |
| `GET /slack_uploads` | `SlackUploadsController#show` | Redirect para blob/avatar usado pelo Slack; não renderiza tela | `VA-C`, sem captura visual estável |
| `GET /installation/onboarding` | `Installation::OnboardingController#index` → `installation/onboarding/index.html.erb` | Criação inicial de conta e super-admin | somente instalação pendente; `VA-C` |
| `GET /swagger` e `/swagger/*path` | `SwaggerController#respond` | Documentação da API | conforme exposição da instalação; `VA-P` |
| `/monitoring/sidekiq` | `Sidekiq::Web` | Operação/filas | super-admin autenticado; `VA-SA` |
| `GET /widget_tests` | `WidgetTestsController#index` → `widget_tests/index.html.erb` | Harness manual do widget | somente fora de produção; `VA-C` |

O mount `devise_token_auth` também declara páginas GET em `/auth/sign_in`, `/auth/password/new`, `/auth/password/edit`, `/auth/cancel`, `/auth/sign_up`, `/auth/edit`, `/auth/confirmation/new` e `/auth/confirmation`. `/auth/validate_token`, `/auth/failure`, `/auth/:provider`, `/auth/:provider/callback` e `/omniauth/*` são validação/redirect, não telas estáveis. A UI primária do produto usa as rotas Vue `/app/login` e `/app/auth/*`; as páginas Devise devem ser verificadas como fallback/fluxo de e-mail (`VA-P`), não confundidas com a SPA.

### Help center público renderizado pelo Rails

Entrypoint comum: controllers `Public::Api::V1::Portals*`, layout `portal` e views HTML em `app/views/public/api/v1/portals/`.

| Rota | Propósito | Auditoria |
|---|---|---|
| `GET /hc/:slug` | Resolve portal e redireciona para o locale padrão | `VA-P` |
| `GET /hc/:slug/:locale` | Home pública do portal | `VA-P` |
| `GET /hc/:slug/:locale/articles` | Busca/lista de artigos | `VA-P` |
| `GET /hc/:slug/:locale/categories` | Lista de categorias | `VA-P` |
| `GET /hc/:slug/:locale/categories/:category_slug` | Página de categoria | `VA-P` |
| `GET /hc/:slug/:locale/categories/:category_slug/articles` | Artigos filtrados por categoria | `VA-P` |
| `GET /hc/:slug/articles/:article_slug` | Artigo público | `VA-P` |
| `GET /hc/:slug/sitemap.xml` | Sitemap; não visual | funcional |
| `GET /hc/:slug/articles/:article_slug.png` | Pixel de visualização; não visual | funcional |

O `DashboardController#index` também pode renderizar a home do portal em domínio customizado; essa variante precisa de `VA-P` com host real, além dos caminhos `/hc/*`.

### Callbacks e rotas Rails legadas

| Padrão | Propósito | Auditoria |
|---|---|---|
| `GET /twitter/callback`, `/linear/callback`, `/shopify/callback`, `/microsoft/callback`, `/google/callback`, `/instagram/callback`, `/tiktok/callback`, `/notion/callback` | Retorno OAuth de integrações/canais | `VA-C`; testar sucesso, erro e redirect final autenticado |
| `GET /crm/google/callback` | Retorno OAuth da agenda Google do CRM | `VA-C`; conta autenticada + consentimento externo |
| `GET /app/accounts/:account_id/conversations/:id` | Helper de link em e-mail | o wildcard `/app/*params` anterior entrega o Vue; `VA-A` |
| rotas REST GET de `/app/accounts`, `/app/accounts/new`, `/app/accounts/:id`, `/app/accounts/:id/edit` | Recursos Rails legados | estão depois de `/app/*params` e são sombreados para GET; validar se devem ser removidos |

`/health`, `/api`, APIs JSON, webhooks, Active Storage e Action Mailbox não são telas. Permanecem no escopo de auditoria funcional/segurança, não da passagem visual.

### Super-admin Rails

Entrypoint comum: controllers `SuperAdmin::*`, layout `layouts/super_admin/application.html.erb` e views Administrate/overrides em `app/views/super_admin/`. Todas as telas internas abaixo exigem `VA-SA`.

| Rotas GET | Propósito |
|---|---|
| `/super_admin/sign_in`, `/password/new`, `/password/edit`, `/cancel`, `/sign_up`, `/edit`, `/confirmation/new`, `/confirmation` | Login, recuperação, registro/edição e confirmação (`VA-P` até autenticar) |
| `/super_admin` | Dashboard da instalação |
| `/super_admin/app_config` | Configuração global do app |
| `/super_admin/accounts`, `/accounts/new`, `/accounts/:id`, `/accounts/:id/edit` | Listar, criar, ver e editar contas |
| `/super_admin/users`, `/users/new`, `/users/:id`, `/users/:id/edit` | Listar, criar, ver e editar usuários |
| `/super_admin/access_tokens`, `/access_tokens/:id` | Tokens de acesso |
| `/super_admin/installation_configs`, `/installation_configs/new`, `/installation_configs/:id`, `/installation_configs/:id/edit` | Configurações da instalação |
| `/super_admin/agent_bots`, `/agent_bots/new`, `/agent_bots/:id`, `/agent_bots/:id/edit` | Bots globais |
| `/super_admin/platform_apps`, `/platform_apps/new`, `/platform_apps/:id`, `/platform_apps/:id/edit` | Apps de plataforma |
| `/super_admin/instance_status` | Saúde/estado da instância |
| `/super_admin/settings`, `/super_admin/settings/refresh` | Informações e atualização de settings |
| `/super_admin/account_users/new`, `/account_users/:id` | Associação usuário–conta |

Rotas de criação/edição por `POST/PATCH/PUT/DELETE`, seed, reset de cache, avatar e logout são ações das telas acima, não novas telas.
Os endpoints `/omniauth/google_oauth2`, `/omniauth/google_oauth2/callback`, `/omniauth/saml` e `/omniauth/saml/callback` são transições de autenticação, não páginas persistentes; validar redirects e erros como `VA-C`.

## Vue — autenticação e widget

### Autenticação v3

Fonte: `core/app/javascript/v3/views/routes.js`. O shell Rails seleciona o pack `v3app` quando o caminho contém `/auth` ou `/login`.

| Rota (`name`) | Componente | Propósito / gate | Auditoria |
|---|---|---|---|
| `/app/login` (`login`) | `login/Index.vue` | Login por e-mail/OAuth e retorno SSO por query | `VA-P` |
| `/app/login/sso` (`sso_login`) | `login/Saml.vue` | Login SAML; `requireEnterprise` | `VA-P` |
| `/app/auth/signup` (`auth_signup`) | `auth/signup/Index.vue` | Cadastro; `requireSignupEnabled` | `VA-P` |
| `/app/auth/confirmation` (`auth_confirmation`) | `auth/confirmation/Index.vue` | Confirmação por token; `ignoreSession` | `VA-P` |
| `/app/auth/password/edit` (`auth_password_edit`) | `auth/password/Edit.vue` | Definição de senha por token; `ignoreSession` | `VA-P` |
| `/app/auth/reset/password` (`auth_reset_password`) | `auth/reset/password/Index.vue` | Solicitação de reset | `VA-P` |

### Widget

Fonte: `core/app/javascript/widget/router.js`. URL completa: `/widget?website_token=...#/<rota>`; o roteador usa hash history. Wrapper: `components/layouts/ViewWithHeader.vue`.

| Hash route (`name`) | Componente | Propósito | Auditoria |
|---|---|---|---|
| `#/` (`home`) | `views/Home.vue` | Home/launcher expandido | `VA-P`, token de inbox |
| `#/unread-messages` (`unread-messages`) | `views/UnreadMessages.vue` | Lista de não lidas | `VA-P`, estado com mensagens |
| `#/campaigns` (`campaigns`) | `views/Campaigns.vue` | Campanha ativa do widget | `VA-P`, campanha configurada |
| `#/prechat-form` (`prechat-form`) | `views/PreChatForm.vue` | Formulário pré-chat | `VA-P`, pre-chat habilitado |
| `#/messages` (`messages`) | `views/Messages.vue` | Conversa do visitante | `VA-P`, conversa criada |
| `#/article` (`article-viewer`) | `views/ArticleViewer.vue` | Artigo do help center dentro do widget | `VA-P`, artigo/portal configurados |

## Vue — dashboard autenticado

Todas as rotas desta seção passam pelo shell `Dashboard.vue`, exigem sessão e, quando têm `:accountId`, associação à conta ativa. Use `VA-A` em todas; `account_suspended` e `no_accounts` exigem fixtures próprias.

### Entrada, conversas, inbox-view e notificações

Fontes: `dashboard.routes.js`, `conversation/conversation.routes.js`, `inbox/routes.js` e `notifications/routes.js`. Componente principal das conversas: `conversation/ConversationView.vue`.

| Rota (`name`) | Componente | Propósito | Gate / VA |
|---|---|---|---|
| `/app/accounts/:accountId/suspended` (`account_suspended`) | `suspended/Index.vue` | Conta suspensa | `P-ALL`; `VA-A` |
| `/app/no-accounts` (`no_accounts`) | `noAccounts/Index.vue` | Usuário autenticado sem conta | sessão sem contas; `VA-A` |
| `/app/accounts/:accountId/dashboard` (`home`) | `ConversationView.vue` | Inbox geral | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/conversations/:conversation_id` (`inbox_conversation`) | `ConversationView.vue` | Conversa direta | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/inbox/:inbox_id` (`inbox_dashboard`) | `ConversationView.vue` | Conversas de uma caixa | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/inbox/:inbox_id/conversations/:conversation_id` (`conversation_through_inbox`) | `ConversationView.vue` | Conversa preservando filtro de caixa | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/label/:label` (`label_conversations`) | `ConversationView.vue` | Conversas por label | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/label/:label/conversations/:conversation_id` (`conversations_through_label`) | `ConversationView.vue` | Conversa no contexto da label | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/team/:teamId` (`team_conversations`) | `ConversationView.vue` | Conversas por time | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/team/:teamId/conversations/:conversationId` (`conversations_through_team`) | `ConversationView.vue` | Conversa no contexto do time | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/custom_view/:id` (`folder_conversations`) | `ConversationView.vue` | Visão/filtro salvo | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/custom_view/:id/conversations/:conversation_id` (`conversations_through_folders`) | `ConversationView.vue` | Conversa na visão salva | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/mentions/conversations` (`conversation_mentions`) | `ConversationView.vue` | Conversas com menções | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/mentions/conversations/:conversationId` (`conversation_through_mentions`) | `ConversationView.vue` | Detalhe vindo de menções | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/unattended/conversations` (`conversation_unattended`) | `ConversationView.vue` | Conversas sem atendimento | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/unattended/conversations/:conversationId` (`conversation_through_unattended`) | `ConversationView.vue` | Detalhe vindo de não atendidas | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/participating/conversations` (`conversation_participating`) | `ConversationView.vue` | Conversas em que o agente participa | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/participating/conversations/:conversationId` (`conversation_through_participating`) | `ConversationView.vue` | Detalhe vindo de participando | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/inbox-view` (`inbox_view`) | `inbox/InboxEmptyState.vue` | Inbox alternativa sem seleção | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/inbox-view/:type/:id` (`inbox_view_conversation`) | `inbox/InboxView.vue` | Inbox alternativa com item selecionado | `P-CONV`; `VA-A` |
| `/app/accounts/:accountId/notifications` (`notifications_index`) | `notifications/components/NotificationsView.vue` | Central de notificações | `P-ALL`; `VA-A` |

### Contatos, empresas e busca

Fontes: `contacts/routes.js`, `companies/routes.js` e `dashboard/modules/search/search.routes.js`. Wrappers: `ContactsDashboardLayout.vue`, `ContactManageView.vue` e `CompaniesIndex.vue`.

| Rota (`name`) | Componente | Propósito | Gate / VA |
|---|---|---|---|
| `/app/accounts/:accountId/contacts` (`contacts_dashboard_index`) | `ContactsIndex.vue` | Lista principal | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/segments/:segmentId` (`contacts_dashboard_segments_index`) | `ContactsIndex.vue` | Lista por segmento | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/labels/:label` (`contacts_dashboard_labels_index`) | `ContactsIndex.vue` | Lista por label | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/categories` (`contacts_dashboard_categories`) | `ContactCategoriesPage.vue` | Navegação de categorias | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/categories/:kind` (`contacts_dashboard_category_kind`) | `ContactCategoriesPage.vue` | Categoria por tipo | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/categories/:kind/:categoryId` (`contacts_dashboard_category_detail`) | `ContactCategoriesPage.vue` | Detalhe de categoria | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/list` (`contacts_dashboard_list`) | `ContactsIndex.vue` | Alias explícito da lista | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/active` (`contacts_dashboard_active`) | redirect | Alias legado → lista, página 1 | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/:contactId` (`contacts_edit`) | `ContactManageView.vue` | Perfil/detalhe do contato | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/:contactId/segments/:segmentId` (`contacts_edit_segment`) | `ContactManageView.vue` | Contato preservando segmento | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/contacts/:contactId/labels/:label` (`contacts_edit_label`) | `ContactManageView.vue` | Contato preservando label | `P-CRM`; `F:crm`; `VA-A` |
| `/app/accounts/:accountId/companies` (`companies_dashboard_index`) | `companies/pages/CompaniesIndex.vue` | Lista/gestão de empresas | admin ou agent; `F:companies`; `I:cloud,enterprise`; `VA-A` |
| `/app/accounts/:accountId/search/:tab?` (`search`) | `search/components/SearchView.vue` | Busca global por domínio/tab | roles + permissões de conversa/contato/KB; `VA-A` |

### CRM, pipeline e vendas

Fonte: `core/app/javascript/dashboard/routes/dashboard/crm/crm.routes.js`. Todas as rotas usam `F:crm`.

| Rota (`name`) | Componente | Propósito | Gate / VA |
|---|---|---|---|
| `/app/accounts/:accountId/crm` (`crm_dashboard`) | `pages/CrmIndex.vue` | Kanban/pipeline principal | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/leads` (`crm_all_leads`) | `pages/AllLeads.vue` | Lista de leads/negócios | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/deals/:dealId` (`crm_deal_details`) | `pages/DealDetails.vue` | Detalhe do negócio | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/activities` (`crm_activities`) | `pages/Activities.vue` | Atividades/follow-ups | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/agenda` (`crm_agenda`) | `pages/Agenda.vue` | Agenda e calendário | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/metrics` (`crm_metrics`) | `pages/CrmMetrics.vue` | Métricas resumidas | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/ai-center` (`crm_ai_center`) | `pages/AiCenter.vue` | Centro operacional da IA/CAPITÃO | `P-CRM`; `VA-A` |
| `/app/accounts/:accountId/crm/reports` (`crm_reports`) | `pages/Reports.vue` | Relatórios comerciais | `P-ADMIN`; `VA-A` |
| `/app/accounts/:accountId/crm/settings/pipelines` (`crm_pipeline_settings`) | `pages/PipelineSettings.vue` | Pipelines e etapas | `P-ADMIN`; `VA-A` |
| `/app/accounts/:accountId/crm/settings/loss-reasons` (`crm_loss_reasons`) | `pages/LossReasons.vue` | Motivos de perda | `P-ADMIN`; `VA-A` |
| `/app/accounts/:accountId/crm/settings/checklist-templates` (`crm_checklist_templates`) | `pages/ChecklistTemplates.vue` | Templates de checklist | `P-ADMIN`; `VA-A` |
| `/app/accounts/:accountId/crm/settings/automation-rules` (`crm_automation_rules`) | `pages/AutomationRules.vue` | Automações do CRM | `P-ADMIN`; `VA-A` |
| `/app/accounts/:accountId/crm/settings/cadences` (`crm_cadences`) | `pages/Cadences.vue` | Cadências de contato | `P-ADMIN`; `VA-A` |
| `/app/accounts/:accountId/crm/settings/scoring` (`crm_scoring_config`) | `pages/ScoringConfig.vue` | Regras de lead scoring | `P-ADMIN`; `VA-A` |

### Campanhas

Fonte: `campaigns/campaigns.routes.js`; wrapper `CampaignsPageRouteView.vue`.

| Rota (`name`) | Componente | Propósito | Gate / VA |
|---|---|---|---|
| `/app/accounts/:accountId/campaigns/ongoing` (`campaigns_ongoing_index`) | redirect para live chat | Alias de campanhas contínuas | `P-ADMIN`; `F:campaigns`; `VA-A` |
| `/app/accounts/:accountId/campaigns/one_off` (`campaigns_one_off_index`) | redirect para SMS | Alias de campanhas avulsas | `P-ADMIN`; `F:campaigns`; `VA-A` |
| `/app/accounts/:accountId/campaigns/live_chat` (`campaigns_livechat_index`) | `pages/LiveChatCampaignsPage.vue` | Campanhas de live chat | `P-ADMIN`; `F:campaigns`; `VA-A` |
| `/app/accounts/:accountId/campaigns/sms` (`campaigns_sms_index`) | `pages/SMSCampaignsPage.vue` | Campanhas SMS | `P-ADMIN`; `F:campaigns`; `VA-A` |
| `/app/accounts/:accountId/campaigns/email` (`campaigns_email_index`) | `pages/EmailCampaignsPage.vue` | Campanhas e-mail | `P-ADMIN`; `F:campaigns`; `VA-A` |
| `/app/accounts/:accountId/campaigns/whatsapp` (`campaigns_whatsapp_index`) | `pages/WhatsAppCampaignsPage.vue` | Campanhas WhatsApp | `P-ADMIN`; `F:whatsapp_campaign`; `VA-A` |

`/app/accounts/:accountId/campaigns` é wrapper sem nome e redireciona para `campaigns_ongoing_index`.

### CAPITÃO

Fonte: `captain/captain.routes.js`; wrapper `pages/CaptainPageRouteView.vue`. Gate comum: `P-ALL`, `featureFlag: ''` intencional e `I:cloud,enterprise,community`; portanto todas exigem `VA-A` nas três modalidades.

| Rota (`name`) | Componente | Propósito |
|---|---|---|
| `/app/accounts/:accountId/captain/:assistantId/faqs` (`captain_assistants_responses_index`) | `responses/Index.vue` | FAQs/respostas do assistente |
| `/app/accounts/:accountId/captain/:assistantId/faqs/pending` (`captain_assistants_responses_pending`) | `responses/Pending.vue` | Respostas pendentes de revisão |
| `/app/accounts/:accountId/captain/:assistantId/documents` (`captain_assistants_documents_index`) | `documents/Index.vue` | Base documental |
| `/app/accounts/:accountId/captain/:assistantId/tools` (`captain_tools_index`) | `tools/Index.vue` | Ferramentas customizadas |
| `/app/accounts/:accountId/captain/:assistantId/scenarios` (`captain_assistants_scenarios_index`) | `assistants/scenarios/Index.vue` | Cenários de atendimento |
| `/app/accounts/:accountId/captain/:assistantId/playground` (`captain_assistants_playground_index`) | `assistants/playground/Index.vue` | Modo de teste/conversa simulada |
| `/app/accounts/:accountId/captain/:assistantId/inboxes` (`captain_assistants_inboxes_index`) | `assistants/inboxes/Index.vue` | Vínculo com caixas/canais |
| `/app/accounts/:accountId/captain/:assistantId/score` (`captain_score_settings_index`) | `score/Index.vue` | Configuração de score |
| `/app/accounts/:accountId/captain/:assistantId/config` (`captain_agent_configs_index`) | `config/Index.vue` | Configuração operacional do agente |
| `/app/accounts/:accountId/captain/:assistantId/settings` (`captain_assistants_settings_index`) | `assistants/settings/Settings.vue` | Dados e comportamento do assistente |
| `/app/accounts/:accountId/captain/:assistantId/settings/guardrails` (`captain_assistants_guardrails_index`) | `assistants/guardrails/Index.vue` | Guardrails |
| `/app/accounts/:accountId/captain/:assistantId/settings/guidelines` (`captain_assistants_guidelines_index`) | `assistants/guidelines/Index.vue` | Diretrizes |
| `/app/accounts/:accountId/captain/flows` (`captain_flow_list`) | `flows/Index.vue` | Lista de fluxos |
| `/app/accounts/:accountId/captain/flows/:flowId/editor` (`captain_flow_editor`) | `flows/Editor.vue` | Editor de fluxo |
| `/app/accounts/:accountId/captain/assistants` (`captain_assistants_create_index`) | `assistants/Index.vue` | Estado vazio/criação de assistente |
| `/app/accounts/:accountId/captain/:navigationPath` (`captain_assistants_index`) | `pages/AssistantsIndexPage.vue` | Navegação/seleção genérica do módulo |

`/app/accounts/:accountId/captain` redireciona para a navegação de assistentes. As rotas específicas devem ser testadas antes do catch-all `:navigationPath`.

### Help center administrativo

Fonte: `helpcenter/helpcenter.routes.js`; wrapper `pages/HelpCenterPageRouteView.vue`. Todas usam `F:help_center` e `VA-A`.

| Rota (`name`) | Componente | Propósito | Permissão |
|---|---|---|---|
| `/app/accounts/:accountId/portals/:portalSlug/:locale/:categorySlug?/articles/:tab?` (`portals_articles_index`) | `pages/PortalsArticlesIndexPage.vue` | Lista de artigos | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/:locale/:categorySlug?/articles/new` (`portals_articles_new`) | `pages/PortalsArticlesNewPage.vue` | Novo artigo | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/:locale/:categorySlug?/articles/:tab?/edit/:articleSlug` (`portals_articles_edit`) | `pages/PortalsArticlesEditPage.vue` | Editar artigo | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/:locale/categories` (`portals_categories_index`) | `pages/PortalsCategoriesIndexPage.vue` | Categorias | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/:locale/categories/:categorySlug/articles` (`portals_categories_articles_index`) | `pages/PortalsArticlesIndexPage.vue` | Artigos da categoria | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/:locale/categories/:categorySlug/articles/:articleSlug` (`portals_categories_articles_edit`) | `pages/PortalsArticlesEditPage.vue` | Editar artigo da categoria | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/locales` (`portals_locales_index`) | `pages/PortalsLocalesIndexPage.vue` | Idiomas do portal | `P-KB` |
| `/app/accounts/:accountId/portals/:portalSlug/settings` (`portals_settings_index`) | `pages/PortalsSettingsIndexPage.vue` | Configurações do portal | `P-KB` |
| `/app/accounts/:accountId/portals/new` (`portals_new`) | `pages/PortalsNewPage.vue` | Novo portal | `P-KB-ADMIN` |
| `/app/accounts/:accountId/portals/:navigationPath` (`portals_index`) | `pages/PortalsIndexPage.vue` | Lista/navegação de portais | `P-KB-ADMIN` |

### Relatórios

Fonte: `settings/reports/reports.routes.js`; wrapper `components/ReportsWrapper.vue`. Todas exigem `P-REPORT` e `VA-A`.

| Rota (`name`) | Componente | Propósito | Feature flag |
|---|---|---|---|
| `/app/accounts/:accountId/reports/overview` (`account_overview_reports`) | `LiveReports.vue` | Visão geral/live | `reports` |
| `/app/accounts/:accountId/reports/conversation` (`conversation_reports`) | `Index.vue` | Métricas de conversas | `reports` |
| `/app/accounts/:accountId/reports/agent` (`agent_reports`) | `AgentReports.vue` | Relatório legado de agentes | `reports` |
| `/app/accounts/:accountId/reports/inboxes` (`inbox_reports`) | `InboxReports.vue` | Relatório legado de caixas | `reports` |
| `/app/accounts/:accountId/reports/label` (`label_reports`) | `LabelReports.vue` | Relatório legado de labels | `reports` |
| `/app/accounts/:accountId/reports/teams` (`team_reports`) | `TeamReports.vue` | Relatório legado de times | `reports` |
| `/app/accounts/:accountId/reports/agents_overview` (`agent_reports_index`) | `AgentReportsIndex.vue` | Índice revisado de agentes | **ausente** |
| `/app/accounts/:accountId/reports/agents/:id` (`agent_reports_show`) | `AgentReportsShow.vue` | Detalhe revisado de agente | **ausente** |
| `/app/accounts/:accountId/reports/inboxes_overview` (`inbox_reports_index`) | `InboxReportsIndex.vue` | Índice revisado de caixas | **ausente** |
| `/app/accounts/:accountId/reports/inboxes/:id` (`inbox_reports_show`) | `InboxReportsShow.vue` | Detalhe revisado de caixa | **ausente** |
| `/app/accounts/:accountId/reports/teams_overview` (`team_reports_index`) | `TeamReportsIndex.vue` | Índice revisado de times | **ausente** |
| `/app/accounts/:accountId/reports/teams/:id` (`team_reports_show`) | `TeamReportsShow.vue` | Detalhe revisado de time | **ausente** |
| `/app/accounts/:accountId/reports/labels_overview` (`label_reports_index`) | `LabelReportsIndex.vue` | Índice revisado de labels | **ausente** |
| `/app/accounts/:accountId/reports/labels/:id` (`label_reports_show`) | `LabelReportsShow.vue` | Detalhe revisado de label | **ausente** |
| `/app/accounts/:accountId/reports/sla` (`sla_reports`) | `SLAReports.vue` | Relatórios de SLA | `reports` |
| `/app/accounts/:accountId/reports/csat` (`csat_reports`) | `CsatResponses.vue` | CSAT/respostas | `reports` |
| `/app/accounts/:accountId/reports/bot` (`bot_reports`) | `BotReports.vue` | Métricas de bots | `reports` |

`/app/accounts/:accountId/reports` redireciona para `overview`.

## Vue — configurações e perfil

Todas as linhas exigem `VA-A`. Fonte agregadora: `settings/settings.routes.js`; `/app/accounts/:accountId/settings` (`settings_home`) redireciona administrador para `general_settings_index` e demais permissões `P-CONV` para `canned_list`.

### Conta, equipe, permissões e automação

| Rota (`name`) | Componente / fonte | Propósito | Gate declarado |
|---|---|---|---|
| `/settings/general` (`general_settings_index`) | `account/Index.vue` | Configuração geral da conta | `P-ADMIN` |
| `/settings/agents/list` (`agent_list`) | `agents/Index.vue` | Agentes | `P-ADMIN`; `F:agent_management` |
| `/settings/agent-bots` (`agent_bots`) | `agentBots/Index.vue` | Bots de agente | `P-ADMIN`; `F:agent_bots` |
| `/settings/assignment-policy/index` (`assignment_policy_index`) | `assignmentPolicy/Index.vue` | Índice das políticas | `P-ADMIN`; `F:assignment_v2` |
| `/settings/assignment-policy/assignment` (`agent_assignment_policy_index`) | `AgentAssignmentIndexPage.vue` | Políticas de atribuição | `P-ADMIN`; `F:assignment_v2` |
| `/settings/assignment-policy/assignment/create` (`agent_assignment_policy_create`) | `AgentAssignmentCreatePage.vue` | Criar política de atribuição | `P-ADMIN`; `F:assignment_v2` |
| `/settings/assignment-policy/assignment/edit/:id` (`agent_assignment_policy_edit`) | `AgentAssignmentEditPage.vue` | Editar política de atribuição | `P-ADMIN`; `F:assignment_v2` |
| `/settings/assignment-policy/capacity` (`agent_capacity_policy_index`) | `AgentCapacityIndexPage.vue` | Políticas de capacidade | `P-ADMIN`; `F:advanced_assignment` |
| `/settings/assignment-policy/capacity/create` (`agent_capacity_policy_create`) | `AgentCapacityCreatePage.vue` | Criar capacidade | `P-ADMIN`; `F:advanced_assignment` |
| `/settings/assignment-policy/capacity/edit/:id` (`agent_capacity_policy_edit`) | `AgentCapacityEditPage.vue` | Editar capacidade | `P-ADMIN`; `F:advanced_assignment` |
| `/settings/custom-attributes/list` (`attributes_list`) | `attributes/Index.vue` | Atributos customizados | `P-ADMIN`; `F:custom_attributes` |
| `/settings/custom-roles/list` (`custom_roles_list`) | `customRoles/Index.vue` | Papéis customizados | `P-ADMIN`; `F:custom_roles`; `I:cloud,enterprise` |
| `/settings/automation/list` (`automation_list`) | `automation/Index.vue` | Regras de automação de atendimento | `P-ADMIN`; `F:automations` |
| `/settings/conversation-workflow` (`conversation_workflow_index`) | `conversationWorkflow/index.vue` | Workflow/auto-resolução | `P-ADMIN`; sem flag |
| `/settings/audit-logs/list` (`auditlogs_list`) | `auditlogs/Index.vue` | Logs de auditoria | `P-ADMIN`; `F:audit_logs`; `I:cloud,enterprise` |
| `/settings/billing` (`billing_settings_index`) | `billing/Index.vue` | Cobrança/créditos | `P-ADMIN`; `I:cloud` |
| `/settings/security` (`security_settings_index`) | `security/Index.vue` | Segurança/SAML | `P-ADMIN`; `F:saml`; `I:cloud,enterprise` |
| `/settings/sla` (`sla_wrapper`) | redirect para `sla_list` | Alias de SLA | `P-ADMIN`; `F:sla`; `I:cloud,enterprise` |
| `/settings/sla/list` (`sla_list`) | `sla/Index.vue` | Políticas de SLA | `P-ADMIN`; `F:sla`; `I:cloud,enterprise` |
| `/settings/captain` (`captain_settings_index`) | `captain/Index.vue` | Preferências gerais do CAPITÃO | `P-ADMIN`; `F:captain_integration`; `I:cloud,enterprise,community` |
| `/settings/evolution` (`settings_evolution_index`) | `evolution/Index.vue` | Configuração Evolution API | `P-ADMIN`; sem flag |

Os paths nesta e nas próximas tabelas têm prefixo `/app/accounts/:accountId`.

### Caixas e canais

Fonte: `settings/inbox/inbox.routes.js`; `F:inbox_management`, `P-ADMIN`.

| Rota (`name`) | Componente | Propósito |
|---|---|---|
| `/settings/inboxes/list` (`settings_inbox_list`) | `inbox/Index.vue` | Lista de caixas |
| `/settings/inboxes/new` (`settings_inbox_new`) | `inbox/ChannelList.vue` | Seleção do canal |
| `/settings/inboxes/new/:sub_page` (`settings_inboxes_page_channel`) | `inbox/ChannelFactory.vue` | Formulário dinâmico do canal |
| `/settings/inboxes/new/:inbox_id/finish` (`settings_inbox_finish`) | `inbox/FinishSetup.vue` | Conclusão da caixa |
| `/settings/inboxes/new/:inbox_id/agents` (`settings_inboxes_add_agents`) | `inbox/AddAgents.vue` | Agentes da nova caixa |
| `/settings/inboxes/:inboxId/:tab?` (`settings_inbox_show`) | `inbox/Settings.vue` | Configuração da caixa por aba |

Valores implementados por `ChannelFactory`: `facebook`, `website`, `twitter`, `api`, `email`, `sms`, `whatsapp`, `line`, `telegram`, `instagram`, `tiktok` e `voice`. `twitter` não aparece na lista atual; `tiktok` só aparece quando `window.chustermConfig.tiktokAppId` existe. Cada variante exige captura própria porque troca o componente inteiro.

### Times

Fonte: `settings/teams/teams.routes.js`; `P-ADMIN`, `F:team_management`.

| Rota (`name`) | Componente | Propósito |
|---|---|---|
| `/settings/teams/list` (`settings_teams_list`) | `teams/Index.vue` | Lista de times |
| `/settings/teams/new` (`settings_teams_new`) | `teams/Create/CreateTeam.vue` | Criar time |
| `/settings/teams/new/:teamId/agents` (`settings_teams_add_agents`) | `teams/Create/AddAgents.vue` | Adicionar membros no wizard |
| `/settings/teams/new/:teamId/finish` (`settings_teams_finish`) | `teams/FinishSetup.vue` | Concluir wizard |
| `/settings/teams/:teamId/edit` (`settings_teams_edit`) | `teams/Edit/EditTeam.vue` | Editar time |
| `/settings/teams/:teamId/edit/agents` (`settings_teams_edit_members`) | `teams/Edit/EditAgents.vue` | Editar membros |
| `/settings/teams/:teamId/edit/finish` (`settings_teams_edit_finish`) | `teams/FinishSetup.vue` | Confirmação final da edição |

### Integrações, respostas e organização

| Rota (`name`) | Componente / fonte | Propósito | Gate declarado |
|---|---|---|---|
| `/settings/integrations` (`settings_applications`) | `integrations/Index.vue` | Catálogo de integrações | `P-ADMIN`; `F:integrations` |
| `/settings/integrations/dashboard_apps` (`settings_integrations_dashboard_apps`) | `integrations/DashboardApps/Index.vue` | Apps embutidos no dashboard | `P-ADMIN`; `F:integrations` |
| `/settings/integrations/webhook` (`settings_integrations_webhook`) | `integrations/Webhooks/Index.vue` | Webhooks | `P-ADMIN`; `F:integrations` |
| `/settings/integrations/slack` (`settings_integrations_slack`) | `integrations/Slack.vue` | Slack | `P-ADMIN`; `F:integrations` |
| `/settings/integrations/linear` (`settings_integrations_linear`) | `integrations/Linear.vue` | Linear/OAuth | `P-ADMIN`; **sem flag** |
| `/settings/integrations/notion` (`settings_integrations_notion`) | `integrations/Notion.vue` | Notion/OAuth | `P-ADMIN`; **sem flag** |
| `/settings/integrations/shopify` (`settings_integrations_shopify`) | `integrations/Shopify.vue` | Shopify | `P-ADMIN`; `F:integrations` |
| `/settings/integrations/:integration_id` (`settings_applications_integration`) | `integrations/IntegrationHooks.vue` | Detalhe genérico da integração | `P-ADMIN`; `F:integrations` |
| `/settings/canned-response/list` (`canned_list`) | `canned/Index.vue` | Respostas prontas | `P-CONV`; `F:canned_responses` |
| `/settings/labels` (`labels_wrapper`) | redirect para `labels_list` | Alias de labels | `P-ADMIN` |
| `/settings/labels/list` (`labels_list`) | `labels/Index.vue` | Labels | `P-ADMIN`; `F:labels` |
| `/settings/macros` (`macros_wrapper`) | `macros/Index.vue` | Lista de macros | `P-CONV`; `F:macros` |
| `/settings/macros/new` (`macros_new`) | `macros/MacroEditor.vue` | Nova macro | `P-CONV`; `F:macros` |
| `/settings/macros/:macroId/edit` (`macros_edit`) | `macros/MacroEditor.vue` | Editar macro | `P-CONV`; `F:macros` |

### Perfil

Fonte: `settings/profile/profile.routes.js`; `P-ALL`.

| Rota (`name`) | Componente | Propósito | Gate extra |
|---|---|---|---|
| `/profile` (`profile_settings`) | `SettingsWrapper.vue` | Wrapper do perfil | não possui redirect nem filho default |
| `/profile/settings` (`profile_settings_index`) | `profile/Index.vue` | Dados/preferências do usuário | nenhum |
| `/profile/mfa` (`profile_settings_mfa`) | `profile/MfaSettings.vue` | MFA | `beforeEnter` exige `window.chustermConfig.isMfaEnabled` |

## Achados estáticos que viram casos obrigatórios de auditoria

1. **Deep link pode furar feature flag.** O guard global bloqueia permissões, mas não `featureFlag`/`installationTypes`; testar URL direta com feature desligada e modalidade incompatível.
2. **Relatórios revisados perderam `F:reports`.** As oito rotas `*_reports_index/show` têm permissão, porém não o metadado presente nas rotas antigas e nas demais telas.
3. **Perfil base potencialmente vazio.** `profile_settings` aponta para `SettingsWrapper.vue`, mas não redireciona nem possui filho `path: ''`.
4. **Canal desconhecido rende vazio.** `ChannelFactory.vue` retorna `null` quando `:sub_page` não pertence ao mapa; testar URL inválida e adicionar tratamento/404 na fase de redesign.
5. **Twitter está implementado, mas oculto na seleção.** Existe componente/factory e helper Rails, porém `ChannelList.vue` não oferece o item.
6. **Rotas Rails sombreadas.** `/app/*params` aparece antes dos helpers específicos e dos recursos Rails legados. Os helpers específicos são equivalentes porque usam o mesmo controller; os GET legados de contas/conversas não chegam aos controllers declarados.
7. **CAPITÃO deliberadamente sem flag.** Suas 16 rotas usam `featureFlag: ''` e aceitam cloud/enterprise/community; a auditoria não deve tratá-las como ausência acidental.
8. **Aliases também precisam de regressão.** Seis rotas nomeadas são redirects (`campaigns_ongoing_index`, `campaigns_one_off_index`, `contacts_dashboard_active`, `settings_home`, `labels_wrapper`, `sla_wrapper`) e existem redirects sem nome nos wrappers de settings.
9. **Matriz mínima de autenticação.** Executar `VA-A` como administrador, agente, custom role com cada permissão granular, conta suspensa e usuário sem contas; executar `VA-SA` separado. Uma única sessão admin não cobre o roteamento declarado.
10. **Variantes não são novas rotas, mas são telas distintas.** Abas de `settings_inbox_show`, `search/:tab?`, filtros de contatos, estados do composer/conversa e 12 variantes do `ChannelFactory` precisam ser abertas individualmente na auditoria visual.

## Fronteira com a auditoria funcional

Os 675 registros Rails em namespaces de API (`api`, `enterprise/api`, `platform/api`, `public/api`) e os 15 webhooks não representam páginas. A prova funcional deve relacioná-los aos fluxos das telas acima, especialmente conversas, CRM, CAPITÃO, canais, campanhas, relatórios e integrações. As 30 rotas internas `/rails/*`, mounts de Active Storage/Action Mailbox e endpoints `.well-known` devem ser validados por contrato, sem entrar na matriz de screenshots.

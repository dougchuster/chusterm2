# Check-up de páginas — Inventário

**Gerado em:** 2026-09-18 · **Branch:** `refactor/crm-deal-owner-assigner` · **HEAD:** `f46e034a01` + worktree
**Método:** rotas extraídas do router real (`router.getRoutes()` de `app/javascript/dashboard/routes/index.js`, via vitest descartável), não de grep — inclui rotas herdadas de `children`, redirects e flags. Auth (`v3/views/routes.js`) e Super Admin (`config/routes.rb` namespace `super_admin`) listados à mão.

**Legenda de status:** `PENDENTE` · `EM ANDAMENTO` · `FALHOU` · `OK` · `BLOQUEADO`
**Perfil "(autenticado, herdado)"** = a rota não declara `meta.permissions`; vale a guarda do container `accounts/:accountId` (qualquer usuário logado da conta). Isso por si só é um item a verificar no checklist F.
**Modais de página cheia** (nova conversa, painel de contato, drawer de negócio, `CRMConversationPanel`, wizards de inbox) não têm rota própria — são auditados dentro da página que os abre e citados no `log.md` pela página-mãe.

## Totais

| Camada | Páginas | Redirects | Total |
|---|---|---|---|
| A. Autenticação (v3, sem login) | 6 | 0 | 6 |
| B. Dashboard Vue (`/app/accounts/:accountId/…`) | 183 | 21 | 204 |
| C. Super Admin (Rails/Administrate) | 27 | 0 | 27 |
| **Total** | **216** | **21** | **237** |

Fora do escopo deste check-up (não são páginas do sistema para o usuário final): widget de live chat (`widget/router.js`), `/swagger`, `/monitoring/sidekiq`, `/widget_tests` (dev), `/installation/onboarding` (só antes da 1ª conta).

## Ordem do loop (Fase 2)

1. **Críticas** — login/reset, `dashboard`, CRM (`crm`, `crm/leads`, `crm/deals/:id`, `crm/reports`, `crm/agenda`, `crm/activities`), `contacts`, `companies`, `conversations`, `reports/*`.
2. **CRM settings** — pipelines, loss-reasons, checklist-templates, automation-rules, cadences, scoring, segment, ai-center.
3. **Operação** — inbox, campaigns, marketing, captain, notifications, search, portals (help center).
4. **Settings gerais** — agents, teams, inboxes, labels, canned, macros, automation, custom-attributes, custom-roles, sla, integrations, evolution, security, audit-logs, billing, profile.
5. **Variações de conversa** (`label/:label/…`, `team/:teamId/…`, `custom_view/:id/…`, `mentions`, `participating`, `unattended`) — mesma tela com filtro; auditar a primeira em profundidade, as demais só checklist A+F.
6. **Redirects** (21) — só checklist A (destino certo, sem loop).
7. **Super Admin** — CRUD de accounts/users/agent_bots/platform_apps/installation_configs.

---

## A. Autenticação (v3)

| # | Rota | Nome | Arquivo | Perfil de acesso | Tipo | Status |
|---|---|---|---|---|---|---|
| A1 | `/app/login` | login | `app/javascript/v3/views/login/Index.vue` | público | form | EM ANDAMENTO |
| A2 | `/app/login/sso` | sso_login | `app/javascript/v3/views/login/Saml.vue` | público | form | OK |
| A3 | `/app/auth/signup` | auth_signup | `app/javascript/v3/views/auth/signup/Index.vue` | público (se signup habilitado) | form | OK |
| A4 | `/app/auth/confirmation` | auth_confirmation | `app/javascript/v3/views/auth/confirmation/Index.vue` | público (token) | form | OK |
| A5 | `/app/auth/password/edit` | auth_password_edit | `app/javascript/v3/views/auth/password/Edit.vue` | público (token) | form | EM ANDAMENTO |
| A6 | `/app/auth/reset/password` | auth_reset_password | `app/javascript/v3/views/auth/reset/password/Index.vue` | público | form | EM ANDAMENTO |

## B. Dashboard Vue

Numeração contínua B1–B204. `…` = `/app/accounts/:accountId`.

### app

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B1 | `/app/no-accounts` | no_accounts | `app/javascript/dashboard/routes/dashboard/noAccounts/Index.vue` | (autenticado, herdado) | — | lista | PENDENTE |

### campaigns

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B2 | `…/campaigns` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B3 | `…/campaigns` | — | `app/javascript/dashboard/routes/dashboard/campaigns/pages/CampaignsPageRouteView.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B4 | `…/campaigns/email` | campaigns_email_index | `app/javascript/dashboard/routes/dashboard/campaigns/pages/EmailCampaignsPage.vue` | administrator | campaigns | lista | PENDENTE |
| B5 | `…/campaigns/live_chat` | campaigns_livechat_index | `app/javascript/dashboard/routes/dashboard/campaigns/pages/LiveChatCampaignsPage.vue` | administrator | campaigns | lista | PENDENTE |
| B6 | `…/campaigns/one_off` | campaigns_one_off_index | → redirect (fn) | administrator | campaigns | redirect | PENDENTE |
| B7 | `…/campaigns/ongoing` | campaigns_ongoing_index | → redirect (fn) | administrator | campaigns | redirect | PENDENTE |
| B8 | `…/campaigns/sms` | campaigns_sms_index | `app/javascript/dashboard/routes/dashboard/campaigns/pages/SMSCampaignsPage.vue` | administrator | campaigns | lista | PENDENTE |
| B9 | `…/campaigns/whatsapp` | campaigns_whatsapp_index | `app/javascript/dashboard/routes/dashboard/campaigns/pages/WhatsAppCampaignsPage.vue` | administrator | whatsapp_campaign | lista | PENDENTE |

### captain

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B10 | `…/captain` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B11 | `…/captain/:assistantId/config` | captain_agent_configs_index | `app/javascript/dashboard/routes/dashboard/captain/config/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B12 | `…/captain/:assistantId/documents` | captain_assistants_documents_index | `app/javascript/dashboard/routes/dashboard/captain/documents/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B13 | `…/captain/:assistantId/faqs` | captain_assistants_responses_index | `app/javascript/dashboard/routes/dashboard/captain/responses/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B14 | `…/captain/:assistantId/faqs/pending` | captain_assistants_responses_pending | `app/javascript/dashboard/routes/dashboard/captain/responses/Pending.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B15 | `…/captain/:assistantId/inboxes` | captain_assistants_inboxes_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/inboxes/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B16 | `…/captain/:assistantId/playground` | captain_assistants_playground_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/playground/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B17 | `…/captain/:assistantId/scenarios` | captain_assistants_scenarios_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/scenarios/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B18 | `…/captain/:assistantId/score` | captain_score_settings_index | `app/javascript/dashboard/routes/dashboard/captain/score/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B19 | `…/captain/:assistantId/settings` | captain_assistants_settings_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/settings/Settings.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B20 | `…/captain/:assistantId/settings/guardrails` | captain_assistants_guardrails_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/guardrails/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B21 | `…/captain/:assistantId/settings/guidelines` | captain_assistants_guidelines_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/guidelines/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B22 | `…/captain/:assistantId/tools` | captain_tools_index | `app/javascript/dashboard/routes/dashboard/captain/tools/Index.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B23 | `…/captain/:navigationPath` | captain_assistants_index | `app/javascript/dashboard/routes/dashboard/captain/pages/AssistantsIndexPage.vue` | administrator, agent, custom_role | — | detalhe | PENDENTE |
| B24 | `…/captain/assistants` | captain_assistants_create_index | `app/javascript/dashboard/routes/dashboard/captain/assistants/Index.vue` | administrator, agent, custom_role | — | form | PENDENTE |
| B25 | `…/captain/flows` | captain_flow_list | `app/javascript/dashboard/routes/dashboard/captain/flows/Index.vue` | administrator, agent, custom_role | — | lista | PENDENTE |
| B26 | `…/captain/flows/:flowId/editor` | captain_flow_editor | `app/javascript/dashboard/routes/dashboard/captain/flows/Editor.vue` | administrator, agent, custom_role | — | form | PENDENTE |

### companies

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B27 | `…/companies` | companies_dashboard_index | `app/javascript/dashboard/routes/dashboard/companies/pages/CompaniesIndex.vue` | administrator, agent | companies | lista | PENDENTE |
| B28 | `…/companies` | — | `app/javascript/dashboard/routes/dashboard/companies/pages/CompaniesIndex.vue` | administrator, agent | companies | lista | PENDENTE |

### contacts

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B29 | `…/contacts` | contacts_dashboard_index | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue` | administrator, agent, contact_manage | crm | lista | PENDENTE |
| B30 | `…/contacts` | — | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsDashboardLayout.vue` | administrator, agent, contact_manage | crm | lista | PENDENTE |
| B31 | `…/contacts/:contactId` | contacts_edit | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` | administrator, agent, contact_manage | crm | form | PENDENTE |
| B32 | `…/contacts/:contactId` | — | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` | administrator, agent, contact_manage | crm | detalhe | PENDENTE |
| B33 | `…/contacts/:contactId/labels/:label` | contacts_edit_label | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` | administrator, agent, contact_manage | crm | form | PENDENTE |
| B34 | `…/contacts/:contactId/segments/:segmentId` | contacts_edit_segment | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` | administrator, agent, contact_manage | crm | form | PENDENTE |
| B35 | `…/contacts/active` | contacts_dashboard_active | → redirect (fn) | administrator, agent, contact_manage | crm | redirect | PENDENTE |
| B36 | `…/contacts/categories` | contacts_dashboard_categories | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactCategoriesPage.vue` | administrator, agent, contact_manage | crm | lista | PENDENTE |
| B37 | `…/contacts/categories/:kind` | contacts_dashboard_category_kind | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactCategoriesPage.vue` | administrator, agent, contact_manage | crm | detalhe | PENDENTE |
| B38 | `…/contacts/categories/:kind/:categoryId` | contacts_dashboard_category_detail | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactCategoriesPage.vue` | administrator, agent, contact_manage | crm | detalhe | PENDENTE |
| B39 | `…/contacts/labels/:label` | contacts_dashboard_labels_index | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue` | administrator, agent, contact_manage | crm | detalhe | PENDENTE |
| B40 | `…/contacts/list` | contacts_dashboard_list | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue` | administrator, agent, contact_manage | crm | lista | PENDENTE |
| B41 | `…/contacts/segments/:segmentId` | contacts_dashboard_segments_index | `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue` | administrator, agent, contact_manage | crm | detalhe | PENDENTE |

### conversations

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B42 | `…/conversations/:conversation_id` | inbox_conversation | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### crm

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B43 | `…/crm` | crm_dashboard | `/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue` | administrator, agent, contact_manage | crm | dashboard | PENDENTE |
| B44 | `…/crm/activities` | crm_activities | `/app/javascript/dashboard/routes/dashboard/crm/pages/Activities.vue` | administrator, agent, contact_manage | crm | lista | PENDENTE |
| B45 | `…/crm/agenda` | crm_agenda | `/app/javascript/dashboard/routes/dashboard/crm/pages/Agenda.vue` | administrator, agent, contact_manage | crm | dashboard | PENDENTE |
| B46 | `…/crm/ai-center` | crm_ai_center | `/app/javascript/dashboard/routes/dashboard/crm/pages/AiCenter.vue` | administrator, agent, contact_manage | crm | dashboard | PENDENTE |
| B47 | `…/crm/analytics` | crm_analytics | → redirect (fn) | administrator, agent, contact_manage | crm | redirect | PENDENTE |
| B48 | `…/crm/deals/:dealId` | crm_deal_details | `/app/javascript/dashboard/routes/dashboard/crm/pages/DealDetails.vue` | administrator, agent, contact_manage | crm | detalhe | PENDENTE |
| B49 | `…/crm/design-system/templates` | crm_page_templates | `/app/javascript/dashboard/routes/dashboard/crm/pages/PageTemplatesGallery.vue` | administrator | crm_v2 | lista | PENDENTE |
| B50 | `…/crm/leads` | crm_all_leads | `/app/javascript/dashboard/routes/dashboard/crm/pages/AllLeads.vue` | administrator, agent, contact_manage | crm | lista | PENDENTE |
| B51 | `…/crm/metrics` | crm_metrics | → redirect (fn) | administrator, agent, contact_manage | crm | redirect | PENDENTE |
| B52 | `…/crm/reports` | crm_reports | `/app/javascript/dashboard/routes/dashboard/crm/pages/ReportsHub.vue` | administrator, agent, contact_manage | crm | dashboard | PENDENTE |
| B53 | `…/crm/settings/automation-rules` | crm_automation_rules | `/app/javascript/dashboard/routes/dashboard/crm/pages/AutomationRules.vue` | administrator | crm | lista | PENDENTE |
| B54 | `…/crm/settings/cadences` | crm_cadences | `/app/javascript/dashboard/routes/dashboard/crm/pages/Cadences.vue` | administrator | crm | lista | PENDENTE |
| B55 | `…/crm/settings/checklist-templates` | crm_checklist_templates | `/app/javascript/dashboard/routes/dashboard/crm/pages/ChecklistTemplates.vue` | administrator | crm | lista | PENDENTE |
| B56 | `…/crm/settings/loss-reasons` | crm_loss_reasons | `/app/javascript/dashboard/routes/dashboard/crm/pages/LossReasons.vue` | administrator | crm | lista | PENDENTE |
| B57 | `…/crm/settings/pipelines` | crm_pipeline_settings | `/app/javascript/dashboard/routes/dashboard/crm/pages/PipelineSettings.vue` | administrator | crm | lista | PENDENTE |
| B58 | `…/crm/settings/scoring` | crm_scoring_config | `/app/javascript/dashboard/routes/dashboard/crm/pages/ScoringConfig.vue` | administrator | crm | lista | PENDENTE |
| B59 | `…/crm/settings/segment` | crm_segment_settings | `/app/javascript/dashboard/routes/dashboard/crm/pages/SegmentSettings.vue` | administrator | crm_universal | lista | PENDENTE |

### custom_view

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B60 | `…/custom_view/:id` | folder_conversations | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |
| B61 | `…/custom_view/:id/conversations/:conversation_id` | conversations_through_folders | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### dashboard

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B62 | `…/dashboard` | home | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | dashboard | PENDENTE |

### inbox-view

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B63 | `…/inbox-view` | inbox_view | `app/javascript/dashboard/routes/dashboard/inbox/InboxEmptyState.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | lista | PENDENTE |
| B64 | `…/inbox-view` | — | `app/javascript/dashboard/routes/dashboard/inbox/InboxList.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B65 | `…/inbox-view/:type/:id` | inbox_view_conversation | `app/javascript/dashboard/routes/dashboard/inbox/InboxView.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### inbox

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B66 | `…/inbox/:inbox_id` | inbox_dashboard | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |
| B67 | `…/inbox/:inbox_id/conversations/:conversation_id` | conversation_through_inbox | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### label

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B68 | `…/label/:label` | label_conversations | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |
| B69 | `…/label/:label/conversations/:conversation_id` | conversations_through_label | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### marketing

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B70 | `…/marketing` | marketing_overview | `/app/javascript/dashboard/routes/dashboard/marketing/pages/MarketingOverview.vue` | administrator, agent, contact_manage | marketing | lista | PENDENTE |
| B71 | `…/marketing/campaigns` | marketing_campaigns | `/app/javascript/dashboard/routes/dashboard/marketing/pages/MarketingCampaigns.vue` | administrator, agent, contact_manage | marketing | lista | PENDENTE |
| B72 | `…/marketing/connections` | marketing_connections | `/app/javascript/dashboard/routes/dashboard/marketing/pages/MarketingConnections.vue` | administrator | marketing | lista | PENDENTE |
| B73 | `…/marketing/events` | marketing_events | `/app/javascript/dashboard/routes/dashboard/marketing/pages/MarketingEvents.vue` | administrator | marketing | lista | PENDENTE |
| B74 | `…/marketing/insights` | marketing_insights | `/app/javascript/dashboard/routes/dashboard/marketing/pages/MarketingInsights.vue` | administrator, agent, contact_manage | marketing | lista | PENDENTE |
| B75 | `…/marketing/leads` | marketing_leads | `/app/javascript/dashboard/routes/dashboard/marketing/pages/MarketingLeads.vue` | administrator, agent, contact_manage | marketing | lista | PENDENTE |

### mentions

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B76 | `…/mentions/conversations` | conversation_mentions | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | lista | PENDENTE |
| B77 | `…/mentions/conversations/:conversationId` | conversation_through_mentions | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### notifications

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B78 | `…/notifications` | notifications_index | `app/javascript/dashboard/routes/dashboard/notifications/components/NotificationsView.vue` | administrator, agent, custom_role | — | lista | PENDENTE |
| B79 | `…/notifications` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |

### participating

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B80 | `…/participating/conversations` | conversation_participating | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | lista | PENDENTE |
| B81 | `…/participating/conversations/:conversationId` | conversation_through_participating | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### portals

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B82 | `…/portals` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B83 | `…/portals/:navigationPath` | portals_index | `app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsIndexPage.vue` | administrator, knowledge_base_manage | help_center | detalhe | PENDENTE |
| B84 | `…/portals/:portalSlug/:locale/:categorySlug?/articles/:tab?` | portals_articles_index | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesIndexPage.vue` | administrator, agent, knowledge_base_manage | help_center | detalhe | PENDENTE |
| B85 | `…/portals/:portalSlug/:locale/:categorySlug?/articles/:tab?/edit/:articleSlug` | portals_articles_edit | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesEditPage.vue` | administrator, agent, knowledge_base_manage | help_center | form | PENDENTE |
| B86 | `…/portals/:portalSlug/:locale/:categorySlug?/articles/new` | portals_articles_new | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesNewPage.vue` | administrator, agent, knowledge_base_manage | help_center | form | PENDENTE |
| B87 | `…/portals/:portalSlug/:locale/categories` | portals_categories_index | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsCategoriesIndexPage.vue` | administrator, agent, knowledge_base_manage | help_center | detalhe | PENDENTE |
| B88 | `…/portals/:portalSlug/:locale/categories/:categorySlug/articles` | portals_categories_articles_index | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesIndexPage.vue` | administrator, agent, knowledge_base_manage | help_center | detalhe | PENDENTE |
| B89 | `…/portals/:portalSlug/:locale/categories/:categorySlug/articles/:articleSlug` | portals_categories_articles_edit | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesEditPage.vue` | administrator, agent, knowledge_base_manage | help_center | form | PENDENTE |
| B90 | `…/portals/:portalSlug/locales` | portals_locales_index | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsLocalesIndexPage.vue` | administrator, agent, knowledge_base_manage | help_center | detalhe | PENDENTE |
| B91 | `…/portals/:portalSlug/settings` | portals_settings_index | `/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsSettingsIndexPage.vue` | administrator, agent, knowledge_base_manage | help_center | detalhe | PENDENTE |
| B92 | `…/portals/new` | portals_new | `app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsNewPage.vue` | administrator, knowledge_base_manage | help_center | form | PENDENTE |

### profile

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B93 | `…/profile` | profile_settings | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | administrator, agent, custom_role | — | lista | PENDENTE |
| B94 | `…/profile/mfa` | profile_settings_mfa | `app/javascript/dashboard/routes/dashboard/settings/profile/MfaSettings.vue` | administrator, agent, custom_role | — | lista | PENDENTE |
| B95 | `…/profile/settings` | profile_settings_index | `app/javascript/dashboard/routes/dashboard/settings/profile/Index.vue` | administrator, agent, custom_role | — | lista | PENDENTE |

### reports

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B96 | `…/reports` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B97 | `…/reports` | — | `app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportsWrapper.vue` | (autenticado, herdado) | — | dashboard | PENDENTE |
| B98 | `…/reports/agent` | agent_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/AgentReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B99 | `…/reports/agents_overview` | agent_reports_index | `app/javascript/dashboard/routes/dashboard/settings/reports/AgentReportsIndex.vue` | administrator, report_manage | — | dashboard | PENDENTE |
| B100 | `…/reports/agents/:id` | agent_reports_show | `app/javascript/dashboard/routes/dashboard/settings/reports/AgentReportsShow.vue` | administrator, report_manage | — | detalhe | PENDENTE |
| B101 | `…/reports/bot` | bot_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/BotReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B102 | `…/reports/conversation` | conversation_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/Index.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B103 | `…/reports/csat` | csat_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/CsatResponses.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B104 | `…/reports/inboxes` | inbox_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/InboxReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B105 | `…/reports/inboxes_overview` | inbox_reports_index | `app/javascript/dashboard/routes/dashboard/settings/reports/InboxReportsIndex.vue` | administrator, report_manage | — | dashboard | PENDENTE |
| B106 | `…/reports/inboxes/:id` | inbox_reports_show | `app/javascript/dashboard/routes/dashboard/settings/reports/InboxReportsShow.vue` | administrator, report_manage | — | detalhe | PENDENTE |
| B107 | `…/reports/label` | label_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/LabelReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B108 | `…/reports/labels_overview` | label_reports_index | `app/javascript/dashboard/routes/dashboard/settings/reports/LabelReportsIndex.vue` | administrator, report_manage | — | dashboard | PENDENTE |
| B109 | `…/reports/labels/:id` | label_reports_show | `app/javascript/dashboard/routes/dashboard/settings/reports/LabelReportsShow.vue` | administrator, report_manage | — | detalhe | PENDENTE |
| B110 | `…/reports/overview` | account_overview_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/LiveReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B111 | `…/reports/sla` | sla_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/SLAReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B112 | `…/reports/teams` | team_reports | `app/javascript/dashboard/routes/dashboard/settings/reports/TeamReports.vue` | administrator, report_manage | reports | dashboard | PENDENTE |
| B113 | `…/reports/teams_overview` | team_reports_index | `app/javascript/dashboard/routes/dashboard/settings/reports/TeamReportsIndex.vue` | administrator, report_manage | — | dashboard | PENDENTE |
| B114 | `…/reports/teams/:id` | team_reports_show | `app/javascript/dashboard/routes/dashboard/settings/reports/TeamReportsShow.vue` | administrator, report_manage | — | detalhe | PENDENTE |

### root

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B115 | `…` | — | `app/javascript/dashboard/routes/dashboard/Dashboard.vue` | (autenticado, herdado) | — | lista | PENDENTE |

### search

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B116 | `…/search/:tab?` | search | `app/javascript/dashboard/modules/search/components/SearchView.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage, contact_manage, knowledge_base_manage | — | detalhe | PENDENTE |

### settings/agent-bots

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B117 | `…/settings/agent-bots` | agent_bots | `app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue` | administrator | agent_bots | lista | PENDENTE |
| B118 | `…/settings/agent-bots` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | administrator | — | lista | PENDENTE |

### settings/agents

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B119 | `…/settings/agents` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B120 | `…/settings/agents` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B121 | `…/settings/agents/list` | agent_list | `app/javascript/dashboard/routes/dashboard/settings/agents/Index.vue` | administrator | agent_management | lista | PENDENTE |

### settings

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B122 | `…/settings` | settings_home | → redirect (fn) | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | redirect | PENDENTE |

### settings/assignment-policy

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B123 | `…/settings/assignment-policy` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B124 | `…/settings/assignment-policy` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B125 | `…/settings/assignment-policy/assignment` | agent_assignment_policy_index | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/pages/AgentAssignmentIndexPage.vue` | administrator | assignment_v2 | lista | PENDENTE |
| B126 | `…/settings/assignment-policy/assignment/create` | agent_assignment_policy_create | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/pages/AgentAssignmentCreatePage.vue` | administrator | assignment_v2 | form | PENDENTE |
| B127 | `…/settings/assignment-policy/assignment/edit/:id` | agent_assignment_policy_edit | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/pages/AgentAssignmentEditPage.vue` | administrator | assignment_v2 | form | PENDENTE |
| B128 | `…/settings/assignment-policy/capacity` | agent_capacity_policy_index | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/pages/AgentCapacityIndexPage.vue` | administrator | advanced_assignment | lista | PENDENTE |
| B129 | `…/settings/assignment-policy/capacity/create` | agent_capacity_policy_create | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/pages/AgentCapacityCreatePage.vue` | administrator | advanced_assignment | form | PENDENTE |
| B130 | `…/settings/assignment-policy/capacity/edit/:id` | agent_capacity_policy_edit | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/pages/AgentCapacityEditPage.vue` | administrator | advanced_assignment | form | PENDENTE |
| B131 | `…/settings/assignment-policy/index` | assignment_policy_index | `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/Index.vue` | administrator | assignment_v2 | lista | PENDENTE |

### settings/audit-logs

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B132 | `…/settings/audit-logs` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B133 | `…/settings/audit-logs` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B134 | `…/settings/audit-logs/list` | auditlogs_list | `app/javascript/dashboard/routes/dashboard/settings/auditlogs/Index.vue` | administrator | audit_logs | lista | PENDENTE |

### settings/automation

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B135 | `…/settings/automation` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B136 | `…/settings/automation` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B137 | `…/settings/automation/list` | automation_list | `app/javascript/dashboard/routes/dashboard/settings/automation/Index.vue` | administrator | automations | lista | PENDENTE |

### settings/billing

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B138 | `…/settings/billing` | billing_settings_index | `app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue` | administrator | — | dashboard | PENDENTE |
| B139 | `…/settings/billing` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | administrator | — | dashboard | PENDENTE |

### settings/canned-response

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B140 | `…/settings/canned-response` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B141 | `…/settings/canned-response` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B142 | `…/settings/canned-response/list` | canned_list | `app/javascript/dashboard/routes/dashboard/settings/canned/Index.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | canned_responses | lista | PENDENTE |

### settings/conversation-workflow

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B143 | `…/settings/conversation-workflow` | conversation_workflow_index | `app/javascript/dashboard/routes/dashboard/settings/conversationWorkflow/index.vue` | administrator | — | lista | PENDENTE |
| B144 | `…/settings/conversation-workflow` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |

### settings/custom-attributes

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B145 | `…/settings/custom-attributes` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B146 | `…/settings/custom-attributes` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B147 | `…/settings/custom-attributes/list` | attributes_list | `app/javascript/dashboard/routes/dashboard/settings/attributes/Index.vue` | administrator | custom_attributes | lista | PENDENTE |

### settings/custom-roles

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B148 | `…/settings/custom-roles` | — | → redirect ("list") | (autenticado, herdado) | — | redirect | PENDENTE |
| B149 | `…/settings/custom-roles` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B150 | `…/settings/custom-roles/list` | custom_roles_list | `app/javascript/dashboard/routes/dashboard/settings/customRoles/Index.vue` | administrator | custom_roles | lista | PENDENTE |

### settings/evolution

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B151 | `…/settings/evolution` | settings_evolution_index | `app/javascript/dashboard/routes/dashboard/settings/evolution/Index.vue` | administrator | — | lista | PENDENTE |
| B152 | `…/settings/evolution` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | administrator | — | lista | PENDENTE |

### settings/general

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B153 | `…/settings/general` | general_settings_index | `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue` | administrator | — | lista | PENDENTE |
| B154 | `…/settings/general` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | administrator | — | lista | PENDENTE |

### settings/inboxes

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B155 | `…/settings/inboxes` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B156 | `…/settings/inboxes` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B157 | `…/settings/inboxes` | — | `app/javascript/dashboard/routes/dashboard/settings/Wrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B158 | `…/settings/inboxes/:inboxId/:tab?` | settings_inbox_show | `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` | administrator | inbox_management | detalhe | PENDENTE |
| B159 | `…/settings/inboxes/list` | settings_inbox_list | `app/javascript/dashboard/routes/dashboard/settings/inbox/Index.vue` | administrator | inbox_management | lista | PENDENTE |
| B160 | `…/settings/inboxes/new` | settings_inbox_new | `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelList.vue` | administrator | inbox_management | form | PENDENTE |
| B161 | `…/settings/inboxes/new` | — | `app/javascript/dashboard/routes/dashboard/settings/inbox/InboxChannels.vue` | (autenticado, herdado) | — | form | PENDENTE |
| B162 | `…/settings/inboxes/new/:inbox_id/agents` | settings_inboxes_add_agents | `app/javascript/dashboard/routes/dashboard/settings/inbox/AddAgents.vue` | administrator | inbox_management | form | PENDENTE |
| B163 | `…/settings/inboxes/new/:inbox_id/finish` | settings_inbox_finish | `app/javascript/dashboard/routes/dashboard/settings/inbox/FinishSetup.vue` | administrator | inbox_management | form | PENDENTE |
| B164 | `…/settings/inboxes/new/:sub_page` | settings_inboxes_page_channel | `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelFactory.vue` | administrator | inbox_management | form | PENDENTE |

### settings/integrations

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B165 | `…/settings/integrations` | settings_applications | `app/javascript/dashboard/routes/dashboard/settings/integrations/Index.vue` | administrator | integrations | lista | PENDENTE |
| B166 | `…/settings/integrations` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B167 | `…/settings/integrations` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B168 | `…/settings/integrations/:integration_id` | settings_applications_integration | `app/javascript/dashboard/routes/dashboard/settings/integrations/IntegrationHooks.vue` | administrator | integrations | detalhe | PENDENTE |
| B169 | `…/settings/integrations/dashboard_apps` | settings_integrations_dashboard_apps | `app/javascript/dashboard/routes/dashboard/settings/integrations/DashboardApps/Index.vue` | administrator | integrations | dashboard | PENDENTE |
| B170 | `…/settings/integrations/linear` | settings_integrations_linear | `app/javascript/dashboard/routes/dashboard/settings/integrations/Linear.vue` | administrator | — | lista | PENDENTE |
| B171 | `…/settings/integrations/notion` | settings_integrations_notion | `app/javascript/dashboard/routes/dashboard/settings/integrations/Notion.vue` | administrator | — | lista | PENDENTE |
| B172 | `…/settings/integrations/shopify` | settings_integrations_shopify | `app/javascript/dashboard/routes/dashboard/settings/integrations/Shopify.vue` | administrator | integrations | lista | PENDENTE |
| B173 | `…/settings/integrations/slack` | settings_integrations_slack | `app/javascript/dashboard/routes/dashboard/settings/integrations/Slack.vue` | administrator | integrations | lista | PENDENTE |
| B174 | `…/settings/integrations/webhook` | settings_integrations_webhook | `app/javascript/dashboard/routes/dashboard/settings/integrations/Webhooks/Index.vue` | administrator | integrations | lista | PENDENTE |

### settings/labels

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B175 | `…/settings/labels` | labels_wrapper | → redirect (fn) | administrator | — | redirect | PENDENTE |
| B176 | `…/settings/labels` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B177 | `…/settings/labels/list` | labels_list | `app/javascript/dashboard/routes/dashboard/settings/labels/Index.vue` | administrator | labels | lista | PENDENTE |

### settings/macros

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B178 | `…/settings/macros` | macros_wrapper | `app/javascript/dashboard/routes/dashboard/settings/macros/Index.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | macros | lista | PENDENTE |
| B179 | `…/settings/macros` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B180 | `…/settings/macros` | — | `app/javascript/dashboard/routes/dashboard/settings/Wrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B181 | `…/settings/macros/:macroId/edit` | macros_edit | `app/javascript/dashboard/routes/dashboard/settings/macros/MacroEditor.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | macros | form | PENDENTE |
| B182 | `…/settings/macros/new` | macros_new | `app/javascript/dashboard/routes/dashboard/settings/macros/MacroEditor.vue` | agent, administrator, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | macros | form | PENDENTE |

### settings/security

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B183 | `…/settings/security` | security_settings_index | `app/javascript/dashboard/routes/dashboard/settings/security/Index.vue` | administrator | saml | lista | PENDENTE |
| B184 | `…/settings/security` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | administrator | — | lista | PENDENTE |

### settings/sla

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B185 | `…/settings/sla` | sla_wrapper | → redirect (fn) | administrator | sla | redirect | PENDENTE |
| B186 | `…/settings/sla` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B187 | `…/settings/sla/list` | sla_list | `app/javascript/dashboard/routes/dashboard/settings/sla/Index.vue` | administrator | sla | lista | PENDENTE |

### settings/teams

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B188 | `…/settings/teams` | — | → redirect (fn) | (autenticado, herdado) | — | redirect | PENDENTE |
| B189 | `…/settings/teams` | — | `app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B190 | `…/settings/teams` | — | `app/javascript/dashboard/routes/dashboard/settings/Wrapper.vue` | (autenticado, herdado) | — | lista | PENDENTE |
| B191 | `…/settings/teams/:teamId/edit` | settings_teams_edit | `app/javascript/dashboard/routes/dashboard/settings/teams/Edit/EditTeam.vue` | administrator | team_management | form | PENDENTE |
| B192 | `…/settings/teams/:teamId/edit` | — | `app/javascript/dashboard/routes/dashboard/settings/teams/Edit/Index.vue` | (autenticado, herdado) | — | form | PENDENTE |
| B193 | `…/settings/teams/:teamId/edit/agents` | settings_teams_edit_members | `app/javascript/dashboard/routes/dashboard/settings/teams/Edit/EditAgents.vue` | administrator | team_management | form | PENDENTE |
| B194 | `…/settings/teams/:teamId/edit/finish` | settings_teams_edit_finish | `app/javascript/dashboard/routes/dashboard/settings/teams/FinishSetup.vue` | administrator | team_management | form | PENDENTE |
| B195 | `…/settings/teams/list` | settings_teams_list | `app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue` | administrator | team_management | lista | PENDENTE |
| B196 | `…/settings/teams/new` | settings_teams_new | `app/javascript/dashboard/routes/dashboard/settings/teams/Create/CreateTeam.vue` | administrator | team_management | form | PENDENTE |
| B197 | `…/settings/teams/new` | — | `app/javascript/dashboard/routes/dashboard/settings/teams/Create/Index.vue` | (autenticado, herdado) | — | form | PENDENTE |
| B198 | `…/settings/teams/new/:teamId/agents` | settings_teams_add_agents | `app/javascript/dashboard/routes/dashboard/settings/teams/Create/AddAgents.vue` | administrator | team_management | form | PENDENTE |
| B199 | `…/settings/teams/new/:teamId/finish` | settings_teams_finish | `app/javascript/dashboard/routes/dashboard/settings/teams/FinishSetup.vue` | administrator | team_management | form | PENDENTE |

### suspended

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B200 | `…/suspended` | account_suspended | `app/javascript/dashboard/routes/dashboard/suspended/Index.vue` | administrator, agent, custom_role | — | lista | PENDENTE |

### team

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B201 | `…/team/:teamId` | team_conversations | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |
| B202 | `…/team/:teamId/conversations/:conversationId` | conversations_through_team | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

### unattended

| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |
|---|---|---|---|---|---|---|---|
| B203 | `…/unattended/conversations` | conversation_unattended | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | lista | PENDENTE |
| B204 | `…/unattended/conversations/:conversationId` | conversation_through_unattended | `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | administrator, agent, conversation_manage, conversation_unassigned_manage, conversation_participating_manage | — | detalhe | PENDENTE |

## C. Super Admin (Rails / Administrate) — `/super_admin`

Perfil: `super_admin` (Devise, separado do login da conta). Views em `app/views/super_admin/` e `app/dashboards/*_dashboard.rb`.

| # | Rota | Controller | Tipo | Status |
|---|---|---|---|---|
| C1 | `/super_admin` | `super_admin/dashboard#index` | dashboard | PENDENTE |
| C2 | `/super_admin/app_config` | `app_configs#show/create` | form | PENDENTE |
| C3 | `/super_admin/accounts` | `accounts#index` | lista | PENDENTE |
| C4 | `/super_admin/accounts/new` | `accounts#new/create` | form | PENDENTE |
| C5 | `/super_admin/accounts/:id` | `accounts#show` (+ `seed`, `reset_cache`) | detalhe | PENDENTE |
| C6 | `/super_admin/accounts/:id/edit` | `accounts#edit/update/destroy` | form | PENDENTE |
| C7 | `/super_admin/users` | `users#index` | lista | PENDENTE |
| C8 | `/super_admin/users/new` | `users#new/create` | form | PENDENTE |
| C9 | `/super_admin/users/:id` | `users#show` | detalhe | PENDENTE |
| C10 | `/super_admin/users/:id/edit` | `users#edit/update/destroy` (+ `destroy_avatar`) | form | PENDENTE |
| C11 | `/super_admin/access_tokens` | `access_tokens#index` | lista | PENDENTE |
| C12 | `/super_admin/access_tokens/:id` | `access_tokens#show` | detalhe | PENDENTE |
| C13 | `/super_admin/installation_configs` | `installation_configs#index` | lista | PENDENTE |
| C14 | `/super_admin/installation_configs/new` | `installation_configs#new/create` | form | PENDENTE |
| C15 | `/super_admin/installation_configs/:id` | `installation_configs#show` | detalhe | PENDENTE |
| C16 | `/super_admin/installation_configs/:id/edit` | `installation_configs#edit/update` | form | PENDENTE |
| C17 | `/super_admin/agent_bots` | `agent_bots#index` | lista | PENDENTE |
| C18 | `/super_admin/agent_bots/new` | `agent_bots#new/create` | form | PENDENTE |
| C19 | `/super_admin/agent_bots/:id` | `agent_bots#show` | detalhe | PENDENTE |
| C20 | `/super_admin/agent_bots/:id/edit` | `agent_bots#edit/update/destroy` | form | PENDENTE |
| C21 | `/super_admin/platform_apps` | `platform_apps#index` | lista | PENDENTE |
| C22 | `/super_admin/platform_apps/new` | `platform_apps#new/create` | form | PENDENTE |
| C23 | `/super_admin/platform_apps/:id` | `platform_apps#show` | detalhe | PENDENTE |
| C24 | `/super_admin/platform_apps/:id/edit` | `platform_apps#edit/update/destroy` | form | PENDENTE |
| C25 | `/super_admin/instance_status` | `instance_statuses#show` | dashboard | PENDENTE |
| C26 | `/super_admin/settings` | `settings#show` (+ `refresh`) | dashboard | PENDENTE |
| C27 | `/super_admin/account_users/new`, `/:id` | `account_users#new/create/show/destroy` | form | PENDENTE |

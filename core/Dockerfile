# syntax=docker/dockerfile:1
# ChusteRM Core - Fork do Chatwoot com Evolution API (Baileys) integrada
FROM chatwoot/chatwoot:latest

WORKDIR /app

# Use repository package manifests so frontend builds install the rebranded dependencies.
COPY package.json ./package.json
COPY pnpm-lock.yaml ./pnpm-lock.yaml

# ChusteRM Theme
COPY app/javascript/dashboard/assets/css/chusterm-theme.css ./app/javascript/dashboard/assets/css/chusterm-theme.css
COPY app/javascript/entrypoints/dashboard.js ./app/javascript/entrypoints/dashboard.js
COPY app/javascript/entrypoints/v3app.js ./app/javascript/entrypoints/v3app.js
COPY app/javascript/entrypoints/superadmin.js ./app/javascript/entrypoints/superadmin.js
COPY config/locales/pt_BR.yml ./config/locales/pt_BR.yml

# Evolution API channel – fix URL validator to accept localhost
COPY app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue ./app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue
COPY app/services/whatsapp/providers/evolution_service.rb ./app/services/whatsapp/providers/evolution_service.rb

# Auth – fix UnsafeRedirectError no redirect OAuth para FRONTEND_URL
COPY app/controllers/devise_overrides/sessions_controller.rb ./app/controllers/devise_overrides/sessions_controller.rb

# Design System – SCSS dark palette + brand color + login/superadmin
COPY app/javascript/dashboard/assets/scss/_next-colors.scss ./app/javascript/dashboard/assets/scss/_next-colors.scss
COPY app/javascript/dashboard/assets/scss/super_admin/index.scss ./app/javascript/dashboard/assets/scss/super_admin/index.scss
COPY app/javascript/dashboard/App.vue ./app/javascript/dashboard/App.vue
COPY app/javascript/dashboard/components-next/table/ ./app/javascript/dashboard/components-next/table/
COPY app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue ./app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue
COPY app/javascript/dashboard/components-next/sidebar/ ./app/javascript/dashboard/components-next/sidebar/
COPY app/javascript/dashboard/components/ChatListHeader.vue ./app/javascript/dashboard/components/ChatListHeader.vue
COPY app/javascript/dashboard/components/widgets/ChatTypeTabs.vue ./app/javascript/dashboard/components/widgets/ChatTypeTabs.vue
COPY app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue ./app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue
COPY app/javascript/dashboard/components/widgets/conversation/EmptyState/EmptyState.vue ./app/javascript/dashboard/components/widgets/conversation/EmptyState/EmptyState.vue
COPY app/javascript/dashboard/routes/dashboard/settings/SettingsLayout.vue ./app/javascript/dashboard/routes/dashboard/settings/SettingsLayout.vue
COPY app/javascript/dashboard/routes/dashboard/settings/SettingsSubPageHeader.vue ./app/javascript/dashboard/routes/dashboard/settings/SettingsSubPageHeader.vue
COPY app/javascript/dashboard/routes/dashboard/settings/Wrapper.vue ./app/javascript/dashboard/routes/dashboard/settings/Wrapper.vue
COPY app/javascript/dashboard/routes/dashboard/settings/SettingsHeader.vue ./app/javascript/dashboard/routes/dashboard/settings/SettingsHeader.vue
COPY app/javascript/dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue ./app/javascript/dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue
COPY app/javascript/dashboard/routes/dashboard/settings/components/BasePaywallModal.vue ./app/javascript/dashboard/routes/dashboard/settings/components/BasePaywallModal.vue
COPY app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportHeader.vue ./app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportHeader.vue
COPY app/javascript/dashboard/routes/dashboard/settings/reports/components/CsatEmptyState.vue ./app/javascript/dashboard/routes/dashboard/settings/reports/components/CsatEmptyState.vue
COPY app/javascript/dashboard/routes/dashboard/settings/teams/AgentSelector.vue ./app/javascript/dashboard/routes/dashboard/settings/teams/AgentSelector.vue
COPY app/javascript/dashboard/routes/dashboard/settings/customRoles/component/CustomRoleTableBody.vue ./app/javascript/dashboard/routes/dashboard/settings/customRoles/component/CustomRoleTableBody.vue
COPY app/javascript/v3/views/login/Index.vue ./app/javascript/v3/views/login/Index.vue
COPY app/javascript/v3/views/login/Saml.vue ./app/javascript/v3/views/login/Saml.vue
COPY app/javascript/superadmin_pages/views/dashboard/Index.vue ./app/javascript/superadmin_pages/views/dashboard/Index.vue
COPY app/javascript/dashboard/i18n/locale/en/login.json ./app/javascript/dashboard/i18n/locale/en/login.json
COPY app/javascript/dashboard/i18n/locale/pt_BR/login.json ./app/javascript/dashboard/i18n/locale/pt_BR/login.json
COPY app/javascript/dashboard/i18n/locale/en/conversation.json ./app/javascript/dashboard/i18n/locale/en/conversation.json
COPY app/javascript/dashboard/i18n/locale/pt_BR/conversation.json ./app/javascript/dashboard/i18n/locale/pt_BR/conversation.json
COPY theme/colors.js ./theme/colors.js
COPY app/views/layouts/super_admin/application.html.erb ./app/views/layouts/super_admin/application.html.erb
COPY app/views/super_admin/devise/sessions/new.html.erb ./app/views/super_admin/devise/sessions/new.html.erb

# Publish the active frontend trees so image builds don't silently miss source edits.
COPY app/javascript/dashboard/ ./app/javascript/dashboard/
COPY app/javascript/v3/ ./app/javascript/v3/
COPY app/javascript/superadmin_pages/ ./app/javascript/superadmin_pages/
COPY app/javascript/shared/ ./app/javascript/shared/
COPY app/views/layouts/vueapp.html.erb ./app/views/layouts/vueapp.html.erb
COPY app/views/evo_manager/ ./app/views/evo_manager/
COPY theme/ ./theme/

# Enterprise Features - Enable Captain
COPY config/features.yml ./config/features.yml
COPY config/installation_config.yml ./config/installation_config.yml
COPY config/llm.yml ./config/llm.yml
COPY app/views/super_admin/settings/show.html.erb ./app/views/super_admin/settings/show.html.erb
COPY app/views/super_admin/app_configs/show.html.erb ./app/views/super_admin/app_configs/show.html.erb
COPY app/views/super_admin/instance_statuses/show.html.erb ./app/views/super_admin/instance_statuses/show.html.erb
COPY app/views/super_admin/dashboard/index.html.erb ./app/views/super_admin/dashboard/index.html.erb
COPY app/views/super_admin/application/_navigation.html.erb ./app/views/super_admin/application/_navigation.html.erb
COPY app/views/super_admin/application/_nav_item.html.erb ./app/views/super_admin/application/_nav_item.html.erb
COPY app/views/super_admin/application/_settings_menu.html.erb ./app/views/super_admin/application/_settings_menu.html.erb
COPY app/views/super_admin/application/_javascript.html.erb ./app/views/super_admin/application/_javascript.html.erb
COPY enterprise/app/views/devise/mailer/confirmation_instructions.html.erb ./enterprise/app/views/devise/mailer/confirmation_instructions.html.erb
COPY enterprise/app/models/captain/assistant.rb ./enterprise/app/models/captain/assistant.rb
COPY enterprise/app/models/captain/document.rb ./enterprise/app/models/captain/document.rb
COPY enterprise/app/models/captain/flow.rb ./enterprise/app/models/captain/flow.rb
COPY enterprise/app/models/captain/flow_edge.rb ./enterprise/app/models/captain/flow_edge.rb
COPY enterprise/app/models/captain/flow_node.rb ./enterprise/app/models/captain/flow_node.rb
COPY enterprise/app/models/captain_inbox.rb ./enterprise/app/models/captain_inbox.rb
COPY enterprise/app/models/enterprise/inbox.rb ./enterprise/app/models/enterprise/inbox.rb
COPY enterprise/app/models/enterprise/message.rb ./enterprise/app/models/enterprise/message.rb
COPY enterprise/app/models/enterprise/concerns/attachment.rb ./enterprise/app/models/enterprise/concerns/attachment.rb
COPY enterprise/app/models/enterprise/concerns/inbox.rb ./enterprise/app/models/enterprise/concerns/inbox.rb
COPY enterprise/app/controllers/api/v1/accounts/captain/assistants_controller.rb ./enterprise/app/controllers/api/v1/accounts/captain/assistants_controller.rb
COPY enterprise/app/controllers/api/v1/accounts/captain/inboxes_controller.rb ./enterprise/app/controllers/api/v1/accounts/captain/inboxes_controller.rb
COPY enterprise/app/views/api/v1/accounts/captain/inboxes/ ./enterprise/app/views/api/v1/accounts/captain/inboxes/
COPY enterprise/app/models/concerns/agentable.rb ./enterprise/app/models/concerns/agentable.rb
COPY enterprise/lib/captain/prompts/assistant.liquid ./enterprise/lib/captain/prompts/assistant.liquid
COPY enterprise/app/jobs/captain/conversation/response_builder_job.rb ./enterprise/app/jobs/captain/conversation/response_builder_job.rb
COPY enterprise/app/jobs/captain/inbox_pending_conversations_resolution_job.rb ./enterprise/app/jobs/captain/inbox_pending_conversations_resolution_job.rb
COPY enterprise/app/services/enterprise/message_templates/hook_execution_service.rb ./enterprise/app/services/enterprise/message_templates/hook_execution_service.rb
COPY enterprise/app/services/llm/base_ai_service.rb ./enterprise/app/services/llm/base_ai_service.rb
COPY enterprise/app/services/captain/llm/assistant_chat_service.rb ./enterprise/app/services/captain/llm/assistant_chat_service.rb
COPY enterprise/app/services/captain/llm/embedding_service.rb ./enterprise/app/services/captain/llm/embedding_service.rb
COPY enterprise/app/services/captain/flow_router.rb ./enterprise/app/services/captain/flow_router.rb
COPY enterprise/app/services/captain/flow_runtime.rb ./enterprise/app/services/captain/flow_runtime.rb
COPY enterprise/app/services/captain/conversation/response_policy_service.rb ./enterprise/app/services/captain/conversation/response_policy_service.rb
COPY enterprise/app/services/llm/legacy_base_open_ai_service.rb ./enterprise/app/services/llm/legacy_base_open_ai_service.rb
COPY app/models/installation_config.rb ./app/models/installation_config.rb
COPY app/models/concerns/featurable.rb ./app/models/concerns/featurable.rb
COPY app/controllers/dashboard_controller.rb ./app/controllers/dashboard_controller.rb
COPY app/controllers/evo_manager_controller.rb ./app/controllers/evo_manager_controller.rb
COPY config/initializers/ai_agents.rb ./config/initializers/ai_agents.rb
COPY config/initializers/enterprise_unlock.rb ./config/initializers/enterprise_unlock.rb
COPY lib/chatwoot_app.rb ./lib/chatwoot_app.rb
COPY lib/chatwoot_hub.rb ./lib/chatwoot_hub.rb
COPY lib/llm_constants.rb ./lib/llm_constants.rb
COPY lib/llm/config.rb ./lib/llm/config.rb
COPY lib/llm/media_config.rb ./lib/llm/media_config.rb
COPY lib/llm/gemini_multimodal_service.rb ./lib/llm/gemini_multimodal_service.rb
COPY lib/integrations/llm_base_service.rb ./lib/integrations/llm_base_service.rb
COPY lib/captain/base_task_service.rb ./lib/captain/base_task_service.rb
COPY lib/filters/filter_keys.yml ./lib/filters/filter_keys.yml
COPY enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb ./enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb
COPY enterprise/app/services/internal/reconcile_plan_config_service.rb ./enterprise/app/services/internal/reconcile_plan_config_service.rb
COPY public/brand-assets/ ./public/brand-assets/
COPY public/dashboard/images/ ./public/dashboard/images/

# Evolution API - Vue components e i18n
COPY app/javascript/dashboard/routes/dashboard/settings/inbox/channels/ ./app/javascript/dashboard/routes/dashboard/settings/inbox/channels/
COPY app/javascript/dashboard/i18n/locale/en/inboxMgmt.json ./app/javascript/dashboard/i18n/locale/en/inboxMgmt.json
COPY app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json ./app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json

# Helpers/constants customizados pelo rebrand ChusteRM (importados pelo dashboard.js)
COPY app/javascript/dashboard/helper/scriptHelpers.js ./app/javascript/dashboard/helper/scriptHelpers.js
COPY app/javascript/dashboard/constants/appEvents.js ./app/javascript/dashboard/constants/appEvents.js

# Instala pnpm via npm global, instala deps e recompila o bundle Vite
# com os componentes Evolution incluidos.
# INSTALL_JS_DEPS=true preserva node_modules para o serviço core-vite (hot-reload de dev).
ARG INSTALL_JS_DEPS=false
RUN node /usr/local/lib/node_modules/npm/bin/npm-cli.js install -g pnpm@10.2.0 && \
    pnpm install --no-frozen-lockfile && \
    SECRET_KEY_BASE=dummy bundle exec rake vite:build RAILS_ENV=production && \
    if [ "$INSTALL_JS_DEPS" != "true" ]; then rm -rf node_modules; fi

# Evolution API - Ruby backend
COPY app/dashboards/account_dashboard.rb ./app/dashboards/account_dashboard.rb
COPY config/routes.rb ./config/routes.rb
COPY app/controllers/api/v1/accounts/captain/ ./app/controllers/api/v1/accounts/captain/
COPY app/controllers/api/v1/accounts/campaigns_controller.rb ./app/controllers/api/v1/accounts/campaigns_controller.rb
COPY app/controllers/api/v1/accounts/crm/ ./app/controllers/api/v1/accounts/crm/
COPY app/views/api/v1/models/_campaign.json.jbuilder ./app/views/api/v1/models/_campaign.json.jbuilder
COPY app/views/api/v1/models/_contact.json.jbuilder ./app/views/api/v1/models/_contact.json.jbuilder
COPY app/views/api/v1/models/_inbox.json.jbuilder ./app/views/api/v1/models/_inbox.json.jbuilder
COPY app/views/api/v1/conversations/partials/_conversation.json.jbuilder ./app/views/api/v1/conversations/partials/_conversation.json.jbuilder
COPY app/views/api/v1/accounts/labels/ ./app/views/api/v1/accounts/labels/
COPY app/finders/conversation_finder.rb ./app/finders/conversation_finder.rb
COPY app/models/account.rb ./app/models/account.rb
COPY app/models/attachment.rb ./app/models/attachment.rb
COPY app/models/campaign.rb ./app/models/campaign.rb
COPY app/models/contact.rb ./app/models/contact.rb
COPY app/models/conversation.rb ./app/models/conversation.rb
COPY app/models/inbox.rb ./app/models/inbox.rb
COPY app/models/label.rb ./app/models/label.rb
COPY app/models/message.rb ./app/models/message.rb
COPY app/models/concerns/crm_score_classification.rb ./app/models/concerns/crm_score_classification.rb
COPY app/models/captain_conversation_state.rb ./app/models/captain_conversation_state.rb
COPY app/models/campaign_delivery_event.rb ./app/models/campaign_delivery_event.rb
COPY app/models/captain/ ./app/models/captain/
COPY app/models/crm_deal.rb ./app/models/crm_deal.rb
COPY app/models/crm_*.rb ./app/models/
COPY app/jobs/delete_object_job.rb ./app/jobs/delete_object_job.rb
COPY app/jobs/data_import_job.rb ./app/jobs/data_import_job.rb
COPY app/jobs/account/contacts_export_job.rb ./app/jobs/account/contacts_export_job.rb
COPY app/jobs/crm/ ./app/jobs/crm/
COPY app/mailers/campaign_mailer.rb ./app/mailers/campaign_mailer.rb
COPY app/controllers/api/v1/accounts/contacts_controller.rb ./app/controllers/api/v1/accounts/contacts_controller.rb
COPY app/controllers/api/v1/accounts/labels_controller.rb ./app/controllers/api/v1/accounts/labels_controller.rb
COPY app/controllers/api/v1/accounts/contact_categories_controller.rb ./app/controllers/api/v1/accounts/contact_categories_controller.rb
COPY app/services/captain/ ./app/services/captain/
COPY app/services/campaigns/ ./app/services/campaigns/
COPY app/services/contacts/sync_attributes.rb ./app/services/contacts/sync_attributes.rb
COPY app/services/data_import/ ./app/services/data_import/
COPY app/services/message_templates/hook_execution_service.rb ./app/services/message_templates/hook_execution_service.rb
COPY app/services/crm/ ./app/services/crm/
COPY app/services/email/ ./app/services/email/
COPY app/services/sms/oneoff_sms_campaign_service.rb ./app/services/sms/oneoff_sms_campaign_service.rb
COPY app/services/twilio/oneoff_sms_campaign_service.rb ./app/services/twilio/oneoff_sms_campaign_service.rb
COPY app/services/whatsapp/oneoff_campaign_service.rb ./app/services/whatsapp/oneoff_campaign_service.rb
COPY app/services/whatsapp/multiple_numbers_error.rb ./app/services/whatsapp/multiple_numbers_error.rb
COPY app/services/whatsapp/phone_info_service.rb ./app/services/whatsapp/phone_info_service.rb
COPY app/services/whatsapp/embedded_signup_service.rb ./app/services/whatsapp/embedded_signup_service.rb
COPY app/services/whatsapp/embedded_signup/ ./app/services/whatsapp/embedded_signup/
COPY app/controllers/api/v1/accounts/whatsapp/ ./app/controllers/api/v1/accounts/whatsapp/
COPY app/models/whatsapp_embedded_onboarding.rb ./app/models/whatsapp_embedded_onboarding.rb
COPY db/migrate/20260508*.rb ./db/migrate/
COPY enterprise/app/jobs/messages/media_understanding_job.rb ./enterprise/app/jobs/messages/media_understanding_job.rb
COPY enterprise/app/services/messages/audio_transcription_service.rb ./enterprise/app/services/messages/audio_transcription_service.rb
COPY enterprise/app/services/messages/media_understanding_service.rb ./enterprise/app/services/messages/media_understanding_service.rb
COPY enterprise/app/services/captain/copilot/chat_service.rb ./enterprise/app/services/captain/copilot/chat_service.rb
COPY enterprise/app/services/captain/llm/assistant_chat_service.rb ./enterprise/app/services/captain/llm/assistant_chat_service.rb
COPY enterprise/app/services/captain/llm/embedding_service.rb ./enterprise/app/services/captain/llm/embedding_service.rb
COPY enterprise/app/services/captain/llm/system_prompts_service.rb ./enterprise/app/services/captain/llm/system_prompts_service.rb
COPY enterprise/app/services/captain/tools/copilot/get_crm_context_service.rb ./enterprise/app/services/captain/tools/copilot/get_crm_context_service.rb
COPY enterprise/app/services/captain/assistant/agent_runner_service.rb ./enterprise/app/services/captain/assistant/agent_runner_service.rb
COPY enterprise/app/services/captain/assistant/deterministic_crm_actions_service.rb ./enterprise/app/services/captain/assistant/deterministic_crm_actions_service.rb
COPY enterprise/app/services/captain/conversation/response_policy_service.rb ./enterprise/app/services/captain/conversation/response_policy_service.rb
COPY enterprise/lib/captain/tools/handoff_tool.rb ./enterprise/lib/captain/tools/handoff_tool.rb
COPY app/listeners/crm_captain_triage_listener.rb ./app/listeners/crm_captain_triage_listener.rb
COPY app/dispatchers/async_dispatcher.rb ./app/dispatchers/async_dispatcher.rb
COPY app/policies/label_policy.rb ./app/policies/label_policy.rb
COPY app/policies/crm_*.rb ./app/policies/
# Patches de migrations da imagem base do Chatwoot com incompatibilidades de versao
COPY db/migrate/20231211010807_add_cached_labels_list.rb ./db/migrate/
COPY db/migrate/20260324102005_repurpose_response_bot_flag_for_custom_tools.rb ./db/migrate/
# Stubs no-op para 22 migrations órfãs herdadas de versão anterior do Chatwoot
# (vide docs/system-audit-report.md NEW-01). Copiar para satisfazer schema_migrations.
COPY db/migrate/20260404*.rb ./db/migrate/
COPY db/migrate/20260405*.rb ./db/migrate/
COPY db/migrate/20260406*.rb ./db/migrate/
COPY db/migrate/20260407*.rb ./db/migrate/
# Wildcard amplo cobre todas as migrations 2026 customizadas — evita órfãs por COPY
# específico esquecido (ex.: 20260502*, 20260507* que ficaram fora antes).
COPY db/migrate/20260403*.rb ./db/migrate/
COPY db/migrate/20260429*.rb ./db/migrate/
COPY db/migrate/20260430*.rb ./db/migrate/
COPY db/migrate/20260501*.rb ./db/migrate/
COPY db/migrate/20260502*.rb ./db/migrate/
COPY db/migrate/20260504*.rb ./db/migrate/
COPY db/migrate/20260505*.rb ./db/migrate/
COPY db/migrate/20260506*.rb ./db/migrate/
COPY db/migrate/20260507*.rb ./db/migrate/
COPY db/migrate/20260519*.rb ./db/migrate/
COPY lib/tasks/crm_labels.rake ./lib/tasks/crm_labels.rake
COPY lib/tasks/crm_contacts.rake ./lib/tasks/crm_contacts.rake
COPY lib/tasks/crm_health.rake ./lib/tasks/crm_health.rake
COPY lib/tasks/crm_smoke.rake ./lib/tasks/crm_smoke.rake
COPY lib/tasks/captain_playbooks.rake ./lib/tasks/captain_playbooks.rake
COPY lib/tasks/captain_dr_paula_matos.rake ./lib/tasks/captain_dr_paula_matos.rake
COPY db/seeds.rb ./db/seeds.rb
COPY db/seeds/ ./db/seeds/
COPY app/models/channel/whatsapp.rb ./app/models/channel/whatsapp.rb
COPY app/controllers/dashboard_controller.rb ./app/controllers/dashboard_controller.rb
COPY app/controllers/evo_manager_controller.rb ./app/controllers/evo_manager_controller.rb
COPY app/controllers/api/v1/accounts/crm_controller.rb ./app/controllers/api/v1/accounts/crm_controller.rb
COPY app/services/whatsapp/providers/evolution_service.rb ./app/services/whatsapp/providers/evolution_service.rb
COPY app/services/whatsapp/incoming_message_evolution_service.rb ./app/services/whatsapp/incoming_message_evolution_service.rb
COPY app/controllers/webhooks/evolution_controller.rb ./app/controllers/webhooks/evolution_controller.rb
COPY app/controllers/api/v1/accounts/channels/evolution_controller.rb ./app/controllers/api/v1/accounts/channels/evolution_controller.rb
COPY app/jobs/webhooks/evolution_events_job.rb ./app/jobs/webhooks/evolution_events_job.rb
COPY app/jobs/webhooks/whatsapp_events_job.rb ./app/jobs/webhooks/whatsapp_events_job.rb
COPY app/jobs/channels/whatsapp/ ./app/jobs/channels/whatsapp/
COPY app/jobs/channels/evolution_connection_health_job.rb ./app/jobs/channels/evolution_connection_health_job.rb
COPY config/schedule.yml ./config/schedule.yml
COPY config/initializers/disable_evented_watcher.rb ./config/initializers/disable_evented_watcher.rb
COPY config/environments/development.rb ./config/environments/development.rb
COPY config/initializers/vite_hot_reload.rb ./config/initializers/vite_hot_reload.rb
COPY config/initializers/evolution_routes.rb ./config/initializers/evolution_routes.rb
COPY config/initializers/01_inject_enterprise_edition_module.rb ./config/initializers/01_inject_enterprise_edition_module.rb
COPY config/initializers/chusterm_branding.rb ./config/initializers/chusterm_branding.rb
COPY config/initializers/chusterm_compatibility_aliases.rb ./config/initializers/chusterm_compatibility_aliases.rb
COPY config/initializers/chusterm_exception_tracker_alias.rb ./config/initializers/chusterm_exception_tracker_alias.rb
COPY config/initializers/active_record_query_trace.rb ./config/initializers/active_record_query_trace.rb
COPY config/application.rb ./config/application.rb
# Templates de email traduzidos para pt_BR
COPY app/views/devise/mailer/ ./app/views/devise/mailer/

EXPOSE 3000
CMD ["sh", "-c", "rm -f /app/tmp/pids/server.pid && bundle exec rails s -b 0.0.0.0 -p 3000"]

# syntax=docker/dockerfile:1
# ChusteRM Core - Fork do Chatwoot com Evolution API (Baileys) integrada
# Keep the fork reproducible and aligned with its locked Ruby/Vite toolchain.
# Upgrading this digest requires an explicit upstream-compatibility audit.
ARG CHATWOOT_BASE_IMAGE=chatwoot/chatwoot@sha256:548710d17cd70b40b402eca3fced7325ebac6a3a998f2accb18fbc574393f458
FROM ${CHATWOOT_BASE_IMAGE}

WORKDIR /app

# Install the locked Ruby runtime instead of silently inheriting the gems from
# the upstream image. This keeps the container aligned with local tests and CI.
COPY Gemfile ./Gemfile
COPY Gemfile.lock ./Gemfile.lock
RUN apk add --no-cache yaml-dev && \
    GRPC_RUBY_BUILD_PROCS=2 bundle install --jobs 2 --retry 3

# Use repository package manifests so frontend builds install the rebranded dependencies.
COPY package.json ./package.json
COPY pnpm-lock.yaml ./pnpm-lock.yaml
COPY tailwind.config.js ./tailwind.config.js
COPY scripts/install_husky.cjs ./scripts/install_husky.cjs

# ChusteRM Theme
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
COPY app/javascript/widget/ ./app/javascript/widget/
COPY app/javascript/portal/ ./app/javascript/portal/
COPY app/javascript/sdk/ ./app/javascript/sdk/
COPY app/javascript/survey/ ./app/javascript/survey/
COPY app/javascript/entrypoints/sdk.js ./app/javascript/entrypoints/sdk.js
COPY app/javascript/entrypoints/widget.js ./app/javascript/entrypoints/widget.js
COPY app/views/layouts/vueapp.html.erb ./app/views/layouts/vueapp.html.erb
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
COPY enterprise/ ./enterprise/
COPY lib/redis/alfred.rb ./lib/redis/alfred.rb
COPY app/models/installation_config.rb ./app/models/installation_config.rb
COPY app/controllers/super_admin/app_configs_controller.rb ./app/controllers/super_admin/app_configs_controller.rb
COPY app/models/concerns/featurable.rb ./app/models/concerns/featurable.rb
COPY app/controllers/dashboard_controller.rb ./app/controllers/dashboard_controller.rb
COPY app/controllers/evo_manager_controller.rb ./app/controllers/evo_manager_controller.rb
COPY config/initializers/ai_agents.rb ./config/initializers/ai_agents.rb
COPY config/initializers/enterprise_unlock.rb ./config/initializers/enterprise_unlock.rb
COPY config/initializers/sidekiq.rb ./config/initializers/sidekiq.rb
COPY lib/chatwoot_app.rb ./lib/chatwoot_app.rb
COPY lib/chatwoot_hub.rb ./lib/chatwoot_hub.rb
COPY lib/llm_constants.rb ./lib/llm_constants.rb
COPY lib/llm/config.rb ./lib/llm/config.rb
COPY lib/llm/media_config.rb ./lib/llm/media_config.rb
COPY lib/llm/transient_provider_error.rb ./lib/llm/transient_provider_error.rb
COPY lib/llm/open_router_multimodal_service.rb ./lib/llm/open_router_multimodal_service.rb
COPY lib/integrations/llm_base_service.rb ./lib/integrations/llm_base_service.rb
COPY lib/captain/base_task_service.rb ./lib/captain/base_task_service.rb
COPY lib/captain/tool_instrumentation.rb ./lib/captain/tool_instrumentation.rb
COPY lib/filters/filter_keys.yml ./lib/filters/filter_keys.yml
COPY enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb ./enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb
COPY enterprise/app/services/internal/reconcile_plan_config_service.rb ./enterprise/app/services/internal/reconcile_plan_config_service.rb
COPY public/brand-assets/ ./public/brand-assets/
COPY public/favicon*.png public/favicon.ico ./public/
COPY public/apple*.png ./public/
COPY public/android*.png ./public/
COPY public/ms-icon*.png ./public/
COPY public/dashboard/images/ ./public/dashboard/images/

# Evolution API - Vue components e i18n
COPY app/javascript/dashboard/routes/dashboard/settings/inbox/channels/ ./app/javascript/dashboard/routes/dashboard/settings/inbox/channels/
COPY app/javascript/dashboard/i18n/locale/en/inboxMgmt.json ./app/javascript/dashboard/i18n/locale/en/inboxMgmt.json
COPY app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json ./app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json

# Helpers/constants customizados pelo rebrand ChusteRM (importados pelo dashboard.js)
COPY app/javascript/dashboard/helper/scriptHelpers.js ./app/javascript/dashboard/helper/scriptHelpers.js
COPY app/javascript/dashboard/constants/appEvents.js ./app/javascript/dashboard/constants/appEvents.js
COPY config/initializers/monkey_patches/schema_dumper.rb ./config/initializers/monkey_patches/schema_dumper.rb
COPY config/initializers/devise_secure_password_compat.rb ./config/initializers/devise_secure_password_compat.rb
COPY lib/devise/models/password_has_required_content.rb ./lib/devise/models/password_has_required_content.rb

# Instala pnpm via npm global, instala deps e recompila o bundle Vite
# com os componentes Evolution incluidos.
# INSTALL_JS_DEPS=true preserva node_modules para o serviço core-vite (hot-reload de dev).
  ARG INSTALL_JS_DEPS=false
  RUN node /usr/local/lib/node_modules/npm/bin/npm-cli.js install -g pnpm@10.2.0 && \
      pnpm install --frozen-lockfile && \
      rm -rf public/vite tmp/cache/vite /app/public/vite-image && \
      SECRET_KEY_BASE=dummy NODE_OPTIONS="--max-old-space-size=4096" bundle exec rake vite:build RAILS_ENV=production && \
      cp -a public/vite /app/public/vite-image && \
      if [ "$INSTALL_JS_DEPS" != "true" ]; then rm -rf node_modules; fi

# Deploy integrity — the repo is the source of truth for ALL application code.
# The previous cherry-picked COPY list silently left ~190 fork-modified files on
# the stale base-image version (e.g. send_on_whatsapp_service.rb ran the March
# upstream file without the Evolution session-message bypass). The base image
# now only provides the OS, system packages and the prebuilt toolchain.
COPY app ./app
COPY lib ./lib
COPY config ./config
COPY db ./db
COPY bin ./bin
COPY vendor ./vendor
COPY scripts ./scripts
COPY swagger ./swagger
RUN rm -f ./app/controllers/api/v1/accounts/crm_controller.rb

EXPOSE 3000
CMD ["sh", "-c", "rm -f /app/tmp/pids/server.pid && bundle exec rails s -b 0.0.0.0 -p 3000"]

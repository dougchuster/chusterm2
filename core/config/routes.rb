Rails.application.routes.draw do
  # Evolution API Manager — login customizado vinculado ao super admin
  # O Evolution Manager é administrativo e fica acessível somente por túnel
  # SSH à porta loopback 8085. Nunca entregue a chave global ao navegador pela
  # aplicação pública.

  # AUTH STARTS
  mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    confirmations: 'devise_overrides/confirmations',
    passwords: 'devise_overrides/passwords',
    sessions: 'devise_overrides/sessions',
    token_validations: 'devise_overrides/token_validations',
    omniauth_callbacks: 'devise_overrides/omniauth_callbacks'
  }, via: [:get, :post]

  ## renders the frontend paths only if its not an api only server
  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('CW_API_ONLY_SERVER', false))
    root to: 'api#index'
  else
    root to: 'dashboard#index'

    get '/app', to: 'dashboard#index'
    get '/app/*params', to: 'dashboard#index'
    get '/app/accounts/:account_id/settings/inboxes/new/twitter', to: 'dashboard#index', as: 'app_new_twitter_inbox'
    get '/app/accounts/:account_id/settings/inboxes/new/microsoft', to: 'dashboard#index', as: 'app_new_microsoft_inbox'
    get '/app/accounts/:account_id/settings/inboxes/new/instagram', to: 'dashboard#index', as: 'app_new_instagram_inbox'
    get '/app/accounts/:account_id/settings/inboxes/new/tiktok', to: 'dashboard#index', as: 'app_new_tiktok_inbox'
    get '/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_twitter_inbox_agents'
    get '/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_email_inbox_agents'
    get '/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_instagram_inbox_agents'
    get '/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_tiktok_inbox_agents'
    get '/app/accounts/:account_id/settings/inboxes/:inbox_id', to: 'dashboard#index', as: 'app_instagram_inbox_settings'
    get '/app/accounts/:account_id/settings/inboxes/:inbox_id', to: 'dashboard#index', as: 'app_tiktok_inbox_settings'
    get '/app/accounts/:account_id/settings/inboxes/:inbox_id', to: 'dashboard#index', as: 'app_email_inbox_settings'

    resource :widget, only: [:show]
    namespace :survey do
      resources :responses, only: [:show]
    end
    resource :slack_uploads, only: [:show]
  end

  get '/health', to: 'health#show'
  get '/api', to: 'api#index'
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      # ----------------------------------
      # start of account scoped api routes
      resources :accounts, only: [:create, :show, :update] do
        member do
          post :update_active_at
          get :cache_keys
        end

        scope module: :accounts do
          namespace :actions do
            resource :contact_merge, only: [:create]
          end
          resource :bulk_actions, only: [:create]
          resources :agents, only: [:index, :create, :update, :destroy] do
            post :bulk_create, on: :collection
          end
          namespace :captain do
            # UX-04: Central de IA — visão consolidada do estado da IA por conta
            get :ai_center, to: 'ai_center#index'
            resource :preferences, only: [:show, :update]
            resources :assistants do
              member do
                post :playground
              end
              collection do
                get :tools
              end
              resources :inboxes, only: [:index, :create, :destroy], param: :inbox_id
              resources :scenarios
            end
            resources :assistant_responses
            resources :bulk_actions, only: [:create]
            resources :copilot_threads, only: [:index, :create] do
              resources :copilot_messages, only: [:index, :create]
            end
            resources :custom_tools
            resources :agent_configs, only: [:show, :update], param: :assistant_id
            resources :documents, only: [:index, :show, :create, :destroy]
            resources :document_versions, only: [:index, :show]
            resources :playbooks, only: [:index, :show, :create, :update, :destroy]
            resources :conversation_states, only: [:show, :update], param: :conversation_display_id
            resources :score_settings, only: [:index, :update], param: :campaign_id do
              collection do
                patch 'conversation_states/:id', action: :update_conversation_state
              end
            end
            resources :flows do
              member do
                post :publish
                post :graph
              end
            end
            resource :tasks, only: [], controller: 'tasks' do
              post :rewrite
              post :summarize
              post :reply_suggestion
              post :label_suggestion
              post :follow_up
            end
          end
          resource :saml_settings, only: [:show, :create, :update, :destroy]
          resources :agent_bots, only: [:index, :create, :show, :update, :destroy] do
            delete :avatar, on: :member
            post :reset_access_token, on: :member
          end
          resources :contact_inboxes, only: [] do
            collection do
              post :filter
            end
          end
          resources :assignable_agents, only: [:index]
          resource :audit_logs, only: [:show]
          resources :callbacks, only: [] do
            collection do
              post :register_facebook_page
              get :register_facebook_page
              post :facebook_pages
              post :reauthorize_page
            end
          end
          resources :canned_responses, only: [:index, :create, :update, :destroy]
          resources :automation_rules, only: [:index, :create, :show, :update, :destroy] do
            post :clone
          end
          resources :macros, only: [:index, :create, :show, :update, :destroy] do
            post :execute, on: :member
          end
          resources :sla_policies, only: [:index, :create, :show, :update, :destroy]
          resources :custom_roles, only: [:index, :create, :show, :update, :destroy]
          resources :agent_capacity_policies, only: [:index, :create, :show, :update, :destroy] do
            scope module: :agent_capacity_policies do
              resources :users, only: [:index, :create, :destroy]
              resources :inbox_limits, only: [:create, :update, :destroy]
            end
          end
          resources :campaigns, only: [:index, :create, :show, :update, :destroy] do
            post :audience_count, on: :collection
            post :audience_preview, on: :collection
            post :track_event, on: :member
          end
          resources :dashboard_apps, only: [:index, :show, :create, :update, :destroy]
          namespace :crm do
            resource :google_authorization, only: [:show, :create]
            get :agenda_events, to: 'agenda_events#index'
            get :dashboard, to: 'dashboard#index'
            get :options, to: 'options#index'
            # Fase 2: packs de vertical (só responde com crm_universal ligado).
            resources :packs, only: [:index, :create] do
              collection do
                # 3.4: prompt da IA do pack + override por conta.
                patch :ai_settings
              end
            end
            resource :health, only: [:show], controller: :health

            # 3.1b: tools de CRM executadas pela IA (orchestrator/AgentBot).
            resources :agent_tools, only: [:index] do
              collection { post :execute }
            end

            # F2.7: visoes salvas do board (lacuna K-05).
            resources :board_views, only: [:index, :create, :update, :destroy]

            # Cofre de documentos (PROJETO-COFRE-DOCUMENTOS.md). Só responde com
            # accounts.settings['crm_documents'] ligado (ADR-DOC, D15).
            resources :document_folders, only: [:index, :create, :update, :destroy]
            resources :document_types, only: [:index, :create, :update, :destroy]
            resource :document_settings, only: [:show, :update]
            resources :document_folder_templates, only: [:index, :update]
            resources :document_forms, only: [:index, :show, :create, :update, :destroy] do
              member { post :links }
            end
            resources :document_submissions, only: [:index, :show, :update]
            resource :document_checklist, only: [:show, :update]
            resources :documents, only: [:index, :show, :create, :update, :destroy] do
              collection do
                get :triage
                get :queue
              end
              member do
                get :download
                post :restore
                delete :purge
              end
            end

            resources :pipelines, only: [:index, :create, :update, :destroy] do
              member do
                delete :purge
                patch :restore
                # F1.5: o board pinta com uma requisicao. Vai para o
                # DealsController porque a coluna devolve cards.
                get :board, to: 'deals#board'
              end
              collection do
                get :archived
              end
              resources :stages, controller: 'pipeline_stages', only: [:index, :create, :update, :destroy] do
                member do
                  delete :purge
                  patch :restore
                end
                collection do
                  get :archived
                end
              end
            end

            resources :deals, only: [:index, :show, :create, :update, :destroy] do
              collection do
                post :export
                post :bulk_action
                delete :purge_orphans
              end

              member do
                post :move
                patch :move
                post :mark_won
                post :mark_lost
                post :reopen
                post :archive
                post :discard
                post :mark_base_client
              end
            end

            resources :loss_reasons, path: 'loss-reasons', only: [:index, :create, :update]
            resources :activities, only: [:index, :create, :update, :destroy] do
              get :calendar, on: :collection
              post :import_google_calendar, on: :collection
              post :suggest_schedule, on: :collection
              post :schedule_suggestion, on: :collection
              post :complete, on: :member
              post :snooze, on: :member
              post :sync_google_calendar, on: :member
            end
            resources :audit_events, path: 'audit-events', only: [:index]
            resources :checklist_templates, path: 'checklist-templates', only: [:index, :create, :update, :destroy]
            resources :automation_rules, path: 'automation-rules', only: [:index, :create, :update, :destroy]
            resources :automation_runs, path: 'automation-runs', only: [:index]
            resources :cadences, only: [:index, :create, :update, :destroy] do
              collection do
                post :enroll_deal
                post :unenroll_deal
              end
            end

            post 'lead-scores/recompute', to: 'lead_scores#recompute'
            post 'triage/from-conversation/:conversation_id', to: 'triage/from_conversation#create'
            post 'analyst/ask', to: 'analyst#create'

            get 'metrics/overview', to: 'metrics#overview'
            get 'metrics/stage_funnel', to: 'metrics#stage_funnel'
            get 'metrics/time_in_stage', to: 'metrics#time_in_stage'
            get 'metrics/win_loss_trend', to: 'metrics#win_loss_trend'
            get 'metrics/top_loss_reasons', to: 'metrics#top_loss_reasons'
            get 'metrics/score_by_stage', to: 'metrics#score_by_stage'
            get 'metrics/area_distribution', to: 'metrics#area_distribution'
            get 'metrics/top_deals', to: 'metrics#top_deals'
            get 'metrics/stale_deals', to: 'metrics#stale_deals'
            get 'metrics/first_response', to: 'metrics#first_response'
            get 'metrics/weighted_forecast', to: 'metrics#weighted_forecast'
            post 'mcp', to: 'mcp#create'
          end
          namespace :marketing do
            resources :connections, only: [:index, :destroy] do
              collection do
                post :authorize
              end
              member do
                post :sync
              end
            end
            resources :campaigns, only: [:index] do
              member do
                post :set_status
              end
            end
            resources :leads, only: [:index, :show] do
              member do
                post :discard
                post :convert
              end
            end
            resources :events, only: [:index] do
              member do
                post :retry
              end
            end
            get 'metrics/overview', to: 'metrics#overview'
            get 'metrics/insights', to: 'metrics#insights'
          end
          namespace :channels do
            resource :twilio_channel, only: [:create]

            namespace :evolution do
              resources :inboxes, only: [:create]
              resources :instances, only: [:show, :destroy] do
                member do
                  get :qr_code
                  get :connection_status
                  post :reconnect
                  post :logout
                  post :restart
                  post :sync
                  post :sync_history
                end
              end
            end

            scope :evolution do
              get 'qr_code', to: 'evolution#qr_code'
              get 'connection_status', to: 'evolution#connection_status'
              get 'instances', to: 'evolution#instances'
              post 'preview_instances', to: 'evolution#preview_instances'
              post 'link_instance', to: 'evolution#link_instance'
            end
          end

          namespace :evolution do
            resource :configuration, only: [:show, :create, :update] do
              post :validate
            end
          end

          resources :conversations, only: [:index, :create, :show, :update, :destroy] do
            collection do
              get :meta
              get :search
              post :filter
            end
            scope module: :conversations do
              resources :messages, only: [:index, :create, :destroy, :update] do
                member do
                  post :translate
                  post :retry
                end
              end
              resources :assignments, only: [:create]
              resources :labels, only: [:create, :index]
              resource :participants, only: [:show, :create, :update, :destroy]
              resource :direct_uploads, only: [:create]
              resource :draft_messages, only: [:show, :update, :destroy]
            end
            member do
              post :mute
              post :unmute
              post :transcript
              post :toggle_status
              post :toggle_priority
              post :toggle_typing_status
              post :update_last_seen
              post :unread
              post :custom_attributes
              get :attachments
              get :inbox_assistant
              get :reporting_events if ChatwootApp.enterprise?
            end
          end

          resources :search, only: [:index] do
            collection do
              get :conversations
              get :messages
              get :contacts
              get :articles
            end
          end

          resources :companies, only: [:index, :show, :create, :update, :destroy] do
            collection do
              get :search
            end
          end
          resources :contacts, only: [:index, :show, :update, :create, :destroy] do
            collection do
              get :active
              get :search
              get :imports
              post :filter
              post :import
              post :export
              post :export_csv
              post :export_google_sheet
            end
            member do
              get :contactable_inboxes
              get :data_export
              post :data_erasure
              post :destroy_custom_attributes
              delete :avatar
            end
            scope module: :contacts do
              resources :conversations, only: [:index]
              resources :contact_inboxes, only: [:create]
              resources :labels, only: [:create, :index]
              resources :notes
              post :call, on: :member, to: 'calls#create' if ChatwootApp.enterprise?
            end
          end
          resources :csat_survey_responses, only: [:index] do
            collection do
              get :metrics
              get :download
            end
            member do
              patch :update if ChatwootApp.enterprise?
            end
          end
          resources :applied_slas, only: [:index] do
            collection do
              get :metrics
              get :download
            end
          end
          resources :reporting_events, only: [:index] if ChatwootApp.enterprise?
          resources :custom_attribute_definitions, only: [:index, :show, :create, :update, :destroy]
          resources :custom_filters, only: [:index, :show, :create, :update, :destroy]
          resources :inboxes, only: [:index, :show, :create, :update, :destroy] do
            get :assignable_agents, on: :member
            get :campaigns, on: :member
            get :agent_bot, on: :member
            post :set_agent_bot, on: :member
            delete :avatar, on: :member
            post :sync_templates, on: :member
            get :health, on: :member
            post :register_webhook, on: :member
            if ChatwootApp.enterprise?
              resource :conference, only: %i[create destroy], controller: 'conference' do
                get :token, on: :member
              end
            end

            resource :csat_template, only: [:show, :create], controller: 'inbox_csat_templates' do
              post :analyze, on: :collection
            end
          end

          resources :inbox_members, only: [:create, :show], param: :inbox_id do
            collection do
              delete :destroy
              patch :update
            end
          end
          resources :labels, only: [:index, :show, :create, :update, :destroy]
          resources :contact_categories, only: [:index, :show, :create, :update, :destroy] do
            collection do
              post :bulk_assign
              post :bulk_remove
            end
          end

          resources :notifications, only: [:index, :update, :destroy] do
            collection do
              post :read_all
              get :unread_count
              post :destroy_all
            end
            member do
              post :snooze
              post :unread
            end
          end
          resource :notification_settings, only: [:show, :update]

          resources :teams do
            resources :team_members, only: [:index, :create] do
              collection do
                delete :destroy
                patch :update
              end
            end
          end

          # Assignment V2 Routes
          resources :assignment_policies do
            resources :inboxes, only: [:index, :create, :destroy], module: :assignment_policies
          end

          resources :inboxes, only: [] do
            resource :assignment_policy, only: [:show, :create, :destroy], module: :inboxes
          end

          namespace :twitter do
            resource :authorization, only: [:create]
          end

          namespace :microsoft do
            resource :authorization, only: [:create]
          end

          namespace :google do
            resource :authorization, only: [:create]
          end

          namespace :instagram do
            resource :authorization, only: [:create]
          end

          namespace :tiktok do
            resource :authorization, only: [:create]
          end

          namespace :notion do
            resource :authorization, only: [:create]
          end

          namespace :whatsapp do
            resource :authorization, only: [:create]
          end

          resources :webhooks, only: [:index, :create, :update, :destroy]
          namespace :integrations do
            resources :apps, only: [:index, :show]
            resources :hooks, only: [:show, :create, :update, :destroy] do
              member do
                post :process_event
              end
            end
            resource :slack, only: [:create, :update, :destroy], controller: 'slack' do
              member do
                get :list_all_channels
              end
            end
            resource :dyte, controller: 'dyte', only: [] do
              collection do
                post :create_a_meeting
                post :add_participant_to_meeting
              end
            end
            resource :shopify, controller: 'shopify', only: [:destroy] do
              collection do
                post :auth
                get :orders
              end
            end
            resource :linear, controller: 'linear', only: [] do
              collection do
                delete :destroy
                get :teams
                get :team_entities
                post :create_issue
                post :link_issue
                post :unlink_issue
                get :search_issue
                get :linked_issues
              end
            end
            resource :notion, controller: 'notion', only: [] do
              collection do
                delete :destroy
              end
            end
          end
          resources :working_hours, only: [:update]

          resources :portals do
            member do
              patch :archive
              delete :logo
              post :send_instructions
              get :ssl_status
            end
            resources :categories do
              post :reorder, on: :collection
            end
            resources :articles do
              post :reorder, on: :collection
            end
          end

          resources :upload, only: [:create]
        end
      end
      # end of account scoped api routes
      # ----------------------------------

      namespace :integrations do
        resources :webhooks, only: [:create]
      end

      # Frontend API endpoint to trigger SAML authentication flow
      post 'auth/saml_login', to: 'auth#saml_login'

      resource :profile, only: [:show, :update] do
        delete :avatar, on: :collection
        member do
          post :availability
          post :auto_offline
          put :set_active_account
          post :resend_confirmation
          post :reset_access_token
        end

        # MFA routes
        scope module: 'profile' do
          resource :mfa, controller: 'mfa', only: [:show, :create, :destroy] do
            post :verify
            post :backup_codes
          end
        end
      end

      resource :notification_subscriptions, only: [:create, :destroy]

      namespace :widget do
        resource :direct_uploads, only: [:create]
        resource :config, only: [:create]
        resources :campaigns, only: [:index]
        resources :events, only: [:create]
        resources :messages, only: [:index, :create, :update]
        resources :conversations, only: [:index, :create] do
          collection do
            post :destroy_custom_attributes
            post :set_custom_attributes
            post :update_last_seen
            post :toggle_typing
            post :transcript
            get  :toggle_status
          end
        end
        resource :contact, only: [:show, :update] do
          collection do
            post :destroy_custom_attributes
            patch :set_user
          end
        end
        resources :inbox_members, only: [:index]
        resources :labels, only: [:create, :destroy]
        namespace :integrations do
          resource :dyte, controller: 'dyte', only: [] do
            collection do
              post :add_participant_to_meeting
            end
          end
        end
      end
    end

    namespace :v2 do
      resources :accounts, only: [:create] do
        scope module: :accounts do
          resources :summary_reports, only: [] do
            collection do
              get :agent
              get :team
              get :inbox
              get :label
              get :channel
            end
          end
          resources :reports, only: [:index] do
            collection do
              get :summary
              get :bot_summary
              get :agents
              get :inboxes
              get :labels
              get :teams
              get :conversations
              get :conversations_summary
              get :conversation_traffic
              get :bot_metrics
              get :inbox_label_matrix
              get :first_response_time_distribution
              get :outgoing_messages_count
            end
          end
          resource :year_in_review, only: [:show]
          resources :live_reports, only: [] do
            collection do
              get :conversation_metrics
              get :grouped_conversation_metrics
            end
          end
        end
      end
    end
  end

  if ChatwootApp.enterprise?
    namespace :enterprise, defaults: { format: 'json' } do
      namespace :api do
        namespace :v1 do
          resources :accounts do
            member do
              post :checkout
              post :subscription
              get :limits
              post :toggle_deletion
              post :topup_checkout
            end
          end
        end
      end

      post 'webhooks/stripe', to: 'webhooks/stripe#process_payload'
      post 'webhooks/firecrawl', to: 'webhooks/firecrawl#process_payload'
    end
  end

  # ----------------------------------------------------------------------
  # Routes for platform APIs
  namespace :platform, defaults: { format: 'json' } do
    namespace :api do
      namespace :v1 do
        resources :users, only: [:create, :show, :update, :destroy] do
          member do
            get :login
            post :token
          end
        end
        resources :agent_bots, only: [:index, :create, :show, :update, :destroy] do
          delete :avatar, on: :member
        end
        resources :accounts, only: [:index, :create, :show, :update, :destroy] do
          resources :account_users, only: [:index, :create] do
            collection do
              delete :destroy
            end
          end
          resources :email_channel_migrations, only: [:create]
        end
      end
    end
  end

  # ----------------------------------------------------------------------
  # Routes for inbox APIs Exposed to contacts
  namespace :public, defaults: { format: 'json' } do
    namespace :api do
      namespace :v1 do
        resources :inboxes do
          scope module: :inboxes do
            resources :contacts, only: [:create, :show, :update] do
              resources :conversations, only: [:index, :create, :show] do
                member do
                  post :toggle_status
                  post :toggle_typing
                  post :update_last_seen
                end

                resources :messages, only: [:index, :create, :update]
              end
            end
          end
        end

        resources :csat_survey, only: [:show, :update]
      end
    end
  end

  get 'hc/:slug', to: 'public/api/v1/portals#show'
  get 'hc/:slug/sitemap.xml', to: 'public/api/v1/portals#sitemap'
  get 'hc/:slug/:locale', to: 'public/api/v1/portals#show'
  get 'hc/:slug/:locale/articles', to: 'public/api/v1/portals/articles#index'
  get 'hc/:slug/:locale/categories', to: 'public/api/v1/portals/categories#index'
  get 'hc/:slug/:locale/categories/:category_slug', to: 'public/api/v1/portals/categories#show'
  get 'hc/:slug/:locale/categories/:category_slug/articles', to: 'public/api/v1/portals/articles#index'
  get 'hc/:slug/articles/:article_slug.png', to: 'public/api/v1/portals/articles#tracking_pixel'
  get 'hc/:slug/articles/:article_slug', to: 'public/api/v1/portals/articles#show'

  # ----------------------------------------------------------------------
  # Used in mailer templates
  resource :app, only: [:index] do
    resources :accounts do
      resources :conversations, only: [:show]
    end
  end

  # ----------------------------------------------------------------------
  # Routes for channel integrations
  mount Facebook::Messenger::Server, at: 'bot'
  get 'webhooks/twitter', to: 'api/v1/webhooks#twitter_crc'
  post 'webhooks/twitter', to: 'api/v1/webhooks#twitter_events'
  post 'webhooks/line/:line_channel_id', to: 'webhooks/line#process_payload'
  post 'webhooks/telegram/:bot_token', to: 'webhooks/telegram#process_payload'
  post 'webhooks/sms/:phone_number', to: 'webhooks/sms#process_payload'
  get 'webhooks/evolution/:webhook_token', to: 'webhooks/evolution#verify', format: false
  post 'webhooks/evolution/:webhook_token', to: 'webhooks/evolution#process_payload', format: false
  get 'webhooks/evolution/*phone_number', to: 'webhooks/evolution#verify', format: false
  post 'webhooks/evolution/*phone_number', to: 'webhooks/evolution#process_payload', format: false
  get 'webhooks/whatsapp/:phone_number', to: 'webhooks/whatsapp#verify'
  post 'webhooks/whatsapp/:phone_number', to: 'webhooks/whatsapp#process_payload'
  get 'webhooks/instagram', to: 'webhooks/instagram#verify'
  post 'webhooks/instagram', to: 'webhooks/instagram#events'
  post 'webhooks/tiktok', to: 'webhooks/tiktok#events'
  post 'webhooks/shopify', to: 'webhooks/shopify#events'
  get 'webhooks/meta_leadgen', to: 'webhooks/meta_leadgen#verify'
  post 'webhooks/meta_leadgen', to: 'webhooks/meta_leadgen#process_payload'

  namespace :twitter do
    resource :callback, only: [:show]
  end

  namespace :linear do
    resource :callback, only: [:show]
  end

  namespace :shopify do
    resource :callback, only: [:show]
  end

  namespace :twilio do
    resources :callback, only: [:create]
    resources :delivery_status, only: [:create]

    if ChatwootApp.enterprise?
      post 'voice/call/:phone', to: 'voice#call_twiml', as: :voice_call
      post 'voice/status/:phone', to: 'voice#status', as: :voice_status
      post 'voice/conference_status/:phone', to: 'voice#conference_status', as: :voice_conference_status
    end
  end

  get 'microsoft/callback', to: 'microsoft/callbacks#show'
  get 'google/callback', to: 'google/callbacks#show'
  get 'crm/google/callback', to: 'crm/google_callbacks#show'
  get 'marketing/meta/callback', to: 'marketing/meta_callbacks#show'
  get 'marketing/google/callback', to: 'marketing/google_callbacks#show'
  get 'instagram/callback', to: 'instagram/callbacks#show'
  get 'tiktok/callback', to: 'tiktok/callbacks#show'
  get 'notion/callback', to: 'notion/callbacks#show'

  # Cofre de documentos: formulário público de envio (PROJETO-COFRE-DOCUMENTOS.md
  # §8.7). /f = link fixo do formulário; /l = link personalizado de um cliente.
  get 'f/:token', to: 'public_document_forms#show', as: :public_document_form
  post 'f/:token', to: 'public_document_forms#submit'
  get 'l/:token', to: 'public_document_forms#show', defaults: { link: true }, as: :public_document_form_link
  post 'l/:token', to: 'public_document_forms#submit', defaults: { link: true }
  # ----------------------------------------------------------------------
  # Routes for external service verifications
  get '.well-known/assetlinks.json' => 'android_app#assetlinks'
  get '.well-known/apple-app-site-association' => 'apple_app#site_association'
  get '.well-known/microsoft-identity-association.json' => 'microsoft#identity_association'
  get '.well-known/cf-custom-hostname-challenge/:id', to: 'custom_domains#verify'

  # ----------------------------------------------------------------------
  # Internal Monitoring Routes
  require 'sidekiq/web'
  require 'sidekiq/cron/web'

  devise_for :super_admins, path: 'super_admin', controllers: { sessions: 'super_admin/devise/sessions' }
  devise_scope :super_admin do
    get 'super_admin/logout', to: 'super_admin/devise/sessions#destroy'
    namespace :super_admin do
      root to: 'dashboard#index'

      resource :app_config, only: [:show, :create]

      # order of resources affect the order of sidebar navigation in super admin
      resources :accounts, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
        post :seed, on: :member
        post :reset_cache, on: :member
      end
      resources :users, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
        delete :avatar, on: :member, action: :destroy_avatar
      end

      resources :access_tokens, only: [:index, :show]
      resources :installation_configs, only: [:index, :new, :create, :show, :edit, :update]
      resources :agent_bots, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
        delete :avatar, on: :member, action: :destroy_avatar
      end
      resources :platform_apps, only: [:index, :new, :create, :show, :edit, :update, :destroy]
      resource :instance_status, only: [:show]

      resource :settings, only: [:show] do
        get :refresh, on: :collection
      end

      # resources that doesn't appear in primary navigation in super admin
      resources :account_users, only: [:new, :create, :show, :destroy]
    end
    authenticated :super_admin do
      mount Sidekiq::Web => '/monitoring/sidekiq'
    end
  end

  namespace :installation do
    get 'onboarding', to: 'onboarding#index'
    post 'onboarding', to: 'onboarding#create'
  end

  # ---------------------------------------------------------------------
  # Routes for swagger docs
  get '/swagger/*path', to: 'swagger#respond'
  get '/swagger', to: 'swagger#respond'

  # ----------------------------------------------------------------------
  # Routes for testing
  resources :widget_tests, only: [:index] unless Rails.env.production?
end

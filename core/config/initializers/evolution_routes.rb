# frozen_string_literal: true

# Adiciona rotas da Evolution API (WhatsApp não-oficial via Baileys)
# ao app sem modificar o config/routes.rb principal (que usa ChusteRMApp).
#
# NOTA: Usa config.after_initialize para executar depois que o Warden/Devise
# já está configurado, evitando o erro "failure_app= for nil".
Rails.application.config.after_initialize do
  Rails.application.routes.draw do
    get  'webhooks/evolution/*phone_number', to: 'webhooks/evolution#verify', format: false
    post 'webhooks/evolution/*phone_number', to: 'webhooks/evolution#process_payload', format: false

    namespace :api, defaults: { format: 'json' } do
      namespace :v1 do
        resources :accounts, only: [] do
          scope module: :accounts do
            namespace :channels do
              scope :evolution do
                get 'qr_code',           to: 'evolution#qr_code'
                get 'connection_status', to: 'evolution#connection_status'
                get 'instances',         to: 'evolution#instances'
                post 'preview_instances', to: 'evolution#preview_instances'
                post 'link_instance',    to: 'evolution#link_instance'
              end
            end
          end
        end
      end
    end
  end
end

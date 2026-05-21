# frozen_string_literal: true

FactoryBot.define do
  factory :evolution_api_configuration do
    account
    base_url { 'https://evolution.example.com' }
    global_api_key { 'global-key' }
    webhook_base_url { 'https://chatwoot.example.com' }
  end
end

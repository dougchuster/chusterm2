# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::Client do
  let(:configuration) { create(:evolution_api_configuration) }
  let(:client) { described_class.new(configuration: configuration) }

  describe '#set_webhook' do
    it 'uses the Evolution 2.3 webhook payload' do
      request = stub_request(:post, 'https://evolution.example.com/webhook/set/dra_paula')
                .with(
                  headers: {
                    'apikey' => 'global-key',
                    'Content-Type' => 'application/json'
                  },
                  body: {
                    enabled: true,
                    url: 'https://chatwoot.example.com/webhooks/evolution/token',
                    headers: { 'x-evolution-webhook-token' => 'token' },
                    webhookByEvents: false,
                    webhook_by_events: false,
                    webhookBase64: true,
                    webhook_base64: true,
                    events: %w[MESSAGES_UPSERT CONNECTION_UPDATE]
                  }.to_json
                )
                .to_return(status: 201, body: '{}', headers: { 'Content-Type' => 'application/json' })

      client.set_webhook(
        instance_name: 'dra_paula',
        url: 'https://chatwoot.example.com/webhooks/evolution/token',
        headers: { 'x-evolution-webhook-token' => 'token' },
        events: %w[MESSAGES_UPSERT CONNECTION_UPDATE]
      )

      expect(request).to have_been_requested
    end
  end

  describe '#set_settings' do
    it 'uses the documented settings payload and enables full history sync' do
      request = stub_request(:post, 'https://evolution.example.com/settings/set/dra_paula')
                .with(
                  headers: {
                    'apikey' => 'global-key',
                    'Content-Type' => 'application/json'
                  },
                  body: {
                    reject_call: true,
                    msg_call: 'Não podemos atender chamadas por este canal. Envie uma mensagem por escrito, por favor.',
                    groups_ignore: true,
                    always_online: false,
                    read_messages: false,
                    read_status: false,
                    sync_full_history: true
                  }.to_json
                )
                .to_return(status: 201, body: '{}', headers: { 'Content-Type' => 'application/json' })

      client.set_settings(
        instance_name: 'dra_paula',
        reject_call: true,
        groups_ignore: true,
        always_online: false,
        read_messages: false,
        read_status: false,
        sync_full_history: true
      )

      expect(request).to have_been_requested
    end
  end

  describe '#fetch_instances' do
    it 'normalizes connected phone and profile metadata' do
      stub_request(:get, 'https://evolution.example.com/instance/fetchInstances')
        .to_return(
          status: 200,
          body: [
            {
              name: 'Dra_Juliana',
              connectionStatus: 'open',
              ownerJid: '556199716604@s.whatsapp.net',
              profileName: 'Dra Juliana',
              profilePicUrl: 'https://example.com/avatar.jpg'
            }
          ].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect(client.fetch_instances.first).to include(
        name: 'Dra_Juliana',
        connection_status: 'open',
        phone_number: '+556199716604',
        profile_name: 'Dra Juliana',
        profile_picture_url: 'https://example.com/avatar.jpg'
      )
    end
  end
end

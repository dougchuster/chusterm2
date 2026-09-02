require 'rails_helper'

RSpec.describe 'Webhooks::EvolutionController', type: :request do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution',
      provider_config: {
        'api_key' => 'test_evolution_key',
        'api_url' => 'http://evolution-api:8080',
        'instance_name' => 'dra_juliana'
      },
      sync_templates: false,
      validate_provider_config: false
    )
  end

  let(:headers) { { 'apikey' => 'test_evolution_key' } }
  let(:payload) do
    {
      event: 'messages.upsert',
      instance: 'dra_juliana',
      data: {
        key: {
          remoteJid: '556199135861@s.whatsapp.net',
          fromMe: false,
          id: 'MSG-1'
        },
        message: {
          conversation: 'Boa tarde'
        },
        messageType: 'conversation'
      }
    }
  end

  describe 'POST /webhooks/evolution/:phone_number' do
    before do
      allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
    end

    it 'enqueues evolution events when the instance matches the channel configuration' do
      allow(Webhooks::EvolutionEventsJob).to receive(:perform_later)

      post "/webhooks/evolution/#{channel.phone_number.delete_prefix('+')}", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      expect(Webhooks::EvolutionEventsJob).to have_received(:perform_later)
    end

    it 'filters credentials before serializing webhook parameters into the job' do
      job_payload = nil
      allow(Webhooks::EvolutionEventsJob).to receive(:perform_later) do |args|
        job_payload = args
      end
      sensitive_payload = payload.deep_merge(
        apikey: 'test_evolution_key',
        webhook_token: 'webhook-secret',
        data: {
          message: {
            messageContextInfo: {
              messageSecret: 'encrypted-message-secret'
            }
          }
        }
      )

      post "/webhooks/evolution/#{channel.phone_number.delete_prefix('+')}",
           params: sensitive_payload,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(job_payload['apikey']).to eq('[FILTERED]')
      expect(job_payload['webhook_token']).to eq('[FILTERED]')
      expect(job_payload.dig('data', 'message', 'messageContextInfo', 'messageSecret')).to eq('[FILTERED]')
      expect(job_payload.dig('evolution', 'apikey')).to eq('[FILTERED]') if job_payload.key?('evolution')
    end

    it 'rejects events for a different evolution instance' do
      allow(Webhooks::EvolutionEventsJob).to receive(:perform_later)

      post "/webhooks/evolution/#{channel.phone_number.delete_prefix('+')}",
           params: payload.merge(instance: 'other_instance'),
           headers: headers

      expect(response).to have_http_status(:conflict)
      expect(Webhooks::EvolutionEventsJob).not_to have_received(:perform_later)
    end

    it 'rejects events without a configured API key header' do
      allow(Webhooks::EvolutionEventsJob).to receive(:perform_later)

      post "/webhooks/evolution/#{channel.phone_number.delete_prefix('+')}", params: payload

      expect(response).to have_http_status(:unauthorized)
      expect(Webhooks::EvolutionEventsJob).not_to have_received(:perform_later)
    end
  end
end

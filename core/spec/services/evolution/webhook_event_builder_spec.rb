# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::WebhookEventBuilder do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution',
      provider_config: { 'source' => 'managed_evolution', 'webhook_verify_token' => 'token' },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:account) { channel.account }
  let(:inbox) { channel.inbox }
  let!(:configuration) { create(:evolution_api_configuration, account: account) }
  let!(:instance) do
    EvolutionInstance.create!(
      account: account,
      inbox: inbox,
      channel_whatsapp: channel,
      configuration: configuration,
      instance_name: 'dra_ingrid',
      connection_state: 'open',
      provisioning_status: 'connected'
    )
  end

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
    allow_any_instance_of(Channel::Whatsapp).to receive(:validate_provider_config)
  end

  it 'builds contact batch events without assuming data is a hash' do
    event = described_class.call(
      params: {
        event: 'contacts.update',
        instance: instance.instance_name,
        data: [
          {
            remoteJid: '48288434749604@lid',
            profilePicUrl: 'https://example.com/avatar.jpg'
          }
        ]
      },
      evolution_instance: instance,
      channel: channel
    )

    expect(event.status).to eq('received')
    expect(event.event_name).to eq('contacts_update')
    expect(event.message_id).to be_nil
  end

  it 'extracts message ids from history batches' do
    event = described_class.call(
      params: {
        event: 'messages.set',
        instance: instance.instance_name,
        data: {
          messages: [
            {
              key: { id: 'HISTORY-1' },
              message: { conversation: 'Mensagem importada' }
            }
          ]
        }
      },
      evolution_instance: instance,
      channel: channel
    )

    expect(event.message_id).to eq('HISTORY-1')
  end
end

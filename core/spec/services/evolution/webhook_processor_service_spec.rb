# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::WebhookProcessorService do
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
      instance_name: 'dra_paula',
      connection_state: 'open',
      provisioning_status: 'connected'
    )
  end

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
    allow_any_instance_of(Channel::Whatsapp).to receive(:validate_provider_config)
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)
  end

  it 'normalizes dotted contact events and syncs contact profile data' do
    event = EvolutionWebhookEvent.create!(
      account: account,
      inbox: inbox,
      evolution_instance: instance,
      event_name: 'contacts.upsert',
      instance_name: instance.instance_name,
      payload: {
        event: 'contacts.upsert',
        instance: instance.instance_name,
        data: [
          {
            id: '556177700000@s.whatsapp.net',
            pushName: 'Contato Teste',
            profilePictureUrl: 'https://example.com/avatar.png'
          }
        ]
      }
    )

    described_class.new(event: event).perform

    contact = account.contacts.find_by!(phone_number: '+556177700000')
    expect(contact.name).to eq('Contato Teste')
    expect(contact.additional_attributes['whatsapp_profile_picture_url']).to eq('https://example.com/avatar.png')
    expect(event.reload.status).to eq('processed')
  end
end

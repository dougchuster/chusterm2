require 'rails_helper'

RSpec.describe Webhooks::EvolutionEventsJob do
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

  let(:params) do
    {
      event: 'messages.upsert',
      instance: 'dra_juliana',
      phone_number: channel.phone_number.delete_prefix('+'),
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

  let(:process_service) { instance_double(Whatsapp::IncomingMessageEvolutionService, perform: true) }

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
    allow_any_instance_of(Channel::Whatsapp).to receive(:validate_provider_config)
  end

  it 'processes messages for the configured evolution instance' do
    allow(Whatsapp::IncomingMessageEvolutionService).to receive(:new).and_return(process_service)

    described_class.perform_now(params)

    expect(Whatsapp::IncomingMessageEvolutionService).to have_received(:new).with(inbox: channel.inbox, params: params)
    expect(process_service).to have_received(:perform)
  end

  it 'ignores messages for a different evolution instance' do
    allow(Whatsapp::IncomingMessageEvolutionService).to receive(:new)

    described_class.perform_now(params.merge(instance: 'other_instance'))

    expect(Whatsapp::IncomingMessageEvolutionService).not_to have_received(:new)
  end

  it 'does not process messages while reauthorization is required' do
    channel.prompt_reauthorization!
    allow(Whatsapp::IncomingMessageEvolutionService).to receive(:new)

    described_class.perform_now(params)

    expect(Whatsapp::IncomingMessageEvolutionService).not_to have_received(:new)
  end

  it 'still processes connection updates while reauthorization is required' do
    channel.prompt_reauthorization!

    described_class.perform_now(
      phone_number: channel.phone_number.delete_prefix('+'),
      instance: 'dra_juliana',
      event: 'connection.update',
      data: { state: 'open' }
    )

    expect(channel).not_to be_reauthorization_required
  end

  it 'records logout_instance in provider_config' do
    described_class.perform_now(
      phone_number: channel.phone_number.delete_prefix('+'),
      instance: 'dra_juliana',
      event: 'LOGOUT_INSTANCE',
      data: { reason: 'Manual logout' }
    )

    channel.reload
    expect(channel.provider_config['evolution_last_warning_code']).to eq('logout_instance')
  end
end

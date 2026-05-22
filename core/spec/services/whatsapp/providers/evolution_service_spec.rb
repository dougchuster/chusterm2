require 'rails_helper'

RSpec.describe Whatsapp::Providers::EvolutionService do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution',
      provider_config: {
        'api_url' => 'http://evolution.test',
        'api_key' => 'evo-key',
        'instance_name' => 'Dra Paula'
      },
      sync_templates: false,
      validate_provider_config: false
    )
  end

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
  end

  it 'falls back from official template sending to normal Evolution text sending' do
    message = build_stubbed(:message, content: 'Mensagem normal')

    stub_request(:post, 'http://evolution.test/message/sendText/Dra%20Paula')
      .with(
        headers: { 'apikey' => 'evo-key', 'Content-Type' => 'application/json' },
        body: { number: '556199999999', text: 'Mensagem normal' }.to_json
      )
      .to_return(status: 200, body: { data: { key: { id: 'EVO-TEMPLATE-FALLBACK' } } }.to_json, headers: { 'content-type' => 'application/json' })

    message_id = described_class.new(whatsapp_channel: channel).send_template(
      '+556199999999',
      { name: 'template' },
      message
    )

    expect(message_id).to eq('EVO-TEMPLATE-FALLBACK')
  end

  it 'marks blank template messages as failed instead of pretending they were sent' do
    message = create(:message, content: '')

    described_class.new(whatsapp_channel: channel).send_template('+556199999999', { name: 'template' }, message)

    expect(message.reload).to be_failed
    expect(message.external_error).to include('não suporta templates')
  end
end

require 'rails_helper'

RSpec.describe Channels::Whatsapp::WebhookSetupJob do
  let(:channel) { instance_double(Channel::Whatsapp, id: 123, phone_number: '+5511999999999') }
  let(:health_service) { instance_double(Whatsapp::HealthService) }

  before do
    allow(Channel::Whatsapp).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(channel).to receive(:setup_webhooks)
    allow(channel).to receive(:prompt_reauthorization!)
    allow(Whatsapp::HealthService).to receive(:new).with(channel).and_return(health_service)
  end

  it 'sets up webhooks and keeps a healthy channel authorized' do
    allow(health_service).to receive(:fetch_health_status).and_return(
      platform_type: 'CLOUD_API', throughput: { 'level' => 'STANDARD' }
    )

    described_class.perform_now(channel.id)

    expect(channel).to have_received(:setup_webhooks)
    expect(channel).not_to have_received(:prompt_reauthorization!)
  end

  it 'requests reauthorization when the platform is not applicable' do
    allow(health_service).to receive(:fetch_health_status).and_return(
      platform_type: 'NOT_APPLICABLE', throughput: { 'level' => 'STANDARD' }
    )

    described_class.perform_now(channel.id)

    expect(channel).to have_received(:prompt_reauthorization!)
  end

  it 'requests reauthorization when throughput is not applicable' do
    allow(health_service).to receive(:fetch_health_status).and_return(
      platform_type: 'CLOUD_API', throughput: { 'level' => 'NOT_APPLICABLE' }
    )

    described_class.perform_now(channel.id)

    expect(channel).to have_received(:prompt_reauthorization!)
  end

  it 'returns without work when the channel no longer exists' do
    allow(Channel::Whatsapp).to receive(:find_by).with(id: channel.id).and_return(nil)

    described_class.perform_now(channel.id)

    expect(channel).not_to have_received(:setup_webhooks)
  end
end

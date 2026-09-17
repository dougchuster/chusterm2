require 'rails_helper'

RSpec.describe Marketing::CampaignStatusJob, type: :job do
  let(:account) { create(:account) }
  let(:connection) do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't',
      metadata: { 'ads_write_enabled' => true }
    )
  end
  let(:campaign) do
    account.marketing_campaigns.create!(
      crm_external_connection: connection, provider: 'meta_ads',
      level: 'campaign', external_id: 'c1', name: 'Leads Jan', status: 'ACTIVE'
    )
  end

  it 'chama a Meta, atualiza o status e audita via marketing_events' do
    client = instance_double(Marketing::Meta::GraphClient)
    allow(Marketing::Meta::GraphClient).to receive(:new).with(access_token: 't').and_return(client)
    expect(client).to receive(:update_campaign_status).with('c1', 'PAUSED')

    described_class.perform_now(campaign.id, 'PAUSED')

    expect(campaign.reload.status).to eq('PAUSED')
    event = account.marketing_events.where(event_name: 'set_campaign_status').last
    expect(event.status).to eq('sent')
    expect(event.sent_at).to be_present
  end

  it 'nao escreve sem ads_write_enabled' do
    connection.update!(metadata: {})
    expect(Marketing::Meta::GraphClient).not_to receive(:new)

    described_class.perform_now(campaign.id, 'PAUSED')

    expect(campaign.reload.status).to eq('ACTIVE')
  end

  it 'ignora status fora da whitelist' do
    expect(Marketing::Meta::GraphClient).not_to receive(:new)
    described_class.perform_now(campaign.id, 'DELETED')
  end

  it 'marca o evento como failed quando a Meta recusa' do
    client = instance_double(Marketing::Meta::GraphClient)
    allow(Marketing::Meta::GraphClient).to receive(:new).and_return(client)
    allow(client).to receive(:update_campaign_status).and_raise(Marketing::Meta::GraphClient::ApiError, 'permissao negada')

    expect { described_class.perform_now(campaign.id, 'PAUSED') }.to raise_error(StandardError)

    event = account.marketing_events.where(event_name: 'set_campaign_status').last
    expect(event.status).to eq('failed')
    expect(event.response['error']).to include('permissao negada')
  end
end

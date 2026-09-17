require 'rails_helper'

RSpec.describe Marketing::Meta::CapiService do
  let(:account) { create(:account) }
  let(:connection) do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 'token',
      metadata: { 'capi_dataset_id' => '12345' }
    )
  end
  let(:pipeline) { account.crm_pipelines.default_first.first }
  let(:stage) { pipeline.crm_pipeline_stages.ordered.first }
  let(:contact) { account.contacts.create!(name: 'Maria', email: 'maria@example.com') }
  let(:lead) do
    account.marketing_leads.create!(
      leadgen_id: 'lg_1',
      crm_external_connection: connection,
      field_data: { 'full_name' => 'Maria', 'email' => 'maria@example.com', 'phone_number' => '+5511999990000' }
    )
  end
  let(:deal) do
    account.crm_deals.create!(
      crm_pipeline: pipeline, crm_pipeline_stage: stage,
      contact: contact, title: 'Deal'
    )
  end
  let(:client) { instance_double(Marketing::Meta::GraphClient) }

  before do
    allow(Marketing::Meta::GraphClient).to receive(:new).and_return(client)
  end

  it 'marca o evento como sent com a resposta da Meta' do
    allow(client).to receive(:post).and_return({ 'events_received' => 1, 'fbtrace_id' => 'fb1' })

    event = described_class.new(connection: connection)
                           .send_stage_event(deal: deal, lead: lead, stage: stage)

    expect(event.status).to eq('sent')
    expect(event.response['events_received']).to eq(1)
  end

  it 'envia user_data hasheado com lead_id' do
    allow(client).to receive(:post).and_return({ 'events_received' => 1 })

    described_class.new(connection: connection)
                   .send_stage_event(deal: deal, lead: lead, stage: stage)

    expect(client).to have_received(:post) do |path, opts|
      expect(path).to eq('/12345/events')
      data = opts[:payload][:data].first.with_indifferent_access
      expect(data[:action_source]).to eq('system_generated')
      expect(data[:user_data][:ph]).to eq(Digest::SHA256.hexdigest('5511999990000'))
      expect(data[:user_data][:em]).to eq(Digest::SHA256.hexdigest('maria@example.com'))
      expect(data[:user_data][:lead_id]).to eq('lg_1')
    end
  end

  it 'marca skipped quando a conexao nao tem dataset' do
    connection.update!(metadata: {})
    allow(client).to receive(:post)

    event = described_class.new(connection: connection)
                           .send_stage_event(deal: deal, lead: lead, stage: stage)

    expect(event.status).to eq('skipped')
    expect(client).not_to have_received(:post)
  end

  it 'marca failed quando a Graph API recusa' do
    allow(client).to receive(:post)
      .and_raise(Marketing::Meta::GraphClient::ApiError, 'invalid dataset')

    event = described_class.new(connection: connection)
                           .send_stage_event(deal: deal, lead: lead, stage: stage)

    expect(event.status).to eq('failed')
    expect(event.response['error']).to eq('invalid dataset')
  end

  it 'e idempotente por event_id (deal+stage+timestamp)' do
    allow(client).to receive(:post).and_return({ 'events_received' => 1 })

    service = described_class.new(connection: connection)
    first = service.send_stage_event(deal: deal, lead: lead, stage: stage)
    second = service.send_stage_event(deal: deal, lead: lead, stage: stage)

    expect(second.id).to eq(first.id)
    expect(account.marketing_events.count).to eq(1)
    expect(client).to have_received(:post).once
  end

  it 'mapeia status won para evento Purchase' do
    allow(client).to receive(:post).and_return({ 'events_received' => 1 })
    deal.update!(status: 'won')

    event = described_class.new(connection: connection)
                           .send_stage_event(deal: deal, lead: lead, stage: stage)

    expect(event.event_name).to eq('Purchase')
  end
end

require 'rails_helper'

RSpec.describe Marketing::CapiDispatchJob, type: :job do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.default_first.first }
  let(:stage) { pipeline.crm_pipeline_stages.ordered.first }
  let(:contact) { account.contacts.create!(name: 'Maria', email: 'm@example.com') }
  let(:deal) do
    account.crm_deals.create!(
      crm_pipeline: pipeline, crm_pipeline_stage: stage,
      contact: contact, title: 'Deal'
    )
  end
  let(:connection) do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't',
      metadata: { 'capi_dataset_id' => 'ds1' }
    )
  end

  it 'dispara CapiService quando o deal veio de lead da Meta' do
    account.marketing_leads.create!(
      leadgen_id: 'lg_x', contact: contact,
      crm_external_connection: connection, field_data: {}
    )
    service = instance_double(Marketing::Meta::CapiService)
    allow(Marketing::Meta::CapiService).to receive(:new).with(connection: connection).and_return(service)
    expect(service).to receive(:send_stage_event).with(deal: deal, lead: anything, stage: stage)

    described_class.perform_now(deal.id)
  end

  it 'ignora deals sem lead de ads' do
    expect(Marketing::Meta::CapiService).not_to receive(:new)
    described_class.perform_now(deal.id)
  end

  it 'ignora quando a conexao nao tem dataset configurado' do
    plain = account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't', metadata: {}
    )
    account.marketing_leads.create!(
      leadgen_id: 'lg_y', contact: contact,
      crm_external_connection: plain, field_data: {}
    )
    expect(Marketing::Meta::CapiService).not_to receive(:new)
    described_class.perform_now(deal.id)
  end
end

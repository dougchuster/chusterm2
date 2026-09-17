require 'rails_helper'

RSpec.describe Marketing::LeadToCrmService do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.default_first.first }
  let(:stage) { pipeline.crm_pipeline_stages.ordered.first }
  let(:connection) do
    account.crm_external_connections.create!(provider: 'meta_ads', status: 'active', access_token: 'token')
  end
  let(:fields) do
    {
      'full_name' => 'Maria Silva',
      'email' => 'maria@example.com',
      'phone_number' => '+55 (11) 99999-0000',
      '_meta' => { 'form_id' => 'form_1', 'campaign_id' => 'camp_1', 'page_id' => 'page_1' }
    }
  end

  def perform(extra_fields: {}, leadgen_id: 'lead_1')
    described_class.new(
      account: account,
      connection: connection,
      leadgen_id: leadgen_id,
      fields: fields.merge(extra_fields),
      context: {}
    ).perform
  end

  it 'cria MarketingLead + Contact + CrmDeal no primeiro estágio' do
    lead = perform

    expect(lead.status).to eq('converted')
    expect(lead.contact.email).to eq('maria@example.com')
    expect(lead.crm_deal).to be_present
    expect(lead.crm_deal.crm_pipeline).to eq(pipeline)
    expect(lead.crm_deal.crm_pipeline_stage).to eq(stage)
    expect(lead.crm_deal.contact).to eq(lead.contact)
    expect(lead.form_id).to eq('form_1')
  end

  it 'reutiliza contato existente por email' do
    contact = account.contacts.create!(name: 'Maria', email: 'maria@example.com')
    lead = perform

    expect(lead.contact).to eq(contact)
    expect(account.contacts.where(email: 'maria@example.com').count).to eq(1)
  end

  it 'reutiliza contato existente por telefone normalizado' do
    contact = account.contacts.create!(name: 'Maria', phone_number: '+5511999990000')
    lead = perform(extra_fields: { 'email' => nil })

    expect(lead.contact).to eq(contact)
  end

  it 'e idempotente por leadgen_id' do
    first = perform
    second = perform

    expect(second.id).to eq(first.id)
    expect(account.marketing_leads.count).to eq(1)
    expect(account.crm_deals.count).to eq(1)
  end

  it 'usa o funil configurado na conexao quando presente' do
    other = CrmPipeline.create!(account: account, name: 'Ads', position: 2)
    ads_stage = other.crm_pipeline_stages.create!(account: account, name: 'Entrada', slug: 'entrada', position: 0)
    connection.update!(metadata: { 'leadgen_pipeline_id' => other.id })

    lead = perform
    expect(lead.crm_deal.crm_pipeline).to eq(other)
    expect(lead.crm_deal.crm_pipeline_stage).to eq(ads_stage)
  end

  it 'vincula o deal aberto existente quando o contato ja esta no funil' do
    contact = account.contacts.create!(name: 'Maria', email: 'maria@example.com')
    existing = account.crm_deals.create!(
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      contact: contact,
      title: 'Ja no kanban'
    )

    lead = perform
    expect(lead.crm_deal).to eq(existing)
    expect(lead.status).to eq('converted')
    expect(account.crm_deals.where(contact: contact).count).to eq(1)
  end

  it 'cria lead sem deal quando nao ha funil' do
    account.crm_pipelines.destroy_all
    lead = perform

    expect(lead.crm_deal).to be_nil
    expect(lead.status).to eq('new')
  end

  it 'isola tenants' do
    other_account = create(:account)
    lead = perform

    expect(lead.account).to eq(account)
    expect(other_account.marketing_leads.count).to eq(0)
    expect(other_account.crm_deals.count).to eq(0)
  end
end

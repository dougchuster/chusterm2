require 'rails_helper'

RSpec.describe Marketing::LeadgenIngestJob, type: :job do
  let(:account) { create(:account) }
  let(:connection) do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 'token',
      metadata: { 'page_id' => 'page_1' }
    )
  end

  let(:graph_response) do
    {
      'full_name' => 'Joao Souza',
      'email' => 'joao@example.com',
      'phone_number' => '+5511988887777',
      '_meta' => { 'form_id' => 'form_9', 'campaign_id' => 'camp_9' }
    }
  end

  before do
    connection
    client = instance_double(Marketing::Meta::GraphClient)
    allow(Marketing::Meta::GraphClient).to receive(:new).and_return(client)
    allow(client).to receive(:leadgen_form_data).and_return(graph_response)
  end

  it 'ingere o lead e cria deal no CRM' do
    described_class.perform_now('lead_9', { 'page_id' => 'page_1' })

    lead = account.marketing_leads.find_by(leadgen_id: 'lead_9')
    expect(lead).to be_present
    expect(lead.status).to eq('converted')
    expect(lead.crm_deal).to be_present
    expect(lead.contact.email).to eq('joao@example.com')
  end

  it 'descarta quando nao ha conexao ativa para a pagina' do
    expect do
      described_class.perform_now('lead_x', { 'page_id' => 'unknown_page' })
    end.not_to(change(MarketingLead, :count))
  end

  it 'descarta quando a Graph API nao retorna dados' do
    client = instance_double(Marketing::Meta::GraphClient)
    allow(Marketing::Meta::GraphClient).to receive(:new).and_return(client)
    allow(client).to receive(:leadgen_form_data).and_return(nil)

    expect do
      described_class.perform_now('lead_nil', { 'page_id' => 'page_1' })
    end.not_to(change(MarketingLead, :count))
  end

  it 'roteia para a conta dona da pagina (isolamento de tenant)' do
    other_account = create(:account)
    other = other_account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't2',
      metadata: { 'page_id' => 'page_2' }
    )

    described_class.perform_now('lead_10', { 'page_id' => 'page_2' })

    lead = other_account.marketing_leads.find_by(leadgen_id: 'lead_10')
    expect(lead.crm_external_connection).to eq(other)
    expect(account.marketing_leads.find_by(leadgen_id: 'lead_10')).to be_nil
  end
end

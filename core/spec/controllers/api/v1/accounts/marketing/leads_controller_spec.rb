require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Marketing::Leads', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin_headers) { admin.create_new_auth_token }

  before do
    account.enable_features!('marketing')
  end

  def create_lead(attrs = {})
    account.marketing_leads.create!({
      leadgen_id: SecureRandom.hex(6),
      field_data: { 'full_name' => 'Lead Teste', 'email' => 'lead@example.com' },
      status: 'new'
    }.merge(attrs))
  end

  describe 'GET /api/v1/accounts/:id/marketing/leads' do
    it 'lista leads da conta com contagens' do
      create_lead
      create_lead(status: 'converted')

      get "/api/v1/accounts/#{account.id}/marketing/leads",
          headers: admin_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['leads'].size).to eq(2)
      expect(body['counts']['new']).to eq(1)
      expect(body['counts']['converted']).to eq(1)
    end

    it 'filtra por status' do
      create_lead
      create_lead(status: 'discarded')

      get "/api/v1/accounts/#{account.id}/marketing/leads?status=new",
          headers: admin_headers

      expect(response.parsed_body['leads'].size).to eq(1)
    end

    it 'nao vaza leads de outra conta' do
      other = create(:account)
      other.marketing_leads.create!(leadgen_id: 'x1', field_data: {})
      create_lead

      get "/api/v1/accounts/#{account.id}/marketing/leads",
          headers: admin_headers

      ids = response.parsed_body['leads'].map { |l| l['leadgen_id'] }
      expect(ids).not_to include('x1')
    end

    it 'retorna 403 sem a feature flag' do
      account.disable_features!('marketing')

      get "/api/v1/accounts/#{account.id}/marketing/leads",
          headers: admin_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST .../leads/:id/discard' do
    it 'marca como descartado' do
      lead = create_lead

      post "/api/v1/accounts/#{account.id}/marketing/leads/#{lead.id}/discard",
           headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(lead.reload.status).to eq('discarded')
    end
  end

  describe 'POST .../leads/:id/convert' do
    let(:pipeline) { account.crm_pipelines.default_first.first }

    it 'converte lead em contato + deal' do
      lead = create_lead

      post "/api/v1/accounts/#{account.id}/marketing/leads/#{lead.id}/convert",
           headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(lead.reload.status).to eq('converted')
      expect(lead.crm_deal).to be_present
      expect(lead.contact).to be_present
    end

    it 'rejeita reconversao de lead ja convertido' do
      lead = create_lead(status: 'converted', crm_deal: account.crm_deals.create!(
        crm_pipeline: pipeline,
        crm_pipeline_stage: pipeline.crm_pipeline_stages.first,
        title: 'x'
      ))

      post "/api/v1/accounts/#{account.id}/marketing/leads/#{lead.id}/convert",
           headers: admin_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

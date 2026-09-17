require 'rails_helper'

RSpec.describe 'Marketing Campaigns + Metrics API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }

  let!(:connection) do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', name: 'Meta', access_token: 'tok'
    )
  end

  before { account.enable_features!('marketing') }

  def seed_campaign!
    campaign = account.marketing_campaigns.create!(
      crm_external_connection: connection, provider: 'meta_ads',
      level: 'campaign', external_id: 'c1', name: 'Leads Jan', status: 'ACTIVE'
    )
    campaign.metric_snapshots.create!(
      account: account, date: Date.current,
      impressions: 1000, clicks: 100, spend: 50, leads: 10, conversions: 4
    )
    campaign
  end

  describe 'GET campaigns' do
    it 'lists campaigns with computed metrics' do
      seed_campaign!
      get "/api/v1/accounts/#{account.id}/marketing/campaigns", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      row = response.parsed_body['campaigns'].first
      expect(row['name']).to eq('Leads Jan')
      expect(row['metrics']['ctr']).to eq(10.0)
      expect(row['metrics']['cpl']).to eq(5.0)
    end

    it 'filters by provider' do
      seed_campaign!
      account.marketing_campaigns.create!(
        crm_external_connection: connection, provider: 'google_ads',
        level: 'campaign', external_id: 'g1', name: 'PMax', status: 'ENABLED'
      )

      get "/api/v1/accounts/#{account.id}/marketing/campaigns?provider=google_ads",
          headers: headers, as: :json

      expect(response.parsed_body['campaigns'].pluck('name')).to eq(['PMax'])
    end

    it 'does not leak other accounts campaigns' do
      seed_campaign!
      other = create(:account)
      other_conn = other.crm_external_connections.create!(
        provider: 'meta_ads', status: 'active', access_token: 'x'
      )
      other.marketing_campaigns.create!(
        crm_external_connection: other_conn, provider: 'meta_ads',
        level: 'campaign', external_id: 'o1', name: 'Conta Vizinha', status: 'ACTIVE'
      )

      get "/api/v1/accounts/#{account.id}/marketing/campaigns", headers: headers, as: :json

      names = response.parsed_body['campaigns'].pluck('name')
      expect(names).to eq(['Leads Jan'])
    end
  end

  describe 'GET metrics/overview' do
    it 'aggregates totals, series and provider breakdown' do
      seed_campaign!
      get "/api/v1/accounts/#{account.id}/marketing/metrics/overview", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      totals = response.parsed_body['totals']
      expect(totals['spend']).to eq(50.0)
      expect(totals['cpl']).to eq(5.0)
      expect(totals['roas']).to be_a(Numeric)
      expect(response.parsed_body['series']).not_to be_empty
      expect(response.parsed_body['by_provider'].first['provider']).to eq('meta_ads')
    end

    it 'returns zeros when there is no data' do
      get "/api/v1/accounts/#{account.id}/marketing/metrics/overview", headers: headers, as: :json
      expect(response.parsed_body['totals']['spend']).to eq(0.0)
    end

    it 'is forbidden without the marketing flag' do
      account.disable_features!('marketing')
      get "/api/v1/accounts/#{account.id}/marketing/metrics/overview", headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST set_status' do
    let(:campaign) { seed_campaign! }

    def url_for(record)
      "/api/v1/accounts/#{account.id}/marketing/campaigns/#{record.id}/set_status"
    end

    it 'enfileira a mudanca quando a conexao permite escrita' do
      connection.update!(metadata: { 'ads_write_enabled' => true })

      expect do
        post url_for(campaign), params: { status: 'PAUSED' }, headers: headers, as: :json
      end.to have_enqueued_job(Marketing::CampaignStatusJob).with(campaign.id, 'PAUSED')

      expect(response).to have_http_status(:accepted)
      expect(account.crm_audit_events.where(action: 'marketing_campaign_status_requested').count).to eq(1)
    end

    it 'recusa sem ads_write_enabled na conexao' do
      expect do
        post url_for(campaign), params: { status: 'PAUSED' }, headers: headers, as: :json
      end.not_to have_enqueued_job(Marketing::CampaignStatusJob)

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejeita status invalido' do
      connection.update!(metadata: { 'ads_write_enabled' => true })
      post url_for(campaign), params: { status: 'DELETED' }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'nao enxerga campanha de outra conta' do
      other = create(:account)
      other_conn = other.crm_external_connections.create!(
        provider: 'meta_ads', status: 'active', access_token: 'x',
        metadata: { 'ads_write_enabled' => true }
      )
      foreign = other.marketing_campaigns.create!(
        crm_external_connection: other_conn, provider: 'meta_ads',
        level: 'campaign', external_id: 'fx', name: 'Alheia', status: 'ACTIVE'
      )

      post url_for(foreign), params: { status: 'PAUSED' }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end

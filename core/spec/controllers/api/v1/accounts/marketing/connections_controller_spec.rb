require 'rails_helper'

RSpec.describe 'Marketing Connections API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin_headers) { admin.create_new_auth_token }
  let(:agent_headers) { agent.create_new_auth_token }

  before { account.enable_features!('marketing') }

  def url(path = '')
    "/api/v1/accounts/#{account.id}/marketing/connections#{path}"
  end

  describe 'GET index' do
    it 'lists every marketing provider even when nothing is connected' do
      get url, headers: agent_headers, as: :json

      expect(response).to have_http_status(:success)
      providers = response.parsed_body['connections'].pluck('provider')
      expect(providers).to eq(%w[meta_ads google_ads ga4])
      expect(response.parsed_body['connections'].first['connected']).to be(false)
    end

    it 'reflects an active connection with its ad accounts metadata' do
      account.crm_external_connections.create!(
        provider: 'meta_ads', status: 'active', name: 'Meta da Firma',
        access_token: 'token',
        metadata: { 'ad_accounts' => [{ 'id' => 'act_1', 'name' => 'Conta 1' }] }
      )

      get url, headers: agent_headers, as: :json

      meta = response.parsed_body['connections'].find { |c| c['provider'] == 'meta_ads' }
      expect(meta['connected']).to be(true)
      expect(meta['metadata']['ad_accounts'].first['name']).to eq('Conta 1')
    end

    it 'is forbidden without the marketing feature flag' do
      account.disable_features!('marketing')

      get url, headers: agent_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST authorize' do
    it 'returns the Meta oauth dialog url for an admin' do
      with_modified_env META_APP_ID: 'app-123', META_APP_SECRET: 'secret', FRONTEND_URL: 'https://crm.test' do
        post url('/authorize'), params: { provider: 'meta_ads' }, headers: admin_headers, as: :json
      end

      expect(response).to have_http_status(:success)
      oauth_url = response.parsed_body['url']
      expect(oauth_url).to include('facebook.com/v25.0/dialog/oauth')
      expect(oauth_url).to include('client_id=app-123')
      expect(oauth_url).to include('leads_retrieval')
      expect(oauth_url).to include('marketing%2Fmeta%2Fcallback')
    end

    it 'returns the Google oauth url with ads + analytics scopes' do
      with_modified_env GOOGLE_OAUTH_CLIENT_ID: 'g-123', GOOGLE_OAUTH_CLIENT_SECRET: 's', FRONTEND_URL: 'https://crm.test' do
        post url('/authorize'), params: { provider: 'google_ads' }, headers: admin_headers, as: :json
      end

      oauth_url = response.parsed_body['url']
      expect(oauth_url).to include('accounts.google.com/o/oauth2/auth')
      expect(oauth_url).to include('adwords')
      expect(oauth_url).to include('analytics.readonly')
    end

    it 'rejects unknown providers' do
      post url('/authorize'), params: { provider: 'tiktok' }, headers: admin_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'explains when oauth keys are missing' do
      with_modified_env META_APP_ID: nil, META_APP_SECRET: nil do
        post url('/authorize'), params: { provider: 'meta_ads' }, headers: admin_headers, as: :json
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('oauth_not_configured')
    end

    it 'blocks non-admin users from starting oauth' do
      post url('/authorize'), params: { provider: 'meta_ads' }, headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE destroy' do
    it 'removes the account-level connection' do
      conn = account.crm_external_connections.create!(provider: 'meta_ads', status: 'active', access_token: 't')

      delete url("/#{conn.id}"), headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(CrmExternalConnection.find_by(id: conn.id)).to be_nil
    end

    it 'never touches a connection from another account' do
      other = create(:account)
      other.enable_features!('marketing')
      conn = other.crm_external_connections.create!(provider: 'meta_ads', status: 'active', access_token: 't')

      delete url("/#{conn.id}"), headers: admin_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(CrmExternalConnection.find_by(id: conn.id)).to be_present
    end
  end

  describe 'POST sync' do
    it 'enqueues the sync job for the connection' do
      conn = account.crm_external_connections.create!(provider: 'google_ads', status: 'active', access_token: 't')

      expect do
        post url("/#{conn.id}/sync"), headers: admin_headers, as: :json
      end.to have_enqueued_job(Marketing::SyncAccountJob).with(conn.id)

      expect(response).to have_http_status(:accepted)
    end
  end
end

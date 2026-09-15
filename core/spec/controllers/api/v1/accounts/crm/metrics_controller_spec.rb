require 'rails_helper'

RSpec.describe 'CRM Metrics API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    # Evita falso-positivo de cache entre exemplos: os endpoints renderizam
    # via `cached`, que persiste o payload por CACHE_TTL.
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  describe 'GET /crm/metrics/overview' do
    it 'returns the computed overview payload' do
      get "/api/v1/accounts/#{account.id}/crm/metrics/overview",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      # Regressao CRM-025: `render json: cached(...) do ... end` ligava o
      # bloco ao `render` (nao ao `cached`), entao a resposta era `null`.
      expect(response.parsed_body).to include('total_deals', 'open_deals', 'won_deals', 'lost_deals')
    end

    it 'counts deals in the response' do
      pipeline = CrmPipeline.create!(account: account, name: 'Pipeline M', position: 1, is_default: true)
      stage = CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo', position: 1)
      CrmDeal.create!(account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage, title: 'Negócio M')

      get "/api/v1/accounts/#{account.id}/crm/metrics/overview",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response.parsed_body['total_deals']).to eq(1)
    end
  end

  %w[stage_funnel time_in_stage win_loss_trend top_loss_reasons score_by_stage area_distribution top_deals stale_deals].each do |action|
    it "GET /crm/metrics/#{action} does not return null" do
      get "/api/v1/accounts/#{account.id}/crm/metrics/#{action}",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).not_to be_nil
    end
  end
end

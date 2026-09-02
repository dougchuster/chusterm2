require 'rails_helper'

RSpec.describe 'CRM Pipelines API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }

  it 'returns total and open deal counts for intelligent initial selection' do
    empty_pipeline = CrmPipeline.create!(
      account: account,
      name: 'Pipeline padrão',
      is_default: true,
      position: 0
    )
    active_pipeline = CrmPipeline.create!(
      account: account,
      name: 'Dra. Paula',
      position: 1
    )
    stage = CrmPipelineStage.create!(
      account: account,
      crm_pipeline: active_pipeline,
      name: 'Triagem',
      position: 1
    )
    CrmDeal.create!(
      account: account,
      crm_pipeline: active_pipeline,
      crm_pipeline_stage: stage,
      title: 'Benefício previdenciário'
    )

    get "/api/v1/accounts/#{account.id}/crm/pipelines",
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    pipelines = response.parsed_body.index_by { |pipeline| pipeline['id'] }
    expect(pipelines.fetch(empty_pipeline.id)).to include(
      'deals_count' => 0,
      'open_deals_count' => 0
    )
    expect(pipelines.fetch(active_pipeline.id)).to include(
      'deals_count' => 1,
      'open_deals_count' => 1
    )
  end
end

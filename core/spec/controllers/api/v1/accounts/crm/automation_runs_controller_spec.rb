require 'rails_helper'

# CRM-004: listagem de crm_automation_runs por deal/regra, sempre no escopo da
# conta da URL.
RSpec.describe 'CRM automation runs', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { agent.create_new_auth_token }

  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Funil', position: 1, is_default: true) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo', position: 1) }
  let(:deal) do
    CrmDeal.create!(account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage, title: 'Deal A')
  end
  let(:rule) do
    CrmAutomationRule.create!(
      account: account, crm_pipeline_stage: stage, name: 'Criar follow-up',
      trigger_event: 'stage_entered', action_type: 'create_activity',
      action_config: { 'kind' => 'follow_up', 'title' => 'Ligar' }
    )
  end
  let!(:run) do
    CrmAutomationRun.create!(
      account: account, crm_automation_rule: rule, crm_deal: deal,
      status: 'executed', started_at: 1.minute.ago, finished_at: Time.current
    )
  end

  def index_path(acc = account, **params)
    "/api/v1/accounts/#{acc.id}/crm/automation-runs?#{params.to_query}"
  end

  it 'lista os runs da conta com regra e deal serializados' do
    get index_path, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.size).to eq(1)
    expect(body.first['id']).to eq(run.id)
    expect(body.first['status']).to eq('executed')
    expect(body.first.dig('automation_rule', 'name')).to eq('Criar follow-up')
    expect(body.first.dig('deal', 'title')).to eq('Deal A')
  end

  it 'filtra por deal_id' do
    other_deal = CrmDeal.create!(account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage, title: 'Deal B')
    CrmAutomationRun.create!(
      account: account, crm_automation_rule: rule, crm_deal: other_deal,
      status: 'skipped', skip_reason: 'same_stage', started_at: Time.current
    )

    get index_path(deal_id: deal.id), headers: headers, as: :json

    body = response.parsed_body
    expect(body.size).to eq(1)
    expect(body.first['id']).to eq(run.id)
  end

  it 'filtra por automation_rule_id e status' do
    other_rule = CrmAutomationRule.create!(
      account: account, crm_pipeline_stage: stage, name: 'Outra regra',
      trigger_event: 'stage_entered', action_type: 'create_activity', action_config: {}
    )
    CrmAutomationRun.create!(
      account: account, crm_automation_rule: other_rule, crm_deal: deal,
      status: 'failed', error: 'boom', started_at: Time.current
    )

    get index_path(automation_rule_id: other_rule.id), headers: headers, as: :json
    expect(response.parsed_body.size).to eq(1)
    expect(response.parsed_body.first['status']).to eq('failed')

    get index_path(status: 'executed'), headers: headers, as: :json
    expect(response.parsed_body.map { |r| r['status'] }).to eq(['executed'])
  end

  it 'não vaza runs de outra conta nem aceita deal_id estrangeiro' do
    foreign_pipeline = CrmPipeline.create!(account: other_account, name: 'Funil B', position: 1, is_default: true)
    foreign_stage = CrmPipelineStage.create!(
      account: other_account, crm_pipeline: foreign_pipeline, name: 'Novo', position: 1
    )
    foreign_deal = CrmDeal.create!(
      account: other_account, crm_pipeline: foreign_pipeline, crm_pipeline_stage: foreign_stage, title: 'Deal B'
    )
    foreign_rule = CrmAutomationRule.create!(
      account: other_account, crm_pipeline_stage: foreign_stage, name: 'Regra B',
      trigger_event: 'stage_entered', action_type: 'create_activity', action_config: {}
    )
    CrmAutomationRun.create!(
      account: other_account, crm_automation_rule: foreign_rule, crm_deal: foreign_deal,
      status: 'executed', started_at: Time.current
    )

    get index_path, headers: headers, as: :json
    expect(response.parsed_body.size).to eq(1)

    get index_path(deal_id: foreign_deal.id), headers: headers, as: :json
    expect(response.parsed_body).to eq([])
  end

  it 'nega acesso a não-membro da conta' do
    outsider = create(:user)
    get index_path, headers: outsider.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end

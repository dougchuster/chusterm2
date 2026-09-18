# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::AutomationActionJob do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban', slug: 'kanban', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Nova', slug: 'nova', position: 0) }
  let(:other_stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Outra', slug: 'outra', position: 1) }
  let(:deal) do
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, title: 'Lead')
  end
  let(:rule) do
    account.crm_automation_rules.create!(
      crm_pipeline_stage: stage, name: 'Follow-up agendado', trigger_event: 'stage_entered',
      action_type: 'create_activity',
      action_config: { 'title' => 'Follow-up agendado', 'kind' => 'follow_up', 'delay_minutes' => 30 }
    )
  end
  let(:run) do
    CrmAutomationRun.create!(
      account: account, crm_automation_rule: rule, crm_deal: deal,
      status: 'scheduled', started_at: Time.current
    )
  end

  it 'executa a ação e finaliza o run agendado' do
    described_class.new.perform(rule.id, deal.id, nil, run.id)

    expect(deal.crm_activities.where(title: 'Follow-up agendado')).to exist
    expect(run.reload.status).to eq('executed')
    expect(run.finished_at).to be_present
  end

  it 'pula quando a regra foi desativada no intervalo' do
    rule.update!(is_active: false)

    described_class.new.perform(rule.id, deal.id, nil, run.id)

    expect(deal.crm_activities).to be_empty
    expect(run.reload.skip_reason).to eq('rule_inactive')
  end

  it 'pula quando o deal saiu da etapa no intervalo' do
    deal.update!(crm_pipeline_stage: other_stage)

    described_class.new.perform(rule.id, deal.id, nil, run.id)

    expect(deal.crm_activities).to be_empty
    expect(run.reload.skip_reason).to eq('stage_changed')
  end

  it 'pula quando a condição deixou de valer no intervalo' do
    rule.update!(action_config: rule.action_config.merge(
      'conditions' => [{ 'field' => 'legal_area', 'operator' => 'eq', 'value' => 'trabalhista' }]
    ))

    described_class.new.perform(rule.id, deal.id, nil, run.id)

    expect(deal.crm_activities).to be_empty
    expect(run.reload.skip_reason).to eq('condition')
  end

  it 'não faz nada quando a regra foi apagada (runs caem em cascade)' do
    run
    rule.destroy!

    expect do
      described_class.new.perform(rule.id, deal.id, nil, run.id)
    end.not_to raise_error
    expect(deal.crm_activities.reload).to be_empty
  end
end

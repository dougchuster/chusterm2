require 'rails_helper'

RSpec.describe Crm::MetricsService do
  let(:account) { create(:account) }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Pipeline Jurídico', position: 1, is_default: true) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', position: 1) }
  let(:qualified_stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', position: 2) }

  def create_deal!(title:, stage: self.stage, **attrs)
    CrmDeal.create!(
      {
        account: account,
        crm_pipeline: pipeline,
        crm_pipeline_stage: stage,
        title: title
      }.merge(attrs)
    )
  end

  def create_stage_change!(deal:, to_stage:, at:)
    CrmAuditEvent.create!(
      account: account,
      actor_type: 'user',
      actor_id: 1,
      action: 'deal_stage_changed',
      target_type: deal.class.name,
      target_id: deal.id,
      payload: { from_stage_id: stage.id, to_stage_id: to_stage.id },
      created_at: at
    )
  end

  describe '#time_in_stage' do
    it 'returns data from deal_stage_changed audit events' do
      deal = create_deal!(title: 'Caso trabalhista')
      create_stage_change!(deal: deal, to_stage: stage, at: 20.hours.ago)
      create_stage_change!(deal: deal, to_stage: qualified_stage, at: 10.hours.ago)

      result = described_class.new(account).time_in_stage
      stage_metric = result.find { |entry| entry[:stage_id] == stage.id }

      expect(stage_metric[:sample_size]).to eq(1)
      expect(stage_metric[:avg_hours]).to eq(10.0)
      expect(stage_metric[:min_hours]).to eq(10.0)
      expect(stage_metric[:max_hours]).to eq(10.0)
    end
  end

  describe '#stale_deals' do
    it 'excludes deals with any activity newer than the cutoff' do
      recent_deal = create_deal!(title: 'Com atividade recente')
      old_deal = create_deal!(title: 'Só com atividade antiga')
      silent_deal = create_deal!(title: 'Sem atividade nenhuma')

      CrmActivity.create!(
        account: account, crm_deal: recent_deal, kind: 'follow_up', title: 'Retorno de ontem',
        priority: 'normal', created_at: 1.day.ago, updated_at: 1.day.ago
      )
      CrmActivity.create!(
        account: account, crm_deal: old_deal, kind: 'follow_up', title: 'Retorno antigo',
        priority: 'normal', created_at: 10.days.ago, updated_at: 10.days.ago
      )

      result = described_class.new(account).stale_deals(days: 7)
      stale_ids = result.map { |entry| entry[:id] }

      expect(stale_ids).not_to include(recent_deal.id)
      expect(stale_ids).to include(old_deal.id, silent_deal.id)

      old_entry = result.find { |entry| entry[:id] == old_deal.id }
      expect(old_entry[:days_stale]).to eq(10)

      silent_entry = result.find { |entry| entry[:id] == silent_deal.id }
      expect(silent_entry[:days_stale]).to be_nil
    end

    it 'does not mark a deal stale when it has both old and recent activities' do
      deal = create_deal!(title: 'Atividade antiga e recente')
      CrmActivity.create!(
        account: account, crm_deal: deal, kind: 'follow_up', title: 'Antiga',
        priority: 'normal', created_at: 30.days.ago, updated_at: 30.days.ago
      )
      CrmActivity.create!(
        account: account, crm_deal: deal, kind: 'follow_up', title: 'Recente',
        priority: 'normal', created_at: 1.day.ago, updated_at: 1.day.ago
      )

      result = described_class.new(account).stale_deals(days: 7)

      expect(result.map { |entry| entry[:id] }).not_to include(deal.id)
    end
  end
end

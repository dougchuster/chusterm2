require 'rails_helper'

RSpec.describe Crm::MetricsService do
  let(:account) { create(:account) }
  # O AccountInitializer semeia um funil default em toda conta — a spec usa
  # esse funil (o mesmo que resolve_pipeline escolhe) em vez de criar um
  # segundo `is_default`, que tornaria a resolução ambígua.
  let(:pipeline) { account.crm_pipelines.active.default_first.first }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', position: 11) }
  let(:qualified_stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', position: 12) }

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

  describe '#stage_funnel' do
    it 'scopes to the default pipeline when pipeline_id is not given' do
      other_pipeline = CrmPipeline.create!(account: account, name: 'Funil Secundário', position: 2)
      other_stage = CrmPipelineStage.create!(account: account, crm_pipeline: other_pipeline, name: 'Entrada', position: 1)

      create_deal!(title: 'Deal do funil default')
      create_deal!(title: 'Deal do funil default 2', stage: qualified_stage)
      CrmDeal.create!(
        account: account, crm_pipeline: other_pipeline,
        crm_pipeline_stage: other_stage, title: 'Deal de outro funil'
      )

      result = described_class.new(account).stage_funnel

      stage_ids = result.map { |entry| entry[:stage_id] }
      expect(stage_ids).to include(stage.id, qualified_stage.id)
      expect(stage_ids).not_to include(other_stage.id)
      expect(result.sum { |entry| entry[:deal_count] }).to eq(2)
    end

    it 'sums to the open deal count of the pipeline (KPI coherence)' do
      create_deal!(title: 'A')
      create_deal!(title: 'B', stage: qualified_stage)
      create_deal!(title: 'C fechado', status: 'won', closed_at: 1.day.ago)

      result = described_class.new(account).stage_funnel

      expect(result.sum { |entry| entry[:deal_count] })
        .to eq(account.crm_deals.open_deals.count)
    end
  end

  describe '#overview' do
    it 'measures won/lost on deals closed in the period (closed_at cohort)' do
      # Criado fora do período, fechado dentro — deve contar no resultado.
      old_won = create_deal!(title: 'Ganho antigo', status: 'won', closed_at: 2.days.ago)
      old_won.update!(created_at: 60.days.ago)
      # Criado e fechado fora do período — não pode contaminar o win_rate.
      old_closed = create_deal!(title: 'Fechado antigo', status: 'lost', closed_at: 40.days.ago)
      old_closed.update!(created_at: 60.days.ago)

      result = described_class.new(account).overview(period_days: 30)

      expect(result[:total_deals]).to eq(0)
      expect(result[:won_deals]).to eq(1)
      expect(result[:lost_deals]).to eq(0)
      expect(result[:win_rate]).to eq(100.0)
    end

    it 'returns win_rate 0 (not a bogus 50%) when nothing closed in the period' do
      create_deal!(title: 'Aberto')

      result = described_class.new(account).overview(period_days: 30)

      expect(result[:win_rate]).to eq(0)
      expect(result[:won_deals]).to eq(0)
      expect(result[:lost_deals]).to eq(0)
    end
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

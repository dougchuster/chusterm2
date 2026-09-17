require 'rails_helper'

RSpec.describe Crm::StageAutomation do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: 'agent') }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban Teste', slug: 'kanban-teste', kind: 'legal_intake') }
  let(:stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Qualificacao', slug: 'qualificacao', position: 0)
  end
  let(:deal) do
    account.crm_deals.create!(
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: 'Atendimento de teste'
    )
  end

  def build_rule(action_type, config)
    account.crm_automation_rules.create!(
      crm_pipeline_stage: stage,
      name: "Regra #{action_type}",
      trigger_event: 'stage_entered',
      action_type: action_type,
      action_config: config
    )
  end

  def build_assign_owner_rule(config)
    build_rule('assign_owner', config)
  end

  describe 'trigger filtering' do
    it 'runs only stage_entered rules by default' do
      account.crm_automation_rules.create!(
        crm_pipeline_stage: stage, name: 'Regra marketing',
        trigger_event: 'marketing_lead_created', action_type: 'assign_owner',
        action_config: { 'user_id' => owner.id }
      )

      described_class.new(deal: deal, actor: nil).perform

      expect(deal.reload.owner_id).to be_nil
      expect(CrmAutomationRun.where(crm_deal: deal)).to be_empty
    end

    it 'runs marketing_lead_created rules when that trigger is requested' do
      account.crm_automation_rules.create!(
        crm_pipeline_stage: stage, name: 'Regra marketing',
        trigger_event: 'marketing_lead_created', action_type: 'assign_owner',
        action_config: { 'user_id' => owner.id }
      )

      described_class.new(deal: deal, actor: nil).perform(trigger: 'marketing_lead_created')

      expect(deal.reload.owner_id).to eq(owner.id)
      expect(CrmAutomationRun.where(crm_deal: deal).last.status).to eq('executed')
    end
  end

  describe 'assign_owner action' do
    it 'assigns the configured user as the deal owner' do
      build_assign_owner_rule({ 'user_id' => owner.id })

      described_class.new(deal: deal, actor: nil).perform

      expect(deal.reload.owner_id).to eq(owner.id)
    end

    it 'syncs assignee_id when the deal has no responsible yet' do
      build_assign_owner_rule({ 'user_id' => owner.id })

      described_class.new(deal: deal, actor: nil).perform

      expect(deal.reload.assignee_id).to eq(owner.id)
    end

    it 'syncs assignee_id when it was only following the previous owner' do
      previous_owner = create(:user, account: account, role: 'agent')
      deal.update!(owner_id: previous_owner.id, assignee_id: previous_owner.id)
      build_assign_owner_rule({ 'user_id' => owner.id })

      described_class.new(deal: deal, actor: nil).perform

      expect(deal.reload.assignee_id).to eq(owner.id)
    end

    it 'never takes the case away from a responsible chosen by hand' do
      previous_owner = create(:user, account: account, role: 'agent')
      paralegal = create(:user, account: account, role: 'agent')
      deal.update!(owner_id: previous_owner.id, assignee_id: paralegal.id)
      build_assign_owner_rule({ 'user_id' => owner.id })

      described_class.new(deal: deal, actor: nil).perform

      expect(deal.reload.owner_id).to eq(owner.id)
      expect(deal.reload.assignee_id).to eq(paralegal.id)
    end

    it 'audits that the hand-picked responsible was preserved' do
      previous_owner = create(:user, account: account, role: 'agent')
      paralegal = create(:user, account: account, role: 'agent')
      deal.update!(owner_id: previous_owner.id, assignee_id: paralegal.id)
      build_assign_owner_rule({ 'user_id' => owner.id })

      allow(Crm::AuditLogger).to receive(:log)

      described_class.new(deal: deal, actor: nil).perform

      expect(Crm::AuditLogger).to have_received(:log)
        .with(hash_including(action: 'automation_preserved_assignee'))
    end

    it 'does not reroute the contact by rewriting crm_owner_id' do
      contact = create(:contact, account: account)
      deal.update!(contact: contact)
      build_assign_owner_rule({ 'user_id' => owner.id })

      described_class.new(deal: deal, actor: nil).perform

      expect(contact.reload.crm_owner_id).to be_nil
    end

    it 'does not report the rule as executed when the configured user is not in the account' do
      outsider = create(:user)
      build_assign_owner_rule({ 'user_id' => outsider.id })

      allow(Crm::AuditLogger).to receive(:log)

      described_class.new(deal: deal, actor: nil).perform

      expect(deal.reload.owner_id).to be_nil
      expect(Crm::AuditLogger).not_to have_received(:log)
        .with(hash_including(action: 'automation_executed_assign_owner'))
    end

    it 'audits the skip when the configured user is not in the account' do
      outsider = create(:user)
      build_assign_owner_rule({ 'user_id' => outsider.id })

      allow(Crm::AuditLogger).to receive(:log)

      described_class.new(deal: deal, actor: nil).perform

      expect(Crm::AuditLogger).to have_received(:log)
        .with(hash_including(action: 'automation_skipped_invalid_owner'))
    end

    it 'skips the rule when the configured user does not exist at all' do
      build_assign_owner_rule({ 'user_id' => 999_999 })

      expect { described_class.new(deal: deal, actor: nil).perform }
        .not_to(change { deal.reload.owner_id })
    end

    it 'skips the rule when no user_id is configured' do
      build_assign_owner_rule({})

      expect { described_class.new(deal: deal, actor: nil).perform }
        .not_to(change { deal.reload.owner_id })
    end
  end

  describe 'truthful audit trail (B-03)' do
    it 'does not log executed when create_activity hits a pending duplicate' do
      build_rule('create_activity', { 'kind' => 'follow_up', 'title' => 'Ligar para o lead' })
      deal.crm_activities.create!(
        account: account, kind: 'follow_up', title: 'Ligar para o lead', priority: 'normal'
      )
      allow(Crm::AuditLogger).to receive(:log)

      described_class.new(deal: deal, actor: nil).perform

      expect(Crm::AuditLogger).not_to have_received(:log)
        .with(hash_including(action: 'automation_executed_create_activity'))
      expect(Crm::AuditLogger).to have_received(:log)
        .with(hash_including(action: 'automation_skipped_duplicate_activity'))
    end

    it 'logs executed when create_activity actually creates the activity' do
      build_rule('create_activity', { 'kind' => 'follow_up', 'title' => 'Ligar para o lead' })
      allow(Crm::AuditLogger).to receive(:log)

      expect { described_class.new(deal: deal, actor: nil).perform }
        .to change { deal.crm_activities.count }.by(1)
      expect(Crm::AuditLogger).to have_received(:log)
        .with(hash_including(action: 'automation_executed_create_activity'))
    end

    it 'does not log executed when set_captain_mode finds no conversation' do
      build_rule('set_captain_mode', { 'ai_mode' => 'assist' })
      allow(Crm::AuditLogger).to receive(:log)

      described_class.new(deal: deal, actor: nil).perform

      expect(Crm::AuditLogger).not_to have_received(:log)
        .with(hash_including(action: 'automation_executed_set_captain_mode'))
      expect(Crm::AuditLogger).to have_received(:log)
        .with(hash_including(action: 'automation_skipped_no_conversation'))
    end

    it 'does not log executed when move_to_stage targets the current stage' do
      build_rule('move_to_stage', { 'stage_slug' => stage.slug })
      allow(Crm::AuditLogger).to receive(:log)

      described_class.new(deal: deal, actor: nil).perform

      expect(Crm::AuditLogger).not_to have_received(:log)
        .with(hash_including(action: 'automation_executed_move_to_stage'))
      expect(Crm::AuditLogger).to have_received(:log)
        .with(hash_including(action: 'automation_skipped_same_stage'))
    end
  end

  describe 'crm_automation_runs persistence (CRM-003)' do
    it 'records an executed run with started/finished timestamps' do
      rule = build_rule('create_activity', { 'kind' => 'follow_up', 'title' => 'Ligar' })

      described_class.new(deal: deal, actor: nil).perform

      run = CrmAutomationRun.find_by(crm_automation_rule: rule, crm_deal: deal)
      expect(run).to be_present
      expect(run.status).to eq('executed')
      expect(run.started_at).to be_present
      expect(run.finished_at).to be_present
      expect(run.account_id).to eq(account.id)
    end

    it 'records a skipped run with the reason' do
      rule = build_rule('move_to_stage', { 'stage_slug' => stage.slug })

      described_class.new(deal: deal, actor: nil).perform

      run = CrmAutomationRun.find_by(crm_automation_rule: rule, crm_deal: deal)
      expect(run.status).to eq('skipped')
      expect(run.skip_reason).to eq('same_stage')
    end

    it 'records a skipped run when conditions do not match' do
      rule = build_rule('create_activity', {
                          'kind' => 'follow_up', 'title' => 'Ligar',
                          'conditions' => [{ 'field' => 'legal_area', 'operator' => 'eq', 'value' => 'previdenciario' }]
                        })

      described_class.new(deal: deal, actor: nil).perform

      run = CrmAutomationRun.find_by(crm_automation_rule: rule, crm_deal: deal)
      expect(run.status).to eq('skipped')
      expect(run.skip_reason).to eq('condition')
    end

    it 'rejects runs in a different account than the deal' do
      rule = build_assign_owner_rule({ 'user_id' => owner.id })
      foreign_account = create(:account)
      foreign_pipeline = CrmPipeline.create!(account: foreign_account, name: 'P', position: 1)
      foreign_stage = CrmPipelineStage.create!(account: foreign_account, crm_pipeline: foreign_pipeline,
                                               name: 'Novo', position: 1)
      other_deal = CrmDeal.create!(
        account: foreign_account, title: 'Deal de outra conta', crm_pipeline: foreign_pipeline,
        crm_pipeline_stage: foreign_stage
      )

      run = CrmAutomationRun.new(
        account: account, crm_automation_rule: rule, crm_deal: other_deal,
        status: 'executed', started_at: Time.current
      )

      expect(run).not_to be_valid
    end
  end
end

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

  def build_assign_owner_rule(config)
    account.crm_automation_rules.create!(
      crm_pipeline_stage: stage,
      name: 'Atribuir responsavel na qualificacao',
      trigger_event: 'stage_entered',
      action_type: 'assign_owner',
      action_config: config
    )
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
end

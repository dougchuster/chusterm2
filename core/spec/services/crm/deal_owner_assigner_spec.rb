require 'rails_helper'

RSpec.describe Crm::DealOwnerAssigner do
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

  describe 'sync_assignee: :always (ação manual)' do
    it 'sets owner and assignee to the given user' do
      described_class.new(deal: deal, owner: owner, sync_assignee: :always).perform

      expect(deal.reload.owner_id).to eq(owner.id)
      expect(deal.assignee_id).to eq(owner.id)
    end

    it 'overrides even a hand-picked assignee' do
      previous_owner = create(:user, account: account, role: 'agent')
      paralegal = create(:user, account: account, role: 'agent')
      deal.update!(owner_id: previous_owner.id, assignee_id: paralegal.id)

      described_class.new(deal: deal, owner: owner, sync_assignee: :always).perform

      expect(deal.reload.assignee_id).to eq(owner.id)
    end

    it 'clears owner and assignee when owner is nil (unassign)' do
      deal.update!(owner_id: owner.id, assignee_id: owner.id)

      described_class.new(deal: deal, owner: nil, sync_assignee: :always).perform

      expect(deal.reload.owner_id).to be_nil
      expect(deal.assignee_id).to be_nil
    end
  end

  describe 'sync_assignee: :if_unmanaged (automação)' do
    it 'syncs assignee when the deal has none' do
      described_class.new(deal: deal, owner: owner, sync_assignee: :if_unmanaged).perform

      expect(deal.reload.assignee_id).to eq(owner.id)
    end

    it 'syncs assignee when it was only following the previous owner' do
      previous_owner = create(:user, account: account, role: 'agent')
      deal.update!(owner_id: previous_owner.id, assignee_id: previous_owner.id)

      described_class.new(deal: deal, owner: owner, sync_assignee: :if_unmanaged).perform

      expect(deal.reload.assignee_id).to eq(owner.id)
    end

    it 'preserves a hand-picked assignee and reports it in the result' do
      previous_owner = create(:user, account: account, role: 'agent')
      paralegal = create(:user, account: account, role: 'agent')
      deal.update!(owner_id: previous_owner.id, assignee_id: paralegal.id)

      result = described_class.new(deal: deal, owner: owner, sync_assignee: :if_unmanaged).perform

      expect(deal.reload.owner_id).to eq(owner.id)
      expect(deal.assignee_id).to eq(paralegal.id)
      expect(result.preserved_assignee_id).to eq(paralegal.id)
    end

    it 'reports no preserved assignee when assignee followed the owner' do
      result = described_class.new(deal: deal, owner: owner, sync_assignee: :if_unmanaged).perform

      expect(result.preserved_assignee_id).to be_nil
    end
  end

  describe 'sync_assignee: :never (roteador)' do
    it 'changes only the owner and leaves assignee untouched' do
      paralegal = create(:user, account: account, role: 'agent')
      deal.update!(assignee_id: paralegal.id)

      described_class.new(deal: deal, owner: owner, sync_assignee: :never).perform

      expect(deal.reload.owner_id).to eq(owner.id)
      expect(deal.assignee_id).to eq(paralegal.id)
    end
  end

  describe 'sync_contact' do
    let(:contact) { create(:contact, account: account) }

    before { deal.update!(contact: contact) }

    it 'assigns the contact crm_owner with the given source and actor' do
      admin = create(:user, account: account, role: 'administrator')

      described_class.new(
        deal: deal, owner: owner, actor: admin,
        sync_assignee: :always, sync_contact: true, contact_source: 'manual'
      ).perform

      contact.reload
      expect(contact.crm_owner_id).to eq(owner.id)
      expect(contact.crm_owner_source).to eq('manual')
      expect(contact.crm_owner_assigned_at).to be_present
    end

    it 'clears the contact crm_owner when owner is nil' do
      contact.assign_crm_owner!(owner, source: 'manual')

      described_class.new(
        deal: deal, owner: nil, sync_assignee: :always, sync_contact: true
      ).perform

      expect(contact.reload.crm_owner_id).to be_nil
    end

    it 'does not touch the contact when sync_contact is false' do
      described_class.new(deal: deal, owner: owner, sync_assignee: :if_unmanaged, sync_contact: false).perform

      expect(contact.reload.crm_owner_id).to be_nil
    end
  end

  describe 'validação de modo' do
    it 'rejects an unknown sync_assignee mode' do
      expect do
        described_class.new(deal: deal, owner: owner, sync_assignee: :bogus)
      end.to raise_error(ArgumentError, /sync_assignee/)
    end
  end
end

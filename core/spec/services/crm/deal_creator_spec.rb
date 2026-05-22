require 'rails_helper'

RSpec.describe Crm::DealCreator do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, :with_phone_number, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban Teste', slug: 'kanban-teste', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo atendimento', slug: 'novo-atendimento', position: 0) }
  let(:inbox) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false, account: account).inbox }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: contact.phone_number.delete('+')) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  before do
    allow(Crm::AuditLogger).to receive(:log)
  end

  it 'reuses the open deal for the same contact and kanban instead of creating a duplicate' do
    first = described_class.new(
      account: account,
      params: base_params.merge(title: 'Atendimento original'),
      actor: nil
    ).perform

    second = described_class.new(
      account: account,
      params: base_params.merge(title: 'Atendimento duplicado'),
      actor: nil
    ).perform

    expect(second.id).to eq(first.id)
    expect(account.crm_deals.where(contact: contact, crm_pipeline: pipeline, status: 'open').count).to eq(1)
  end

  it 'updates the reused deal to the current conversation and inbox' do
    first = described_class.new(
      account: account,
      params: base_params.merge(conversation_id: nil, inbox_id: nil),
      actor: nil
    ).perform

    second = described_class.new(
      account: account,
      params: base_params,
      actor: nil
    ).perform

    expect(second.id).to eq(first.id)
    expect(second.reload.conversation_id).to eq(conversation.id)
    expect(second.inbox_id).to eq(inbox.id)
  end

  private

  def base_params
    {
      title: "Atendimento ##{conversation.display_id}",
      contact_id: contact.id,
      conversation_id: conversation.id,
      inbox_id: inbox.id,
      crm_pipeline_id: pipeline.id,
      crm_pipeline_stage_id: stage.id
    }
  end
end

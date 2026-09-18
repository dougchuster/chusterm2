require 'rails_helper'

# 2.5 — deal por contato: conversas novas do mesmo contato anexam ao deal
# aberto em vez de criar outro card no kanban.
RSpec.describe Crm::TriageFromConversation do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, :with_phone_number, account: account) }
  let(:inbox) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false, account: account).inbox }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: contact.phone_number.delete('+')) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:second_conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  let(:analyzer) { instance_double(Crm::LegalTriageAnalyzer) }
  let(:insufficient_triage) { { data_quality: 'insufficient', intake_answers: [] } }

  before do
    allow(Crm::LegalTriageAnalyzer).to receive(:new).and_return(analyzer)
    allow(analyzer).to receive(:perform).and_return(insufficient_triage)
    allow(Crm::LeadScoreCalculator).to receive(:new).and_return(instance_double(Crm::LeadScoreCalculator, perform: nil))
    allow(Crm::ContactOwnerRouter).to receive(:new).and_return(instance_double(Crm::ContactOwnerRouter, perform: nil))
    allow(Crm::LegalLabelSync).to receive(:new).and_return(instance_double(Crm::LegalLabelSync, perform: nil))
    allow(Crm::AuditLogger).to receive(:log)
  end

  def run_triage(conversation)
    described_class.new(conversation: conversation, account: account, actor: nil).perform
  end

  it 'creates a deal linked to the conversation' do
    deal = run_triage(conversation)

    expect(deal.conversation_id).to eq(conversation.id)
    expect(deal.conversations).to contain_exactly(conversation)
  end

  it 'attaches a second conversation to the contact open deal instead of creating a card' do
    first_deal = run_triage(conversation)
    second_deal = run_triage(second_conversation)

    expect(second_deal.id).to eq(first_deal.id)
    expect(first_deal.reload.conversations).to contain_exactly(conversation, second_conversation)
  end

  it 'finds the open deal through the join table on re-triage' do
    first_deal = run_triage(conversation)
    first_deal.update!(conversation_id: nil)

    expect(run_triage(conversation).id).to eq(first_deal.id)
  end

  it 'creates a new deal when the previous one is closed' do
    first_deal = run_triage(conversation)
    first_deal.update!(status: 'won', closed_at: Time.current)

    second_deal = run_triage(second_conversation)

    expect(second_deal.id).not_to eq(first_deal.id)
    expect(second_deal.conversations).to contain_exactly(second_conversation)
  end
end

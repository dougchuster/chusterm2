require 'rails_helper'

RSpec.describe CaptainConversationState do
  describe '.for_conversation!' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }

    it 'creates a state for the conversation when one does not exist' do
      state = described_class.for_conversation!(conversation)

      expect(state).to be_persisted
      expect(state.account).to eq(account)
      expect(state.conversation).to eq(conversation)
      expect(state.contact).to eq(conversation.contact)
    end

    it 'returns the existing state for the conversation' do
      existing_state = described_class.create!(
        account: account,
        conversation: conversation,
        contact: conversation.contact,
        ai_mode: 'auto'
      )

      expect(described_class.for_conversation!(conversation)).to eq(existing_state)
    end

    it 'repairs a stale deal link when the deal moved to another conversation' do
      other_conversation = create(:conversation, account: account, inbox: inbox)
      pipeline = account.crm_pipelines.create!(
        name: 'Atendimento',
        slug: 'atendimento',
        kind: 'legal_intake'
      )
      stage = pipeline.crm_pipeline_stages.create!(
        account: account,
        name: 'Novo',
        slug: 'novo',
        position: 0
      )
      deal = account.crm_deals.create!(
        title: 'Atendimento atual',
        crm_pipeline: pipeline,
        crm_pipeline_stage: stage,
        conversation: other_conversation,
        contact: other_conversation.contact
      )
      existing_state = described_class.create!(
        account: account,
        conversation: conversation,
        contact: conversation.contact,
        ai_mode: 'auto'
      )
      # rubocop:disable Rails/SkipsModelValidations -- builds the cross-linked legacy row this repair path must handle
      existing_state.update_columns(crm_deal_id: deal.id)
      # rubocop:enable Rails/SkipsModelValidations

      repaired_state = described_class.for_conversation!(conversation)

      expect(repaired_state).to eq(existing_state)
      expect(repaired_state.crm_deal_id).to be_nil
    end
  end

  describe '#resumed_after?' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:state) { described_class.for_conversation!(conversation) }
    let(:human_message_at) { 2.hours.ago }

    it 'recognizes an automatic resume after the last human message' do
      state.mark_automatic_resume!
      state.apply_ai_mode!(mode: 'auto', reason_code: 'automatic_resume')

      expect(state.resumed_after?(human_message_at)).to be(true)
      expect(state.resume_source).to eq(described_class::RESUME_SOURCE_AUTOMATIC)
    end

    it 'does not resume while the conversation is human controlled' do
      state.mark_automatic_resume!
      state.apply_ai_mode!(mode: 'human_only', reason_code: 'human_message')

      expect(state.resumed_after?(human_message_at)).to be(false)
    end
  end
end

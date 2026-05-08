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
  end
end

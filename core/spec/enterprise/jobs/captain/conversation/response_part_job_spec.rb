# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::ResponsePartJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }

  before do
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
    allow(inbox).to receive(:captain_active?).and_return(true)
  end

  it 'does not reapply the policy to a part from an already sanitized complete response' do
    expect(Captain::Conversation::ResponsePolicyService).not_to receive(:new)

    described_class.perform_now(
      conversation,
      assistant,
      'Segunda parte segura.',
      'Dra. Letícia',
      policy_applied: true
    )

    message = conversation.messages.outgoing.last
    expect(message.content).to eq('Segunda parte segura.')
    expect(message.additional_attributes).to include(
      'agent_name' => 'Dra. Letícia',
      'ai_response_part' => true
    )
  end

  it 'keeps backward compatibility by applying the policy to legacy queued parts' do
    policy = instance_double(Captain::Conversation::ResponsePolicyService, apply: 'Parte sanitizada.')
    allow(Captain::Conversation::ResponsePolicyService).to receive(:new)
      .with(conversation: conversation, assistant: assistant)
      .and_return(policy)

    described_class.perform_now(conversation, assistant, 'Parte antiga.', nil, policy_applied: false)

    expect(conversation.messages.outgoing.last.content).to eq('Parte sanitizada.')
  end

  it 'discards a delayed part when a newer incoming message starts another customer turn' do
    origin = create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      message_type: :incoming,
      content: 'Primeira pergunta.'
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: assistant,
      message_type: :outgoing,
      content: 'Primeira parte da resposta.'
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      message_type: :incoming,
      content: 'Nova pergunta antes da segunda parte.'
    )

    expect do
      described_class.perform_now(
        conversation,
        assistant,
        Captain::Conversation::ResponsePolicyService::NEW_LEAD_REVIEW_NOTICE,
        nil,
        policy_applied: true,
        origin_incoming_id: origin.id
      )
    end.not_to(change { conversation.messages.outgoing.count })

    expect(conversation.reload.captain_conversation_state&.analysis_notice_sent_at).to be_blank
  end

  it 'marks the review notice only after the part containing it is actually created' do
    expect do
      described_class.perform_now(
        conversation,
        assistant,
        Captain::Conversation::ResponsePolicyService::NEW_LEAD_REVIEW_NOTICE,
        nil,
        policy_applied: true
      )
    end.to change { conversation.messages.outgoing.count }.by(1)

    expect(conversation.reload.captain_conversation_state.analysis_notice_sent_at).to be_present
  end
end

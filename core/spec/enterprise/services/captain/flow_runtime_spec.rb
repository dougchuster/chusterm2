# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::FlowRuntime do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:flow) do
    Captain::Flow.create!(
      account: account,
      name: 'Fluxo com handoff',
      slug: "fluxo-com-handoff-#{SecureRandom.hex(4)}",
      status: 'published'
    )
  end
  let!(:handoff_node) do
    flow.flow_nodes.create!(
      account: account,
      node_id: 'handoff',
      node_type: 'handoff',
      config: { 'mode' => 'human_only', 'reason' => 'Handoff do fluxo' }
    )
  end
  let!(:end_node) do
    flow.flow_nodes.create!(account: account, node_id: 'end', node_type: 'end')
  end
  let(:edge) do
    flow.flow_edges.create!(
      account: account,
      edge_id: 'handoff-end',
      source_node_id: handoff_node.node_id,
      target_node_id: end_node.node_id
    )
  end
  let!(:state) do
    CaptainConversationState.create!(
      account: account,
      conversation: conversation,
      captain_flow: flow,
      current_node_id: handoff_node.node_id
    )
  end

  before { edge }

  it 'skips a configured handoff when the customer did not request a human' do
    result = described_class.new(conversation: conversation).step(
      incoming_message: 'Meu pedido do INSS foi negado e preciso entender o motivo.'
    )

    expect(result).to eq(action: :flow_complete)
    expect(state.reload.ai_mode).to eq('auto')
    expect(state.current_node_id).to be_nil
  end

  it 'keeps the configured handoff when the customer explicitly requests Dra. Paula' do
    result = described_class.new(conversation: conversation).step(
      incoming_message: 'Quero falar com a Dra. Paula.'
    )

    expect(result).to eq(action: :handoff)
    expect(state.reload.ai_mode).to eq('human_only')
    expect(state.handoff_reason).to eq('Handoff do fluxo')
  end
end

class Captain::FlowRouter
  def initialize(conversation:)
    @conversation = conversation
  end

  def route!
    state = @conversation.captain_conversation_state
    return if state&.captain_flow_id.present?

    flow, assistant = detect_flow_and_assistant
    return unless flow || assistant

    state ||= @conversation.build_captain_conversation_state(
      account: @conversation.account,
      contact: @conversation.contact
    )

    state.captain_flow = flow if flow
    state.captain_assistant_id = assistant.id if assistant && state.captain_assistant_id.blank?

    if flow && state.current_node_id.blank?
      start_node = flow.flow_nodes.find_by(node_type: 'start')
      state.current_node_id = start_node&.node_id
    end

    state.save!
  end

  private

  def detect_flow_and_assistant
    campaign = @conversation.campaign
    return [nil, nil] unless campaign

    [campaign.captain_flow, campaign.captain_assistant]
  end
end

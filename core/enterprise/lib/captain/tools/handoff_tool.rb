class Captain::Tools::HandoffTool < Captain::Tools::BasePublicTool
  description 'Hand off the conversation to a human agent when unable to assist further'
  param :reason, type: 'string', desc: 'The reason why handoff is needed (optional)', required: false

  def perform(tool_context, reason: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    # Log the handoff with reason
    log_tool_usage('tool_handoff', {
                     conversation_id: conversation.id,
                     reason: reason || 'Agent requested handoff'
                   })

    # Use existing handoff mechanism from ResponseBuilderJob
    trigger_handoff(conversation, reason)

    "Conversation handed off to human support team#{" (Reason: #{reason})" if reason}"
  rescue StandardError => e
    ChusteRMExceptionTracker.new(e).capture_exception
    'Failed to handoff conversation'
  end

  private

  def trigger_handoff(conversation, reason)
    create_public_handoff_message(conversation)

    handoff_summary = Captain::CrmHandoffSummaryBuilder.new(conversation, reason: reason).perform

    # Post a private CRM note so the human agent starts with the case context.
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: @assistant,
      account: conversation.account,
      inbox: conversation.inbox,
      content: handoff_summary
    )

    # Trigger the bot handoff (sets status to open + dispatches events)
    conversation.bot_handoff!

    # Send out of office message if applicable (since template messages were suppressed while Captain was handling)
    send_out_of_office_message_if_applicable(conversation)
  end

  def create_public_handoff_message(conversation)
    message_content = @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff')
    message_content = Captain::Conversation::ResponsePolicyService.new(conversation: conversation, assistant: @assistant).apply(message_content)
    return if recent_public_handoff_message_exists?(conversation, message_content)

    conversation.messages.create!(
      message_type: :outgoing,
      private: false,
      sender: @assistant,
      account: conversation.account,
      inbox: conversation.inbox,
      content: message_content,
      additional_attributes: { handoff_message: true }
    )
  end

  def recent_public_handoff_message_exists?(conversation, message_content)
    conversation.messages
                .where(message_type: :outgoing, private: false, sender: @assistant)
                .where('created_at > ?', 10.minutes.ago)
                .where(content: message_content)
                .exists?
  end

  def send_out_of_office_message_if_applicable(conversation)
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  # TODO: Future enhancement - Add team assignment capability
  # This tool could be enhanced to:
  # 1. Accept team_id parameter for routing to specific teams
  # 2. Set conversation priority based on handoff reason
  # 3. Add metadata for intelligent agent assignment
  # 4. Support escalation levels (L1 -> L2 -> L3)
  #
  # Example future signature:
  # param :team_id, type: 'string', desc: 'ID of team to assign conversation to', required: false
  # param :priority, type: 'string', desc: 'Priority level (low/medium/high/urgent)', required: false
  # param :escalation_level, type: 'string', desc: 'Support level (L1/L2/L3)', required: false
end

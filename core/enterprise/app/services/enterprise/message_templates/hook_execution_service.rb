module Enterprise::MessageTemplates::HookExecutionService
  def should_send_greeting?
    return false if captain_handling_conversation?

    super
  end

  def should_send_out_of_office_message?
    return false if captain_handling_conversation?

    super
  end

  def should_send_email_collect?
    return false if captain_handling_conversation?

    super
  end

  # Override base perform_captain_handoff with enterprise-specific handoff message
  def perform_captain_handoff
    return unless conversation.pending?

    Rails.logger.info("Captain limit exceeded, performing handoff for conversation: #{conversation.id}")
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferindo para outro atendente.'
    )
    conversation.bot_handoff!
    send_out_of_office_message_after_handoff
  end

  private

  def send_out_of_office_message_after_handoff
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def captain_handling_conversation?
    conversation.pending? && inbox.respond_to?(:captain_assistant) && inbox.captain_assistant.present?
  end
end

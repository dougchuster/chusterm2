class MessageTemplates::HookExecutionService
  MAX_ATTACHMENT_WAIT_SECONDS = 4
  DEFAULT_CAPTAIN_RESPONSE_DELAY_SECONDS = 3

  pattr_initialize [:message!]

  def perform
    return if conversation.last_incoming_message.blank?
    return if message.auto_reply_email?

    trigger_templates
  end

  private

  delegate :inbox, :conversation, to: :message
  delegate :contact, to: :conversation

  def trigger_templates
    ::MessageTemplates::Template::OutOfOffice.new(conversation: conversation).perform if should_send_out_of_office_message?
    ::MessageTemplates::Template::Greeting.new(conversation: conversation).perform if should_send_greeting?
    ::MessageTemplates::Template::EmailCollect.new(conversation: conversation).perform if inbox.enable_email_collect && should_send_email_collect?
    return unless should_process_captain_response?
    return perform_captain_handoff unless inbox.captain_active?

    activate_captain_conversation
    schedule_captain_response
  end

  def should_send_out_of_office_message?
    return false if captain_human_controlled?
    return false if captain_handling_conversation?
    return false if conversation.campaign.present?
    # should not send if its a tweet message
    return false if conversation.tweet?
    # should not send for outbound messages
    return false unless message.incoming?
    # prevents sending out-of-office message if an agent has sent a message in last 5 minutes
    # ensures better UX by not interrupting active conversations at the end of business hours
    return false if conversation.messages.outgoing.where(private: false).exists?(['created_at > ?', 5.minutes.ago])

    inbox.out_of_office? && conversation.messages.today.template.empty? && inbox.out_of_office_message.present?
  end

  def first_message_from_contact?
    conversation.messages.outgoing.count.zero? && conversation.messages.template.count.zero?
  end

  def should_send_greeting?
    return false if captain_human_controlled?
    return false if captain_handling_conversation?
    return false if conversation.campaign.present?
    # should not send if its a tweet message
    return false if conversation.tweet?

    first_message_from_contact? && inbox.greeting_enabled? && inbox.greeting_message.present?
  end

  def email_collect_was_sent?
    conversation.messages.where(content_type: 'input_email').present?
  end

  # TODO: we should be able to reduce this logic once we have a toggle for email collect messages
  def should_send_email_collect?
    return false if captain_human_controlled?
    return false if captain_handling_conversation?
    return false if conversation.campaign.present?

    !contact_has_email? && inbox.web_widget? && !email_collect_was_sent?
  end

  def contact_has_email?
    contact.email
  end

  def schedule_captain_response
    assistant = inbox.captain_assistant
    return if assistant.blank?

    job_args = [
      conversation,
      assistant,
      0,
      message.id,
      Time.current
    ]
    wait_seconds = [captain_response_delay_seconds, attachment_wait_seconds].max

    if wait_seconds.zero?
      Captain::Conversation::ResponseBuilderJob.perform_later(*job_args)
    else
      Captain::Conversation::ResponseBuilderJob.set(wait: wait_seconds.seconds).perform_later(*job_args)
    end
  end

  def attachment_wait_seconds
    return 0 if message.attachments.blank?

    1 + [message.attachments.size, MAX_ATTACHMENT_WAIT_SECONDS].min
  end

  def captain_response_delay_seconds
    delay = inbox.captain_inbox&.routing_config&.dig('response_delay_seconds')
    delay.to_i.clamp(DEFAULT_CAPTAIN_RESPONSE_DELAY_SECONDS, 120)
  end

  def should_process_captain_response?
    message.incoming? &&
      inbox.captain_responsible? &&
      !captain_human_controlled? &&
      captain_manageable_conversation?
  end

  def captain_manageable_conversation?
    return true if conversation.pending?
    return false unless conversation.open?
    return false if conversation.assignee_id.present?
    return false if public_human_response_exists?

    true
  end

  def public_human_response_exists?
    conversation.messages.outgoing
                .where(private: false)
                .where.not(sender_type: ['AgentBot', 'Captain::Assistant'])
                .exists?
  end

  def activate_captain_conversation
    conversation.pending! unless conversation.pending?
  end

  def perform_captain_handoff
    Rails.logger.info("Captain inactive, performing handoff for conversation: #{conversation.id}")
    return unless conversation.pending?

    conversation.bot_handoff!
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def captain_handling_conversation?
    return false unless inbox.captain_responsible? && inbox.captain_assistant.present?
    return false if captain_human_controlled?

    conversation.pending? || captain_manageable_conversation?
  end

  def captain_human_controlled?
    conversation.captain_conversation_state&.human_controlled?
  end
end
MessageTemplates::HookExecutionService.prepend_mod_with('MessageTemplates::HookExecutionService')

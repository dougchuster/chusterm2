class CrmCaptainTriageListener < BaseListener
  TRIAGE_ENQUEUED_KEY = 'crm_triage_enqueued_at'.freeze
  TRIAGE_THROTTLE = 90.seconds

  def message_created(event)
    message = event.data[:message]
    return unless should_enqueue_triage?(message)

    conversation = message.conversation
    mark_triage_enqueued(conversation)
    Crm::CaptainTriageJob.perform_later(conversation.id, message.account_id)
  end

  private

  def should_enqueue_triage?(message)
    return false unless processable_message?(message)
    return false unless crm_pipeline_ready?(message.account)
    return false if triage_recently_enqueued?(message.conversation)

    true
  end

  def processable_message?(message)
    return false if message.blank?
    return false unless message.incoming?
    return false if message.private? || message.activity? || message.auto_reply_email?

    message.conversation.present?
  end

  def crm_pipeline_ready?(account)
    return false if account.blank?

    account.crm_pipelines.active
           .joins(:crm_pipeline_stages)
           .merge(CrmPipelineStage.active)
           .exists?
  end

  def triage_recently_enqueued?(conversation)
    enqueued_at = conversation.additional_attributes&.[](TRIAGE_ENQUEUED_KEY)
    return false if enqueued_at.blank?

    Time.zone.parse(enqueued_at) > TRIAGE_THROTTLE.ago
  rescue ArgumentError, TypeError
    false
  end

  def mark_triage_enqueued(conversation)
    attributes = conversation.additional_attributes || {}
    conversation.update!(
      additional_attributes: attributes.merge(TRIAGE_ENQUEUED_KEY => Time.current.iso8601)
    )
  end
end

class Captain::InboxPendingConversationsResolutionJob < ApplicationJob
  CAPTAIN_INFERENCE_RESOLVE_ACTIVITY_REASON = 'no outstanding questions'.freeze
  CAPTAIN_INFERENCE_HANDOFF_ACTIVITY_REASON = 'pending clarification from customer'.freeze
  # LLM evaluations are deduplicated per conversation: the scheduler fires every
  # few minutes, but each pending conversation is evaluated at most once per
  # cooldown window. Without this the sweep issues an API call per conversation
  # per run — the dominant OpenRouter consumer in production.
  EVALUATION_COOLDOWN = 24.hours
  PROVIDER_FAILURE_PATTERN =
    /api error|provider|timeout|unavailable|indisponível|credit|quota|billing|rate.?limit|insufficient|more tokens|\b402\b|\b429\b|\b5\d\d\b/i

  queue_as :low

  def perform(inbox)
    return if inbox.account.captain_auto_resolve_disabled?

    if evaluate_conversation_completion?(inbox.account)
      perform_with_evaluation(inbox)
    else
      perform_time_based(inbox)
    end
  ensure
    Current.reset
  end

  private

  def evaluate_conversation_completion?(account)
    account.feature_enabled?('captain_tasks') && account.captain_auto_resolve_evaluated?
  end

  def perform_time_based(inbox)
    Current.executed_by = inbox.captain_assistant

    resolvable_pending_conversations(inbox).each do |conversation|
      create_resolution_message(conversation, inbox)
      conversation.resolved!
    end
  end

  def perform_with_evaluation(inbox)
    Current.executed_by = inbox.captain_assistant

    resolvable_pending_conversations(inbox).each do |conversation|
      next if recently_evaluated?(conversation)

      # Marked before the call so a persistent failure also exits the loop —
      # otherwise every sweep retries the same conversation indefinitely.
      mark_evaluated!(conversation)
      evaluation = evaluate_conversation(conversation, inbox)
      next unless still_resolvable_after_evaluation?(conversation)

      act_on_evaluation(conversation, inbox, evaluation)
    rescue StandardError => e
      # A bad conversation must not abort the whole batch or leave the remaining
      # ones unevaluated until the next sweep.
      Rails.logger.error("[CaptainResolution] conversation #{conversation.id}: #{e.class} #{e.message}")
      ::ChusteRMExceptionTracker.new(e, account: inbox.account).capture_exception
    end
  end

  def act_on_evaluation(conversation, inbox, evaluation)
    if evaluation[:complete]
      resolve_conversation(conversation, inbox, evaluation[:reason])
    elsif provider_failure?(evaluation) || auto_handoff_on_incomplete?(inbox)
      handoff_conversation(conversation, inbox, evaluation[:reason])
    else
      recommend_human_review(conversation, inbox, evaluation[:reason])
    end
  end

  def evaluate_conversation(conversation, inbox)
    Captain::ConversationCompletionService.new(
      account: inbox.account,
      conversation_display_id: conversation.display_id
    ).perform
  end

  def resolvable_pending_conversations(inbox)
    inbox.conversations.pending
         .where('last_activity_at < ?', auto_resolve_cutoff_time)
         .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  def still_resolvable_after_evaluation?(conversation)
    conversation.reload
    conversation.pending? && conversation.last_activity_at < auto_resolve_cutoff_time
  rescue ActiveRecord::RecordNotFound
    false
  end

  def auto_resolve_cutoff_time
    Time.now.utc - 1.hour
  end

  def resolve_conversation(conversation, inbox, reason)
    create_private_note(conversation, inbox, "Auto-resolved: #{reason}")
    create_resolution_message(conversation, inbox)
    conversation.with_captain_activity_context(
      reason: CAPTAIN_INFERENCE_RESOLVE_ACTIVITY_REASON,
      reason_type: :inference
    ) { conversation.resolved! }
    conversation.dispatch_captain_inference_resolved_event
  end

  def handoff_conversation(conversation, inbox, reason)
    create_private_note(conversation, inbox, "Auto-handoff: #{reason}")
    create_handoff_message(conversation, inbox)
    conversation.with_captain_activity_context(
      reason: CAPTAIN_INFERENCE_HANDOFF_ACTIVITY_REASON,
      reason_type: :inference
    ) { conversation.bot_handoff! }
    conversation.dispatch_captain_inference_handoff_event
    send_out_of_office_message_if_applicable(conversation.reload)
  end

  def recommend_human_review(conversation, inbox, reason)
    note = "Revisão recomendada: #{reason}"
    create_private_note(conversation, inbox, note) unless recent_private_note?(conversation, note)

    state = CaptainConversationState.for_conversation!(conversation)
    payload = state.score_payload.to_h.merge(
      'review_recommended' => true,
      'review_reason' => reason,
      'automatic_handoff' => false
    )
    state.update!(score_payload: payload)
  end

  def auto_handoff_on_incomplete?(inbox)
    ActiveModel::Type::Boolean.new.cast(
      inbox.captain_inbox&.routing_config&.dig('auto_handoff_on_pending_timeout')
    )
  end

  def recently_evaluated?(conversation)
    evaluated_at = conversation.captain_conversation_state&.score_payload&.dig('last_evaluated_at')
    return false if evaluated_at.blank?

    Time.zone.parse(evaluated_at.to_s) > EVALUATION_COOLDOWN.ago
  rescue ArgumentError, TypeError
    false
  end

  def mark_evaluated!(conversation)
    state = CaptainConversationState.for_conversation!(conversation)
    state.update!(score_payload: state.score_payload.to_h.merge('last_evaluated_at' => Time.current.iso8601))
  end

  def provider_failure?(evaluation)
    return true if evaluation[:provider_error] == true

    evaluation[:reason].to_s.match?(PROVIDER_FAILURE_PATTERN)
  end

  def recent_private_note?(conversation, content)
    conversation.messages.where(private: true, content: content).exists?(['created_at > ?', 24.hours.ago])
  end

  def send_out_of_office_message_if_applicable(conversation)
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def create_private_note(conversation, inbox, content)
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: inbox.captain_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: content
    )
  end

  def create_resolution_message(conversation, inbox)
    I18n.with_locale(inbox.account.locale) do
      resolution_message = inbox.captain_assistant.config['resolution_message']
      conversation.messages.create!(
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        content: resolution_message.presence || I18n.t('conversations.activity.auto_resolution_message'),
        sender: inbox.captain_assistant
      )
    end
  end

  def create_handoff_message(conversation, inbox)
    handoff_message = inbox.captain_assistant.config['handoff_message']
    return if handoff_message.blank?

    conversation.messages.create!(
      message_type: :outgoing,
      sender: inbox.captain_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: handoff_message,
      preserve_waiting_since: true
    )
  end
end

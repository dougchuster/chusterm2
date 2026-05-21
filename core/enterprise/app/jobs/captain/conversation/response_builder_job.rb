class Captain::Conversation::ResponseBuilderJob < ApplicationJob
  MAX_MESSAGE_LENGTH = 10_000
  MEDIA_UNDERSTANDING_RETRY_WAIT = 3.seconds
  MAX_MEDIA_UNDERSTANDING_WAIT_ATTEMPTS = 20
  DEFAULT_RESPONSE_MAX_WAIT_SECONDS = 45
  RESPONSE_GENERATION_LOCK_TTL = 90.seconds
  retry_on ActiveStorage::FileNotFoundError, attempts: 3, wait: 2.seconds
  retry_on Faraday::BadRequestError, attempts: 3, wait: 2.seconds

  def perform(conversation, assistant, media_wait_attempt = 0, scheduled_after_incoming_id = nil, burst_started_at = nil)
    @conversation = conversation
    @inbox = conversation.inbox
    @assistant = assistant
    @media_wait_attempt = media_wait_attempt.to_i
    @scheduled_after_incoming_id = scheduled_after_incoming_id
    @burst_started_at = normalize_time(burst_started_at)

    return unless conversation_pending?
    ensure_captain_state!
    return if ai_response_paused?
    return unless latest_public_message_needs_ai_response?
    return if wait_for_debounce_window?
    return if wait_for_pending_media_understanding?
    return unless acquire_response_generation_lock

    begin
      Captain::FlowRouter.new(conversation: @conversation).route! if @conversation.captain_conversation_state.nil? || @conversation.captain_conversation_state.captain_flow_id.blank?

      runtime = Captain::FlowRuntime.new(conversation: @conversation)
      if runtime.active?
        return execute_flow_step(runtime)
      end

      Current.executed_by = @assistant

      if captain_v2_enabled?
        generate_response_with_v2
      else
        generate_and_process_response
      end
    ensure
      release_response_generation_lock
    end
  rescue ActiveStorage::FileNotFoundError, Faraday::BadRequestError => e
    handle_error(e)
    raise e
  rescue StandardError => e
    handle_error(e)
  ensure
    Current.executed_by = nil
  end

  private

  delegate :account, :inbox, to: :@conversation

  def execute_flow_step(runtime)
    last_incoming = @conversation.messages.where(message_type: :incoming).last
    result = runtime.step(incoming_message: last_incoming&.content)

    case result[:action]
    when :send_message
      create_outgoing_message(result[:text]) if result[:text].present?
      account.increment_response_usage
    when :handoff
      I18n.with_locale(@assistant.account.locale) do
        create_handoff_message
        @conversation.bot_handoff!
        send_out_of_office_message_if_applicable
      end
    when :flow_complete, :no_action
      nil
    end
  end

  def generate_and_process_response
    @response = if deterministic_triage_enabled?
                  deterministic_triage_response
                else
                  Captain::Llm::AssistantChatService.new(assistant: @assistant, conversation: @conversation).generate_response(
                    message_history: collect_previous_messages
                  )
                end
    process_response
  end

  def generate_response_with_v2
    @response = if deterministic_triage_enabled?
                  deterministic_triage_response
                else
                  Captain::Assistant::AgentRunnerService.new(assistant: @assistant, conversation: @conversation).generate_response(
                    message_history: collect_previous_messages
                  )
                end
    process_response
  end

  def process_response
    return unless conversation_pending?

    if handoff_requested?
      process_action('handoff')
    else
      ActiveRecord::Base.transaction do
        create_messages
        Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Incrementing response usage for #{account.id}")
        account.increment_response_usage
      end
      schedule_followup_if_unhandled_messages
    end
  end

  def collect_previous_messages
    messages = @conversation
      .messages
      .where(message_type: [:incoming, :outgoing])
      .where(private: false)
      .to_a

    # Snapshot the highest incoming ID present at context-collection time.
    # Stored on the outgoing AI message so latest_public_message_needs_ai_response?
    # can detect messages that arrived during LLM generation (lower ID, but not in context).
    @last_context_incoming_id = messages
      .select { |m| m.message_type == 'incoming' }
      .map(&:id)
      .max

    messages.map do |message|
      message_hash = {
        content: prepare_multimodal_message_content(message),
        role: determine_role(message)
      }

      message_hash[:agent_name] = message.additional_attributes['agent_name'] if message.additional_attributes&.dig('agent_name').present?

      message_hash
    end
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'user' : 'assistant'
  end

  def prepare_multimodal_message_content(message)
    Captain::OpenAiMessageBuilderService.new(message: message).generate_content
  end

  def handoff_requested?
    @response['response'] == 'conversation_handoff'
  end

  def process_action(action)
    case action
    when 'handoff'
      I18n.with_locale(@assistant.account.locale) do
        mark_ai_handoff!
        create_crm_handoff_private_note
        create_handoff_message
        @conversation.bot_handoff!
        send_out_of_office_message_if_applicable
      end
    end
  end

  def send_out_of_office_message_if_applicable
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if @conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(@conversation)
  end

  def create_handoff_message
    create_outgoing_message(
      @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff')
    )
  end

  def create_crm_handoff_private_note
    return unless defined?(Captain::CrmHandoffSummaryBuilder)
    return if recent_crm_handoff_note_exists?

    @conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: @assistant,
      account: @conversation.account,
      inbox: @conversation.inbox,
      content: Captain::CrmHandoffSummaryBuilder.new(
        @conversation,
        reason: @response&.dig('reasoning')
      ).perform
    )
  rescue StandardError => e
    Rails.logger.warn "[CAPTAIN][ResponseBuilderJob] CRM handoff note failed: #{e.class} - #{e.message}"
    ChusteRMExceptionTracker.new(e, account: account).capture_exception
  end

  def recent_crm_handoff_note_exists?
    @conversation.messages
                 .where(private: true, sender: @assistant)
                 .where('created_at > ?', 5.minutes.ago)
                 .where('content LIKE ?', 'Handoff para atendimento humano%')
                 .exists?
  end

  def create_messages
    validate_message_content!(@response['response'])
    create_outgoing_message(
      @response['response'],
      agent_name: @response['agent_name'],
      context_incoming_id: @last_context_incoming_id
    )
  end

  def validate_message_content!(content)
    raise ArgumentError, 'Message content cannot be blank' if content.blank?
  end

  def create_outgoing_message(message_content, agent_name: nil, context_incoming_id: nil)
    message_content = response_policy.apply(message_content)
    validate_message_content!(message_content)

    additional_attrs = {}
    additional_attrs[:agent_name] = agent_name if agent_name.present?
    # Records the last incoming message ID that was in context when this response was generated.
    # Used by latest_public_message_needs_ai_response? to handle messages that arrived during LLM generation.
    additional_attrs[:context_latest_incoming_id] = context_incoming_id if context_incoming_id.present?

    message = @conversation.messages.create!(
      message_type: :outgoing,
      account_id: account.id,
      inbox_id: inbox.id,
      sender: @assistant,
      content: message_content,
      additional_attributes: additional_attrs
    )
    mark_last_ai_message!(message)
    message
  end

  def schedule_followup_if_unhandled_messages
    return unless @last_context_incoming_id
    return unless conversation_pending?

    unhandled = @conversation.messages
      .where(message_type: :incoming, private: false)
      .where('id > ?', @last_context_incoming_id)
      .exists?

    if unhandled
      Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Unhandled incoming messages after LLM generation, scheduling follow-up for conversation #{@conversation.id}")
      schedule_response_for_latest_incoming
    end
  end

  def wait_for_pending_media_understanding?
    pending_attachments = pending_media_attachments_for_ai_response
    return false if pending_attachments.blank?

    if @media_wait_attempt >= MAX_MEDIA_UNDERSTANDING_WAIT_ATTEMPTS
      Rails.logger.info(
        "[CAPTAIN][ResponseBuilderJob] Media still pending after #{@media_wait_attempt} attempts; continuing conversation #{@conversation.id}"
      )
      return false
    end

    Rails.logger.info(
      "[CAPTAIN][ResponseBuilderJob] Waiting for media context on conversation #{@conversation.id}; " \
      "attachments=#{pending_attachments.map(&:id).join(',')} attempt=#{@media_wait_attempt + 1}"
    )
    Captain::Conversation::ResponseBuilderJob
      .set(wait: MEDIA_UNDERSTANDING_RETRY_WAIT)
      .perform_later(@conversation, @assistant, @media_wait_attempt + 1, @scheduled_after_incoming_id, @burst_started_at)
    true
  end

  def pending_media_attachments_for_ai_response
    incoming_messages_requiring_response.flat_map(&:attachments).select do |attachment|
      attachment_pending_for_ai_context?(attachment)
    end
  end

  def incoming_messages_requiring_response
    latest_incoming = @conversation.messages
                                   .where(message_type: :incoming)
                                   .where(private: false)
                                   .reorder(id: :desc)
                                   .first
    return [] if latest_incoming.blank?

    last_ai_message = @conversation.messages
                                   .where(sender_type: 'Captain::Assistant')
                                   .reorder(id: :desc)
                                   .first
    return [latest_incoming] if last_ai_message.blank?

    last_handled_id = last_ai_message.additional_attributes&.dig('context_latest_incoming_id')&.to_i
    reference_id = last_handled_id.presence || last_ai_message.id

    @conversation.messages
                 .where(message_type: :incoming, private: false)
                 .where('id > ?', reference_id)
                 .includes(:attachments)
                 .to_a
  end

  def attachment_pending_for_ai_context?(attachment)
    return audio_pending_for_ai_context?(attachment) if attachment.audio?
    return media_pending_for_ai_context?(attachment) if attachment.image? || attachment.file?

    false
  end

  def audio_pending_for_ai_context?(attachment)
    return false if attachment.meta&.dig('transcribed_text').present?
    return false unless account.audio_transcriptions.present? && Llm::MediaConfig.transcription_configured?

    true
  end

  def media_pending_for_ai_context?(attachment)
    return false unless Llm::GeminiMultimodalService.active?(purpose: :media)
    return false if attachment.meta&.dig('image_description').present? || attachment.meta&.dig('ocr_text').present?

    status = attachment.meta&.dig('media_understanding_status')
    status.blank? || status == 'processing'
  end

  def handle_error(error)
    log_error(error)
    process_action('handoff') if conversation_pending?
    true
  end

  def log_error(error)
    ::ChusteRMExceptionTracker.new(error, account: account).capture_exception
  end

  def captain_v2_enabled?
    return false if ActiveModel::Type::Boolean.new.cast(@assistant.config['force_legacy_chat'])

    account.feature_enabled?('captain_integration_v2')
  end

  def deterministic_triage_enabled?
    ActiveModel::Type::Boolean.new.cast(@assistant.config['deterministic_triage'])
  end

  def deterministic_triage_response
    collect_previous_messages
    latest_message = latest_public_incoming_message&.content.to_s.strip
    normalized = ActiveSupport::Inflector.transliterate(latest_message).downcase

    response_text = if greeting_message?(normalized)
                      'Boa tarde! Aqui é a Dra. Paula Matos, advogada previdenciária. Para eu entender melhor, qual é o seu objetivo no INSS hoje?'
                    elsif normalized.include?('planejamento') || normalized.include?('como funciona')
                      'O planejamento previdenciário serve para conferir seu histórico no INSS antes de qualquer decisão, identificar erros no CNIS e avaliar o melhor momento para pedir o benefício. Para começarmos, me diga sua idade.'
                    elsif normalized.include?('nao sei') || normalized.include?('nao tenho certeza')
                      'Sem problema. Vamos por partes. Primeiro, me diga sua idade.'
                    else
                      'Entendi. Vou organizar sua triagem com cuidado. Primeiro, me diga qual benefício ou objetivo você quer avaliar no INSS.'
                    end

    {
      'response' => response_text,
      'reasoning' => 'Resposta determinística de triagem previdenciária para evitar fallback genérico quando o provedor LLM está indisponível.'
    }
  end

  def greeting_message?(normalized)
    normalized.match?(/\A(oi|ola|bom dia|boa tarde|boa noite|tudo bem|opa)[\s!.?]*\z/)
  end

  def ai_response_paused?
    @conversation.captain_conversation_state&.human_controlled?
  end

  def ensure_captain_state!
    state = @conversation.captain_conversation_state || CaptainConversationState.for_conversation!(@conversation)
    state.captain_assistant ||= @assistant
    state.ai_mode = inbox.captain_inbox.ai_mode if inbox.captain_inbox&.ai_mode.present? && state.ai_mode.blank?
    state.save! if state.new_record? || state.changed?
  end

  def mark_last_ai_message!(message)
    ensure_captain_state!
    @conversation.captain_conversation_state.update!(
      captain_assistant: @assistant,
      last_ai_message_at: message.created_at || Time.current
    )
  end

  def mark_ai_handoff!
    state = @conversation.captain_conversation_state || CaptainConversationState.for_conversation!(@conversation)
    state.apply_ai_mode!(
      mode: 'human_only',
      reason: @response&.dig('reasoning').presence || 'Handoff solicitado pela IA',
      actor: nil
    )
  end

  def conversation_pending?
    status = Conversation.uncached { Conversation.where(id: @conversation.id).pick(:status) }
    status == 'pending' || status == Conversation.statuses[:pending]
  end

  def latest_public_message_needs_ai_response?
    latest_incoming = latest_public_incoming_message

    return false unless latest_incoming

    last_ai_message = @conversation.messages
                                   .where(sender_type: 'Captain::Assistant')
                                   .reorder(id: :desc)
                                   .first
    return true if last_ai_message.nil?

    # When a message arrives during LLM generation it gets an ID lower than the AI response
    # but was NOT included in the context. Use the snapshotted context ID when available
    # so those messages are correctly identified as needing a response.
    last_handled_id = last_ai_message.additional_attributes&.dig('context_latest_incoming_id')&.to_i
    reference_id = last_handled_id.present? ? last_handled_id : last_ai_message.id

    latest_incoming.id > reference_id
  end

  def wait_for_debounce_window?
    delay_seconds = response_delay_seconds
    return false unless delay_seconds.positive?

    latest_incoming = latest_public_incoming_message
    return false unless latest_incoming

    burst_started_at = @burst_started_at || latest_incoming.created_at
    return false if Time.current - burst_started_at >= response_max_wait_seconds

    elapsed_since_latest = Time.current - latest_incoming.created_at
    return false if elapsed_since_latest >= delay_seconds

    wait_seconds = [(delay_seconds - elapsed_since_latest).ceil, 1].max
    Rails.logger.info(
      "[CAPTAIN][ResponseBuilderJob] Debouncing response for conversation #{@conversation.id}; " \
      "wait=#{wait_seconds}s latest_incoming_id=#{latest_incoming.id}"
    )
    schedule_response(wait_seconds, latest_incoming.id, burst_started_at)
    true
  end

  def latest_public_incoming_message
    @conversation.messages
                 .where(message_type: :incoming)
                 .where(private: false)
                 .reorder(id: :desc)
                 .first
  end

  def schedule_response_for_latest_incoming
    latest_incoming = latest_public_incoming_message
    schedule_response(response_delay_seconds, latest_incoming&.id, Time.current)
  end

  def schedule_response(wait_seconds, latest_incoming_id, burst_started_at)
    job = Captain::Conversation::ResponseBuilderJob
    job = job.set(wait: wait_seconds.seconds) if wait_seconds.to_i.positive?
    job.perform_later(@conversation, @assistant, 0, latest_incoming_id, burst_started_at)
  end

  def response_delay_seconds
    @inbox.captain_inbox&.routing_config&.dig('response_delay_seconds').to_i.clamp(0, 120)
  end

  def response_max_wait_seconds
    configured = @inbox.captain_inbox&.routing_config&.dig('response_max_wait_seconds').to_i
    configured = DEFAULT_RESPONSE_MAX_WAIT_SECONDS unless configured.positive?
    [configured, response_delay_seconds].max
  end

  def response_policy
    @response_policy ||= Captain::Conversation::ResponsePolicyService.new(
      conversation: @conversation,
      assistant: @assistant
    )
  end

  def acquire_response_generation_lock
    Redis::Alfred.set(response_generation_lock_key, true, nx: true, ex: RESPONSE_GENERATION_LOCK_TTL.to_i).tap do |locked|
      Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Response already being generated for conversation #{@conversation.id}") unless locked
    end
  end

  def release_response_generation_lock
    Redis::Alfred.delete(response_generation_lock_key)
  end

  def response_generation_lock_key
    "captain:response_builder:conversation:#{@conversation.id}"
  end

  def normalize_time(value)
    return value if value.respond_to?(:to_time)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end

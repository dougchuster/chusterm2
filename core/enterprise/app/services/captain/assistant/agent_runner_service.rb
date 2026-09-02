require 'agents'
require 'agents/instrumentation'
require 'json'
require 'timeout'

class Captain::Assistant::AgentRunnerService
  include Integrations::LlmInstrumentationConstants
  include Captain::Assistant::RunnerCallbacksHelper
  include Captain::Assistant::TracePayloadHelper

  MALFORMED_OUTPUT_FALLBACK =
    'Tive uma dificuldade para concluir a resposta. Pode repetir em uma frase o que você precisa saber agora?'.freeze
  HANGUL_PATTERN = /[\u1100-\u11FF\u3130-\u318F\uA960-\uA97F\uAC00-\uD7AF\uD7B0-\uD7FF]/
  META_OUTPUT_PATTERN = /
    correct\s+format\s+needed |
    response[_\s-]*format |
    (?:json|response|output)\s+schema |
    schema\s+(?:validation\s+)?(?:error|failed|failure|invalid) |
    (?:invalid|incorrect|malformed|expected)\s+(?:json|schema|format|response|output) |
    (?:erro|falha)\s+(?:de|do|no|na|em)\s+(?:json|schema|esquema|formato) |
    (?:schema|esquema|formato)\s+(?:invalido|incorreto)
  /ix
  RAW_STRUCTURED_OUTPUT_PATTERN = /
    ``` |
    \A\s*[\{\[] |
    \{\s*["']?[a-z_][\w-]*["']?\s*: |
    ["'](?:response|reasoning|error)["']\s*:
  /ix
  CREDENTIAL_ASSIGNMENT_PATTERN = /
    \b(?:minha\s+)?(?:senha(?:\s+(?:do\s+)?meu\s+inss|\s+banc[aá]ria)?|pin|token|
    c[oó]digo\s+(?:de\s+)?(?:acesso|autentica[cç][aã]o|verifica[cç][aã]o))
    \s*(?:(?:[eé]|eh|igual\s+a)\s+|[:=-]\s*|\s+)
    ["']?.*?
    (?=
      \s+e\s+(?:j[aá]|tamb[eé]m|tenho|possuo|enviei|encaminhei|anexei|meu|minha)(?=\s|\z) |
      [,;!?] |
      \.(?=\s|\z) |
      \n |
      \z
    )
  /imx
  PROMPT_INJECTION_PATTERN = /
    \b(?:ignore|desconsidere|esqueca)\b.{0,100}\b(?:instrucoes|regras|orientacoes|contexto)\b |
    \b(?:revele|mostre|exiba|repita|imprima)\b.{0,80}
      \b(?:prompt|instrucoes\s+(?:internas|do\s+sistema)|metadados?|schema|chain\s+of\s+thought)\b |
    \b(?:diga|afirme|finja|aja|responda)\b.{0,100}
      \b(?:capitao|a\s+propria\s+dra\.?\s+paula|como\s+(?:a\s+)?dra\.?\s+paula)\b
  /ix
  PROMPT_INJECTION_SAFE_RESPONSE = <<~TEXT.squish.freeze
    Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.
    Posso ajudar com seu atendimento previdenciário. Conte, em uma frase, o que você precisa resolver.
  TEXT
  CREDENTIAL_SAFETY_RESPONSE = <<~TEXT.squish.freeze
    Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.
    Por segurança, mantenha senhas, tokens e códigos de acesso em sigilo e não os compartilhe por aqui.
    Qual é o seu objetivo previdenciário?
  TEXT

  CONVERSATION_STATE_ATTRIBUTES = %i[
    id display_id inbox_id contact_id status priority
    label_list custom_attributes additional_attributes
  ].freeze

  CONTACT_STATE_ATTRIBUTES = %i[
    id name email phone_number identifier contact_type relationship_status
    lifecycle_stage crm_owner_id
    custom_attributes additional_attributes
  ].freeze

  CONTACT_INBOX_STATE_ATTRIBUTES = %i[id hmac_verified].freeze

  CAMPAIGN_STATE_ATTRIBUTES = %i[id title message campaign_type description].freeze
  ERROR_CATEGORY_PATTERNS = {
    insufficient_credit: /\b402\b|payment required|insufficient (?:credit|balance)|(?:credit|balance).*(?:low|depleted)/,
    authentication: /\b401\b|unauthoriz|invalid api key|authentication/,
    rate_limit: /\b429\b|rate.?limit|too many requests/,
    timeout: /timeout|timed out|execution expired/,
    model_unavailable: /model.*(?:not found|unavailable)|no endpoints found|\b404\b/,
    provider_error: /\b(?:500|502|503|504)\b|provider error|upstream/,
    schema: /schema|structured output|json/
  }.freeze
  PREVIDENCIARIO_INITIAL_RESPONSE_FLAG = 'feature_previdenciario_initial_responses'.freeze
  LEGAL_INTAKE_PROFILE_KEY = 'dra_leticia_intake'.freeze
  LEGACY_LEGAL_INTAKE_ASSISTANT_NAMES = ['Dra. Letícia', 'Dra. Paula Matos'].freeze
  CANONICAL_INTAKE_IDENTITY =
    'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.'.freeze
  INITIAL_DRA_LETICIA_PRESENTATION_PATTERN = /
    \A\s*(?:ol[aá]\s*[!,.?]\s*)?
    (?:
      sou\s+a\s+dra\.?\s+let[ií]cia\b
      [\s\S]{0,240}?
      (?:\bdra\.?\s+paula\s+matos\b[.!?]?|[.!?](?=\s|\z))
      |
      dra\.?\s+let[ií]cia\s+aqui[.!?]?
    )
    \s*
  /ix
  MAX_AGENT_TURNS = 3
  SHORT_CONTEXTUAL_ACQUISITION_FOLLOWUP_PATTERN = /
    \A\s*(?:como|onde)\s+(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|consult\w*)
    \s*(?:isso|esse|essa|o|a|documento)?[?!.\s]*\z
  /x

  def initialize(assistant:, conversation: nil, callbacks: {}, source: nil)
    @assistant = assistant
    @conversation = conversation
    @callbacks = callbacks
    @source = source
  end

  def generate_response(message_history: [])
    message_to_process, context = run_payload(message_history)
    return deterministic_credential_safety_payload if credential_redacted_in_current_burst?
    return deterministic_prompt_injection_payload if prompt_injection_attempt?
    return deterministic_handoff_payload if explicit_human_handoff_requested?

    initial_response = standardized_initial_response
    return deterministic_initial_response_payload(initial_response) if initial_response.present?

    timeout_seconds = @assistant.llm_config_with_defaults[:timeout_seconds]
    result = Timeout.timeout(timeout_seconds) do
      runner.run(message_to_process, context: context, max_turns: MAX_AGENT_TURNS)
    end

    process_agent_result(result)
  rescue StandardError => e
    # In rake/local runs, conversation may not be present, so account is optional here.
    ::ChusteRMExceptionTracker.new(e, account: @conversation&.account).capture_exception
    Rails.logger.error "[Captain V2] AgentRunnerService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    error_response(e.message)
  end

  private

  def build_context(message_history)
    conversation_history = message_history.map do |msg|
      content = msg[:content]
      # Preserve multimodal arrays (with image_url entries) as-is for the runner to restore with attachments.
      # Only extract text from non-array formats (hashes from agent structured output, plain strings).
      content = extract_text_from_content(content) unless content.is_a?(Array)
      content = sanitize_message_content(content)

      {
        role: msg[:role].to_sym,
        content: content,
        agent_name: msg[:agent_name]
      }
    end

    {
      session_id: "#{@assistant.account_id}_#{@conversation&.display_id}",
      conversation_history: conversation_history,
      state: build_state
    }
  end

  def extract_last_user_message(message_history)
    last_user_msg = message_history.reverse.find { |msg| msg[:role] == 'user' }
    return '' if last_user_msg.blank?

    content = last_user_msg[:content]
    return sanitize_message_content(extract_text_from_content(content)) unless content.is_a?(Array)

    text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(content)
    text = redact_credential_assignments(text)
    return text if attachments.blank?

    RubyLLM::Content.new(text, attachments)
  end

  def message_history_without_last_user_message(message_history)
    last_user_index = message_history.rindex { |msg| msg[:role] == 'user' }
    return message_history if last_user_index.nil?

    message_history.reject.with_index { |_msg, index| index == last_user_index }
  end

  def extract_text_from_content(content)
    # Handle structured output from agents
    return content[:response] || content['response'] || content.to_s if content.is_a?(Hash)

    return content unless content.is_a?(Array)

    text_parts = content.select { |part| part[:type] == 'text' }.pluck(:text)
    text_parts.join(' ')
  end

  def sanitize_message_content(content)
    return redact_credential_assignments(content.to_s) unless content.is_a?(Array)

    content.map do |part|
      next part unless (part[:type] || part['type']) == 'text'

      sanitized = part.deep_dup
      if sanitized.key?(:text)
        sanitized[:text] = redact_credential_assignments(sanitized[:text].to_s)
      elsif sanitized.key?('text')
        sanitized['text'] = redact_credential_assignments(sanitized['text'].to_s)
      end
      sanitized
    end
  end

  def redact_credential_assignments(text)
    text.to_s
        .gsub(CREDENTIAL_ASSIGNMENT_PATTERN, '[credencial omitida]')
        .gsub(/\[credencial omitida\]\s*\.(?=\s|\z)/i, '[credencial omitida]')
  end

  def process_agent_result(result)
    error = result.respond_to?(:error) ? result.error : nil
    output_class = result.respond_to?(:output) ? result.output.class.name : 'unknown'
    Rails.logger.info(
      "[Captain V2] Agent completed error=#{error.present?} output_class=#{output_class}"
    )

    if error.present?
      Rails.logger.warn "[Captain V2] Agent returned error: #{error.message}"
      return recoverable_error_response(error.message)
    end

    output = result.output
    response = normalize_agent_output(output)
    return malformed_output_response if response.blank?

    response = enforce_first_turn_intake_identity(response)
    response['agent_name'] = result.context&.dig(:current_agent)
    response['response_origin'] = 'model'
    response
  end

  def enforce_first_turn_intake_identity(response)
    public_text = response['response'].to_s
    return response unless legal_intake_profile? && first_customer_turn?
    return response if public_text == 'conversation_handoff' || complete_intake_identity?(public_text)

    response_body = public_text.sub(INITIAL_DRA_LETICIA_PRESENTATION_PATTERN, '').strip
    response['response'] = [CANONICAL_INTAKE_IDENTITY, response_body].compact_blank.join(' ')
    response
  end

  def complete_intake_identity?(text)
    canonical_identity = CANONICAL_INTAKE_IDENTITY.delete_prefix('Olá! ')
    normalize_identity_text(text).include?(normalize_identity_text(canonical_identity))
  end

  def normalize_identity_text(text)
    I18n.transliterate(text.to_s).downcase.squish
  end

  def deterministic_initial_response_payload(initial_response)
    Rails.logger.info '[Captain V2] Using deterministic initial intake template'
    {
      'response' => initial_response,
      'reasoning' => 'Generated from the approved deterministic initial intake template',
      'response_origin' => 'deterministic_initial_template'
    }
  end

  def deterministic_prompt_injection_payload
    Rails.logger.info '[Captain V2] Applying deterministic prompt injection guard'
    {
      'response' => PROMPT_INJECTION_SAFE_RESPONSE,
      'reasoning' => 'Explicit prompt injection blocked by deterministic security policy',
      'response_origin' => 'deterministic_prompt_injection_guard'
    }
  end

  def deterministic_credential_safety_payload
    Rails.logger.info '[Captain V2] Applying deterministic credential safety response'
    {
      'response' => CREDENTIAL_SAFETY_RESPONSE,
      'reasoning' => 'Credential was redacted and handled by deterministic security policy',
      'response_origin' => 'deterministic_credential_safety'
    }
  end

  def deterministic_handoff_payload
    Rails.logger.info '[Captain V2] Honoring deterministic explicit human handoff request'
    {
      'response' => 'conversation_handoff',
      'reasoning' => 'Explicit human handoff request confirmed by deterministic policy',
      'response_origin' => 'deterministic_handoff'
    }
  end

  def normalize_agent_output(output)
    response = if output.is_a?(Hash)
                 output.with_indifferent_access
               else
                 response_from_string(output.to_s)
               end
    return if response.blank?

    public_text = response['response'].to_s.strip
    return if unsafe_public_output?(public_text)

    response['response'] = public_text
    response
  end

  def response_from_string(output)
    text = output.to_s.strip
    return if text.blank?

    payload, structured_output = extract_structured_payload(text)
    return payload if payload.present?
    return if structured_output || unsafe_public_output?(text)

    { 'response' => text, 'reasoning' => 'Processed by agent' }
  end

  def extract_structured_payload(text)
    parsed_json = false

    json_candidates(text).each do |candidate|
      parsed = JSON.parse(candidate)
      parsed_json = true
      next unless parsed.is_a?(Hash)

      payload = parsed.with_indifferent_access
      return [payload, true] if payload.key?('response')
    rescue JSON::ParserError, TypeError
      next
    end

    [nil, parsed_json || structured_output_like?(text)]
  end

  def json_candidates(text)
    candidates = [text.strip]
    candidates.concat(text.scan(/```(?:json)?\s*(.*?)\s*```/im).flatten)
    candidates.concat(embedded_json_objects(text))
    candidates.map(&:strip).reject(&:blank?).uniq
  end

  # Balanced JSON extraction is intentionally stateful: it must ignore escaped
  # quotes and nested braces without exposing malformed provider output.
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def embedded_json_objects(text)
    objects = []
    start_index = nil
    depth = 0
    in_string = false
    escaped = false

    text.each_char.with_index do |character, index|
      if start_index.nil?
        next unless character == '{'

        start_index = index
        depth = 1
        next
      end

      if in_string
        if escaped
          escaped = false
        elsif character == '\\'
          escaped = true
        elsif character == '"'
          in_string = false
        end
        next
      end

      case character
      when '"'
        in_string = true
      when '{'
        depth += 1
      when '}'
        depth -= 1
        next unless depth.zero?

        objects << text[start_index..index]
        start_index = nil
      end
    end

    objects
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def structured_output_like?(text)
    text.match?(RAW_STRUCTURED_OUTPUT_PATTERN)
  end

  def unsafe_public_output?(text)
    return true if text.blank?
    return true unless text.match?(/[[:alnum:]]/)
    return true if text.match?(HANGUL_PATTERN)
    return true if I18n.transliterate(text).match?(META_OUTPUT_PATTERN)

    structured_output_like?(text)
  end

  def malformed_output_response
    {
      'response' => contextual_initial_response || MALFORMED_OUTPUT_FALLBACK,
      'reasoning' => 'Recovered from malformed or unsafe agent output',
      'response_origin' => 'malformed_fallback',
      'ai_error_category' => 'malformed_output'
    }
  end

  def error_response(error_message)
    {
      'response' => contextual_initial_response || MALFORMED_OUTPUT_FALLBACK,
      'reasoning' => "Recovered from runner error: #{error_message}",
      'response_origin' => 'runner_fallback',
      'ai_error_category' => error_category(error_message)
    }
  end

  def recoverable_error_response(error_message)
    {
      'response' => concise_recoverable_response_message,
      'reasoning' => "Recovered from agent error: #{error_message}",
      'response_origin' => 'provider_fallback',
      'ai_error_category' => error_category(error_message)
    }
  end

  def error_category(error_message)
    normalized = I18n.transliterate(error_message.to_s).downcase
    category = ERROR_CATEGORY_PATTERNS.find { |_name, pattern| normalized.match?(pattern) }&.first
    category&.to_s || 'unknown'
  end

  def concise_recoverable_response_message
    contextual_initial_response || @assistant.config['fallback_message'].presence ||
      'Recebi sua mensagem, mas tive uma dificuldade para concluir a resposta. Pode resumir em uma frase como posso ajudar?'
  end

  def contextual_initial_response
    return unless previdenciario_initial_responses_enabled?
    return unless first_customer_turn?

    return @assistant.config['welcome_message'] if initial_message_response_service.greeting_only? &&
                                                   @assistant.config['welcome_message'].present?

    initial_message_response_service.perform
  rescue StandardError => e
    Rails.logger.warn "[Captain V2] Contextual fallback failed: #{e.class} - #{e.message}"
    nil
  end

  def standardized_initial_response
    return unless previdenciario_initial_responses_enabled?

    contextual_response = deterministic_contextual_followup_response
    return contextual_response if contextual_response.present?
    return initial_message_response_service.perform if initial_message_response_service.other_lawyer_request?

    deterministic_first_turn_response
  end

  def deterministic_first_turn_response
    return unless first_customer_turn?
    return if initial_message_response_service.material_case_details?

    return @assistant.config['welcome_message'].presence if initial_message_response_service.greeting_only?

    return unless initial_message_response_service.previdenciario_intent?

    initial_message_response_service.perform
  end

  def explicit_human_handoff_requested?
    message = @initial_customer_burst_text.presence || @latest_user_message_text
    Captain::Conversation::HumanHandoffRequestService.requested?(message)
  end

  def credential_redacted_in_current_burst?
    @initial_customer_burst_text.to_s.include?('[credencial omitida]')
  end

  def prompt_injection_attempt?
    normalized_initial_customer_burst.match?(PROMPT_INJECTION_PATTERN)
  end

  def deterministic_contextual_followup_response
    latest = normalized_initial_customer_burst
    policy = Captain::Conversation::ResponsePolicyService

    return policy::CNIS_ACQUISITION_RESPONSE if contextual_acquisition_followup?(latest) && recent_history_mentions_cnis?
    return unless latest.match?(policy::THANKS_PATTERN) && recent_assistant_history_mentions_cnis_guidance?

    policy::GUIDANCE_ACKNOWLEDGEMENT_RESPONSE
  end

  def contextual_acquisition_followup?(latest)
    policy_pattern = Captain::Conversation::ResponsePolicyService::CONTEXTUAL_ACQUISITION_FOLLOWUP_PATTERN
    latest.match?(policy_pattern) || latest.match?(SHORT_CONTEXTUAL_ACQUISITION_FOLLOWUP_PATTERN)
  end

  def normalized_initial_customer_burst
    I18n.transliterate(@initial_customer_burst_text.to_s).downcase
  end

  def recent_history_mentions_cnis?
    prior_customer_burst_history.last(8).any? { |message| normalized_history_content(message).match?(/\bcnis\b/) }
  end

  def recent_assistant_history_mentions_cnis_guidance?
    prior_customer_burst_history
      .select { |message| message[:role].to_s == 'assistant' }
      .last(4)
      .any? { |message| normalized_history_content(message).match?(/\b(?:meu inss|cnis)\b/) }
  end

  def prior_customer_burst_history
    return @prior_customer_burst_history if defined?(@prior_customer_burst_history)

    reversed_history = @current_message_history.to_a.reverse
    @prior_customer_burst_history = reversed_history.drop_while { |message| message[:role].to_s == 'user' }.reverse
  end

  def normalized_history_content(message)
    content = extract_text_from_content(message[:content])
    I18n.transliterate(content.to_s).downcase
  end

  def initial_message_response_service
    @initial_message_response_service ||= Captain::Assistant::InitialMessageResponseService.new(
      message: @initial_customer_burst_text.presence || @latest_user_message_text,
      identity_disclosure: @assistant.config['intake_identity_disclosure'],
      new_lead: new_lead_contact?
    )
  end

  def first_customer_turn?
    history_has_captain_response = @current_message_history.to_a.any? do |message|
      message[:role].to_s == 'assistant' && message[:agent_name].present?
    end
    return false if history_has_captain_response

    return !@conversation.messages.exists?(sender_type: 'Captain::Assistant', private: false) if @conversation

    true
  end

  def previdenciario_initial_responses_enabled?
    return false unless legal_intake_profile?

    ActiveModel::Type::Boolean.new.cast(
      @assistant.config[PREVIDENCIARIO_INITIAL_RESPONSE_FLAG]
    )
  end

  def legal_intake_profile?
    @assistant.config['profile_key'] == LEGAL_INTAKE_PROFILE_KEY ||
      @assistant.name.in?(LEGACY_LEGAL_INTAKE_ASSISTANT_NAMES)
  end

  def new_lead_contact?
    return true if @conversation.blank? || @conversation.contact.blank?

    Crm::ContactRelationshipClassifier.new(@conversation.contact).perform[:status] == 'lead'
  end

  def build_state
    state = {
      account_id: @assistant.account_id,
      assistant_id: @assistant.id,
      assistant_config: @assistant.config
    }
    state[:source] = @source if @source.present?

    build_conversation_state(state) if @conversation
    state
  end

  def build_conversation_state(state)
    state[:conversation] = slice_attrs(@conversation, CONVERSATION_STATE_ATTRIBUTES)
    state[:channel_type] = @conversation.inbox&.channel_type
    state[:contact] = slice_attrs(@conversation.contact, CONTACT_STATE_ATTRIBUTES) if @conversation.contact
    state[:campaign] = slice_attrs(@conversation.campaign, CAMPAIGN_STATE_ATTRIBUTES) if @conversation.campaign
    state[:contact_inbox] = slice_attrs(@conversation.contact_inbox, CONTACT_INBOX_STATE_ATTRIBUTES) if @conversation.contact_inbox
    state[:crm_context] = Captain::CrmContextBuilder.new(@conversation).perform
  end

  def slice_attrs(record, keys)
    record.attributes.symbolize_keys.slice(*keys)
  end

  def build_and_wire_agents
    assistant_agent = @assistant.agent
    scenario_agents = @assistant.scenarios.enabled.map(&:agent)

    assistant_agent.register_handoffs(*scenario_agents) if scenario_agents.any?
    scenario_agents.each { |scenario_agent| scenario_agent.register_handoffs(assistant_agent) }

    [assistant_agent] + scenario_agents
  end

  def install_instrumentation(runner)
    return unless ChusteRMApp.otel_enabled?

    Agents::Instrumentation.install(
      runner,
      tracer: OpentelemetryConfig.tracer,
      trace_name: 'llm.captain_v2',
      span_attributes: {
        ATTR_LANGFUSE_TAGS => ['captain_v2'].to_json
      },
      attribute_provider: ->(context_wrapper) { dynamic_trace_attributes(context_wrapper) }
    )
    register_trace_input_callback(runner)
  end

  def dynamic_trace_attributes(context_wrapper)
    state = context_wrapper&.context&.dig(:state) || {}
    conversation = state[:conversation] || {}
    trace_input = context_wrapper&.context&.dig(:captain_v2_trace_input)

    {
      ATTR_LANGFUSE_USER_ID => state[:account_id],
      format(ATTR_LANGFUSE_METADATA, 'assistant_id') => state[:assistant_id],
      format(ATTR_LANGFUSE_METADATA, 'conversation_id') => conversation[:id],
      format(ATTR_LANGFUSE_METADATA, 'conversation_display_id') => conversation[:display_id],
      format(ATTR_LANGFUSE_METADATA, 'channel_type') => state[:channel_type],
      format(ATTR_LANGFUSE_METADATA, 'source') => state[:source],
      ATTR_LANGFUSE_TRACE_INPUT => trace_input,
      ATTR_LANGFUSE_OBSERVATION_INPUT => trace_input
    }.compact.transform_values(&:to_s)
  end

  def add_usage_metadata_callback(runner)
    return runner unless ChusteRMApp.otel_enabled?

    handoff_tool_name = Captain::Tools::HandoffTool.new(@assistant).name

    runner.on_tool_complete do |tool_name, _tool_result, context_wrapper|
      track_handoff_usage(tool_name, handoff_tool_name, context_wrapper)
    end

    runner.on_run_complete do |_agent_name, _result, context_wrapper|
      write_credits_used_metadata(context_wrapper)
    end
    runner
  end

  def track_handoff_usage(tool_name, handoff_tool_name, context_wrapper)
    return unless context_wrapper&.context
    return unless tool_name.to_s == handoff_tool_name

    context_wrapper.context[:captain_v2_handoff_tool_called] = true
  end

  def write_credits_used_metadata(context_wrapper)
    root_span = context_wrapper&.context&.dig(:__otel_tracing, :root_span)
    return unless root_span

    credit_used = !context_wrapper.context[:captain_v2_handoff_tool_called]
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'credit_used'), credit_used.to_s)
  end

  def runner
    @runner ||= begin
      configured_runner = Agents::Runner.with_agents(*build_and_wire_agents)
      max_tokens = @assistant.llm_config_with_defaults[:max_tokens]
      configured_runner.on_chat_created do |chat, _agent_name, _model, _context_wrapper|
        chat.with_params(max_tokens: max_tokens)
      end
      configured_runner = add_usage_metadata_callback(configured_runner)
      configured_runner = add_callbacks_to_runner(configured_runner) if @callbacks.any?
      install_instrumentation(configured_runner)
      configured_runner
    end
  end

  def run_payload(message_history)
    sanitized_history = message_history.map do |message|
      message.merge(content: sanitize_message_content(message[:content]))
    end
    @current_message_history = sanitized_history
    @initial_customer_burst_text = current_customer_burst_text(sanitized_history)
    message_to_process = extract_last_user_message(sanitized_history)
    @latest_user_message_text = if message_to_process.respond_to?(:text)
                                  message_to_process.text.to_s
                                else
                                  message_to_process.to_s
                                end
    context = build_context(message_history_without_last_user_message(sanitized_history))
    enrich_context_with_trace_payload!(context, sanitized_history, message_to_process)
    [message_to_process, context]
  end

  def current_customer_burst_text(message_history)
    burst = message_history.reverse.take_while { |message| message[:role].to_s == 'user' }.reverse
    burst.filter_map do |message|
      content = message[:content]
      text = if content.is_a?(Array)
               extracted_text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(content)
               attachment_marker = 'Cliente enviou um anexo.' if attachments.present?
               [extracted_text, attachment_marker].compact_blank.join(' ')
             else
               extract_text_from_content(content)
             end
      sanitized = redact_credential_assignments(text.to_s).strip
      sanitized.presence
    end.join("\n")
  end
end

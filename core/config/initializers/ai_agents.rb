# frozen_string_literal: true

require 'agents'

# Allow arbitrary OpenAI-compatible model IDs (for example `provider/model` on
# OpenRouter) across all RubyLLM callers, including the Agents gem internals.
module RubyLLMModelsResolvePatch
  def resolve(model_id, provider: nil, assume_exists: false, config: nil)
    if provider.nil? && openai_compatible_gemini_model?(model_id, config)
      return super(model_id, provider: :openai, assume_exists: true, config: config)
    end

    if provider.nil? && anthropic_model?(model_id)
      return super(model_id, provider: :anthropic, assume_exists: true, config: config)
    end

    super
  rescue RubyLLM::ModelNotFoundError
    if provider.nil? && anthropic_model?(model_id)
      return super(model_id, provider: :anthropic, assume_exists: true, config: config)
    end

    # If model is unknown and no provider was forced, retry as an OpenAI-compatible
    # model id so gateways like OpenRouter can route custom model names.
    raise unless provider.nil? && model_id.to_s.include?('/')

    super(model_id, provider: :openai, assume_exists: true, config: config)
  end

  private

  def openai_compatible_gemini_model?(model_id, config)
    return false unless model_id.to_s.start_with?('gemini-')

    endpoint = if config&.respond_to?(:openai_api_base)
                 config.openai_api_base
               elsif defined?(InstallationConfig)
                 InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
               end

    endpoint.to_s.include?('generativelanguage.googleapis.com') && endpoint.to_s.include?('/openai/')
  rescue StandardError
    false
  end

  def anthropic_model?(model_id)
    model_id.to_s.start_with?('claude-')
  end
end

RubyLLM::Models.singleton_class.prepend(RubyLLMModelsResolvePatch)

# RubyLLM may receive a raw JSON string body from some OpenAI-compatible gateways
# (for example specific OpenRouter model/provider combinations). Normalize this
# shape before delegating to the default parser logic.
module RubyLLMOpenAIChatResponsePatch
  def parse_completion_response(response)
    data = response.body
    return if data.empty?

    if data.is_a?(String)
      begin
        data = JSON.parse(data)
      rescue JSON::ParserError
        # Keep original behavior when body is not valid JSON.
      end
    end

    read_key = lambda do |hash, key|
      hash[key] || hash[key.to_sym]
    end

    read_nested = lambda do |hash, *keys|
      keys.reduce(hash) do |acc, key|
        break nil unless acc.is_a?(Hash)

        read_key.call(acc, key)
      end
    end

    error_message = read_nested.call(data, 'error', 'message') if data.is_a?(Hash)
    raise RubyLLM::Error.new(response, error_message) if error_message.present?

    choices = read_key.call(data, 'choices') if data.is_a?(Hash)
    message_data = choices&.first&.then { |choice| read_key.call(choice, 'message') }
    return unless message_data

    usage = read_key.call(data, 'usage') || {}
    prompt_token_details = read_key.call(usage, 'prompt_tokens_details') || {}
    cached_tokens = read_key.call(prompt_token_details, 'cached_tokens')

    RubyLLM::Message.new(
      role: :assistant,
      content: read_key.call(message_data, 'content'),
      tool_calls: parse_tool_calls(read_key.call(message_data, 'tool_calls')),
      input_tokens: read_key.call(usage, 'prompt_tokens'),
      output_tokens: read_key.call(usage, 'completion_tokens'),
      cached_tokens: cached_tokens,
      cache_creation_tokens: 0,
      model_id: read_key.call(data, 'model'),
      raw: response
    )
  end
end

RubyLLM::Providers::OpenAI::Chat.prepend(RubyLLMOpenAIChatResponsePatch)

# Most OpenRouter-hosted models don't support the strict json_schema response_format
# that RubyLLM sends when a response schema is set. Fall back to json_object format,
# which is broadly supported, whenever the model id uses the provider/model notation.
module RubyLLMOpenAIJsonObjectPatch
  def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil)
    if schema && model.id.to_s.include?('/')
      payload = super(messages, tools: tools, temperature: temperature, model: model, stream: stream, schema: nil)
      payload[:response_format] = { type: 'json_object' }
      return payload
    end
    super
  end
end

RubyLLM::Providers::OpenAI::Chat.prepend(RubyLLMOpenAIJsonObjectPatch)

Rails.application.config.after_initialize do
  api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  anthropic_api_key = InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_API_KEY')&.value
  model = Llm::Config.resolve_model(InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value)
  api_endpoint = Llm::Config.normalize_endpoint(
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
  )

  if api_key.present? || anthropic_api_key.present?
    Agents.configure do |config|
      config.openai_api_key = api_key if api_key.present?
      config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present?
      if api_endpoint.present? && api_key.present?
        config.openai_api_base = api_endpoint
      end
      config.default_model = model
      config.debug = false
    end
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end

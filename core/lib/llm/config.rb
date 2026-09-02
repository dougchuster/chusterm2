require 'ruby_llm'
require 'uri'

module Llm::Config
  DEFAULT_MODEL = LlmConstants::DEFAULT_MODEL.freeze
  class GatewayConfigurationError < StandardError; end

  class << self
    def normalize_endpoint(endpoint)
      value = endpoint.to_s.strip
      return LlmConstants::OPENROUTER_API_ENDPOINT if value.blank?

      normalized = value.gsub(%r{/+$}, '')
      normalized = LlmConstants::OPENROUTER_API_ENDPOINT if normalized.blank?
      "#{normalized}/"
    end

    def normalize_model(model)
      value = model.to_s.strip
      return LlmConstants::DEFAULT_MODEL if value.blank?

      value
    end

    def supported_model?(model)
      normalize_model(model).present?
    end

    def resolve_model(model)
      value = normalize_model(model)
      return "anthropic/#{value}" if value.start_with?('claude-')
      return "google/#{value}" if value.start_with?('gemini-')
      return "openai/#{value}" if value.match?(/\A(?:gpt-|o[134]-|text-embedding-|whisper-)/)

      value
    end

    def anthropic_model?(model)
      resolve_model(model).start_with?('anthropic/claude-')
    end

    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key.presence || system_api_key
        config.openai_api_base = normalize_endpoint(api_base.presence || openai_endpoint)
      end

      yield context
    end

    def system_api_key
      ENV.fetch('LLM_API_KEY', nil).presence || InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      endpoint = normalize_endpoint(configured_endpoint)
      return endpoint if openrouter?(endpoint)

      raise GatewayConfigurationError, 'LLM_BASE_URL must point to the unified OpenRouter gateway'
    end

    def openrouter?(endpoint = nil)
      candidate = endpoint.presence || configured_endpoint
      URI.parse(normalize_endpoint(candidate)).host == 'openrouter.ai'
    rescue URI::InvalidURIError
      false
    end

    def chat_for(client:, model:)
      normalized_model = resolve_model(model)
      client.chat(model: normalized_model, provider: :openai, assume_model_exists: true)
    end

    private

    def configured_endpoint
      ENV.fetch('LLM_BASE_URL', nil).presence ||
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence ||
        LlmConstants::OPENROUTER_API_ENDPOINT
    end

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = normalize_endpoint(openai_endpoint) if openai_endpoint.present?
        config.logger = Rails.logger
      end
    end
  end
end

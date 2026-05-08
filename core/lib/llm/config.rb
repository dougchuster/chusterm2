require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def normalize_endpoint(endpoint)
      value = endpoint.to_s.strip
      return LlmConstants::OPENAI_API_ENDPOINT if value.blank?

      normalized = value.gsub(%r{/+$}, '')
      normalized = LlmConstants::OPENAI_API_ENDPOINT if normalized.blank?
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
      normalize_model(model)
    end

    def openai_compatible_gemini_model?(model, api_base: nil)
      return false unless normalize_model(model).start_with?('gemini-')

      endpoint = normalize_endpoint(api_base.presence || openai_endpoint)
      endpoint.include?('generativelanguage.googleapis.com') && endpoint.include?('/openai/')
    end

    def anthropic_model?(model)
      normalize_model(model).start_with?('claude-')
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
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    def chat_for(client:, model:)
      normalized_model = normalize_model(model)
      if openai_compatible_gemini_model?(normalized_model)
        return client.chat(model: normalized_model, provider: :openai, assume_model_exists: true)
      end

      if anthropic_model?(normalized_model)
        return client.chat(model: normalized_model, provider: :anthropic, assume_model_exists: true)
      end

      client.chat(model: normalized_model)
    rescue RubyLLM::ModelNotFoundError
      if anthropic_model?(normalized_model)
        return client.chat(model: normalized_model, provider: :anthropic, assume_model_exists: true)
      end

      # Allow arbitrary OpenAI-compatible model IDs (for example provider/model on OpenRouter).
      client.chat(model: normalized_model, provider: :openai, assume_model_exists: true)
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = normalize_endpoint(openai_endpoint) if openai_endpoint.present?
        config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present?
        config.logger = Rails.logger
      end
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def anthropic_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end

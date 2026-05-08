class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  def initialize(account_id: nil)
    Llm::Config.initialize!
    @account_id = account_id
    @embedding_config = self.class.embedding_config
    @embedding_model = @embedding_config[:model]
  end

  def self.embedding_model
    embedding_config[:model]
  end

  def self.embedding_config
    explicit_model = config_value('CAPTAIN_EMBEDDING_MODEL')
    explicit_endpoint = config_value('CAPTAIN_EMBEDDING_ENDPOINT')

    if gemini_embedding_configured?(explicit_model, explicit_endpoint)
      {
        provider: :gemini,
        model: explicit_model.presence || LlmConstants::DEFAULT_GEMINI_EMBEDDING_MODEL,
        api_key: gemini_embedding_api_key,
        api_base: gemini_native_endpoint(explicit_endpoint.presence || Llm::MediaConfig.media_endpoint),
        dimensions: LlmConstants::DEFAULT_EMBEDDING_DIMENSIONS
      }
    else
      {
        provider: :openai,
        model: explicit_model.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL,
        api_key: config_value('CAPTAIN_EMBEDDING_API_KEY').presence || config_value('CAPTAIN_OPEN_AI_API_KEY'),
        api_base: explicit_endpoint.presence || non_gemini_chat_endpoint,
        dimensions: LlmConstants::DEFAULT_EMBEDDING_DIMENSIONS
      }
    end
  end

  def get_embedding(content, model: @embedding_model)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content, model)) do
      embedding_context.embed(
        content,
        model: model,
        provider: @embedding_config[:provider],
        assume_model_exists: true,
        dimensions: @embedding_config[:dimensions]
      ).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def instrumentation_params(content, model)
    {
      span_name: 'llm.captain.embedding',
      model: model,
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end

  def embedding_context
    RubyLLM.context do |config|
      case @embedding_config[:provider]
      when :gemini
        config.gemini_api_key = @embedding_config[:api_key]
        config.gemini_api_base = @embedding_config[:api_base] if @embedding_config[:api_base].present?
      when :openai
        config.openai_api_key = @embedding_config[:api_key]
        config.openai_api_base = Llm::Config.normalize_endpoint(@embedding_config[:api_base]) if @embedding_config[:api_base].present?
      end
    end
  end

  class << self
    private

    def gemini_embedding_configured?(model, endpoint)
      gemini_model?(model) ||
        Llm::MediaConfig.media_gemini? ||
        gemini_endpoint?(endpoint) ||
        gemini_endpoint?(config_value('CAPTAIN_OPEN_AI_ENDPOINT'))
    end

    def gemini_embedding_api_key
      config_value('CAPTAIN_EMBEDDING_API_KEY').presence ||
        Llm::MediaConfig.media_api_key ||
        config_value('CAPTAIN_OPEN_AI_API_KEY')
    end

    def gemini_native_endpoint(endpoint)
      value = endpoint.to_s.strip
      value = 'https://generativelanguage.googleapis.com/v1beta' if value.blank?
      value = value.sub(%r{/openai/?\z}, '')
      value = value.sub(%r{/?\z}, '/v1beta') if gemini_endpoint?(value) && !value.include?('/v1beta')
      Llm::Config.normalize_endpoint(value)
    end

    def non_gemini_chat_endpoint
      endpoint = config_value('CAPTAIN_OPEN_AI_ENDPOINT')
      return if gemini_endpoint?(endpoint)

      endpoint.presence
    end

    def gemini_model?(model)
      model.to_s.start_with?('gemini-', 'embedding-', 'text-embedding-004')
    end

    def gemini_endpoint?(endpoint)
      endpoint.to_s.include?('generativelanguage.googleapis.com')
    end

    def config_value(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end

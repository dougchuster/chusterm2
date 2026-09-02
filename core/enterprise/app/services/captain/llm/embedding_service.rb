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

    {
      provider: :openai,
      model: Llm::Config.resolve_model(explicit_model.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL),
      api_key: Llm::Config.system_api_key,
      api_base: Llm::Config.openai_endpoint,
      dimensions: LlmConstants::DEFAULT_EMBEDDING_DIMENSIONS
    }
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
      config.openai_api_key = @embedding_config[:api_key]
      config.openai_api_base = Llm::Config.normalize_endpoint(@embedding_config[:api_base]) if @embedding_config[:api_base].present?
    end
  end

  class << self
    private

    def config_value(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end

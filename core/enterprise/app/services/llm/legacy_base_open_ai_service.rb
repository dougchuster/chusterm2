# frozen_string_literal: true

# Compatibility wrapper around an OpenAI-format client. The key and endpoint
# always come from the installation-wide OpenRouter gateway.
class Llm::LegacyBaseOpenAiService
  DEFAULT_MODEL = LlmConstants::DEFAULT_MODEL

  attr_reader :client, :model

  def initialize
    @client = OpenAI::Client.new(
      access_token: Llm::Config.system_api_key,
      uri_base: uri_base,
      log_errors: Rails.env.development?
    )
    setup_model
  rescue StandardError => e
    raise "Failed to initialize OpenAI client: #{e.message}"
  end

  private

  # Strips markdown code fences (```json ... ``` or ``` ... ```) that some
  # LLM providers/gateways wrap around JSON responses despite response_format hints.
  def sanitize_json_response(response)
    return response if response.nil?

    response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end

  def uri_base
    Llm::Config.normalize_endpoint(Llm::Config.openai_endpoint)
  end

  def setup_model
    config_value = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
    @model = Llm::Config.resolve_model(config_value.presence || DEFAULT_MODEL)
  end
end

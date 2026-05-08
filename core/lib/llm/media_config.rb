module Llm::MediaConfig
  GEMINI_ENDPOINT_PATTERN = /generativelanguage\.googleapis\.com/.freeze
  OPENAI_ENDPOINT_PATTERN = /api\.openai\.com/.freeze
  DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash'.freeze
  DEFAULT_TRANSCRIPTION_MODEL = 'whisper-1'.freeze

  class << self
    def media_api_key
      explicit_config_value('CAPTAIN_MEDIA_AI_API_KEY') || gemini_chat_config_value('CAPTAIN_OPEN_AI_API_KEY')
    end

    def media_endpoint
      endpoint = explicit_config_value('CAPTAIN_MEDIA_AI_ENDPOINT') || gemini_chat_config_value('CAPTAIN_OPEN_AI_ENDPOINT')
      normalize_endpoint(endpoint)
    end

    def media_model
      explicit_config_value('CAPTAIN_MEDIA_AI_MODEL') ||
        (media_gemini? ? gemini_chat_config_value('CAPTAIN_OPEN_AI_MODEL') : nil) ||
        DEFAULT_GEMINI_MODEL
    end

    def transcription_api_key
      explicit_config_value('CAPTAIN_AUDIO_TRANSCRIPTION_API_KEY') ||
        explicit_config_value('CAPTAIN_MEDIA_AI_API_KEY') ||
        compatible_chat_config_value('CAPTAIN_OPEN_AI_API_KEY')
    end

    def transcription_endpoint
      endpoint = explicit_config_value('CAPTAIN_AUDIO_TRANSCRIPTION_ENDPOINT') ||
                 explicit_config_value('CAPTAIN_MEDIA_AI_ENDPOINT') ||
                 compatible_chat_config_value('CAPTAIN_OPEN_AI_ENDPOINT')
      normalize_endpoint(endpoint)
    end

    def transcription_model
      explicit_config_value('CAPTAIN_AUDIO_TRANSCRIPTION_MODEL') ||
        (transcription_gemini? ? media_model : DEFAULT_TRANSCRIPTION_MODEL)
    end

    def media_gemini?
      media_api_key.present? && gemini_endpoint?(media_endpoint)
    end

    def transcription_gemini?
      transcription_api_key.present? && gemini_endpoint?(transcription_endpoint)
    end

    def transcription_openai?
      transcription_api_key.present? && !gemini_endpoint?(transcription_endpoint)
    end

    def transcription_configured?
      transcription_gemini? || transcription_openai?
    end

    def normalize_endpoint(endpoint)
      return nil if endpoint.blank?

      Llm::Config.normalize_endpoint(endpoint)
    end

    def normalize_model(model)
      Llm::Config.normalize_model(model)
    end

    def gemini_endpoint?(endpoint)
      endpoint.to_s.match?(GEMINI_ENDPOINT_PATTERN)
    end

    private

    def compatible_chat_config_value(name)
      endpoint = Llm::Config.normalize_endpoint(config_value('CAPTAIN_OPEN_AI_ENDPOINT').presence || LlmConstants::OPENAI_API_ENDPOINT)
      return unless gemini_endpoint?(endpoint) || endpoint.match?(OPENAI_ENDPOINT_PATTERN)

      config_value(name)
    end

    def gemini_chat_config_value(name)
      endpoint = Llm::Config.normalize_endpoint(config_value('CAPTAIN_OPEN_AI_ENDPOINT'))
      return unless gemini_endpoint?(endpoint)

      config_value(name)
    end

    def explicit_config_value(name)
      value = config_value(name)
      value.presence
    end

    def config_value(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end

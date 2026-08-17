module Llm::MediaConfig
  DEFAULT_MEDIA_MODEL = 'google/gemini-3.7-flash'.freeze
  DEFAULT_TRANSCRIPTION_MODEL = 'openai/gpt-4o-transcribe'.freeze

  class << self
    def media_api_key
      Llm::Config.system_api_key
    end

    def media_endpoint
      Llm::Config.normalize_endpoint(Llm::Config.openai_endpoint)
    end

    def media_model
      config_value('CAPTAIN_MEDIA_AI_MODEL').presence || DEFAULT_MEDIA_MODEL
    end

    def transcription_api_key
      Llm::Config.system_api_key
    end

    def transcription_endpoint
      media_endpoint
    end

    def transcription_model
      config_value('CAPTAIN_AUDIO_TRANSCRIPTION_MODEL').presence || DEFAULT_TRANSCRIPTION_MODEL
    end

    def media_openrouter?
      media_api_key.present? && Llm::Config.openrouter?(media_endpoint)
    end

    def transcription_openrouter?
      transcription_api_key.present? && Llm::Config.openrouter?(transcription_endpoint)
    end

    def media_configured?
      media_openrouter? && media_model.present?
    end

    def transcription_configured?
      transcription_openrouter? && transcription_model.present?
    end

    def normalize_endpoint(endpoint)
      Llm::Config.normalize_endpoint(endpoint)
    end

    def normalize_model(model)
      Llm::Config.resolve_model(model)
    end

    private

    def config_value(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end

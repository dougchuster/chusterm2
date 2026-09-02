# frozen_string_literal: true

module LlmConstants
  DEFAULT_MODEL = 'anthropic/claude-sonnet-5'
  DEFAULT_EMBEDDING_MODEL = 'openai/text-embedding-3-small'
  DEFAULT_EMBEDDING_DIMENSIONS = 1536
  PDF_PROCESSING_MODEL = 'google/gemini-2.5-flash'

  OPENROUTER_API_ENDPOINT = 'https://openrouter.ai/api/v1'
  # Compatibility alias for code that still uses the historical constant name.
  OPENAI_API_ENDPOINT = OPENROUTER_API_ENDPOINT

  PROVIDER_PREFIXES = {
    'openai' => %w[gpt- o1 o3 o4 text-embedding- whisper- tts-],
    'anthropic' => %w[claude-],
    'google' => %w[gemini-],
    'mistral' => %w[mistral- codestral-],
    'deepseek' => %w[deepseek-]
  }.freeze
end

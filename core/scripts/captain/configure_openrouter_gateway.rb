# frozen_string_literal: true

OPENROUTER_ENDPOINT = 'https://openrouter.ai/api/v1'
CONFIG_VALUES = {
  'CAPTAIN_OPEN_AI_MODEL' => 'anthropic/claude-sonnet-5',
  'CAPTAIN_OPEN_AI_ENDPOINT' => OPENROUTER_ENDPOINT,
  'CAPTAIN_MEDIA_AI_MODEL' => 'google/gemini-3.7-flash',
  'CAPTAIN_MEDIA_AI_FALLBACK_MODELS' => 'anthropic/claude-sonnet-5,google/gemini-2.5-flash',
  'CAPTAIN_AUDIO_TRANSCRIPTION_MODEL' => 'openai/gpt-4o-transcribe',
  'CAPTAIN_AUDIO_TRANSCRIPTION_FALLBACK_MODELS' => 'openai/gpt-4o-mini-transcribe,openai/whisper-large-v3',
  'CAPTAIN_EMBEDDING_MODEL' => 'openai/text-embedding-3-small'
}.freeze
LEGACY_CONFIG_NAMES = %w[
  CAPTAIN_ANTHROPIC_API_KEY
  CAPTAIN_MEDIA_AI_API_KEY
  CAPTAIN_MEDIA_AI_ENDPOINT
  CAPTAIN_AUDIO_TRANSCRIPTION_API_KEY
  CAPTAIN_AUDIO_TRANSCRIPTION_ENDPOINT
  CAPTAIN_EMBEDDING_API_KEY
  CAPTAIN_EMBEDDING_ENDPOINT
].freeze

def normalize_openrouter_model(model)
  value = model.to_s.strip
  return value if value.blank? || value.include?('/')
  return "anthropic/#{value}" if value.start_with?('claude-')
  return "google/#{value}" if value.start_with?('gemini-')
  return "openai/#{value}" if value.match?(/\A(?:gpt-|o[134]-|text-embedding-|whisper-)/)

  value
end

api_key = ENV.fetch('LLM_API_KEY', nil).presence ||
          InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.presence
raise 'LLM_API_KEY/CAPTAIN_OPEN_AI_API_KEY is required' if api_key.blank?

InstallationConfig.where(name: 'CAPTAIN_OPEN_AI_API_KEY').first_or_initialize.tap do |config|
  config.value = api_key
  config.save!
end

CONFIG_VALUES.each do |name, value|
  InstallationConfig.where(name: name).first_or_initialize.tap do |config|
    config.value = value
    config.save!
  end
end

LEGACY_CONFIG_NAMES.each do |name|
  config = InstallationConfig.find_by(name: name)
  config&.update!(value: '')
end

updated_assistants = 0
target_account_id = ENV.fetch('ACCOUNT_ID', 1).to_i
Captain::Assistant.find_each do |assistant|
  next_config = assistant.config.deep_dup
  next_config['llm_provider'] = 'openrouter'
  %w[llm_main_model llm_fallback_model llm_classifier_model llm_summarizer_model].each do |key|
    next_config[key] = normalize_openrouter_model(next_config[key]) if next_config[key].present?
  end
  if assistant.account_id == target_account_id && assistant.name == 'Dra. Paula Matos'
    # O modelo principal do atendimento fica no Sonnet 5 por decisao de qualidade;
    # so o resumidor usa o Gemini Flash, bem mais barato para essa tarefa.
    next_config['llm_main_model'] = 'anthropic/claude-sonnet-5'
    next_config['llm_summarizer_model'] = 'google/gemini-3.7-flash'
  end
  next if next_config == assistant.config

  assistant.update!(config: next_config)
  updated_assistants += 1
end

Llm::Config.reset!
puts 'OPENROUTER_GATEWAY_CONFIGURED=true'
puts "OPENROUTER_ENDPOINT=#{OPENROUTER_ENDPOINT}"
puts "CAPTAIN_MODEL=#{CONFIG_VALUES.fetch('CAPTAIN_OPEN_AI_MODEL')}"
puts "MEDIA_MODEL=#{CONFIG_VALUES.fetch('CAPTAIN_MEDIA_AI_MODEL')}"
puts "TRANSCRIPTION_MODEL=#{CONFIG_VALUES.fetch('CAPTAIN_AUDIO_TRANSCRIPTION_MODEL')}"
puts "EMBEDDING_MODEL=#{CONFIG_VALUES.fetch('CAPTAIN_EMBEDDING_MODEL')}"
puts "ASSISTANTS_UPDATED=#{updated_assistants}"

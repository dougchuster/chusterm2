require 'rails_helper'

RSpec.describe Captain::Llm::EmbeddingService do
  describe '.embedding_config' do
    before do
      InstallationConfig.where(name: %w[
        CAPTAIN_OPEN_AI_API_KEY CAPTAIN_OPEN_AI_ENDPOINT
        CAPTAIN_MEDIA_AI_API_KEY CAPTAIN_MEDIA_AI_ENDPOINT
        CAPTAIN_EMBEDDING_API_KEY CAPTAIN_EMBEDDING_MODEL CAPTAIN_EMBEDDING_ENDPOINT
      ]).delete_all
    end

    it 'uses native Gemini embeddings when the Captain endpoint is Gemini-compatible' do
      InstallationConfig.create!(name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'gemini-key')
      InstallationConfig.create!(name: 'CAPTAIN_OPEN_AI_ENDPOINT', value: 'https://generativelanguage.googleapis.com/v1beta/openai/')

      config = described_class.embedding_config

      expect(config[:provider]).to eq(:gemini)
      expect(config[:model]).to eq('gemini-embedding-001')
      expect(config[:api_key]).to eq('gemini-key')
      expect(config[:api_base]).to eq('https://generativelanguage.googleapis.com/v1beta/')
      expect(config[:dimensions]).to eq(1536)
    end

    it 'allows an explicit OpenAI embedding endpoint' do
      InstallationConfig.create!(name: 'CAPTAIN_EMBEDDING_API_KEY', value: 'openai-key')
      InstallationConfig.create!(name: 'CAPTAIN_EMBEDDING_MODEL', value: 'text-embedding-3-small')
      InstallationConfig.create!(name: 'CAPTAIN_EMBEDDING_ENDPOINT', value: 'https://api.openai.com/')

      config = described_class.embedding_config

      expect(config[:provider]).to eq(:openai)
      expect(config[:model]).to eq('text-embedding-3-small')
      expect(config[:api_key]).to eq('openai-key')
      expect(config[:api_base]).to eq('https://api.openai.com/')
    end
  end
end

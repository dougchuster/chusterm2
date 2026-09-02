require 'rails_helper'

RSpec.describe Captain::Llm::EmbeddingService do
  describe '.embedding_config' do
    before do
      allow(Llm::Config).to receive(:system_api_key).and_return('openrouter-key')
      allow(Llm::Config).to receive(:openai_endpoint).and_return('https://openrouter.ai/api/v1')
    end

    it 'uses the unified OpenRouter gateway' do
      InstallationConfig.where(name: 'CAPTAIN_EMBEDDING_MODEL').first_or_initialize.update!(
        value: 'openai/text-embedding-3-small'
      )

      config = described_class.embedding_config

      expect(config[:provider]).to eq(:openai)
      expect(config[:model]).to eq('openai/text-embedding-3-small')
      expect(config[:api_key]).to eq('openrouter-key')
      expect(config[:api_base]).to eq('https://openrouter.ai/api/v1')
      expect(config[:dimensions]).to eq(1536)
    end

    it 'normalizes legacy unprefixed embedding model names for OpenRouter' do
      InstallationConfig.where(name: 'CAPTAIN_EMBEDDING_MODEL').first_or_initialize.update!(value: 'text-embedding-3-small')

      config = described_class.embedding_config

      expect(config[:model]).to eq('openai/text-embedding-3-small')
    end
  end
end

require 'rails_helper'

RSpec.describe Llm::Config do
  describe '.chat_for' do
    let(:client) { instance_double(RubyLLM::Context) }
    let(:chat) { instance_double(RubyLLM::Chat) }

    it 'routes Claude models through the OpenRouter OpenAI-compatible gateway' do
      expect(client).to receive(:chat)
        .with(model: 'anthropic/claude-sonnet-4-6', provider: :openai, assume_model_exists: true)
        .and_return(chat)

      expect(described_class.chat_for(client: client, model: 'claude-sonnet-4-6')).to eq(chat)
    end

    it 'preserves explicit OpenRouter provider/model slugs' do
      expect(client).to receive(:chat)
        .with(model: 'x-ai/grok-4.5', provider: :openai, assume_model_exists: true)
        .and_return(chat)

      expect(described_class.chat_for(client: client, model: 'x-ai/grok-4.5')).to eq(chat)
    end
  end

  describe '.openai_endpoint' do
    it 'rejects endpoints outside OpenRouter' do
      allow(described_class).to receive(:configured_endpoint).and_return('https://api.openai.com/v1')

      expect { described_class.openai_endpoint }.to raise_error(Llm::Config::GatewayConfigurationError)
    end
  end
end

require 'rails_helper'

RSpec.describe Llm::Config do
  describe '.chat_for' do
    let(:client) { instance_double(RubyLLM::Context) }
    let(:chat) { instance_double(RubyLLM::Chat) }

    around do |example|
      previous_key = RubyLLM.config.anthropic_api_key
      RubyLLM.configure { |config| config.anthropic_api_key = 'test-anthropic-key' }
      example.run
      RubyLLM.configure { |config| config.anthropic_api_key = previous_key }
    end

    it 'routes Claude models directly to Anthropic' do
      expect(client).to receive(:chat)
        .with(model: 'claude-sonnet-4-6', provider: :anthropic, assume_model_exists: true)
        .and_return(chat)

      expect(described_class.chat_for(client: client, model: 'claude-sonnet-4-6')).to eq(chat)
    end

    it 'treats unknown Claude aliases as Anthropic models in RubyLLM resolution' do
      model, provider = RubyLLM::Models.resolve('claude-sonnet-4-6')

      expect(model.id).to eq('claude-sonnet-4-6')
      expect(model.provider).to eq('anthropic')
      expect(provider.slug).to eq('anthropic')
    end
  end
end

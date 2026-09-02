require 'rails_helper'

RSpec.describe Captain::Assistant do
  describe '#agent_tools' do
    let(:assistant) { create(:captain_assistant, config: { 'feature_faq' => feature_faq }) }

    context 'when FAQ is enabled' do
      let(:feature_faq) { true }

      it 'includes the FAQ lookup and handoff tools' do
        tools = assistant.send(:agent_tools)

        expect(tools).to include(an_instance_of(Captain::Tools::FaqLookupTool))
        expect(tools).to include(an_instance_of(Captain::Tools::HandoffTool))
      end
    end

    context 'when FAQ is disabled' do
      let(:feature_faq) { false }

      it 'only includes the handoff tool' do
        tools = assistant.send(:agent_tools)

        expect(tools).to contain_exactly(an_instance_of(Captain::Tools::HandoffTool))
      end
    end
  end

  describe '#prompt_context' do
    it 'keeps the restored professional identity separate from the Gemini model configuration' do
      assistant = create(
        :captain_assistant,
        name: 'Dra. Paula Matos',
        config: {
          'public_identity' => 'Dra. Paula Matos, advogada do escritório Coimbra & Ruas',
          'professional_identity' => true,
          'instructions' => 'Responda em mensagens curtas e colete documentos gradualmente.',
          'llm_provider' => 'openrouter',
          'llm_main_model' => 'google/gemini-3.6-flash',
          'llm_summarizer_model' => 'google/gemini-3.6-flash'
        }
      )

      context = assistant.send(:prompt_context)
      llm_config = assistant.llm_config_with_defaults

      expect(context).to include(
        public_identity: 'Dra. Paula Matos, advogada do escritório Coimbra & Ruas',
        professional_identity: true
      )
      expect(context[:instructions]).to include('mensagens curtas')
      expect(llm_config).to include(
        provider: 'openrouter',
        main_model: 'google/gemini-3.6-flash',
        summarizer_model: 'google/gemini-3.6-flash'
      )
    end
  end
end

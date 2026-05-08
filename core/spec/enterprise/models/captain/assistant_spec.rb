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
end

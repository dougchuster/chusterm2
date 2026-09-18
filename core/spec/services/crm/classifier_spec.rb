require 'rails_helper'

# 3.2 do PLANO_17_09.md — classificação por LLM com taxonomia do pack;
# sem LLM cai nas regras do LegalTriageAnalyzer.
RSpec.describe Crm::Classifier do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def add_incoming(text)
    create(:message, conversation: conversation, account: account,
                     message_type: :incoming, content: text, sender: contact)
  end

  context 'when the LLM is not enabled' do
    it 'cai nas regras do LegalTriageAnalyzer' do
      add_incoming('Preciso de ajuda com meu benefício do INSS que foi negado')

      result = described_class.new(conversation: conversation, account: account).perform

      expect(result[:classified_by]).to eq('rules')
      expect(result[:legal_area]).to eq('previdenciario')
    end
  end

  context 'when the LLM is enabled' do
    let(:chat_double) { instance_double(RubyLLM::Chat) }
    let(:llm_payload) do
      {
        category: 'consulta', subcategory: 'primeira_consulta', urgency_level: 'media',
        intent: 'agendamento', summary: 'Cliente quer marcar consulta.', confidence: 0.9,
        next_best_action: 'Oferecer horários.', intake_answers: []
      }
    end

    before do
      account.enable_features!('captain_tasks', 'crm_universal')
      Crm::PackInstaller.new(account).install('clinic')
      allow(Llm::Config).to receive(:system_api_key).and_return('sk-test')
      add_incoming('Bom dia, quero marcar uma consulta com o dentista')
    end

    def stub_chat(payload)
      allow(Llm::Config).to receive(:with_api_key).and_yield(nil)
      allow(Llm::Config).to receive(:chat_for).and_return(chat_double)
      allow(chat_double).to receive(:with_instructions)
      allow(chat_double).to receive(:with_schema)
      allow(chat_double).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: JSON.generate(payload)))
    end

    it 'classifica dentro da taxonomia do pack' do
      stub_chat(llm_payload)

      result = described_class.new(conversation: conversation, account: account).perform

      expect(result[:classified_by]).to eq('llm')
      expect(result[:legal_area]).to eq('consulta')
      expect(result[:case_type]).to eq('primeira_consulta')
      expect(result[:summary]).to include('consulta')
    end

    it 'rebaixa categoria alucinada para outro' do
      stub_chat(llm_payload.merge(category: 'previdenciario'))

      result = described_class.new(conversation: conversation, account: account).perform

      expect(result[:legal_area]).to eq('outro')
    end

    it 'cai nas regras quando o LLM falha' do
      allow(Llm::Config).to receive(:with_api_key).and_raise(StandardError, 'timeout')

      result = described_class.new(conversation: conversation, account: account).perform

      expect(result[:classified_by]).to eq('rules')
    end

    it 'devolve intake_answers normalizadas' do
      stub_chat(llm_payload.merge(intake_answers: [
                                    { question_key: 'consulta.convenio', answer: 'Unimed' },
                                    { question_key: '', answer: 'x' },
                                    { question_key: 'consulta.horario_preferido', answer: '' }
                                  ]))

      result = described_class.new(conversation: conversation, account: account).perform

      expect(result[:intake_answers]).to eq([{ question_key: 'consulta.convenio', answer: 'Unimed' }])
    end
  end
end

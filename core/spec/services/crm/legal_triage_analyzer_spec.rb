require 'rails_helper'

RSpec.describe Crm::LegalTriageAnalyzer do
  subject(:triage) { described_class.new(conversation: conversation).perform }

  let(:conversation) { create(:conversation) }

  def create_incoming_message(content, *traits)
    create(
      :message,
      *traits,
      conversation: conversation,
      account: conversation.account,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: content,
      message_type: :incoming
    )
  end

  shared_examples 'a document mention without receipt' do |message|
    before { create_incoming_message(message) }

    it 'infers the legal area without treating the document as received' do
      expect(triage).to include(
        legal_area: 'previdenciario',
        documents_status: 'solicitado',
        engagement_level: 'baixo'
      )
    end
  end

  it_behaves_like 'a document mention without receipt', 'uma advogada pediu meu CNIS?'
  it_behaves_like 'a document mention without receipt', 'tenho CNIS'

  context 'when the client explicitly says the CNIS was sent' do
    ['enviei CNIS', 'anexei CNIS'].each do |message|
      it "recognizes '#{message}' as document receipt evidence" do
        create_incoming_message(message)

        expect(triage).to include(
          legal_area: 'previdenciario',
          documents_status: 'parcial',
          engagement_level: 'alto'
        )
      end
    end
  end

  context 'when the incoming message has a real attachment' do
    before { create_incoming_message('tenho CNIS', :with_attachment) }

    it 'recognizes the attachment as document receipt evidence' do
      expect(triage).to include(
        legal_area: 'previdenciario',
        documents_status: 'parcial',
        engagement_level: 'alto'
      )
    end
  end

  context 'when the client writes with accents' do
    {
      'quero pensão alimentícia, a guarda ficou comigo' => 'familia',
      'meu cartão foi negativado pelo banco' => 'consumidor',
      'preciso de indenização por dano moral no imóvel' => 'civel',
      'houve prisão em flagrante e audiência de custódia' => 'criminal',
      'fui demitido e a rescisão não pagou FGTS' => 'trabalhista',
      'meu benefício do INSS foi negado após perícia' => 'previdenciario',
      'recebi notificação de dívida ativa da Receita Federal' => 'tributario'
    }.each do |message, expected_area|
      it "detects '#{expected_area}' from accented text" do
        create_incoming_message(message)

        expect(triage[:legal_area]).to eq(expected_area)
      end
    end

    it 'detects urgency from accented text' do
      create_incoming_message('recebi uma intimação com prazo final para amanhã')

      expect(triage[:urgency_level]).to eq('critica')
    end

    it 'detects hiring intent from accented text' do
      create_incoming_message('quero contratar um advogado para entrar com ação')

      expect(triage[:intent]).to eq('contratacao')
    end
  end

  context 'when the client sends an audio message with transcription' do
    let(:message) { create_incoming_message(nil, :with_attachment) }

    before do
      message.attachments.first.update!(
        meta: { 'transcribed_text' => 'quero revisar minha aposentadoria do INSS que foi negada' }
      )
    end

    it 'uses the transcription for triage' do
      expect(triage[:legal_area]).to eq('previdenciario')
    end
  end

  context 'when the client sends a document with OCR text' do
    let(:message) { create_incoming_message(nil, :with_attachment) }

    before do
      message.attachments.first.update!(
        meta: { 'ocr_text' => 'decisão de guarda e pensão alimentícia' }
      )
    end

    it 'uses the OCR text for triage' do
      expect(triage[:legal_area]).to eq('familia')
    end
  end
end

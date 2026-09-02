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
end

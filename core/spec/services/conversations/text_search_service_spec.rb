require 'rails_helper'

RSpec.describe Conversations::TextSearchService do
  subject(:search_results) { described_class.new(scope, query).perform }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:scope) { account.conversations }

  describe '#perform' do
    context 'when the query matches conversation metadata' do
      let!(:identifier_match) do
        create(:conversation, account: account, inbox: inbox, identifier: 'legal-case-raven')
      end
      let!(:subject_match) do
        create(
          :conversation,
          account: account,
          inbox: inbox,
          additional_attributes: { 'mail_subject' => 'Revisão previdenciária urgente' }
        )
      end

      before do
        identifier_match.update!(display_id: 987_654)
      end

      it 'searches display id, identifier and email subject' do
        expect(described_class.new(scope, '987654').perform).to contain_exactly(identifier_match)
        expect(described_class.new(scope, 'case-raven').perform).to contain_exactly(identifier_match)
        expect(described_class.new(scope, 'previdenciária urgente').perform).to contain_exactly(subject_match)
      end
    end

    context 'when the query matches contact data' do
      let(:contact) do
        create(
          :contact,
          account: account,
          name: 'Helena Pesquisa Jurídica',
          email: 'helena.search@example.com',
          phone_number: '+5561987654321',
          identifier: 'client-raven-987'
        )
      end
      let!(:contact_match) { create(:conversation, account: account, inbox: inbox, contact: contact) }

      it 'searches name, email, phone number and identifier' do
        expect(described_class.new(scope, 'Pesquisa Jurídica').perform).to contain_exactly(contact_match)
        expect(described_class.new(scope, 'helena.search').perform).to contain_exactly(contact_match)
        expect(described_class.new(scope, '61987654321').perform).to contain_exactly(contact_match)
        expect(described_class.new(scope, 'raven-987').perform).to contain_exactly(contact_match)
      end
    end

    context 'when more than one message in the conversation matches' do
      let(:query) { 'benefício exclusivo' }
      let!(:message_match) { create(:conversation, account: account, inbox: inbox) }

      before do
        create(:message, account: account, conversation: message_match, content: "Dúvida sobre #{query}", message_type: :incoming)
        create(:message, account: account, conversation: message_match, content: "Retorno do #{query}", message_type: :outgoing)
      end

      it 'returns the conversation only once' do
        expect(search_results).to contain_exactly(message_match)
      end
    end

    context 'when the query contains LIKE wildcard characters' do
      let(:query) { '%_confirmada' }
      let!(:literal_match) { create(:conversation, account: account, inbox: inbox) }
      let!(:unrelated_conversation) { create(:conversation, account: account, inbox: inbox) }

      before do
        create(:message, account: account, conversation: literal_match, content: 'A taxa está 100%_confirmada')
        create(:message, account: account, conversation: unrelated_conversation, content: 'Texto sem os caracteres pesquisados')
      end

      it 'treats wildcard characters as literal text' do
        expect(search_results).to contain_exactly(literal_match)
      end
    end

    context 'when the query is blank' do
      let(:query) { '  ' }
      let!(:conversation) { create(:conversation, account: account, inbox: inbox) }

      it 'keeps the original scope' do
        expect(search_results).to contain_exactly(conversation)
      end
    end

    context 'when the query is too short for a broad text search' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, display_id: 42) }

      it 'allows an exact short display id without running a broad search' do
        expect(described_class.new(scope, '42').perform).to contain_exactly(conversation)
        expect(described_class.new(scope, 'x').perform).to be_empty
      end
    end

    context 'when the query exceeds the supported length' do
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, identifier: 'bounded-query') }

      it 'does not execute an unbounded text search' do
        expect(described_class.new(scope, 'a' * 121).perform).to be_empty
        expect(conversation).to be_present
      end
    end
  end
end

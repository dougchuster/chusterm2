# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::ResponsePolicyService do
  subject(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Savia') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  it 'keeps public replies concise with a single question' do
    content = 'Entendi. Primeiro, me diga sua idade? Voce ja fez pedido no INSS? Tambem envie CNIS, CTPS e comprovantes.'

    result = service.apply(content)

    expect(result.count('?')).to eq(1)
    expect(result.scan(/[.!?]/).size).to be <= 2
  end

  it 'removes repeated assistant introductions after the conversation already has an AI reply' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      message_type: :outgoing,
      sender: assistant,
      content: 'Mensagem anterior da IA'
    )

    result = service.apply(
      'Ola! Aqui e a Dra. Paula Matos, do Coimbra & Ruas. Como posso te ajudar hoje? Para seguir, me diga qual ponto quer priorizar.'
    )

    expect(result).not_to match(/Aqui .*Dra/i)
    expect(result).to include('Para seguir')
  end

  it 'removes low value openings instead of wasting the reply on generic repetition' do
    content = 'Claro, Daniel! Tudo bem, sim, obrigada! Pode encaminhar o que ele ja te passou. Assim que receber, analiso.'

    result = service.apply(content)

    expect(result).not_to match(/Tudo bem|obrigada|Claro, Daniel/i)
    expect(result).to include('Pode encaminhar')
  end
end

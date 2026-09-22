require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §7 — todo anexo que o cliente manda entra sozinho
# na gaveta dele. A pasta é do contato, não da conversa.
RSpec.describe Crm::Documents::AttachmentIngestor do
  let(:account) { create(:account) }
  let(:inbox) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox }
  let(:contact) { create(:contact, account: account, name: 'Maria da Silva') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  before { crm_documents_enable!(account) }

  def message_with_file(message_type: 'incoming', content: nil, **file)
    file = { asset: 'sample.pdf', type: 'application/pdf', file_type: :file }.merge(file)
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: message_type, content: content)
    attachment = message.attachments.new(account_id: account.id, file_type: file[:file_type])
    attachment.file.attach(io: Rails.root.join('spec/assets', file[:asset]).open,
                           filename: file[:filename] || file[:asset], content_type: file[:type])
    attachment.save!
    attachment
  end

  def ingest(attachment)
    described_class.new(attachment).call
  end

  it 'guarda o anexo recebido na triagem do contato, com origem e vínculo com a conversa' do
    attachment = message_with_file(content: 'segue meu rg', filename: 'IMG-WA0012.pdf')

    document = ingest(attachment)

    expect(document).to have_attributes(contact_id: contact.id, source: 'whatsapp', uploaded_by_contact: true,
                                        source_attachment_id: attachment.id,
                                        source_message_id: attachment.message_id, doc_type: nil)
    expect(document.crm_document_folder.slot).to eq('triagem')
    expect(document.meta).to include('suggested_doc_type' => 'rg', 'caption' => 'segue meu rg')
  end

  it 'usa a hora em que o cliente mandou, não a hora do processamento' do
    attachment = message_with_file
    attachment.message.update!(created_at: Time.zone.parse('2026-09-22 17:37 UTC'))

    expect(ingest(attachment).file_name).to start_with('2026-09-22 14h37 — WhatsApp —')
  end

  it 'guarda uma cópia própria do arquivo, que sobrevive à mensagem apagada' do
    attachment = message_with_file
    document = ingest(attachment)

    expect(document.file.blob.id).not_to eq(attachment.file.blob.id)
    attachment.message.destroy!
    expect(document.reload.file.download).to start_with('%PDF')
  end

  it 'é idempotente para o mesmo anexo (webhook duplicado)' do
    attachment = message_with_file
    first = ingest(attachment)

    expect(ingest(attachment).id).to eq(first.id)
    expect(CrmDocument.count).to eq(1)
  end

  it 'não duplica o mesmo arquivo reenviado em outra mensagem' do
    first = ingest(message_with_file)

    expect(ingest(message_with_file).id).to eq(first.id)
    expect(CrmDocument.count).to eq(1)
  end

  it 'guarda o que o escritório enviou em 05 Enviados pelo Escritório' do
    document = ingest(message_with_file(message_type: 'outgoing'))

    expect(document.crm_document_folder.slot).to eq('enviados')
    expect(document.uploaded_by_contact).to be(false)
  end

  it 'não guarda o que o escritório enviou quando a conta desligou essa opção' do
    account.update!(settings: account.settings.merge('crm_documents_capture_outgoing' => false))

    expect(ingest(message_with_file(message_type: 'outgoing'))).to be_nil
  end

  it 'ignora áudio (conversa, não documento)' do
    expect(ingest(message_with_file(asset: 'sample.ogg', type: 'audio/ogg', file_type: :audio))).to be_nil
  end

  it 'ignora nota privada' do
    attachment = message_with_file
    attachment.message.update!(private: true)

    expect(ingest(attachment)).to be_nil
  end

  it 'marca imagem pequena sem legenda como provável irrelevante' do
    document = ingest(message_with_file(asset: 'avatar.png', type: 'image/png', file_type: :image))

    expect(document.meta['likely_irrelevant']).to be(true)
  end

  it 'usa a origem genérica "chat" para canais sem mapeamento próprio' do
    widget_inbox = create(:inbox, account: account)
    widget_conversation = create(:conversation, account: account, inbox: widget_inbox, contact: contact)
    message = create(:message, account: account, inbox: widget_inbox, conversation: widget_conversation)
    attachment = message.attachments.new(account_id: account.id, file_type: :file)
    attachment.file.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'x.pdf',
                           content_type: 'application/pdf')
    attachment.save!

    expect(ingest(attachment).source).to eq('chat')
  end

  it 'não faz nada com o módulo desligado' do
    Crm::Documents::Feature.disable!(account)

    expect(ingest(message_with_file)).to be_nil
  end
end

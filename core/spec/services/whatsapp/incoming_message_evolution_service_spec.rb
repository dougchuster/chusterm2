require 'rails_helper'

RSpec.describe Whatsapp::IncomingMessageEvolutionService do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:remote_lid) { '211750628651261@lid' }
  let(:sender_pn) { '556184410419@s.whatsapp.net' }

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
    allow_any_instance_of(Channel::Whatsapp).to receive(:validate_provider_config)
  end

  it 'stores the LID alias when senderPn is available' do
    described_class.new(inbox: inbox, params: payload(id: 'MSG-1', remote_jid: remote_lid, sender_pn: sender_pn)).perform

    contact = inbox.contacts.first
    expect(contact.phone_number).to eq('+556184410419')
    expect(contact.identifier).to eq(sender_pn)
    expect(contact.additional_attributes['whatsapp_lid_jids']).to include(remote_lid)
    expect(inbox.contact_inboxes.first.source_id).to eq('556184410419')
  end

  it 'promotes an incoming Evolution saved contact payload to customer' do
    described_class.new(
      inbox: inbox,
      params: payload(id: 'MSG-SAVED-1', remote_jid: '556184410419@s.whatsapp.net', saved: true)
    ).perform

    contact = inbox.contacts.first
    expect(contact).to be_customer
    expect(contact.crm_relationship_status).to eq('customer')
    expect(contact.crm_lifecycle_stage).to eq('customer')
    expect(contact.additional_attributes['saved_contact_customer']).to be true
    expect(contact.additional_attributes['whatsapp_saved_contact']).to be true
  end

  it 'does not promote a regular incoming contact payload to customer' do
    described_class.new(
      inbox: inbox,
      params: payload(id: 'MSG-REGULAR-1', remote_jid: '556184410419@s.whatsapp.net')
    ).perform

    contact = inbox.contacts.first
    expect(contact).not_to be_customer
    expect(contact.crm_relationship_status).to eq('lead')
  end

  it 'uses the stored LID alias when a later message arrives without senderPn' do
    described_class.new(inbox: inbox, params: payload(id: 'MSG-1', remote_jid: remote_lid, sender_pn: sender_pn, body: 'Oi')).perform
    first_conversation = inbox.conversations.first

    described_class.new(inbox: inbox, params: payload(id: 'MSG-2', remote_jid: remote_lid, body: '6')).perform

    expect(inbox.contacts.count).to eq(1)
    expect(inbox.conversations.count).to eq(1)
    expect(first_conversation.reload.messages.pluck(:content)).to include('Oi', '6')
    expect(inbox.contacts.where(phone_number: '+211750628651261')).to be_empty
  end

  it 'creates an unresolved LID contact without a fake phone when no alias exists' do
    described_class.new(inbox: inbox, params: payload(id: 'MSG-1', remote_jid: remote_lid, body: 'Oi')).perform

    contact = inbox.contacts.first
    expect(contact.phone_number).to be_nil
    expect(contact.identifier).to eq(remote_lid)
    expect(contact.additional_attributes['whatsapp_lid_unresolved']).to be true
    expect(inbox.contact_inboxes.first.source_id).to eq('211750628651261')
  end

  it 'imports outgoing historical messages without resending them' do
    described_class.new(
      inbox: inbox,
      params: payload(id: 'MSG-HISTORY-1', remote_jid: '556184410419@s.whatsapp.net', body: 'Mensagem antiga', from_me: true),
      import_history: true
    ).perform

    message = inbox.messages.find_by!(source_id: 'MSG-HISTORY-1')
    expect(message).to be_outgoing
    expect(message).to be_delivered
    expect(message.sender).to be_nil
    expect(message.content_attributes['external_echo']).to be true
    expect(message.content_attributes['external_import']).to be true
  end

  it 'attaches base64 media received from Evolution webhooks' do
    described_class.new(
      inbox: inbox,
      params: payload(
        id: 'MSG-IMG-1',
        remote_jid: '556184410419@s.whatsapp.net',
        body: '',
        message_type: 'imageMessage',
        message: {
          imageMessage: {
            mimetype: 'image/png',
            fileName: 'documento.png',
            base64: Base64.strict_encode64('fake-image')
          }
        }
      )
    ).perform

    message = inbox.messages.find_by!(source_id: 'MSG-IMG-1')
    expect(message.attachments.count).to eq(1)
    expect(message.attachments.first.file).to be_attached
    expect(message.attachments.first.file_type).to eq('image')
  end

  it 'prefers decrypted message-level base64 over the encrypted WhatsApp media URL' do
    described_class.new(
      inbox: inbox,
      params: payload(
        id: 'MSG-IMG-2',
        remote_jid: '556184410419@s.whatsapp.net',
        body: '',
        message_type: 'imageMessage',
        message: {
          base64: Base64.strict_encode64('decrypted-image'),
          imageMessage: {
            mimetype: 'image/jpeg',
            url: 'https://mmg.whatsapp.net/encrypted-media.enc'
          }
        }
      )
    ).perform

    attachment = inbox.messages.find_by!(source_id: 'MSG-IMG-2').attachments.first
    expect(attachment.file).to be_attached
    expect(attachment.file.blob.download).to eq('decrypted-image')
    expect(attachment.file.blob.filename.to_s).to end_with('.jpg')
  end

  def payload(id:, remote_jid:, body: 'Oi', sender_pn: nil, from_me: false, message_type: 'conversation', message: nil, saved: false)
    key = {
      remoteJid: remote_jid,
      fromMe: from_me,
      id: id
    }
    key[:senderPn] = sender_pn if sender_pn.present?

    payload = {
      event: 'messages.upsert',
      data: {
        key: key,
        pushName: 'Savia',
        message: message || { conversation: body },
        messageType: message_type
      }
    }.with_indifferent_access
    payload[:data][:isMyContact] = true if saved
    payload
  end
end

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

  def payload(id:, remote_jid:, body: 'Oi', sender_pn: nil)
    key = {
      remoteJid: remote_jid,
      fromMe: false,
      id: id
    }
    key[:senderPn] = sender_pn if sender_pn.present?

    {
      event: 'messages.upsert',
      data: {
        key: key,
        pushName: 'Savia',
        message: { conversation: body },
        messageType: 'conversation'
      }
    }.with_indifferent_access
  end
end

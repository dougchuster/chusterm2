# frozen_string_literal: true

# Processes incoming webhook payloads from Evolution API (Baileys).
#
# Evolution API sends payloads like:
# {
#   "event": "messages.upsert",
#   "instance": "my-instance",
#   "data": {
#     "key": { "remoteJid": "5511999999999@s.whatsapp.net", "fromMe": false, "id": "ABC123" },
#     "pushName": "John Doe",
#     "message": { "conversation": "Hello!" },
#     "messageType": "conversation",
#     "messageTimestamp": 1700000000
#   }
# }
#
class Whatsapp::IncomingMessageEvolutionService
  include ::Whatsapp::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  IGNORABLE_MESSAGE_TYPES = %w[
    reactionMessage
    protocolMessage
    senderKeyDistributionMessage
    ephemeralMessage
    pollUpdateMessage
    pollCreationMessage
    encReactionMessage
  ].freeze

  def perform
    return unless message_event?

    @data = params[:data] || params['data']
    return if @data.blank?

    key = @data[:key] || @data['key'] || {}

    # Skip messages sent by ourselves
    from_me = key[:fromMe] || key['fromMe']
    return if ActiveModel::Type::Boolean.new.cast(from_me)

    source_id = key[:id] || key['id']
    return if source_id.blank?
    return if find_message_by_source_id(source_id)

    set_contact
    return unless @contact

    if message_body.blank? && !has_media?
      maybe_record_undecryptable_incoming(key)
      return
    end

    ActiveRecord::Base.transaction do
      set_conversation
      create_message(source_id)
    end
  end

  private

  def maybe_record_undecryptable_incoming(key)
    mt = message_type_key.to_s
    return if self.class::IGNORABLE_MESSAGE_TYPES.include?(mt)

    remote = (key[:remoteJid] || key['remoteJid']).to_s
    detail = <<~MSG.squish
      Webhook messages.upsert recebido sem texto/mídia legível (messageType=#{mt}, remoteJid=#{remote}).
      Em Evolution/Baileys isso costuma indicar sessão criptográfica corrompida ou falha de descriptografia (ex.: Bad MAC).
      Refaça o pareamento: apague a instância na Evolution, recrie e escaneie um QR novo; em Docker, prefira volumes persistentes estáveis.
    MSG
    channel = inbox.channel
    return unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'evolution'

    channel.evolution_record_session_warning!(
      code: 'incoming_message_not_decryptable',
      detail: detail
    )
  end

  def message_event?
    event = params[:event] || params['event']
    event.to_s.downcase.tr('.', '_').include?('messages_upsert')
  end

  def phone_from_jid
    remote_jid = remote_jid_from_key

    # WhatsApp LID (Linked Identity): privacy feature where remoteJid uses a random
    # numeric ID instead of the real phone number. Evolution API v2+ provides the real
    # phone number in key.senderPn when remoteJid ends with @lid.
    if remote_jid.end_with?('@lid')
      if sender_pn_from_key.include?('@s.whatsapp.net')
        Rails.logger.info "[EVOLUTION] LID detected (#{remote_jid}), using senderPn: #{sender_pn_from_key}"
        return sender_pn_from_key.split('@').first
      end

      aliased_phone = phone_from_lid_alias(remote_jid)
      return aliased_phone if aliased_phone.present?

      Rails.logger.warn "[EVOLUTION] LID JID without senderPn fallback: #{remote_jid}"
      return nil
    end

    remote_jid.split('@').first
  end

  def contact_name
    @data[:pushName] || @data['pushName'] || phone_from_jid || remote_jid_from_key.split('@').first
  end

  def message_body
    msg = @data[:message] || @data['message'] || {}
    msg[:conversation] || msg['conversation'] ||
      msg.dig(:extendedTextMessage, :text) || msg.dig('extendedTextMessage', 'text') ||
      msg.dig(:imageMessage, :caption) || msg.dig('imageMessage', 'caption') ||
      msg.dig(:videoMessage, :caption) || msg.dig('videoMessage', 'caption') ||
      msg.dig(:documentMessage, :caption) || msg.dig('documentMessage', 'caption') ||
      ''
  end

  def message_type_key
    @data[:messageType] || @data['messageType'] || 'conversation'
  end

  def has_media?
    %w[imageMessage videoMessage audioMessage documentMessage stickerMessage].include?(message_type_key)
  end

  def media_data
    msg = @data[:message] || @data['message'] || {}
    msg[message_type_key] || msg[message_type_key.to_sym] || {}
  end

  def set_contact
    phone = phone_from_jid
    Rails.logger.info "[EVOLUTION] set_contact phone=#{phone} remoteJid=#{@data.dig(:key, :remoteJid) || @data.dig('key', 'remoteJid')} sender=#{@data[:sender] || @data['sender']}"

    contact_inbox = if phone.present?
                      contact_with_phone(phone)
                    elsif lid_remote_jid?
                      unresolved_lid_contact
                    end

    return if contact_inbox.blank?

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
    persist_lid_alias! if lid_remote_jid?
  end

  def contact_with_phone(phone)
    phone_with_plus = phone.start_with?('+') ? phone : "+#{phone}"

    ::ContactInboxWithContactBuilder.new(
      source_id: phone,
      inbox: inbox,
      contact_attributes: {
        name: contact_name,
        phone_number: phone_with_plus,
        identifier: sender_pn_from_key.presence,
        additional_attributes: lid_contact_attributes
      }
    ).perform
  end

  def unresolved_lid_contact
    ::ContactInboxWithContactBuilder.new(
      source_id: remote_jid_from_key.split('@').first,
      inbox: inbox,
      contact_attributes: {
        name: contact_name,
        identifier: remote_jid_from_key,
        additional_attributes: lid_contact_attributes.merge('whatsapp_lid_unresolved' => true)
      }
    ).perform
  end

  def set_conversation
    @conversation = @contact_inbox.conversations
                                  .where.not(status: :resolved)
                                  .last

    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  def create_message(source_id)
    @message = @conversation.messages.build(
      content: message_body,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: source_id
    )

    attach_media if has_media?
    @message.save!
  end

  def attach_media
    media = media_data
    url = media[:url] || media['url'] || media[:directPath] || media['directPath']
    return if url.blank?

    mimetype = media[:mimetype] || media['mimetype'] || 'application/octet-stream'
    filename = media[:fileName] || media['fileName'] || "media_#{Time.now.to_i}"

    file_type = if mimetype.start_with?('image')
                  :image
                elsif mimetype.start_with?('video')
                  :video
                elsif mimetype.start_with?('audio')
                  :audio
                else
                  :file
                end

    attachment = @message.attachments.new(
      account_id: inbox.account_id,
      file_type: file_type
    )

    begin
      downloaded = Down.download(url)
      attachment.file.attach(
        io: downloaded,
        filename: filename,
        content_type: mimetype
      )
    rescue Down::Error => e
      Rails.logger.error "[EVOLUTION] Media download failed: #{e.message}"
    end
  end

  def find_message_by_source_id(source_id)
    inbox.messages.find_by(source_id: source_id)
  end

  def account
    @account ||= inbox.account
  end

  def remote_jid_from_key
    key = @data[:key] || @data['key'] || {}
    (key[:remoteJid] || key['remoteJid']).to_s
  end

  def sender_pn_from_key
    key = @data[:key] || @data['key'] || {}
    (key[:senderPn] || key['senderPn']).to_s
  end

  def lid_remote_jid?
    remote_jid_from_key.end_with?('@lid')
  end

  def phone_from_lid_alias(remote_jid)
    contact = account.contacts
                     .where("jsonb_exists(additional_attributes -> 'whatsapp_lid_jids', :remote_jid)", remote_jid: remote_jid)
                     .where.not(phone_number: [nil, ''])
                     .first
    contact&.phone_number&.delete_prefix('+')
  end

  def persist_lid_alias!
    return unless @contact

    attrs = @contact.additional_attributes.to_h
    lid_jids = Array(attrs['whatsapp_lid_jids'])
    lid_jids << remote_jid_from_key
    attrs['whatsapp_lid_jids'] = lid_jids.compact_blank.uniq
    attrs['whatsapp_sender_pn'] = sender_pn_from_key if sender_pn_from_key.present?
    attrs['whatsapp_lid_last_seen_at'] = Time.current.iso8601
    attrs['whatsapp_lid_unresolved'] = false if sender_pn_from_key.present?

    updates = { additional_attributes: attrs }
    updates[:identifier] = sender_pn_from_key if sender_pn_from_key.present? && @contact.identifier.blank?
    @contact.update!(updates)
  end

  def lid_contact_attributes
    return {} unless lid_remote_jid?

    {
      'whatsapp_lid_jids' => [remote_jid_from_key],
      'whatsapp_sender_pn' => sender_pn_from_key.presence,
      'whatsapp_lid_last_seen_at' => Time.current.iso8601
    }.compact
  end
end

# frozen_string_literal: true

module Evolution
  class WebhookProcessorService
    def initialize(event:)
      @event = event
      @params = event.payload.with_indifferent_access
      @instance = event.evolution_instance
      @channel = @instance&.channel_whatsapp || find_channel_from_payload
    end

    def perform
      return if @event.status_processed?
      return mark_failed!('Evolution channel not found') unless @channel&.provider == 'evolution'
      return mark_failed!('Inactive account') unless @channel.account.active?
      return mark_failed!('Evolution inbox not found') unless target_inbox
      return mark_failed!('Instance mismatch') unless matching_instance?

      @event.status_processing!

      case normalized_event
      when 'messages_upsert'
        process_incoming_message
      when 'messages_set'
        process_message_history
      when 'messages_update'
        handle_message_status_update
      when 'contacts_set', 'contacts_upsert', 'contacts_update'
        process_contact_updates
      when 'chats_set', 'chats_upsert', 'chats_update'
        process_chat_updates
      when 'connection_update'
        handle_connection_update
      when 'qrcode_updated'
        handle_qr_update
      when 'logout_instance'
        handle_logout_or_remove('logout_instance')
      when 'remove_instance'
        handle_logout_or_remove('remove_instance')
      else
        Rails.logger.info "[EVOLUTION] Unhandled event: #{normalized_event}"
      end

      @event.processed!
    rescue StandardError => e
      mark_failed!(e.message)
      raise
    end

    private

    def process_incoming_message
      return if @channel.reauthorization_required?

      Whatsapp::IncomingMessageEvolutionService.new(inbox: target_inbox, params: @params).perform
    end

    def process_message_history
      return if @channel.reauthorization_required?

      each_payload_entry do |entry|
        next if entry.blank?

        Whatsapp::IncomingMessageEvolutionService.new(
          inbox: target_inbox,
          params: @params.merge(data: entry, event: 'messages.set'),
          import_history: true
        ).perform
      end
    end

    def process_contact_updates
      each_payload_entry { |entry| sync_contact_profile!(entry.with_indifferent_access) if entry.present? }
    end

    def process_chat_updates
      each_payload_entry { |entry| sync_contact_profile!(entry.with_indifferent_access) if entry.present? }
    end

    def handle_message_status_update
      data = @params[:data]
      return if data.blank?

      Array.wrap(data).each { |entry| update_message_status(entry.with_indifferent_access) }
    end

    def update_message_status(data)
      source_ids = evolution_message_ids(data)
      return if source_ids.blank?

      message = target_inbox.messages.where(source_id: source_ids).first
      unless message
        Rails.logger.info "[EVOLUTION] Status update ignored; source_ids=#{source_ids.join(',')} inbox_id=#{target_inbox.id}"
        source_ids.each { |source_id| track_evolution_campaign_status(source_id, data) }
        return
      end

      status = data[:status]
      normalized_status = normalized_delivery_status(status)
      case normalized_status
      when :sent
        message.update(status: :sent)
      when :delivered
        message.update(status: :delivered)
      when :read
        message.update(status: :read)
      when :failed
        message.update(status: :failed, external_error: status_error(data))
      end

      track_evolution_campaign_status(message.source_id || source_ids.first, data, message: message, normalized_status: normalized_status)
    end

    def handle_connection_update
      data = (@params[:data] || {}).with_indifferent_access
      return if data.blank?

      state = data[:state] || data[:status]
      error = data[:error] || data[:reason]

      case state.to_s.downcase
      when 'open', 'connected'
        @channel.reauthorized! if @channel.reauthorization_required?
        @channel.evolution_clear_session_warnings!
        @channel.evolution_update_health!(state: state, error: nil)
        sync_instance_identity_from_connection!(data)
        @instance&.update_connection!(state: state, error: nil)
      when 'close', 'closed', 'disconnected'
        @channel.authorization_error!
        @channel.evolution_update_health!(state: state, error: error)
        @instance&.update_connection!(state: state, error: error)
      end

      broadcast('connection_update')
    end

    def handle_qr_update
      data = (@params[:data] || {}).with_indifferent_access
      qr = data[:qrcode] || data[:base64]
      return if qr.blank?

      if @instance.present?
        @instance.store_qr!(qr)
      else
        config = @channel.provider_config.to_h.merge('latest_qr' => qr)
        @channel.update(provider_config: config)
      end

      broadcast('qrcode_updated', qrcode: qr)
    end

    def handle_logout_or_remove(kind)
      data = (@params[:data] || {}).with_indifferent_access
      reason = data[:reason] || data[:error] || @params[:reason] || kind
      detail = "#{kind}: #{reason}"

      @channel.evolution_update_health!(state: kind, error: reason.to_s)
      @channel.evolution_record_session_warning!(code: kind, detail: detail)
      @channel.authorization_error!
      @instance&.update_connection!(state: kind == 'remove_instance' ? 'removed' : kind, error: reason.to_s)
      @instance&.update!(provisioning_status: kind == 'remove_instance' ? 'removed' : 'disconnected')
      broadcast(kind)
    end

    def find_channel_from_payload
      phone_number = @params[:phone_number].to_s
      return if phone_number.blank?

      normalized_phone = phone_number.delete_prefix('+')
      Channel::Whatsapp.find_by(phone_number: normalized_phone) ||
        Channel::Whatsapp.find_by(phone_number: "+#{normalized_phone}")
    end

    def each_payload_entry
      data = @params[:data]
      entries =
        if data.is_a?(Hash) && data[:messages].is_a?(Array)
          data[:messages]
        elsif data.is_a?(Hash) && data['messages'].is_a?(Array)
          data['messages']
        else
          Array.wrap(data)
        end

      entries.each { |entry| yield(entry) }
    end

    def normalized_event
      raw_event = @event.event_name.presence || @params[:event] || @params['event']
      raw_event.to_s.downcase.tr('.', '_')
    end

    def matching_instance?
      expected = @instance&.instance_name || @channel.provider_config&.dig('instance_name')
      received = @params[:instance] || @params.dig(:evolution, :instance)
      expected.blank? || received.blank? || received == expected
    end

    def evolution_message_ids(data)
      key = data[:key] || {}
      [
        key[:id],
        data[:keyId],
        data[:messageId],
        data[:id]
      ].compact_blank.map(&:to_s).uniq
    end

    def normalized_delivery_status(status)
      case status&.to_s&.downcase
      when 'server_ack', 'sent', '2'
        :sent
      when 'delivery_ack', 'delivered', '3'
        :delivered
      when 'read', 'played', 'read_ack', '4', '5'
        :read
      when 'error', 'failed', 'delivery_error'
        :failed
      end
    end

    def status_error(data)
      data[:error] || data[:message]
    end

    def track_evolution_campaign_status(source_id, data, message: nil, normalized_status: nil)
      normalized_status ||= normalized_delivery_status(data[:status])
      return if normalized_status.blank?

      Campaigns::ProviderEventTracker.new(provider: @channel.provider).track_status!(
        external_id: source_id,
        status: normalized_status,
        message: message,
        metadata: {
          provider_status: data[:status],
          error: status_error(data)
        }.compact
      )
    end

    def mark_failed!(error)
      @event.failed!(error)
      Rails.logger.warn({ component: 'evolution', action: 'webhook_failed', event_id: @event.id, error: error }.to_json)
      false
    end

    def sync_instance_identity_from_connection!(data)
      phone_number = real_phone_from_connection(data)
      profile_name = data[:profileName] || data[:profile_name]
      profile_picture_url = data[:profilePictureUrl] || data[:profile_picture_url]

      @instance&.update!(
        {
          phone_number: phone_number,
          profile_name: profile_name,
          profile_picture_url: profile_picture_url
        }.compact_blank
      )

      sync_channel_phone!(phone_number) if phone_number.present?
    end

    def sync_contact_profile!(data)
      jid = data[:id] || data[:remoteJid] || data[:remote_jid] || data.dig(:key, :remoteJid)
      return if jid.blank? || jid.to_s.end_with?('@g.us')

      phone = normalize_profile_phone(jid)
      return sync_lid_contact_profile!(jid.to_s, data) if phone.blank?

      source_id = phone&.delete_prefix('+') || jid.to_s.split('@').first
      return if source_id.blank?

      name = data[:pushName] || data[:pushname] || data[:name] || data[:notify] || phone
      profile_picture_url = data[:profilePictureUrl] || data[:profile_picture_url] || data[:picture] || data[:imgUrl]
      contact_inbox = ContactInboxWithContactBuilder.new(
        source_id: source_id,
        inbox: target_inbox,
        contact_attributes: {
          name: name,
          phone_number: phone,
          additional_attributes: { 'whatsapp_jid' => jid.to_s }.compact
        }.compact
      ).perform

      contact = contact_inbox.contact
      contact.update!(name: name) if should_update_contact_name?(contact, name)
      attach_contact_avatar(contact, profile_picture_url)
    end

    def sync_lid_contact_profile!(jid, data)
      contact = contact_for_lid(jid)
      unless contact
        Rails.logger.info({ component: 'evolution', action: 'lid_contact_profile_skipped', jid: jid, reason: 'missing_phone_alias' }.to_json)
        return
      end

      name = data[:pushName] || data[:pushname] || data[:name] || data[:notify]
      contact.update!(name: name) if should_update_contact_name?(contact, name)

      profile_picture_url = data[:profilePictureUrl] || data[:profile_picture_url] || data[:profilePicUrl] || data[:picture] || data[:imgUrl]
      attach_contact_avatar(contact, profile_picture_url)
    end

    def contact_for_lid(jid)
      source_id = jid.split('@').first
      by_contact_inbox = target_inbox.contact_inboxes.includes(:contact).find_by(source_id: source_id)&.contact
      return by_contact_inbox if by_contact_inbox

      target_inbox.account.contacts
                  .where("jsonb_exists(additional_attributes -> 'whatsapp_lid_jids', :jid)", jid: jid)
                  .first ||
        target_inbox.account.contacts.find_by(identifier: jid)
    end

    def should_update_contact_name?(contact, name)
      return false if name.blank?

      current = contact.name.to_s
      current.blank? || current.start_with?('+') || current.match?(/\A[a-z]+-[a-z]+-\d+\z/)
    end

    def normalize_profile_phone(value)
      text = value.to_s
      return if text.blank? || text.include?('@lid')

      digits = text.split('@').first.gsub(/\D/, '')
      digits.present? ? "+#{digits}" : nil
    end

    def attach_contact_avatar(contact, profile_picture_url)
      return if profile_picture_url.blank?

      attrs = contact.additional_attributes.to_h
      return if attrs['whatsapp_profile_picture_url'] == profile_picture_url && contact.avatar.attached?

      contact.update!(additional_attributes: attrs.merge('whatsapp_profile_picture_url' => profile_picture_url))
      Avatar::AvatarFromUrlJob.perform_later(contact, profile_picture_url)
    rescue StandardError => e
      Rails.logger.warn({ component: 'evolution', action: 'contact_avatar_sync_failed', contact_id: contact.id, error: e.message }.to_json)
    end

    def target_inbox
      @target_inbox ||= @instance&.inbox ||
                        @channel&.inbox ||
                        Inbox.find_by(channel_type: @channel.class.name, channel_id: @channel.id)
    end

    def real_phone_from_connection(data)
      [
        data[:wuid],
        data[:sender],
        data[:ownerJid],
        data[:owner],
        @params[:sender]
      ].filter_map { |candidate| normalize_real_phone(candidate) }.first
    end

    def normalize_real_phone(value)
      text = value.to_s
      return if text.blank? || text.include?('@lid')
      return unless text.include?('@s.whatsapp.net')

      digits = text.split('@').first.gsub(/\D/, '')
      digits.present? ? "+#{digits}" : nil
    end

    def sync_channel_phone!(phone_number)
      return if @channel.blank? || @channel.phone_number == phone_number
      return if Channel::Whatsapp.where(phone_number: phone_number).where.not(id: @channel.id).exists?

      @channel.update!(phone_number: phone_number)
    end

    def broadcast(type, extra = {})
      return if @instance.blank?

      ActionCable.server.broadcast(
        "evolution_instance_#{@instance.id}",
        {
          type: type,
          evolution_instance_id: @instance.id,
          connection_state: @instance.connection_state,
          provisioning_status: @instance.provisioning_status,
          last_error: @instance.last_error
        }.merge(extra)
      )
    rescue StandardError => e
      Rails.logger.warn({ component: 'evolution', action: 'broadcast_failed', error: e.message }.to_json)
    end
  end
end

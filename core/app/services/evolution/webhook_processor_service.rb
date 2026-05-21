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
      return mark_failed!('Instance mismatch') unless matching_instance?

      @event.status_processing!

      case normalized_event
      when 'messages_upsert'
        process_incoming_message
      when 'messages_update'
        handle_message_status_update
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

      Whatsapp::IncomingMessageEvolutionService.new(inbox: @channel.inbox, params: @params).perform
    end

    def handle_message_status_update
      data = @params[:data]
      return if data.blank?

      Array.wrap(data).each { |entry| update_message_status(entry.with_indifferent_access) }
    end

    def update_message_status(data)
      source_id = evolution_message_id(data)
      return if source_id.blank?

      message = @channel.inbox.messages.find_by(source_id: source_id)
      unless message
        Rails.logger.info "[EVOLUTION] Status update ignored; source_id=#{source_id} inbox_id=#{@channel.inbox_id}"
        track_evolution_campaign_status(source_id, data)
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

      track_evolution_campaign_status(source_id, data, message: message, normalized_status: normalized_status)
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

    def normalized_event
      @event.event_name.presence || (@params[:event] || @params['event']).to_s.downcase.tr('.', '_')
    end

    def matching_instance?
      expected = @instance&.instance_name || @channel.provider_config&.dig('instance_name')
      received = @params[:instance] || @params.dig(:evolution, :instance)
      expected.blank? || received.blank? || received == expected
    end

    def evolution_message_id(data)
      key = data[:key] || {}
      key[:id] || data[:keyId] || data[:messageId] || data[:id]
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

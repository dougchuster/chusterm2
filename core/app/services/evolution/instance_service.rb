# frozen_string_literal: true

module Evolution
  class InstanceService
    EVENTS = %w[
      MESSAGES_UPSERT
      MESSAGES_UPDATE
      CONNECTION_UPDATE
      QRCODE_UPDATED
      SEND_MESSAGE
      LOGOUT_INSTANCE
      REMOVE_INSTANCE
    ].freeze

    def initialize(instance:)
      @instance = instance
      @client = Evolution::Client.new(configuration: instance.configuration)
    end

    def provision!
      raise Evolution::CircuitOpenError, 'Circuit breaker is open' if @instance.circuit_open?

      @instance.update!(provisioning_status: 'creating', last_error: nil)
      create_remote_instance_unless_present!
      configure_webhook!
      @instance.update!(provisioning_status: 'waiting_qr', failure_count: 0, circuit_open_until: nil)
      broadcast('provisioned')
    rescue StandardError => e
      @instance.record_failure!(e.message)
      @instance.update!(provisioning_status: 'failed')
      broadcast('failed')
      raise
    end

    def configure_webhook!
      @client.set_webhook(
        instance_name: @instance.instance_name,
        url: webhook_url,
        headers: webhook_headers,
        events: EVENTS
      )
    end

    def qr_code_payload
      state = connection_state
      return status_payload(status: 'connected', state: state) if connected_state?(state)

      parsed = @client.connect(instance_name: @instance.instance_name)
      qrcode = extract_qr_code(parsed)
      code = extract_code(parsed)

      @instance.store_qr!(qrcode) if qrcode.present?

      if qrcode.present? || code.present? || @instance.latest_qr.present?
        return status_payload(
          status: 'qr',
          state: state,
          qrcode: qrcode.presence || @instance.latest_qr,
          code: code,
          pairing_code: extract_pairing_code(parsed),
          count: extract_count(parsed)
        )
      end

      status_payload(status: 'pending', state: state, count: extract_count(parsed))
    rescue StandardError => e
      @instance.record_failure!(e.message)
      status_payload(status: 'error', state: @instance.connection_state, error: e.message)
    end

    def connection_state
      state = @client.connection_state(instance_name: @instance.instance_name)
      if state.present? && state != 'unknown'
        @instance.update_connection!(state: state, error: nil)
        sync_remote_metadata! if connected_state?(state)
      end
      state
    rescue StandardError => e
      @instance.record_failure!(e.message)
      'unknown'
    end

    def reconnect!
      @instance.update!(latest_qr: nil, latest_qr_hash: nil, latest_qr_at: nil, provisioning_status: 'connecting')
      qr_code_payload
    end

    def logout!
      @client.logout(instance_name: @instance.instance_name)
      @instance.update_connection!(state: 'logout', error: nil)
      @instance.channel_whatsapp&.authorization_error!
      broadcast('logout')
    end

    def restart!
      @client.restart(instance_name: @instance.instance_name)
      @instance.update!(provisioning_status: 'connecting', last_error: nil)
      broadcast('restart')
    end

    def delete_remote!
      @client.delete_instance(instance_name: @instance.instance_name)
      @instance.update_connection!(state: 'removed', error: nil)
      @instance.update!(provisioning_status: 'removed')
      broadcast('removed')
    end

    private

    def create_remote_instance_unless_present!
      existing = @client.fetch_instances.any? { |remote| remote[:name].to_s == @instance.instance_name.to_s }
      @client.create_instance(instance_name: @instance.instance_name) unless existing
    end

    def sync_remote_metadata!
      remote = @client.fetch_instances.find { |item| item[:name].to_s == @instance.instance_name.to_s }
      return if remote.blank?

      attrs = {
        phone_number: remote[:phone_number],
        profile_name: remote[:profile_name],
        profile_picture_url: remote[:profile_picture_url]
      }.compact_blank

      @instance.update!(attrs) if attrs.present?
      sync_channel_phone!(remote[:phone_number]) if remote[:phone_number].present?
    rescue StandardError => e
      Rails.logger.warn({ component: 'evolution', action: 'sync_remote_metadata_failed', instance_id: @instance.id, error: e.message }.to_json)
    end

    def sync_channel_phone!(phone_number)
      channel = @instance.channel_whatsapp
      return if channel.blank?
      return if channel.phone_number == phone_number

      existing = Channel::Whatsapp.where(phone_number: phone_number).where.not(id: channel.id).exists?
      return if existing

      channel.update!(phone_number: phone_number)
    end

    def webhook_url
      "#{@instance.configuration.webhook_base_url}/webhooks/evolution/#{@instance.webhook_token}"
    end

    def webhook_headers
      {
        'x-evolution-webhook-token' => @instance.webhook_token
      }
    end

    def connected_state?(state)
      %w[open connected].include?(state.to_s.downcase)
    end

    def status_payload(**payload)
      payload.merge(
        evolution_instance_id: @instance.id,
        evolution_health: @instance.channel_whatsapp&.evolution_health_for_api
      )
    end

    def extract_qr_code(parsed)
      parsed['base64'].presence ||
        dig_value(parsed, 'qrcode', 'base64').presence ||
        parsed['qrcode'].presence ||
        dig_value(parsed, 'data', 'base64').presence ||
        dig_value(parsed, 'data', 'qrcode').presence ||
        dig_value(parsed, 'data', 'qr').presence
    end

    def extract_code(parsed)
      parsed['code'].presence || dig_value(parsed, 'data', 'code').presence
    end

    def extract_pairing_code(parsed)
      parsed['pairingCode'].presence ||
        parsed['pairing_code'].presence ||
        dig_value(parsed, 'data', 'pairingCode').presence ||
        dig_value(parsed, 'data', 'pairing_code').presence
    end

    def extract_count(parsed)
      parsed['count'] || dig_value(parsed, 'data', 'count')
    end

    def dig_value(value, *keys)
      keys.reduce(value) do |memo, key|
        return nil unless memo.respond_to?(:[])

        memo[key]
      end
    end

    def broadcast(event)
      ActionCable.server.broadcast(
        "evolution_instance_#{@instance.id}",
        {
          type: event,
          evolution_instance_id: @instance.id,
          connection_state: @instance.connection_state,
          provisioning_status: @instance.provisioning_status,
          last_error: @instance.last_error
        }
      )
    rescue StandardError => e
      Rails.logger.warn({ component: 'evolution', action: 'broadcast_failed', error: e.message }.to_json)
    end
  end
end

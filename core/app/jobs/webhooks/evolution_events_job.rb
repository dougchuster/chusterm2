# frozen_string_literal: true

class Webhooks::EvolutionEventsJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    phone_number = params[:phone_number] || params['phone_number']
    instance_id = params[:evolution_instance_id] || params['evolution_instance_id']
    evolution_instance = EvolutionInstance.find_by(id: instance_id)
    channel = evolution_instance&.channel_whatsapp || find_channel(phone_number)

    unless channel&.provider == 'evolution'
      Rails.logger.warn "[EVOLUTION] No evolution channel found for #{phone_number}"
      return
    end

    event = Evolution::WebhookEventBuilder.call(params: params, evolution_instance: evolution_instance, channel: channel)
    return if event.blank?
    return if event.status_processed?

    Evolution::WebhookProcessorService.new(event: event).perform
  end

  private

  def find_channel(phone_number)
    normalized_phone = phone_number.to_s
    Channel::Whatsapp.find_by(phone_number: normalized_phone) ||
      Channel::Whatsapp.find_by(phone_number: "+#{normalized_phone.delete_prefix('+')}")
  end

  def normalized_event(event)
    event.to_s.downcase.tr('.', '_')
  end

  def matching_instance?(channel, params)
    expected = channel.provider_config&.dig('instance_name')
    received = params[:instance] || params['instance']
    return true if expected.blank? || received.blank?
    return true if received == expected

    Rails.logger.warn "[EVOLUTION] Ignored event for instance=#{received}; expected=#{expected} channel_id=#{channel.id}"
    false
  end

  def handle_message_status_update(channel, params)
    data = params[:data] || params['data']
    return if data.blank?

    Array.wrap(data).each { |entry| update_message_status(channel, entry) }
  end

  def update_message_status(channel, data)
    return unless data.respond_to?(:[])

    source_id = evolution_message_id(data)
    return if source_id.blank?

    message = channel.inbox.messages.find_by(source_id: source_id)
    unless message
      Rails.logger.info "[EVOLUTION] Status update ignored; message source_id=#{source_id} was not found for inbox_id=#{channel.inbox&.id}"
      track_evolution_campaign_status(channel, source_id, data)
      return
    end

    status = data[:status] || data['status']
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

    track_evolution_campaign_status(channel, source_id, data, message: message, normalized_status: normalized_status)
  end

  def evolution_message_id(data)
    key = data[:key] || data['key'] || {}
    key[:id] || key['id'] || data[:keyId] || data['keyId'] || data[:messageId] || data['messageId'] || data[:id] || data['id']
  end

  def track_evolution_campaign_status(channel, source_id, data, message: nil, normalized_status: nil)
    status = data[:status] || data['status']
    normalized_status ||= normalized_delivery_status(status)
    return if normalized_status.blank?

    Campaigns::ProviderEventTracker.new(provider: channel.provider).track_status!(
      external_id: source_id,
      status: normalized_status,
      message: message,
      metadata: {
        provider_status: status,
        error: status_error(data)
      }.compact
    )
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
    data[:error] || data['error'] || data[:message] || data['message']
  end

  def handle_connection_update(channel, params)
    data = params[:data] || params['data']
    return if data.blank?

    state = data[:state] || data['state']
    case state&.to_s&.downcase
    when 'open', 'connected'
      channel.reauthorized! if channel.reauthorization_required?
      channel.evolution_clear_session_warnings!
      channel.evolution_update_health!(state: state, error: nil)
      Rails.logger.info "[EVOLUTION] Channel #{channel.phone_number} connected"
    when 'close', 'disconnected'
      channel.authorization_error!
      error = data[:error] || data['error'] || data[:reason] || data['reason']
      channel.evolution_update_health!(state: state, error: error)
      Rails.logger.warn "[EVOLUTION] Channel #{channel.phone_number} disconnected: #{error}"
    end
  end

  def handle_logout_or_remove(channel, params, kind)
    data = params[:data] || params['data'] || {}
    reason = data[:reason] || data['reason'] || data[:error] || data['error'] ||
             params[:reason] || params['reason'] || kind
    detail = "#{kind}: #{reason}"
    channel.evolution_update_health!(state: kind, error: reason.to_s)
    channel.evolution_record_session_warning!(
      code: kind,
      detail: detail
    )
    channel.authorization_error!
    Rails.logger.warn "[EVOLUTION] Channel #{channel.phone_number} #{detail}"
  end

  def handle_qr_update(channel, params)
    data = params[:data] || params['data']
    return if data.blank?

    qr = data[:qrcode] || data['qrcode'] || data[:base64] || data['base64']
    return if qr.blank?

    # Store latest QR in provider_config for frontend polling
    config = channel.provider_config.to_h.merge('latest_qr' => qr)
    channel.update(provider_config: config)
  end
end

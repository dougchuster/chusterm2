# frozen_string_literal: true

# Provider service for Evolution API (Baileys-based unofficial WhatsApp)
# Docs: https://doc.evolution-api.com/
#
# provider_config expected keys:
#   - api_url:        Base URL of Evolution API (e.g. http://evolution-api:8080)
#   - api_key:        Global API key or instance token
#   - instance_name:  Name of the Evolution instance
#
class Whatsapp::Providers::EvolutionService < Whatsapp::Providers::BaseService
  API_VERSION = 'v2'
  HTTP_TIMEOUT = 30

  def send_message(phone_number, message)
    @message = message

    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(_phone_number, _template_info, _message)
    # Evolution API / Baileys does not support official message templates
    # Templates are a Meta Business API concept; with Baileys you send regular messages
    Rails.logger.info '[EVOLUTION] Template sending not supported on unofficial API — sending as regular text'
    nil
  end

  def sync_templates
    # No template syncing for unofficial API
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    return false if base_url.blank? || api_key.blank?

    response = HTTParty.get(
      "#{base_url}/instance/fetchInstances",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )
    response.success?
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION] Validation failed: #{e.message}"
    false
  end

  def api_headers
    {
      'apikey' => api_key,
      'Content-Type' => 'application/json'
    }
  end

  def media_url(media_id)
    # Evolution API serves media via base64 in the webhook payload
    # or via direct download URL. media_id here is the actual URL.
    media_id
  end

  # Fetch QR code for pairing the WhatsApp number
  def qr_code
    payload = qr_code_payload
    payload[:qrcode] || payload[:code]
  end

  def qr_code_payload
    return Evolution::InstanceService.new(instance: managed_instance).qr_code_payload if managed_instance.present?

    state = connection_status
    return { status: 'connected', state: state } if connected_state?(state)

    response = connect_instance
    parsed = parsed_response(response)

    if response.code.to_i == 404
      create_instance_on_evolution
      response = connect_instance
      parsed = parsed_response(response)
    end

    qrcode = extract_qr_code(parsed)
    code = extract_pairing_code_payload(parsed)
    stored_qr = provider_config['latest_qr']

    if qrcode.present? || code.present? || stored_qr.present?
      return {
        status: 'qr',
        state: state,
        qrcode: qrcode.presence || stored_qr,
        code: code,
        pairing_code: extract_pairing_code(parsed),
        count: extract_count(parsed)
      }
    end

    {
      status: response.success? ? 'pending' : 'error',
      state: state,
      count: extract_count(parsed),
      error: response.success? ? nil : error_message(response),
      raw_status: response.code
    }
  end

  # Check connection state of the instance
  def connection_status
    return Evolution::InstanceService.new(instance: managed_instance).connection_state if managed_instance.present?

    response = HTTParty.get(
      "#{base_url}/instance/connectionState/#{instance_name}",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )

    return 'unknown' unless response.success?

    parsed = response.parsed_response
    parsed.dig('instance', 'state') || parsed.dig('instance', 'status') || parsed['state'] || parsed['status'] || 'unknown'
  end

  # Create the instance on Evolution API and configure its webhook
  def setup_instance
    return Evolution::InstanceService.new(instance: managed_instance).provision! if managed_instance.present?

    create_instance_on_evolution unless instance_exists?
    configure_webhook
  end

  # Instances visible in Evolution Manager (fetchInstances) — same server as api_url/api_key.
  def fetch_instances_list
    if managed_configuration.present?
      return Evolution::Client.new(configuration: managed_configuration).fetch_instances
    end

    self.class.remote_fetch_instances(
      api_url: base_url,
      api_key: api_key
    )
  end

  class << self
    def remote_fetch_instances(api_url:, api_key:)
      base = api_url.to_s.chomp('/')
      return [] if base.blank? || api_key.blank?

      response = HTTParty.get(
        "#{base}/instance/fetchInstances",
        headers: {
          'apikey' => api_key,
          'Content-Type' => 'application/json'
        },
        timeout: 20
      )
      return [] unless response.success?

      normalize_instances_response(response.parsed_response)
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION] fetchInstances failed: #{e.message}"
      []
    end

    def normalize_instances_response(parsed)
      raw_list =
        case parsed
        when Array then parsed
        when Hash
          parsed['instances'] || parsed['data'] || Array(parsed['value'])
        else
          []
        end

      Array(raw_list).filter_map do |raw|
        next unless raw.is_a?(Hash)

        name = raw['name'] || raw['instanceName'] || raw.dig('instance', 'instanceName') || raw.dig('instance', 'name')
        next if name.blank?

        {
          name: name,
          connection_status: raw['connectionStatus'] || raw['status'] ||
            raw.dig('instance', 'status') || raw.dig('instance', 'state')
        }.compact
      end
    end
  end

  private

  def provider_config
    whatsapp_channel.provider_config
  end

  def managed_instance
    @managed_instance ||= whatsapp_channel.evolution_instance
  end

  def managed_configuration
    @managed_configuration ||= managed_instance&.configuration || whatsapp_channel.account&.evolution_api_configuration
  end

  def base_url
    managed_configuration&.base_url.presence || provider_config['api_url']&.chomp('/')
  end

  def instance_name
    managed_instance&.instance_name.presence || provider_config['instance_name']
  end

  def api_key
    managed_configuration&.global_api_key.presence || provider_config['api_key']
  end

  def phone_number_without_plus(phone)
    phone.delete('+').strip
  end

  def connected_state?(state)
    %w[open connected].include?(state.to_s.downcase)
  end

  def instance_exists?
    response = HTTParty.get(
      "#{base_url}/instance/fetchInstances",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )
    return false unless response.success?

    # Use the same normalization as remote_fetch_instances to handle all response shapes
    instances = self.class.normalize_instances_response(response.parsed_response)
    instances.any? { |i| i[:name].to_s == instance_name.to_s }
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION] Could not check instance existence: #{e.message}"
    false
  end

  def connect_instance
    HTTParty.get(
      "#{base_url}/instance/connect/#{instance_name}",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )
  end

  def parsed_response(response)
    response.parsed_response
  rescue StandardError
    {}
  end

  def extract_qr_code(parsed)
    return if parsed.blank?

    parsed['base64'].presence ||
      dig_value(parsed, 'qrcode', 'base64').presence ||
      parsed['qrcode'].presence ||
      dig_value(parsed, 'data', 'base64').presence ||
      dig_value(parsed, 'data', 'qrcode').presence ||
      dig_value(parsed, 'data', 'qr').presence
  end

  def extract_pairing_code_payload(parsed)
    return if parsed.blank?

    parsed['code'].presence ||
      dig_value(parsed, 'data', 'code').presence
  end

  def extract_pairing_code(parsed)
    return if parsed.blank?

    parsed['pairingCode'].presence ||
      parsed['pairing_code'].presence ||
      dig_value(parsed, 'data', 'pairingCode').presence ||
      dig_value(parsed, 'data', 'pairing_code').presence
  end

  def extract_count(parsed)
    return if parsed.blank?

    parsed['count'] || dig_value(parsed, 'data', 'count')
  end

  def dig_value(value, *keys)
    keys.reduce(value) do |memo, key|
      return nil unless memo.respond_to?(:[])

      memo[key]
    end
  end

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      "#{base_url}/message/sendText/#{instance_name}",
      headers: api_headers,
      timeout: HTTP_TIMEOUT,
      body: {
        number: phone_number_without_plus(phone_number),
        text: message.content
      }.to_json
    )
    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    type = attachment_type(attachment)

    response = HTTParty.post(
      "#{base_url}/message/sendMedia/#{instance_name}",
      headers: api_headers,
      timeout: HTTP_TIMEOUT,
      body: {
        number: phone_number_without_plus(phone_number),
        mediatype: type,
        media: attachment.download_url,
        caption: message.content || '',
        fileName: attachment.file.filename.to_s
      }.to_json
    )
    process_response(response, message)
  end

  def send_interactive_text_message(phone_number, message)
    # Baileys doesn't support interactive messages natively,
    # fall back to text with numbered options
    items = message.content_attributes['items'] || []
    text = message.content.to_s.dup
    items.each_with_index do |item, index|
      text << "\n#{index + 1}. #{item['title']}"
    end

    response = HTTParty.post(
      "#{base_url}/message/sendText/#{instance_name}",
      headers: api_headers,
      timeout: HTTP_TIMEOUT,
      body: {
        number: phone_number_without_plus(phone_number),
        text: text
      }.to_json
    )
    process_response(response, message)
  end

  def attachment_type(attachment)
    case attachment.file_type
    when 'image' then 'image'
    when 'video' then 'video'
    when 'audio' then 'audio'
    else 'document'
    end
  end

  def process_response(response, message)
    if response.success?
      parsed = response.parsed_response
      parsed.dig('key', 'id') || parsed['messageId']
    else
      handle_error(response, message)
      nil
    end
  end

  def error_message(response = nil)
    return '' if response.blank?

    parsed = response.parsed_response
    parsed['message'] || parsed.dig('error', 'message') || response.body.to_s.truncate(200)
  rescue StandardError
    response.body.to_s.truncate(200)
  end

  def create_instance_on_evolution
    response = HTTParty.post(
      "#{base_url}/instance/create",
      headers: api_headers,
      timeout: HTTP_TIMEOUT,
      body: {
        instanceName: instance_name,
        integration: 'WHATSAPP-BAILEYS',
        qrcode: true
      }.to_json
    )
    unless response.success?
      raise "[EVOLUTION] Falha ao criar instância '#{instance_name}' (#{response.code}): #{error_message(response)}"
    end

    Rails.logger.info "[EVOLUTION] Instância '#{instance_name}' criada com sucesso"
    response
  end

  def configure_webhook
    callback_url = if managed_instance.present?
                     "#{managed_instance.configuration.webhook_base_url}/webhooks/evolution/#{managed_instance.webhook_token}"
                   else
                     "#{webhook_base_url}/webhooks/evolution/#{whatsapp_channel.phone_number.to_s.delete_prefix('+')}"
                   end

    response = HTTParty.post(
      "#{base_url}/webhook/set/#{instance_name}",
      headers: api_headers,
      timeout: HTTP_TIMEOUT,
      body: {
        webhook: {
          enabled: true,
          url: callback_url,
          headers: {
            apikey: api_key,
            'x-evolution-webhook-token': managed_instance&.webhook_token
          },
          webhookByEvents: false,
          events: %w[
            MESSAGES_UPSERT
            MESSAGES_UPDATE
            CONNECTION_UPDATE
            QRCODE_UPDATED
            LOGOUT_INSTANCE
            REMOVE_INSTANCE
          ]
        }
      }.to_json
    )

    unless response.success?
      raise "[EVOLUTION] Falha ao configurar webhook para '#{instance_name}' (#{response.code}): #{error_message(response)}"
    end

    Rails.logger.info "[EVOLUTION] Webhook configurado: #{instance_name} → #{callback_url}"
    response
  end

  def webhook_base_url
    ENV['EVOLUTION_WEBHOOK_BASE_URL'].presence ||
      ENV['RAILS_INTERNAL_URL'].presence ||
      ENV['FRONTEND_URL'].presence ||
      'http://core:3000'
  end
end

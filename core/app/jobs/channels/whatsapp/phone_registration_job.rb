# frozen_string_literal: true

# Registers a WhatsApp Cloud API phone number asynchronously after channel creation.
# Registration is required when migrating from on-premises API or BSP, and is a no-op
# for numbers that are already registered with Cloud API.
class Channels::Whatsapp::PhoneRegistrationJob < ApplicationJob
  queue_as :default

  def perform(channel_id)
    channel = Channel::Whatsapp.find_by(id: channel_id)
    return unless channel&.provider == 'whatsapp_cloud'

    phone_number_id = channel.provider_config&.dig('phone_number_id')
    access_token    = channel.provider_config&.dig('api_key')
    return if phone_number_id.blank? || access_token.blank?

    api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    response = HTTParty.post(
      "https://graph.facebook.com/#{api_version}/#{phone_number_id}/register",
      headers: { 'Authorization' => "Bearer #{access_token}" },
      body: { messaging_product: 'whatsapp', pin: '000000' }.to_json,
      content_type: :json
    )

    if response.success?
      Rails.logger.info("[WHATSAPP] Phone #{phone_number_id} registered successfully.")
    else
      Rails.logger.warn("[WHATSAPP] Phone registration returned #{response.code} for #{phone_number_id}: #{response.body}")
    end
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] PhoneRegistrationJob failed for channel #{channel_id}: #{e.message}")
  end
end

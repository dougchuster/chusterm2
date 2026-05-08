# frozen_string_literal: true

class Webhooks::EvolutionController < ActionController::API
  before_action :load_channel
  before_action :verify_api_key
  before_action :verify_instance, only: :process_payload

  def process_payload
    phone_number = params[:phone_number]

    if phone_number.blank? || @channel.blank?
      head :unprocessable_entity
      return
    end

    Webhooks::EvolutionEventsJob.perform_later(params.to_unsafe_hash.merge(phone_number: phone_number))
    head :ok
  end

  # Evolution API may issue a GET to verify the webhook URL
  def verify
    head :ok
  end

  private

  def load_channel
    phone_number = params[:phone_number].to_s
    return if phone_number.blank?

    normalized_phone = phone_number.delete_prefix('+')
    @channel = Channel::Whatsapp.find_by(phone_number: normalized_phone) ||
               Channel::Whatsapp.find_by(phone_number: "+#{normalized_phone}")
  end

  def verify_api_key
    provided = request.headers['apikey'] || request.headers['Authorization']&.delete_prefix('Bearer ')
    allowed_keys = [
      ENV['EVOLUTION_API_KEY'].presence,
      @channel&.provider_config&.dig('api_key').presence
    ].compact
    return if provided.present? && allowed_keys.any? { |key| token_matches?(key, provided) }

    head :unauthorized
  end

  def token_matches?(expected, provided)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(expected),
      Digest::SHA256.hexdigest(provided)
    )
  end

  def verify_instance
    return if @channel.blank?

    configured_instance = @channel.provider_config&.dig('instance_name')
    incoming_instance = params[:instance].presence || params.dig(:evolution, :instance)
    return if configured_instance.blank? || incoming_instance.blank?
    return if incoming_instance == configured_instance

    Rails.logger.warn(
      "[EVOLUTION] Rejected webhook for phone=#{@channel.phone_number}; " \
      "instance=#{incoming_instance} expected=#{configured_instance}"
    )
    head :conflict
  end
end

# frozen_string_literal: true

class Webhooks::EvolutionController < ActionController::API
  before_action :load_target
  before_action :verify_api_key
  before_action :verify_instance, only: :process_payload

  def process_payload
    phone_number = params[:phone_number] || @channel&.phone_number&.delete_prefix('+')

    if phone_number.blank? || @channel.blank?
      head :unprocessable_entity
      return
    end

    Webhooks::EvolutionEventsJob.perform_later(
      params.to_unsafe_hash.merge(
        phone_number: phone_number,
        evolution_instance_id: @evolution_instance&.id
      )
    )
    head :ok
  end

  # Evolution API may issue a GET to verify the webhook URL
  def verify
    head :ok
  end

  private

  def load_target
    load_instance_from_token
    return if @channel.present?

    load_instance_from_name
    return if @channel.present?

    load_channel_from_phone(params[:phone_number] || params[:webhook_token])
  end

  def load_instance_from_token
    token = params[:webhook_token].to_s
    return if token.blank?

    @evolution_instance = EvolutionInstance.find_by(webhook_token: token)
    @channel = @evolution_instance&.channel_whatsapp
  end

  def load_instance_from_name
    incoming_instance = params[:instance].presence || params.dig(:evolution, :instance).presence
    return if incoming_instance.blank?

    matches = EvolutionInstance.where(instance_name: incoming_instance)
    return unless matches.one?

    @evolution_instance = matches.first
    @channel = @evolution_instance.channel_whatsapp
  end

  def load_channel_from_phone(raw_phone)
    phone_number = raw_phone.to_s
    return if phone_number.blank?

    normalized_phone = phone_number.delete_prefix('+')
    @channel = Channel::Whatsapp.find_by(phone_number: normalized_phone) ||
               Channel::Whatsapp.find_by(phone_number: "+#{normalized_phone}")
    @evolution_instance = @channel&.evolution_instance
  end

  def verify_api_key
    provided = request.headers['apikey'] || request.headers['Authorization']&.delete_prefix('Bearer ') || params[:apikey].presence
    token = request.headers['x-evolution-webhook-token'] || params[:webhook_token].presence
    return if @evolution_instance&.webhook_token.present? && token_matches?(@evolution_instance.webhook_token, token.to_s)

    allowed_keys = [
      ENV['EVOLUTION_API_KEY'].presence,
      @channel&.provider_config&.dig('api_key').presence,
      @evolution_instance&.configuration&.global_api_key.presence
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

    configured_instance = @evolution_instance&.instance_name || @channel.provider_config&.dig('instance_name')
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

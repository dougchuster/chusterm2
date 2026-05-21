# frozen_string_literal: true

class Api::V1::Accounts::Evolution::ConfigurationsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    configuration = Current.account.evolution_api_configuration
    return render json: { configured: false } if configuration.blank?

    render json: serialize(configuration)
  end

  def create
    upsert
  end

  def update
    upsert
  end

  def validate
    configuration = Current.account.evolution_api_configuration || Current.account.build_evolution_api_configuration
    configuration.assign_attributes(configuration_params)
    validate_connectivity!(configuration)
    render json: { ok: true, health_status: configuration.health_status }
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def upsert
    configuration = Current.account.evolution_api_configuration || Current.account.build_evolution_api_configuration
    configuration.assign_attributes(configuration_params)
    validate_connectivity!(configuration)
    configuration.save!

    render json: serialize(configuration)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def validate_connectivity!(configuration)
    Evolution::Client.new(configuration: configuration).health
    configuration.health_status = 'ok'
    configuration.last_health_check_at = Time.current
    configuration.last_health_error = nil
  rescue StandardError => e
    configuration.health_status = 'error'
    configuration.last_health_check_at = Time.current
    configuration.last_health_error = e.message
    raise
  end

  def serialize(configuration)
    {
      configured: true,
      id: configuration.id,
      base_url: configuration.base_url,
      webhook_base_url: configuration.webhook_base_url,
      global_api_key_present: configuration.global_api_key.present?,
      health_status: configuration.health_status,
      last_health_check_at: configuration.last_health_check_at,
      last_health_error: configuration.last_health_error,
      settings: configuration.settings
    }
  end

  def configuration_params
    params.permit(:base_url, :global_api_key, :webhook_base_url, settings: {})
  end
end

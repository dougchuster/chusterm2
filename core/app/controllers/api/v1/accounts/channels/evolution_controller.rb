# frozen_string_literal: true

class Api::V1::Accounts::Channels::EvolutionController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_evolution_channel,
                only: %i[qr_code connection_status instances link_instance]
  before_action :check_preview_authorization, only: [:preview_instances]

  def qr_code
    service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: @channel)
    payload = service.qr_code_payload.merge(evolution_health: @channel.evolution_health_for_api)

    return render json: payload if payload[:status] != 'error'

    render json: payload.merge(error: payload[:error].presence || 'QR code not available'), status: :unprocessable_entity
  end

  def connection_status
    service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: @channel)
    status = service.connection_status

    render json: {
      status: status,
      phone_number: @channel.phone_number,
      evolution_health: @channel.evolution_health_for_api
    }
  end

  # GET — lista instâncias já criadas na Evolution (ex.: pelo /manager)
  def instances
    service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: @channel)
    list = service.fetch_instances_list
    configured = @channel.provider_config['instance_name']

    render json: {
      instances: list,
      configured_instance_name: configured,
      configured_instance_found: list.any? { |i| i[:name].to_s == configured.to_s }
    }
  end

  # POST — lista instâncias antes de existir o canal (wizard), usando URL + chave do formulário
  def preview_instances
    api_url = preview_params[:api_url].to_s.chomp('/')
    api_key = preview_params[:api_key].to_s
    if api_url.blank? || api_key.blank?
      return render json: { error: 'api_url and api_key are required' }, status: :unprocessable_entity
    end

    list = Whatsapp::Providers::EvolutionService.remote_fetch_instances(api_url: api_url, api_key: api_key)
    render json: { instances: list }
  end

  # POST — grava instance_name no canal e reaplica webhook na Evolution
  def link_instance
    name = link_instance_params[:instance_name].to_s.strip
    if name.blank?
      return render json: { error: 'instance_name is required' }, status: :unprocessable_entity
    end

    service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: @channel)
    known = service.fetch_instances_list.any? { |i| i[:name].to_s == name }
    unless known
      return render json: { error: 'Instance not found on Evolution for this channel api_url/api_key' }, status: :unprocessable_entity
    end

    cfg = @channel.provider_config.to_h.merge('instance_name' => name)
    @channel.update!(provider_config: cfg)
    @channel.provider_service.setup_instance

    render json: {
      ok: true,
      instance_name: name,
      provider_config: @channel.reload.provider_config
    }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION] link_instance: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_evolution_channel
    @channel = find_evolution_channel
    head :not_found unless @channel
  end

  def find_evolution_channel
    inbox = Current.account.inboxes.find_by(id: params[:inbox_id])
    return nil unless inbox&.channel.is_a?(Channel::Whatsapp)
    return nil unless inbox.channel.provider == 'evolution'

    inbox.channel
  end

  def check_authorization
    authorize :inbox, :update?
  end

  def check_preview_authorization
    authorize Inbox, :create?
  end

  def preview_params
    params.permit(:api_url, :api_key)
  end

  def link_instance_params
    params.permit(:instance_name)
  end
end

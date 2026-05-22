# frozen_string_literal: true

class Api::V1::Accounts::Channels::Evolution::InstancesController < Api::V1::Accounts::BaseController
  before_action -> { authorize :inbox, :update? }
  before_action :set_instance

  def show
    render json: serialize(@instance)
  end

  def qr_code
    payload = Evolution::InstanceService.new(instance: @instance).qr_code_payload
    status = payload[:status] == 'error' ? :unprocessable_entity : :ok
    render json: payload.merge(instance: serialize(@instance.reload)), status: status
  end

  def connection_status
    state = Evolution::InstanceService.new(instance: @instance).connection_state
    render json: { status: state, instance: serialize(@instance.reload) }
  end

  def reconnect
    payload = Evolution::InstanceService.new(instance: @instance).reconnect!
    render json: payload.merge(instance: serialize(@instance.reload))
  end

  def logout
    Evolution::InstanceService.new(instance: @instance).logout!
    render json: { ok: true, instance: serialize(@instance.reload) }
  end

  def restart
    Evolution::InstanceService.new(instance: @instance).restart!
    render json: { ok: true, instance: serialize(@instance.reload) }
  end

  def sync
    Evolution::SyncConnectionStatusJob.perform_later(@instance.id)
    render json: { ok: true, instance: serialize(@instance.reload) }
  end

  def sync_history
    Evolution::SyncHistoryJob.perform_later(
      @instance.id,
      limit: sync_history_params[:limit].presence || Evolution::HistorySyncService::DEFAULT_LIMIT,
      contact_limit: sync_history_params[:contact_limit].presence || Evolution::HistorySyncService::DEFAULT_CONTACT_LIMIT
    )
    render json: { ok: true, instance: serialize(@instance.reload) }
  end

  def destroy
    Evolution::DeleteInstanceJob.perform_later(@instance.id)
    render json: { ok: true, instance: serialize(@instance.reload) }
  end

  private

  def set_instance
    @instance = Current.account.evolution_instances.find(params[:id])
  end

  def sync_history_params
    params.permit(:limit, :contact_limit)
  end

  def serialize(instance)
    {
      id: instance.id,
      inbox_id: instance.inbox_id,
      channel_id: instance.channel_whatsapp_id,
      instance_name: instance.instance_name,
      connection_state: instance.connection_state,
      provisioning_status: instance.provisioning_status,
      phone_number: instance.phone_number,
      profile_name: instance.profile_name,
      profile_picture_url: instance.profile_picture_url,
      latest_qr_at: instance.latest_qr_at,
      last_connected_at: instance.last_connected_at,
      last_disconnected_at: instance.last_disconnected_at,
      last_sync_at: instance.last_sync_at,
      last_error: instance.last_error,
      circuit_open_until: instance.circuit_open_until
    }
  end
end

# frozen_string_literal: true

class Api::V1::Accounts::Channels::Evolution::InboxesController < Api::V1::Accounts::BaseController
  before_action -> { authorize Inbox, :create? }

  def create
    configuration = Current.account.evolution_api_configuration
    return render json: { message: 'Evolution API configuration is required' }, status: :unprocessable_entity if configuration.blank?

    ActiveRecord::Base.transaction do
      @channel = Current.account.whatsapp_channels.create!(
        phone_number: generated_phone_number,
        provider: 'evolution',
        provider_config: {
          'source' => 'managed_evolution',
          'instance_name' => inbox_params[:instance_name]
        }
      )
      @inbox = Current.account.inboxes.create!(
        name: inbox_params[:name],
        channel: @channel
      )
      @evolution_instance = EvolutionInstance.create!(
        account: Current.account,
        inbox: @inbox,
        channel_whatsapp: @channel,
        configuration: configuration,
        instance_name: inbox_params[:instance_name],
        phone_number: @channel.phone_number
      )
    end

    Evolution::ProvisionInstanceJob.perform_later(@evolution_instance.id)
    render 'api/v1/accounts/inboxes/create', status: :accepted
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def inbox_params
    params.permit(:name, :instance_name)
  end

  def generated_phone_number
    loop do
      candidate = "+1#{Current.account.id.to_s.rjust(4, '0')}#{SecureRandom.random_number(10**8).to_s.rjust(8, '0')}"
      return candidate unless Channel::Whatsapp.exists?(phone_number: candidate)
    end
  end
end

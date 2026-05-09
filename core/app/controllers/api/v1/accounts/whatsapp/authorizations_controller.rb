# frozen_string_literal: true

class Api::V1::Accounts::Whatsapp::AuthorizationsController < Api::V1::Accounts::BaseController
  before_action :fetch_and_validate_inbox, if: -> { params[:inbox_id].present? }

  # POST /api/v1/accounts/:account_id/whatsapp/authorization
  def create
    validate_embedded_signup_params!
    channel = process_embedded_signup
    render_success_response(channel.inbox)

  rescue Whatsapp::MultipleNumbersError => e
    render json: {
      success: true,
      needs_number_selection: true,
      phone_numbers: e.phone_numbers,
      session_key: e.session_key
    }, status: :ok

  rescue StandardError => e
    render_error_response(e)
  end

  private

  def process_embedded_signup
    Whatsapp::EmbeddedSignupService.new(
      account: Current.account,
      user: Current.user,
      params: embedded_signup_params,
      inbox_id: params[:inbox_id]
    ).perform
  end

  def embedded_signup_params
    params.permit(:code, :business_id, :waba_id, :phone_number_id, :session_key, :flow_type)
          .to_h
          .symbolize_keys
  end

  def fetch_and_validate_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    validate_reauthorization_required
  end

  def validate_reauthorization_required
    return if @inbox.channel.reauthorization_required? || can_upgrade_to_embedded_signup?

    render json: {
      success: false,
      message: I18n.t('inbox.reauthorization.not_required')
    }, status: :unprocessable_entity
  end

  def can_upgrade_to_embedded_signup?
    @inbox.channel.provider == 'whatsapp_cloud'
  end

  def render_success_response(inbox)
    response = {
      success: true,
      id: inbox.id,
      name: inbox.name,
      channel_type: 'whatsapp'
    }
    response[:message] = I18n.t('inbox.reauthorization.success') if params[:inbox_id].present?
    render json: response
  end

  def render_error_response(error)
    Rails.logger.error "[WHATSAPP AUTHORIZATION] #{error.class}: #{error.message}"
    Rails.logger.error error.backtrace&.join("\n")
    render json: { success: false, error: error.message }, status: :unprocessable_entity
  end

  def validate_embedded_signup_params!
    errors = []
    errors << 'code ou session_key' if params[:code].blank? && params[:session_key].blank?
    errors << 'waba_id' if params[:waba_id].blank? && params[:session_key].blank?
    raise ArgumentError, "Parâmetros obrigatórios ausentes: #{errors.join(', ')}" if errors.any?
  end
end

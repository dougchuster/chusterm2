# frozen_string_literal: true

class Whatsapp::EmbeddedSignupService
  SESSION_CACHE_TTL = 15.minutes

  def initialize(account:, params:, user: nil, inbox_id: nil)
    @account        = account
    @user           = user
    @code           = params[:code]
    @business_id    = params[:business_id]
    @waba_id        = params[:waba_id]
    @phone_number_id = params[:phone_number_id]
    @session_key    = params[:session_key]
    @flow_type      = params[:flow_type]
    @inbox_id       = inbox_id
  end

  def perform
    validate_parameters!

    onboarding = find_or_init_onboarding
    onboarding.mark_connecting!

    access_token = resolve_access_token
    phone_info   = fetch_phone_info(access_token)
    validate_token_access(access_token)

    channel = create_or_reauthorize_channel(access_token, phone_info)
    onboarding.mark_connected!(inbox: channel.inbox)

    Channels::Whatsapp::WebhookSetupJob.perform_later(channel.id)
    Channels::Whatsapp::PhoneRegistrationJob.perform_later(channel.id)
    audit_event(channel, 'embedded_signup_connected')

    channel

  rescue Whatsapp::MultipleNumbersError => e
    session_key = cache_token(access_token)
    e.session_key = session_key
    onboarding&.mark_needs_number_selection!(e.phone_numbers)
    raise e

  rescue StandardError => e
    onboarding&.mark_error!(e.message)
    Rails.logger.error("[WHATSAPP] Embedded signup failed: #{e.message}")
    raise e
  end

  private

  def find_or_init_onboarding
    WhatsappEmbeddedOnboarding.find_or_initialize_by(
      account: @account,
      waba_id: @waba_id,
      phone_number_id: @phone_number_id.presence || 'pending'
    ).tap do |o|
      o.user        = @user
      o.business_id = @business_id
      o.flow_type   = @flow_type
      o.save!
    end
  end

  def resolve_access_token
    if @session_key.present?
      cached = Rails.cache.read("whatsapp_signup_token:#{@session_key}")
      return cached if cached.present?
    end
    exchange_code_for_token
  end

  def exchange_code_for_token
    Whatsapp::TokenExchangeService.new(@code).perform
  end

  def fetch_phone_info(access_token)
    Whatsapp::PhoneInfoService.new(@waba_id, @phone_number_id, access_token).perform
  end

  def validate_token_access(access_token)
    Whatsapp::TokenValidationService.new(access_token, @waba_id).perform
  end

  def create_or_reauthorize_channel(access_token, phone_info)
    if @inbox_id.present?
      Whatsapp::ReauthorizationService.new(
        account: @account,
        inbox_id: @inbox_id,
        phone_number_id: @phone_number_id,
        business_id: @business_id
      ).perform(access_token, phone_info)
    else
      waba_info = { waba_id: @waba_id, business_name: phone_info[:business_name] }
      Whatsapp::ChannelCreationService.new(@account, waba_info, phone_info, access_token).perform
    end
  end

  def cache_token(access_token)
    key = "wa_signup_#{SecureRandom.hex(16)}"
    Rails.cache.write("whatsapp_signup_token:#{key}", access_token, expires_in: SESSION_CACHE_TTL)
    key
  end

  def audit_event(channel, event)
    Whatsapp::EmbeddedSignup::AuditService.new(
      channel: channel,
      user: @user,
      event: event
    ).perform
  end

  def validate_parameters!
    errors = []
    errors << 'code ou session_key' if @code.blank? && @session_key.blank?
    errors << 'waba_id' if @waba_id.blank?
    raise ArgumentError, "Parâmetros obrigatórios ausentes: #{errors.join(', ')}" if errors.any?
  end
end

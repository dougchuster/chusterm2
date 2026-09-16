class Api::V1::Accounts::Marketing::ConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_feature_flag
  before_action :check_admin_authorization?, except: [:index]
  before_action :connection, only: [:destroy, :sync]

  PROVIDER_LABELS = {
    'meta_ads' => 'Meta Ads',
    'google_ads' => 'Google Ads',
    'ga4' => 'Google Analytics 4'
  }.freeze

  def index
    render json: {
      connections: CrmExternalConnection::MARKETING_PROVIDERS.map { |provider| serialize_provider(provider) },
      oauth_configured: {
        meta_ads: meta_oauth_configured?,
        google_ads: google_oauth_configured?,
        ga4: google_oauth_configured?
      }
    }
  end

  def authorize
    provider = params[:provider].to_s
    unless CrmExternalConnection::MARKETING_PROVIDERS.include?(provider)
      render json: { error: 'unknown_provider' }, status: :unprocessable_entity
      return
    end

    url = authorize_url_for(provider)
    if url.blank?
      render json: {
        error: 'oauth_not_configured',
        message: oauth_missing_message(provider)
      }, status: :unprocessable_entity
      return
    end

    render json: { success: true, url: url }
  end

  def destroy
    @connection.destroy!
    head :ok
  end

  def sync
    Marketing::SyncAccountJob.perform_later(@connection.id)
    head :accepted
  end

  private

  def check_feature_flag
    render json: { error: 'feature_disabled' }, status: :forbidden unless Current.account.feature_enabled?('marketing')
  end

  def connection
    @connection = Current.account.crm_external_connections.marketing.find(params[:id])
  end

  def serialize_provider(provider)
    conn = Current.account.crm_external_connections.marketing.find_by(provider: provider)
    {
      provider: provider,
      label: PROVIDER_LABELS[provider],
      connected: conn&.active? || false,
      status: conn&.status || 'disconnected',
      connection_id: conn&.id,
      name: conn&.name,
      metadata: conn&.metadata || {},
      last_synced_at: conn&.metadata&.dig('last_synced_at'),
      last_error: conn&.metadata&.dig('last_error')
    }
  end

  def authorize_url_for(provider)
    case provider
    when 'meta_ads' then meta_authorize_url
    when 'google_ads', 'ga4' then google_authorize_url(provider)
    end
  end

  def state_for(provider)
    Rails.application.message_verifier(:marketing_oauth_state).generate(
      {
        account: Current.account.to_sgid(expires_in: 15.minutes).to_s,
        user_id: Current.user.id,
        provider: provider,
        return_to: safe_return_to
      }
    )
  end

  def meta_authorize_url
    return if meta_app_id.blank?

    params_hash = {
      client_id: meta_app_id,
      redirect_uri: "#{base_url}/marketing/meta/callback",
      response_type: 'code',
      state: state_for('meta_ads'),
      scope: Marketing::OauthScopes::META
    }
    "https://www.facebook.com/v25.0/dialog/oauth?#{params_hash.to_query}"
  end

  def google_authorize_url(provider)
    return unless google_oauth_configured?

    client = OAuth2::Client.new(google_client_id, google_client_secret,
                                site: 'https://oauth2.googleapis.com',
                                authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                                token_url: 'https://oauth2.googleapis.com/token')
    client.auth_code.authorize_url(
      redirect_uri: "#{base_url}/marketing/google/callback",
      scope: Marketing::OauthScopes.for(provider),
      response_type: 'code',
      prompt: 'consent',
      access_type: 'offline',
      state: state_for(provider)
    )
  end

  def meta_oauth_configured?
    meta_app_id.present? && meta_app_secret.present?
  end

  def google_oauth_configured?
    google_client_id.present? && google_client_secret.present?
  end

  def meta_app_id
    @meta_app_id ||= GlobalConfigService.load('META_APP_ID', nil).presence
  end

  def meta_app_secret
    @meta_app_secret ||= GlobalConfigService.load('META_APP_SECRET', nil).presence
  end

  def google_client_id
    @google_client_id ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil).presence
  end

  def google_client_secret
    @google_client_secret ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil).presence
  end

  def oauth_missing_message(provider)
    keys = provider == 'meta_ads' ? 'META_APP_ID/META_APP_SECRET' : 'GOOGLE_OAUTH_CLIENT_ID/GOOGLE_OAUTH_CLIENT_SECRET'
    "Configure #{keys} antes de conectar."
  end

  def safe_return_to
    value = params[:return_to].to_s
    fallback = "/app/accounts/#{Current.account.id}/marketing/connections"
    return fallback if value.blank?

    value.start_with?("/app/accounts/#{Current.account.id}/") ? value : fallback
  end

  def base_url
    ENV.fetch('FRONTEND_URL', request.base_url)
  end
end

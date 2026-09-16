class Marketing::GoogleCallbacksController < ApplicationController
  include MarketingOauthCallback

  def show
    unless google_oauth_configured?
      redirect_to safe_marketing_account ? marketing_callback_path('not_configured') : '/'
      return
    end

    unless valid_marketing_state?
      redirect_to safe_marketing_account ? marketing_callback_path('error') : '/'
      return
    end

    response = google_client.auth_code.get_token(
      params[:code],
      redirect_uri: "#{marketing_base_url}/marketing/google/callback"
    )
    store_connections!(response)

    redirect_to marketing_callback_path('connected')
  rescue StandardError => e
    ChusteRMExceptionTracker.new(e).capture_exception
    redirect_to safe_marketing_account ? marketing_callback_path('error') : '/'
  end

  private

  # Um unico consentimento Google cria/atualiza as conexoes google_ads e ga4 —
  # os scopes dos dois produtos viajam no mesmo token.
  def store_connections!(response)
    token_payload = response.to_hash.with_indifferent_access
    granted_scopes = token_payload[:scope].to_s.split

    upsert_marketing_connection('google_ads', token_payload, granted_scopes)
    upsert_marketing_connection('ga4', token_payload, granted_scopes)
  end

  def upsert_marketing_connection(provider, token_payload, granted_scopes)
    marketing_account.crm_external_connections.find_or_initialize_by(provider: provider, user_id: nil).tap do |conn|
      conn.status = 'active'
      conn.name = 'Google'
      conn.access_token = token_payload[:access_token]
      conn.refresh_token = token_payload[:refresh_token].presence || conn.refresh_token
      conn.expires_at = token_payload[:expires_at] ? Time.at(token_payload[:expires_at]).utc : 1.hour.from_now
      conn.metadata = (conn.metadata || {}).merge(google_metadata(token_payload, granted_scopes))
      conn.save!
    end
  end

  def google_metadata(token_payload, granted_scopes)
    {
      'scope' => token_payload[:scope],
      'granted_scopes' => granted_scopes,
      'connected_at' => Time.current.iso8601,
      'connected_by_user_id' => marketing_user.id
    }
  end

  def google_client
    OAuth2::Client.new(google_client_id, google_client_secret,
                       site: 'https://oauth2.googleapis.com',
                       authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                       token_url: 'https://oauth2.googleapis.com/token')
  end

  def google_oauth_configured?
    google_client_id.present? && google_client_secret.present?
  end

  def google_client_id
    @google_client_id ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil).presence
  end

  def google_client_secret
    @google_client_secret ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil).presence
  end
end

class Crm::GoogleCallbacksController < ApplicationController
  def show
    unless google_oauth_configured?
      redirect_to safe_account ? callback_path('not_configured') : '/'
      return
    end

    response = google_client.auth_code.get_token(
      params[:code],
      redirect_uri: "#{base_url}/crm/google/callback"
    )
    store_connection!(response)

    redirect_to callback_path('connected')
  rescue StandardError => e
    ChusteRMExceptionTracker.new(e).capture_exception
    redirect_to safe_account ? callback_path('error') : '/'
  end

  private

  def store_connection!(response)
    token_payload = response.to_hash.with_indifferent_access
    @parsed_body = token_payload
    account.crm_external_connections.find_or_initialize_by(provider: 'google_workspace', user: user).tap do |connection|
      connection.user = user
      connection.status = 'active'
      connection.name = users_data['email'] || 'Google Workspace'
      connection.access_token = token_payload[:access_token]
      connection.refresh_token = token_payload[:refresh_token].presence || connection.refresh_token
      connection.expires_at = token_payload[:expires_at] ? Time.at(token_payload[:expires_at]).utc : 1.hour.from_now
      connection.metadata = (connection.metadata || {}).merge(
        'email' => users_data['email'],
        'name' => users_data['name'],
        'scope' => token_payload[:scope],
        'connected_at' => Time.current.iso8601
      )
      connection.save!
    end
  end

  def google_client
    OAuth2::Client.new(google_client_id, google_client_secret, {
                         site: 'https://oauth2.googleapis.com',
                         authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                         token_url: 'https://oauth2.googleapis.com/token'
                       })
  end

  def google_client_id
    @google_client_id ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil).presence
  end

  def google_client_secret
    @google_client_secret ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil).presence
  end

  def google_oauth_configured?
    google_client_id.present? && google_client_secret.present?
  end

  def users_data
    return {} if parsed_body[:id_token].blank?

    decoded_token = JWT.decode parsed_body[:id_token], nil, false
    decoded_token[0] || {}
  end

  def parsed_body
    @parsed_body ||= @response_body || {}
  end

  def state_payload
    @state_payload ||= Rails.application
                              .message_verifier(:crm_google_oauth_state)
                              .verify(params[:state])
                              .with_indifferent_access
  end

  def account
    @account ||= GlobalID::Locator.locate_signed(state_payload[:account])
  end

  def safe_account
    account
  rescue StandardError
    nil
  end

  def user
    @user ||= account.users.find(state_payload[:user_id])
  end

  def callback_path(status)
    uri = URI.parse(safe_return_to)
    query = Rack::Utils.parse_nested_query(uri.query)
    query['google_workspace'] = status
    uri.query = query.to_query
    uri.to_s
  rescue URI::InvalidURIError
    "/app/accounts/#{safe_account.id}/crm/agenda?google_workspace=#{status}"
  end

  def safe_return_to
    value = state_payload[:return_to].to_s
    return "/app/accounts/#{account.id}/crm/agenda" if value.blank?
    return value if value.start_with?("/app/accounts/#{account.id}/")

    "/app/accounts/#{account.id}/crm/agenda"
  end

  def base_url
    ENV.fetch('FRONTEND_URL', request.base_url)
  end
end

class Api::V1::Accounts::Crm::GoogleAuthorizationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    connection = google_connection
    metadata = connection&.metadata || {}

    render json: {
      connected: connection&.active? || false,
      status: connection&.status || 'disconnected',
      email: metadata['email'] || connection&.name,
      name: metadata['name'],
      connected_at: metadata['connected_at'],
      last_error: metadata['last_error'],
      user_id: connection&.user_id,
      legacy_connection: connection&.user_id.blank? && connection.present?,
      oauth_configured: google_oauth_configured?
    }
  end

  def create
    unless google_oauth_configured?
      render json: {
        error: 'google_oauth_not_configured',
        message: 'Configure GOOGLE_OAUTH_CLIENT_ID e GOOGLE_OAUTH_CLIENT_SECRET antes de conectar o Google.'
      }, status: :unprocessable_entity
      return
    end

    render json: {
      success: true,
      url: google_client.auth_code.authorize_url(
        redirect_uri: "#{base_url}/crm/google/callback",
        scope: scope,
        response_type: 'code',
        prompt: 'consent',
        access_type: 'offline',
        state: state,
        client_id: google_client_id
      )
    }
  end

  private

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.present?
  end

  def google_connection
    Current.account.crm_external_connections.find_by(provider: 'google_workspace', user: Current.user) ||
      Current.account.crm_external_connections.find_by(provider: 'google_workspace', user_id: nil)
  end

  def google_client
    OAuth2::Client.new(google_client_id, google_client_secret, {
                         site: 'https://oauth2.googleapis.com',
                         authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                         token_url: 'https://oauth2.googleapis.com/token'
                       })
  end

  def scope
    [
      'email',
      'profile',
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/calendar.events'
    ].join(' ')
  end

  def state
    Rails.application.message_verifier(:crm_google_oauth_state).generate(
      {
        account: Current.account.to_sgid(expires_in: 15.minutes).to_s,
        user_id: Current.user.id,
        return_to: safe_return_to
      }
    )
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

  def safe_return_to
    value = params[:return_to].to_s
    return "/app/accounts/#{Current.account.id}/crm/agenda" if value.blank?
    return value if value.start_with?("/app/accounts/#{Current.account.id}/")

    "/app/accounts/#{Current.account.id}/crm/agenda"
  end

  def base_url
    ENV.fetch('FRONTEND_URL', request.base_url)
  end
end

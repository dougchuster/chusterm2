# Renova o access_token OAuth do Google usando o refresh_token persistido.
# Devolve o novo access_token e atualiza a conexao.
class Marketing::GoogleTokenRefresher
  TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze

  def initialize(connection:)
    @connection = connection
  end

  def refresh!
    response = Faraday.post(TOKEN_URL, {
                              client_id: client_id,
                              client_secret: client_secret,
                              refresh_token: @connection.refresh_token,
                              grant_type: 'refresh_token'
                            })
    body = JSON.parse(response.body.presence || '{}')
    raise "Google token refresh failed: #{body['error_description'] || body['error'] || response.status}" if body['access_token'].blank?

    @connection.update!(
      access_token: body['access_token'],
      expires_at: (body['expires_in'] || 3600).to_i.seconds.from_now
    )
    body['access_token']
  end

  private

  def client_id
    GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil)
  end

  def client_secret
    GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil)
  end
end

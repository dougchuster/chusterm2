class Crm::GoogleSheetsExporter
  class AuthorizationRequired < StandardError; end
  class ExportFailed < StandardError; end

  SHEETS_API_BASE = 'https://sheets.googleapis.com/v4/spreadsheets'.freeze

  def initialize(account:, title:, rows:, user: nil)
    @account = account
    @title = title
    @rows = rows
    @user = user
  end

  def perform
    raise AuthorizationRequired if connection.blank? || !connection.active?

    spreadsheet_id = create_spreadsheet
    write_rows(spreadsheet_id)

    {
      spreadsheet_id: spreadsheet_id,
      url: "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit"
    }
  end

  private

  attr_reader :account, :title, :rows, :user

  def connection
    @connection ||= begin
      user_connection = account.crm_external_connections.find_by(provider: 'google_workspace', user: user) if user.present?
      user_connection || account.crm_external_connections.find_by(provider: 'google_workspace', user_id: nil)
    end
  end

  def access_token
    return connection.access_token unless connection.token_expired?

    refreshed_tokens = oauth_access_token.refresh!.to_hash
    connection.update!(
      access_token: refreshed_tokens[:access_token],
      refresh_token: refreshed_tokens[:refresh_token].presence || connection.refresh_token,
      expires_at: refreshed_tokens[:expires_at] ? Time.at(refreshed_tokens[:expires_at]).utc : 1.hour.from_now
    )
    connection.access_token
  rescue StandardError => e
    connection.update!(status: 'error', metadata: connection.metadata.merge('last_error' => e.message))
    raise AuthorizationRequired
  end

  def oauth_access_token
    OAuth2::AccessToken.new(
      google_client,
      connection.access_token,
      refresh_token: connection.refresh_token
    )
  end

  def google_client
    app_id = GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil)
    app_secret = GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil)

    OAuth2::Client.new(app_id, app_secret, {
                         site: 'https://oauth2.googleapis.com',
                         authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                         token_url: 'https://accounts.google.com/o/oauth2/token'
                       })
  end

  def create_spreadsheet
    response = HTTParty.post(
      SHEETS_API_BASE,
      headers: headers,
      body: {
        properties: { title: title },
        sheets: [{ properties: { title: 'Contatos' } }]
      }.to_json
    )
    raise ExportFailed, response.body unless response.success?

    response.parsed_response['spreadsheetId']
  end

  def write_rows(spreadsheet_id)
    response = HTTParty.post(
      "#{SHEETS_API_BASE}/#{spreadsheet_id}/values/Contatos!A1:append",
      query: { valueInputOption: 'RAW' },
      headers: headers,
      body: { values: rows }.to_json
    )
    raise ExportFailed, response.body unless response.success?
  end

  def headers
    {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    }
  end
end

class Crm::GoogleCalendarExporter
  class AuthorizationRequired < StandardError; end
  class ExportFailed < StandardError; end

  CALENDAR_API_BASE = 'https://www.googleapis.com/calendar/v3/calendars/primary/events'.freeze

  def initialize(account:, activity:, user: nil)
    @account = account
    @activity = activity
    @user = user || activity.assignee || activity.owner
  end

  def perform
    raise AuthorizationRequired if connection.blank? || !connection.active?
    raise ExportFailed, 'Activity has no due date' if activity.due_at.blank?

    response = HTTParty.send(
      activity.external_calendar_event_id.present? ? :patch : :post,
      calendar_event_url,
      query: { conferenceDataVersion: 1 },
      headers: headers,
      body: event_payload.to_json
    )
    raise ExportFailed, response.body unless response.success?

    calendar_event = response.parsed_response
    result = {
      event_id: calendar_event['id'],
      html_link: calendar_event['htmlLink'],
      meet_link: calendar_event.dig('conferenceData', 'entryPoints')&.find { |entry| entry['entryPointType'] == 'video' }&.[]('uri')
    }
    activity.update!(
      external_calendar_event_id: result[:event_id],
      external_calendar_link: result[:html_link],
      meeting_url: result[:meet_link],
      external_calendar_synced_at: Time.current
    )
    result
  end

  private

  attr_reader :account, :activity, :user

  def calendar_event_url
    return CALENDAR_API_BASE if activity.external_calendar_event_id.blank?

    "#{CALENDAR_API_BASE}/#{activity.external_calendar_event_id}"
  end

  def connection
    @connection ||= begin
      user_connection = account.crm_external_connections.find_by(provider: 'google_workspace', user: user) if user.present?
      user_connection || account.crm_external_connections.find_by(provider: 'google_workspace', user_id: nil)
    end
  end

  def event_payload
    payload = {
      summary: activity.title,
      description: description,
      start: { dateTime: activity.due_at.iso8601 },
      end: { dateTime: (activity.due_at + duration.minutes).iso8601 },
      extendedProperties: {
        private: {
          chusterm_account_id: account.id.to_s,
          crm_activity_id: activity.id.to_s
        }
      }
    }
    payload[:attendees] = attendees if attendees.present?
    payload[:conferenceData] = meet_payload if activity.kind == 'reuniao'
    payload
  end

  def attendees
    contact = activity.contact || activity.crm_deal&.contact

    [contact&.email, activity.assignee&.email, activity.owner&.email]
      .compact_blank
      .uniq
      .map { |email| { email: email } }
  end

  def meet_payload
    {
      createRequest: {
        requestId: "crm-activity-#{activity.id}-#{Time.current.to_i}",
        conferenceSolutionKey: { type: 'hangoutsMeet' }
      }
    }
  end

  def description
    contact = activity.contact || activity.crm_deal&.contact
    [
      activity.description,
      ("Contato: #{contact.name}" if contact&.name.present?),
      ("Telefone: #{contact.phone_number}" if contact&.phone_number.present?),
      ("Caso: #{activity.crm_deal.title}" if activity.crm_deal&.title.present?)
    ].compact_blank.join("\n")
  end

  def duration
    activity.kind == 'reuniao' ? 60 : 30
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
                         token_url: 'https://oauth2.googleapis.com/token'
                       })
  end

  def headers
    {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    }
  end
end

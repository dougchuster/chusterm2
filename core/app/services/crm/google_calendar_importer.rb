class Crm::GoogleCalendarImporter
  class AuthorizationRequired < StandardError; end
  class ImportFailed < StandardError; end

  CALENDAR_API_BASE = 'https://www.googleapis.com/calendar/v3/calendars/primary/events'.freeze

  def initialize(account:, owner: nil, from: nil, to: nil)
    @account = account
    @owner = owner
    @from = from || Time.current.beginning_of_day
    @to = to || 30.days.from_now.end_of_day
  end

  def perform
    raise AuthorizationRequired if connection.blank? || !connection.active?

    response = HTTParty.get(
      CALENDAR_API_BASE,
      query: calendar_query,
      headers: headers
    )
    raise ImportFailed, response.body unless response.success?

    import_events(Array(response.parsed_response['items']))
  end

  private

  attr_reader :account, :owner, :from, :to

  def calendar_query
    {
      singleEvents: true,
      orderBy: 'startTime',
      timeMin: from.iso8601,
      timeMax: to.iso8601
    }
  end

  def import_events(events)
    counters = { imported: 0, updated: 0, skipped: 0 }

    events.each do |event|
      next counters[:skipped] += 1 if skip_event?(event)

      activity = activity_for(event)
      activity.assign_attributes(activity_attributes(event))
      increment_counter(counters, activity) if activity.changed?
      activity.save! if activity.changed?
    rescue StandardError => e
      counters[:skipped] += 1
      Rails.logger.warn("[CRM Google Calendar] event import failed id=#{event['id']}: #{e.message}")
    end

    counters
  end

  def skip_event?(event)
    event['status'] == 'cancelled' || event_start(event).blank? || event['id'].blank?
  end

  def activity_for(event)
    activity_id = event.dig('extendedProperties', 'private', 'crm_activity_id')
    if activity_id.present?
      existing = account.crm_activities.find_by(id: activity_id)
      return existing if existing
    end

    account.crm_activities.find_or_initialize_by(external_calendar_event_id: event['id'])
  end

  def activity_attributes(event)
    {
      title: event['summary'].presence || 'Evento Google Calendar',
      description: event['description'],
      kind: meeting_url(event).present? ? 'reuniao' : 'follow_up',
      priority: 'normal',
      due_at: event_start(event),
      reminder_at: event_start(event),
      owner: owner,
      external_calendar_event_id: event['id'],
      external_calendar_link: event['htmlLink'],
      meeting_url: meeting_url(event),
      external_calendar_synced_at: Time.current
    }.compact
  end

  def increment_counter(counters, activity)
    activity.new_record? ? counters[:imported] += 1 : counters[:updated] += 1
  end

  def event_start(event)
    value = event.dig('start', 'dateTime') || event.dig('start', 'date')
    return if value.blank?

    Time.zone.parse(value.to_s)
  end

  def meeting_url(event)
    event['hangoutLink'].presence ||
      Array(event.dig('conferenceData', 'entryPoints')).find { |entry| entry['entryPointType'] == 'video' }&.[]('uri')
  end

  def connection
    @connection ||= begin
      user_connection = account.crm_external_connections.find_by(provider: 'google_workspace', user: owner) if owner.present?
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

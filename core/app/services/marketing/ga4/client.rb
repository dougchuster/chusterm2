# Cliente minimo do GA4 Data API (runReport).
# Docs: https://developers.google.com/analytics/devguides/reporting/data/v1/rest
class Marketing::Ga4::Client
  BASE_URL = 'https://analyticsdata.googleapis.com/v1beta'.freeze

  ApiError = Class.new(StandardError)

  def initialize(access_token:)
    @access_token = access_token
  end

  # Lista properties acessiveis via Admin API.
  def account_summaries
    response = connection.get('https://analyticsadmin.googleapis.com/v1beta/accountSummaries') do |req|
      req.headers['Authorization'] = "Bearer #{@access_token}"
      req.params[:pageSize] = 200
    end
    Array(parse(response)['accountSummaries'])
  end

  # Trafego diario por origem/midia (last 30d default via caller).
  def daily_traffic(property_id, date_from:, date_to:)
    run_report(property_id, {
                 dateRanges: [{ startDate: date_from.to_s, endDate: date_to.to_s }],
                 dimensions: [{ name: 'date' }, { name: 'sessionSource' }, { name: 'sessionMedium' }],
                 metrics: [{ name: 'sessions' }, { name: 'conversions' }, { name: 'totalUsers' }],
                 limit: 10_000
               })
  end

  def run_report(property_id, body)
    response = connection.post("#{BASE_URL}/properties/#{property_id}:runReport") do |req|
      req.headers['Authorization'] = "Bearer #{@access_token}"
      req.headers['Content-Type'] = 'application/json'
      req.body = body.to_json
    end
    parse(response)
  end

  private

  def parse(response)
    body = JSON.parse(response.body.presence || '{}')
    raise ApiError, "GA4 API #{response.status}: #{body.dig('error', 'message') || response.body}" unless response.success?

    body
  end

  def connection
    @connection ||= Faraday.new { |f| f.adapter Faraday.default_adapter }
  end
end

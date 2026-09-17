# Cliente minimo da Google Ads REST API (GAQL).
# POST /vXX/customers/{id}/googleAds:search com developer-token.
# Docs: https://developers.google.com/google-ads/api/rest
class Marketing::GoogleAds::Client
  API_VERSION = 'v21'.freeze
  BASE_URL = "https://googleads.googleapis.com/#{API_VERSION}".freeze

  ApiError = Class.new(StandardError)

  def initialize(access_token:, developer_token:, login_customer_id: nil)
    @access_token = access_token
    @developer_token = developer_token
    @login_customer_id = login_customer_id.to_s.delete('-').presence
  end

  # Lista customer IDs acessiveis (hierarquia MCC suportada via login-customer-id).
  def accessible_customers
    response = connection.get("#{BASE_URL}/customers:listAccessibleCustomers") { |r| headers(r) }
    body = parse(response)
    Array(body['resourceNames']).map { |rn| rn.split('/').last }
  end

  def campaigns(customer_id)
    search(customer_id, <<~GAQL)
      SELECT campaign.id, campaign.name, campaign.status,
             campaign.advertising_channel_type, campaign_budget.amount_micros
      FROM campaign
      WHERE campaign.status != 'REMOVED'
      ORDER BY campaign.id
    GAQL
  end

  def daily_metrics(customer_id, date_from:, date_to:)
    search(customer_id, <<~GAQL)
      SELECT campaign.id, segments.date, metrics.impressions, metrics.clicks,
             metrics.cost_micros, metrics.leads, metrics.conversions,
             metrics.conversions_value
      FROM campaign
      WHERE segments.date BETWEEN '#{date_from}' AND '#{date_to}'
        AND campaign.status != 'REMOVED'
    GAQL
  end

  def search(customer_id, gaql)
    id = customer_id.to_s.delete('-')
    response = connection.post("#{BASE_URL}/customers/#{id}/googleAds:search") do |req|
      headers(req)
      req.body = { query: gaql }.to_json
    end
    Array(parse(response)['results'])
  end

  private

  def headers(request)
    request.headers['Authorization'] = "Bearer #{@access_token}"
    request.headers['developer-token'] = @developer_token
    request.headers['login-customer-id'] = @login_customer_id if @login_customer_id
    request.headers['Content-Type'] = 'application/json'
  end

  def parse(response)
    body = JSON.parse(response.body.presence || '{}')
    unless response.success?
      detail = body.dig('error', 'message') || body.dig('error', 'details', 0, 'errors', 0, 'message')
      raise ApiError, "Google Ads API #{response.status}: #{detail || response.body}"
    end

    body
  end

  def connection
    @connection ||= Faraday.new { |f| f.adapter Faraday.default_adapter }
  end
end

# Cliente minimo para a Meta Marketing/Graph API.
# Paginacao cursored, retry com backoff em rate-limit (17/4xx transitorios),
# e nunca loga o access_token.
class Marketing::Meta::GraphClient
  GRAPH_URL = 'https://graph.facebook.com/v25.0'.freeze
  MAX_RETRIES = 3
  RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

  RateLimited = Class.new(StandardError)
  ApiError = Class.new(StandardError)

  def initialize(access_token:)
    @access_token = access_token
  end

  # GET com paginacao cursored — retorna o array `data` completo.
  def get_all(path, params: {}, limit: 250)
    results = []
    next_url = "#{GRAPH_URL}#{path}"
    next_params = params.merge(access_token: @access_token, limit: limit)

    loop do
      body = perform_get(next_url, next_params)
      results.concat(Array(body['data']))
      after = body.dig('paging', 'cursors', 'after')
      break if after.blank? || body.dig('paging', 'next').blank?

      next_url = body['paging']['next']
      next_params = {}
    end

    results
  end

  def get(path, params: {})
    perform_get("#{GRAPH_URL}#{path}", params.merge(access_token: @access_token))
  end

  def post(path, payload: {})
    response = connection.post("#{GRAPH_URL}#{path}") do |req|
      req.params[:access_token] = @access_token
      req.body = payload
    end
    parse_response(response)
  end

  # Campanhas + adsets + ads de uma ad account (act_xxx).
  def campaigns_for(ad_account_id)
    get_all("/#{ad_account_id}/campaigns",
            params: { fields: 'id,name,status,objective,daily_budget,lifetime_budget,currency' })
  end

  def insights_for(ad_account_id, date_from:, date_to:, level: 'campaign')
    get_all("/#{ad_account_id}/insights",
            params: {
              level: level,
              time_range: { since: date_from.to_s, until: date_to.to_s }.to_json,
              time_increment: 1,
              fields: 'campaign_id,adset_id,ad_id,campaign_name,adset_name,ad_name,' \
                      'impressions,clicks,spend,actions,action_values,leads'
            })
  end

  # Detalhe de um leadgen: GET /{leadgen_id}?fields=field_data,form_id,...
  # Retorna hash de campos já normalizado {name => value}.
  def leadgen_form_data(leadgen_id)
    body = get("/#{leadgen_id}", params: { fields: 'field_data,form_id,campaign_id,adset_id,ad_id,created_time,platform' })
    (body['field_data'] || []).each_with_object({}) do |entry, acc|
      acc[entry['name']] = entry['values']&.first
    end.merge(
      '_meta' => {
        'form_id' => body['form_id'],
        'campaign_id' => body['campaign_id'],
        'adset_id' => body['adset_id'],
        'ad_id' => body['ad_id'],
        'created_time' => body['created_time'],
        'platform' => body['platform']
      }.compact
    )
  rescue ApiError
    nil
  end

  private

  def perform_get(url, params_hash)
    attempts = 0
    begin
      response = connection.get(url, params_hash)
      return parse_response(response)
    rescue RateLimited => e
      attempts += 1
      raise e if attempts > MAX_RETRIES

      sleep(2**attempts)
      retry
    end
  end

  def parse_response(response)
    body = JSON.parse(response.body.presence || '{}')
    raise RateLimited, rate_limit_message(body) if RETRYABLE_STATUSES.include?(response.status) || throttled?(body)
    raise ApiError, (body.dig('error', 'message') || "HTTP #{response.status}") if body['error'].present?

    body
  end

  def throttled?(body)
    %w[17 4 32 613].include?(body.dig('error', 'code').to_s)
  end

  def rate_limit_message(body)
    "Meta rate limit: #{body.dig('error', 'message') || 'throttled'}"
  end

  def connection
    @connection ||= Faraday.new do |f|
      f.request :json
      f.response :raise_error, include_request: false
      f.adapter Faraday.default_adapter
    end
  end
end

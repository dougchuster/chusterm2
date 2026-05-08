require 'json'
require 'net/http'
require 'uri'

class Api::V1::Accounts::CrmController < Api::V1::Accounts::BaseController
  ALLOWED_ROOTS = %w[pipelines deals lead-profiles activities loss-reasons audit-events].freeze
  BODY_METHODS = %w[POST PATCH].freeze

  def proxy
    return render_not_found_error('CRM resource could not be found') unless allowed_path?

    response = perform_proxy_request
    render_proxy_response(response)
  rescue JSON::ParserError
    render json: { error: 'BAD_REQUEST', message: 'Invalid JSON payload' }, status: :bad_request
  rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[CRM proxy] #{e.class}: #{e.message}")
    render json: { error: 'CRM_SERVICE_UNAVAILABLE', message: 'CRM service is unavailable' }, status: :service_unavailable
  end

  private

  def allowed_path?
    ALLOWED_ROOTS.include?(proxy_path.split('/').first)
  end

  def proxy_path
    params[:path].to_s
  end

  def service_base_url
    ENV.fetch('CRM_SERVICE_INTERNAL_URL', 'http://crm-service:4000')
  end

  def service_uri
    uri = URI.join("#{service_base_url}/", proxy_path)
    query = request.query_parameters.except(:account_id, :path, :controller, :action)
    query = query.merge(accountId: Current.account.id)
    uri.query = query.to_query if query.present?
    uri
  end

  def perform_proxy_request
    uri = service_uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 3
    http.read_timeout = 10

    http.request(build_proxy_request(uri))
  end

  def build_proxy_request(uri)
    klass = case request.request_method
            when 'GET' then Net::HTTP::Get
            when 'POST' then Net::HTTP::Post
            when 'PATCH' then Net::HTTP::Patch
            when 'DELETE' then Net::HTTP::Delete
            else Net::HTTP::Get
            end

    proxy_request = klass.new(uri)
    proxy_request['Accept'] = 'application/json'
    proxy_request['Content-Type'] = 'application/json'
    proxy_request.body = proxy_body if BODY_METHODS.include?(request.request_method)
    proxy_request
  end

  def proxy_body
    body = request.raw_post.present? ? JSON.parse(request.raw_post) : {}
    body = body.merge('accountId' => Current.account.id) if BODY_METHODS.include?(request.request_method)
    body.to_json
  end

  def render_proxy_response(response)
    return head response.code.to_i if response.body.blank?

    render json: JSON.parse(response.body), status: response.code.to_i
  rescue JSON::ParserError
    render plain: response.body, status: response.code.to_i
  end
end

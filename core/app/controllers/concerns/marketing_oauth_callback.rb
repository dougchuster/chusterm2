module MarketingOauthCallback
  extend ActiveSupport::Concern

  private

  def valid_marketing_state?
    marketing_state_payload
    true
  rescue StandardError
    false
  end

  def marketing_state_payload
    @marketing_state_payload ||= Rails.application
                                      .message_verifier(:marketing_oauth_state)
                                      .verify(params[:state])
                                      .with_indifferent_access
  end

  def marketing_account
    @marketing_account ||= GlobalID::Locator.locate_signed(marketing_state_payload[:account])
  end

  def safe_marketing_account
    marketing_account
  rescue StandardError
    nil
  end

  def marketing_user
    @marketing_user ||= marketing_account.users.find(marketing_state_payload[:user_id])
  end

  def marketing_callback_path(status)
    uri = URI.parse(marketing_return_to)
    query = Rack::Utils.parse_nested_query(uri.query)
    query['marketing_oauth'] = status
    uri.query = query.to_query
    uri.to_s
  rescue URI::InvalidURIError
    "/app/accounts/#{safe_marketing_account.id}/marketing/connections?marketing_oauth=#{status}"
  end

  def marketing_return_to
    value = marketing_state_payload[:return_to].to_s
    fallback = "/app/accounts/#{marketing_account.id}/marketing/connections"
    return fallback if value.blank?

    value.start_with?("/app/accounts/#{marketing_account.id}/") ? value : fallback
  end

  def marketing_base_url
    ENV.fetch('FRONTEND_URL', request.base_url)
  end
end

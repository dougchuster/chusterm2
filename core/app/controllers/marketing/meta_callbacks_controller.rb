class Marketing::MetaCallbacksController < ApplicationController
  include MarketingOauthCallback

  GRAPH_URL = 'https://graph.facebook.com/v25.0'.freeze

  def show
    unless meta_oauth_configured?
      redirect_to safe_marketing_account ? marketing_callback_path('not_configured') : '/'
      return
    end

    # O state é verificado ANTES de trocar o code — um state forjado não pode
    # queimar o authorization code de uso único de um fluxo legítimo.
    unless valid_marketing_state?
      redirect_to safe_marketing_account ? marketing_callback_path('error') : '/'
      return
    end

    store_connection!
    redirect_to marketing_callback_path('connected')
  rescue StandardError => e
    ChusteRMExceptionTracker.new(e).capture_exception
    redirect_to safe_marketing_account ? marketing_callback_path('error') : '/'
  end

  private

  def store_connection!
    token = exchange_code_for_long_lived_token
    profile = graph_get('/me', fields: 'id,name', access_token: token[:access_token])
    ad_accounts = graph_get('/me/adaccounts', fields: 'account_id,name,currency,account_status',
                                              access_token: token[:access_token])
    upsert_meta_connection(token, profile, ad_accounts)
  end

  def upsert_meta_connection(token, profile, ad_accounts)
    conn = marketing_account.crm_external_connections.find_or_initialize_by(provider: 'meta_ads', user_id: nil)
    conn.status = 'active'
    conn.name = profile['name'] || 'Meta Ads'
    conn.access_token = token[:access_token]
    conn.expires_at = token[:expires_in].present? ? token[:expires_in].to_i.seconds.from_now : 60.days.from_now
    conn.metadata = (conn.metadata || {}).merge(meta_metadata(profile, ad_accounts))
    conn.save!
  end

  def meta_metadata(profile, ad_accounts)
    {
      'meta_user_id' => profile['id'],
      'ad_accounts' => Array(ad_accounts['data']).map do |acc|
        { 'id' => acc['id'], 'account_id' => acc['account_id'], 'name' => acc['name'], 'currency' => acc['currency'] }
      end,
      'scope' => Marketing::OauthScopes::META,
      'connected_at' => Time.current.iso8601,
      'connected_by_user_id' => marketing_user.id
    }
  end

  def exchange_code_for_long_lived_token
    short_lived = graph_get('/oauth/access_token',
                            client_id: meta_app_id,
                            client_secret: meta_app_secret,
                            redirect_uri: "#{marketing_base_url}/marketing/meta/callback",
                            code: params[:code])
    # Troca imediata por token long-lived (~60 dias) — o refresh é refeito
    # via mesmo endpoint enquanto o token estiver válido.
    graph_get('/oauth/access_token',
              grant_type: 'fb_exchange_token',
              client_id: meta_app_id,
              client_secret: meta_app_secret,
              fb_exchange_token: short_lived['access_token'])
      .with_indifferent_access
  end

  def graph_get(path, params_hash)
    response = Faraday.get("#{GRAPH_URL}#{path}", params_hash)
    body = JSON.parse(response.body.presence || '{}')
    raise "Meta Graph API error: #{body.dig('error', 'message') || response.status}" unless response.success? && body['error'].blank?

    body
  end

  def meta_oauth_configured?
    meta_app_id.present? && meta_app_secret.present?
  end

  def meta_app_id
    @meta_app_id ||= GlobalConfigService.load('META_APP_ID', nil).presence
  end

  def meta_app_secret
    @meta_app_secret ||= GlobalConfigService.load('META_APP_SECRET', nil).presence
  end
end

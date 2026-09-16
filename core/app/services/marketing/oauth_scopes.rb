module Marketing::OauthScopes
  META = %w[
    ads_read
    ads_management
    leads_retrieval
    pages_manage_metadata
    pages_show_list
    pages_read_engagement
    business_management
  ].join(',').freeze

  GOOGLE_ADS = 'https://www.googleapis.com/auth/adwords'.freeze
  GA4_READONLY = 'https://www.googleapis.com/auth/analytics.readonly'.freeze

  # O fluxo Google do marketing pede os dois scopes de uma vez: um unico
  # consentimento cria/atualiza as conexoes google_ads e ga4 da conta.
  GOOGLE_ALL = [GOOGLE_ADS, GA4_READONLY, 'email', 'profile'].join(' ').freeze

  def self.for(provider)
    case provider
    when 'meta_ads' then META
    when 'google_ads', 'ga4' then GOOGLE_ALL
    end
  end
end

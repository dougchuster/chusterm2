module Enterprise; end unless defined?(Enterprise)

module Enterprise::ChusteRMHub
  ENTERPRISE_BASE_URL = 'https://hub.2.chusterm.com'.freeze

  def base_url
    return ENV.fetch('ChusteRM_HUB_URL', ENTERPRISE_BASE_URL) if Rails.env.development?

    ENTERPRISE_BASE_URL
  end
end

Enterprise::ChatwootHub = Enterprise::ChusteRMHub unless defined?(Enterprise::ChatwootHub)

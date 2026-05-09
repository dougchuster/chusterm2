# Garante que o branding no banco (InstallationConfig) reflita ChusteRM.
# Roda apenas se DB e tabela estiverem disponíveis — evita ruído em rake tasks,
# asset precompile e contextos onde a conexão usaria fallback (127.0.0.1).
Rails.application.config.after_initialize do
  next unless defined?(InstallationConfig)

  begin
    next unless ActiveRecord::Base.connection.data_source_exists?('installation_configs')
  rescue StandardError
    next
  end

  brand_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3010')
  branding = {
    'INSTALLATION_NAME' => 'ChusteRM',
    'BRAND_NAME'        => 'ChusteRM',
    'BRAND_URL'         => brand_url,
    'WIDGET_BRAND_URL'  => brand_url,
    'TERMS_URL'         => ENV.fetch('TERMS_URL', 'https://www.chusterm.com/terms-of-service'),
    'PRIVACY_URL'       => ENV.fetch('PRIVACY_URL', 'https://www.chusterm.com/privacy-policy'),
    'LOGO'              => '/brand-assets/logo.svg',
    'LOGO_DARK'         => '/brand-assets/logo_dark.svg',
    'LOGO_THUMBNAIL'    => '/brand-assets/logo_thumbnail.svg'
  }

  branding.each do |key, value|
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.save!
  rescue StandardError => e
    Rails.logger.warn "[ChusteRM] Branding init skipped for #{key}: #{e.class}: #{e.message}"
  end

  GlobalConfig.clear_cache rescue nil
end

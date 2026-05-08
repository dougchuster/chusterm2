# Garante que o branding no banco (InstallationConfig) reflita ChusteRM.
# Executa na inicialização apenas se os valores ainda estiverem como Chatwoot.
Rails.application.config.after_initialize do
  branding = {
    'INSTALLATION_NAME' => 'ChusteRM',
    'BRAND_NAME'        => 'ChusteRM',
    'BRAND_URL'         => ENV.fetch('FRONTEND_URL', 'http://localhost:3010'),
    'LOGO'              => '/brand-assets/logo.svg',
    'LOGO_DARK'         => '/brand-assets/logo_dark.svg',
    'LOGO_THUMBNAIL'    => '/brand-assets/logo_thumbnail.svg'
  }

  branding.each do |key, value|
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.save!
  rescue StandardError => e
    Rails.logger.warn "[ChusteRM] Branding init error for #{key}: #{e.message}"
  end

  GlobalConfig.clear_cache rescue nil
end

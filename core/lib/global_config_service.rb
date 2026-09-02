class GlobalConfigService
  def self.load(config_key, default_value)
    config = GlobalConfig.get(config_key)[config_key]
    return config if config.present?

    # To support migrating existing instance relying on env variables
    # TODO: deprecate this later down the line
    config_value = ENV.fetch(config_key) { default_value }

    return if config_value.blank?

    installation_config = persist_config(config_key, config_value)
    # To clear a nil value that might have been cached in the previous call
    GlobalConfig.clear_cache
    installation_config.value.presence || config_value
  end

  def self.persist_config(config_key, config_value)
    installation_config = InstallationConfig.find_or_initialize_by(name: config_key)
    if installation_config.new_record?
      installation_config.update!(value: config_value, locked: false)
    elsif installation_config.value.blank? && !installation_config.locked?
      installation_config.update!(value: config_value)
    end

    installation_config
  end
  private_class_method :persist_config

  def self.account_signup_enabled?
    load('ENABLE_ACCOUNT_SIGNUP', 'false').to_s != 'false'
  end
end

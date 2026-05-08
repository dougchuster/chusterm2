module Enterprise::Internal::CheckNewVersionsJob
  def perform
    super
    update_plan_info
    reconcile_premium_config_and_features
  end

  private

  def update_plan_info
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: ChusteRMApp.max_limit)
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end

  def reconcile_premium_config_and_features
    Internal::ReconcilePlanConfigService.new.perform
  end
end

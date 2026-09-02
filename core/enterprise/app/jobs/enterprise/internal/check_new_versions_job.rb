module Enterprise::Internal::CheckNewVersionsJob
  def perform
    super
    update_plan_info
    reconcile_premium_config_and_features
  end

  private

  def update_plan_info
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: @instance_info['plan'].presence || 'enterprise')
    update_installation_config(
      key: 'INSTALLATION_PRICING_PLAN_QUANTITY',
      value: @instance_info['plan_quantity'].presence || ChusteRMApp.max_limit
    )

    {
      'ChusteRM_support_website_token' => 'ChusteRM_SUPPORT_WEBSITE_TOKEN',
      'ChusteRM_support_identifier_hash' => 'ChusteRM_SUPPORT_IDENTIFIER_HASH',
      'ChusteRM_support_script_url' => 'ChusteRM_SUPPORT_SCRIPT_URL'
    }.each do |source_key, config_key|
      update_installation_config(key: config_key, value: @instance_info[source_key]) if @instance_info[source_key].present?
    end
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

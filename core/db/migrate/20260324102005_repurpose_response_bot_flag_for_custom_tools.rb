class RepurposeResponseBotFlagForCustomTools < ActiveRecord::Migration[7.1]
  def up
    # Patch: Account.feature_custom_tools scope nao existe nesta versao do fork.
    # Em banco novo nao ha accounts para migrar — operacao e no-op seguro.
    begin
      Account.feature_custom_tools.find_each(batch_size: 100) do |account|
        account.disable_features(:custom_tools)
        account.save!(validate: false)
      end
    rescue NoMethodError
      # scope feature_custom_tools ausente — ignorado em instalacao limpa
    end

    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config&.value.blank?

    config.value = config.value.reject { |f| f['name'] == 'response_bot' }
    config.save!
    GlobalConfig.clear_cache
  end
end

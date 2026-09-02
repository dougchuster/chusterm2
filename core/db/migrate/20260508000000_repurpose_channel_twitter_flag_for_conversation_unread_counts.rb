class RepurposeChannelTwitterFlagForConversationUnreadCounts < ActiveRecord::Migration[7.1]
  def up
    # This fork still exposes the original channel_twitter feature and does not
    # define the upstream replacement scope. Mark the upstream migration as
    # applied without mutating the active Twitter flag until the fork adopts the
    # renamed feature.
    return unless Account.respond_to?(:feature_conversation_unread_counts)

    Account.feature_conversation_unread_counts.find_each(batch_size: 100) do |account|
      account.disable_features(:conversation_unread_counts)
      account.save!(validate: false)
    end

    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config&.value.blank?

    config.value = config.value.reject { |feature| feature['name'] == 'channel_twitter' }
    config.save!
    GlobalConfig.clear_cache
  end
end

namespace :crm do
  desc 'Ensures each CRM-enabled inbox has an exclusive CRM pipeline'
  task ensure_channel_pipelines: :environment do
    scope = ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV['ACCOUNT_ID']) : Account.all
    summary = []

    scope.find_each do |account|
      pipelines = Crm::ChannelPipelineProvisioner.perform_for_account(
        account,
        move_existing_deals: ActiveModel::Type::Boolean.new.cast(ENV['MOVE_EXISTING_DEALS'])
      )

      summary << {
        account_id: account.id,
        inboxes: account.inboxes.count,
        channel_pipelines: pipelines.compact.count,
        total_pipelines: account.crm_pipelines.count
      }
    end

    puts JSON.pretty_generate(summary)
  end
end

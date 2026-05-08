namespace :crm do
  desc 'Run a non-destructive CRM operational smoke. Usage: bin/rails crm:operational_smoke ACCOUNT_ID=1'
  task operational_smoke: :environment do
    account = ENV['ACCOUNT_ID'].present? ? Account.find_by(id: ENV['ACCOUNT_ID']) : Account.first
    abort('Account not found') unless account

    actor = account.users.first || User.first
    abort("No user found for account #{account.id}") unless actor

    old_queue_adapter = ActiveJob::Base.queue_adapter
    old_delivery_method = ActionMailer::Base.delivery_method
    old_perform_deliveries = ActionMailer::Base.perform_deliveries

    created = {}

    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear

    created[:label] = account.labels.create!(
      title: "smoke-email-#{SecureRandom.hex(3)}",
      color: '#3457d5'
    )
    created[:contact] = account.contacts.create!(name: 'Smoke Email Cliente')
    created[:contact].update_columns(
      email: "smoke-#{SecureRandom.hex(3)}@example.com",
      updated_at: Time.current
    )
    created[:contact].update_labels([created[:label].title])

    schedule = Crm::ScheduleSuggestionService.new(
      account: account,
      owner: actor,
      params: {
        from: Time.current.change(hour: 9, min: 0, sec: 0).iso8601,
        to: (Time.current + 2.days).change(hour: 18, min: 0, sec: 0).iso8601,
        contact_id: created[:contact].id,
        kind: 'reuniao',
        priority: 'alta',
        duration_minutes: 60
      }
    ).perform
    raise 'CRM smoke failed: schedule suggestions are empty' if schedule[:suggestions].blank?

    audience = [{ type: 'Label', id: created[:label].id }]
    preview = Campaigns::AudienceResolver.new(account, audience, actor).preview
    raise 'CRM smoke failed: audience total mismatch' unless preview[:summary][:total].to_i == 1
    raise 'CRM smoke failed: audience with_email mismatch' unless preview[:summary][:with_email].to_i == 1

    created[:channel] = Channel::Email.create!(
      account: account,
      email: "smoke-inbox-#{SecureRandom.hex(3)}@example.com",
      forward_to_email: "forward-#{SecureRandom.hex(3)}@example.com"
    )
    created[:inbox] = Inbox.create!(account: account, channel: created[:channel], name: 'Smoke Email')
    created[:campaign] = account.campaigns.create!(
      inbox: created[:inbox],
      sender: actor,
      title: 'Smoke Email Marketing',
      message: 'Ola {{contact.name}}, smoke operacional.',
      audience: audience,
      scoring_config: {}
    )

    Email::OneoffCampaignService.new(campaign: created[:campaign]).perform
    raise 'CRM smoke failed: email was not rendered' if ActionMailer::Base.deliveries.empty?
    raise 'CRM smoke failed: campaign was not completed' unless created[:campaign].reload.completed?

    result = {
      status: 'ok',
      account_id: account.id,
      schedule_suggestions: schedule[:suggestions].size,
      audience_total: preview[:summary][:total],
      rendered_emails: ActionMailer::Base.deliveries.size,
      campaign_status: created[:campaign].campaign_status
    }

    puts JSON.pretty_generate(result)
  ensure
    created[:inbox].working_hours.destroy_all if created[:inbox]&.persisted? && created[:inbox].respond_to?(:working_hours)

    [created[:campaign], created[:inbox], created[:channel], created[:contact], created[:label]].compact.each do |record|
      record.destroy if record.persisted?
    rescue StandardError => e
      Rails.logger.warn("[CRM Smoke] cleanup failed for #{record.class.name} #{record.id}: #{e.message}")
    end

    ActiveJob::Base.queue_adapter = old_queue_adapter if defined?(old_queue_adapter) && old_queue_adapter
    ActionMailer::Base.delivery_method = old_delivery_method if defined?(old_delivery_method) && old_delivery_method
    ActionMailer::Base.perform_deliveries = old_perform_deliveries unless old_perform_deliveries.nil?
  end
end

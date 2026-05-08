namespace :crm do
  desc 'Print CRM/Captain operational health as JSON. Usage: crm:health_check ACCOUNT_ID=1 STRICT=true'
  task health_check: :environment do
    account_id = ENV.fetch('ACCOUNT_ID', nil)
    account = account_id.present? ? Account.find_by(id: account_id) : Account.first
    abort('Account not found') unless account

    result = Crm::HealthCheckService.new(account: account).perform
    puts JSON.pretty_generate(result)

    if ActiveModel::Type::Boolean.new.cast(ENV.fetch('STRICT', false)) && result[:status] != 'ok'
      abort("CRM health check requires attention for account #{account.id}")
    end
  end
end

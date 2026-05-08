namespace :crm do
  desc 'Seed standard legal CRM labels for one account. Usage: bin/rails crm:seed_legal_labels ACCOUNT_ID=1'
  task seed_legal_labels: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    account = Account.find(account_id)

    Crm::LegalLabelSeedService.new(account).perform
    puts "Seeded legal CRM labels for account #{account.id}"
  end
end

namespace :captain do
  desc 'Seed default legal CRM playbooks for an account'
  task seed_playbooks: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    account = Account.find(account_id)
    assistant = account.captain_assistants.find_by(id: ENV['ASSISTANT_ID']) if ENV['ASSISTANT_ID'].present?

    playbooks = Captain::DefaultPlaybooksSeeder.new(account, assistant: assistant).perform
    puts "Created or found #{playbooks.size} Captain playbooks for account #{account.id}"
  end
end

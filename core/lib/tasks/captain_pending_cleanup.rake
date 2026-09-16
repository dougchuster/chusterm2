namespace :captain do
  # Cleans up artifacts produced by the pending-conversation auto-resolve sweep.
  #
  # Usage:
  #   bundle exec rake captain:cleanup_pending_sweep ACCOUNT_ID=1 [INBOX_ID=3] [SINCE=2026-09-01] [DRY_RUN=false]
  #
  # DRY_RUN defaults to true — it only reports what would change. Take a DB
  # backup before running with DRY_RUN=false: deletions are not reversible.
  desc 'Clean review notes, failed Captain messages and hand off pending conversations'
  task cleanup_pending_sweep: :environment do
    Captain::PendingSweepCleanup.new(
      account: Account.find(ENV.fetch('ACCOUNT_ID')),
      inbox_id: ENV['INBOX_ID'].presence,
      since: ENV['SINCE'].present? ? Time.zone.parse(ENV['SINCE']) : nil,
      dry_run: ENV.fetch('DRY_RUN', 'true') != 'false'
    ).perform
  end
end

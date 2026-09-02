# Usage:
#   APPLY=true ACCOUNT_ID=1 bundle exec rails runner \
#     scripts/crm/repair_duplicate_system_activities.rb
#
# The repair never deletes activities. Older duplicates are marked as completed
# and the newest pending action remains available to the team.

apply_changes = ActiveModel::Type::Boolean.new.cast(ENV.fetch('APPLY', 'false'))
account_scope =
  if ENV['ACCOUNT_ID'].present?
    Account.where(id: ENV['ACCOUNT_ID'])
  else
    Account.all
  end

completed_at = Time.current
stale_completed = 0
health_completed = 0

account_scope.find_each do |account|
  stale_scope = account.crm_activities
                       .pending
                       .where(kind: Crm::StaleDetectorJob::STALE_ACTIVITY_KIND, created_by_type: 'system')
                       .where('title LIKE ?', 'Retomar deal parado em "%')
                       .where.not(crm_deal_id: nil)

  stale_duplicate_ids = stale_scope
                        .order(created_at: :desc, id: :desc)
                        .pluck(:crm_deal_id, :id)
                        .group_by(&:first)
                        .values
                        .flat_map { |rows| rows.drop(1).map(&:last) }

  health_scope = account.crm_activities
                        .pending
                        .where(
                          kind: 'revisao_juridica',
                          title: Crm::HealthCheckJob::ALERT_TITLE,
                          created_by_type: 'system'
                        )
  health_duplicate_ids = health_scope
                         .order(created_at: :desc, id: :desc)
                         .offset(1)
                         .pluck(:id)

  puts [
    'ACCOUNT_ACTIVITY_REPAIR',
    "account_id=#{account.id}",
    "apply=#{apply_changes}",
    "stale_duplicates=#{stale_duplicate_ids.length}",
    "health_duplicates=#{health_duplicate_ids.length}",
  ].join(' ')

  next unless apply_changes

  if stale_duplicate_ids.any?
    stale_completed += account.crm_activities
                              .where(id: stale_duplicate_ids)
                              .update_all(
                                completed_at: completed_at,
                                updated_at: completed_at,
                                outcome: 'Encerrada automaticamente: alerta de inatividade duplicado.'
                              )
  end

  if health_duplicate_ids.any?
    health_completed += account.crm_activities
                               .where(id: health_duplicate_ids)
                               .update_all(
                                 completed_at: completed_at,
                                 updated_at: completed_at,
                                 outcome: 'Encerrada automaticamente: alerta de saúde duplicado.'
                               )
  end

  Crm::AuditLogger.log(
    account: account,
    actor: nil,
    action: 'duplicate_system_activities_repaired',
    target: account,
    payload: {
      stale_completed: stale_duplicate_ids.length,
      health_completed: health_duplicate_ids.length
    }
  )
end

puts [
  'SYSTEM_ACTIVITY_REPAIR_COMPLETE',
  "apply=#{apply_changes}",
  "stale_completed=#{stale_completed}",
  "health_completed=#{health_completed}",
].join(' ')

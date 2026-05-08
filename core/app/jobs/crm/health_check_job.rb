class Crm::HealthCheckJob < ApplicationJob
  queue_as :default

  ALERT_TITLE = 'Revisar saude CRM/Captain'.freeze

  def perform(account_id: nil)
    scope = account_id.present? ? Account.where(id: account_id) : Account.all
    scope.find_each { |account| check_account(account) }
  end

  private

  def check_account(account)
    result = Crm::HealthCheckService.new(account: account).perform
    log_health_result(account, result)
    create_attention_activity(account, result) if result[:status] == 'attention'
  end

  def log_health_result(account, result)
    Crm::AuditLogger.log(
      account: account,
      actor: nil,
      action: "crm_health_#{result[:status]}",
      target: account,
      payload: summarized_payload(result)
    )
  end

  def create_attention_activity(account, result)
    return if recent_attention_activity?(account)

    account.crm_activities.create!(
      kind: 'revisao_juridica',
      title: ALERT_TITLE,
      description: attention_description(result),
      priority: 'alta',
      due_at: 4.hours.from_now,
      created_by_type: 'system'
    )
  end

  def recent_attention_activity?(account)
    account.crm_activities.pending
           .where(kind: 'revisao_juridica', title: ALERT_TITLE, created_by_type: 'system')
           .where('created_at > ?', 24.hours.ago)
           .exists?
  end

  def attention_description(result)
    [
      "Status: #{result[:status]}",
      "Leads quentes sem responsavel: #{result.dig(:deals, :hot_leads_without_owner)}",
      "Labels sistemicas no menu: #{result.dig(:labels, :system_visible_on_sidebar)}",
      "Midias paradas: #{result.dig(:media, :stale_processing)}"
    ].join("\n")
  end

  def summarized_payload(result)
    result.slice(:status, :contacts, :deals, :labels, :media, :activities, :captain)
  end
end

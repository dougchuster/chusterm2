class Crm::AuditLogger
  # rubocop:disable Metrics/ParameterLists
  def self.log(account:, action:, target:, actor: nil, payload: {}, ip: nil, user_agent: nil)
    actor_type = actor.is_a?(User) ? 'user' : (actor ? actor.class.name : 'system')
    actor_id = actor.respond_to?(:id) ? actor.id : nil

    CrmAuditEvent.create!(
      account: account,
      actor_type: actor_type,
      actor_id: actor_id,
      action: action,
      target_type: target.class.name,
      target_id: target.id,
      payload: payload,
      ip: ip,
      user_agent: user_agent,
      created_at: Time.current
    )
  rescue StandardError => e
    # Falha de auditoria nunca derruba o request, mas também não pode sumir:
    # loga com backtrace e reporta ao tracker (Sentry, quando SENTRY_DSN está
    # configurado — ver ChusteRMExceptionTracker).
    Rails.logger.error("[CRM AuditLogger] #{e.class}: #{e.message}\n#{Array(e.backtrace).first(10).join("\n")}")
    ChusteRMExceptionTracker.new(e).capture_exception
    nil
  end
  # rubocop:enable Metrics/ParameterLists
end

class Crm::AuditLogger
  def self.log(account:, action:, target:, actor: nil, payload: {})
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
      created_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("[CRM AuditLogger] #{e.message}")
  end
end

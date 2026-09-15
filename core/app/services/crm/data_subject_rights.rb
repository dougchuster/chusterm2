# CRM-045 — Direitos do titular (LGPD arts. 18-20): exportação e eliminação.
#
# O operador executa a pedido do titular (self-service operacional): export
# devolve um bundle JSON com tudo que a conta guarda sobre o contato;
# erase! anonimiza PII mantendo integridade referencial — deals e
# atividades continuam existindo, mas sem apontar dados identificáveis.
# Ambas as operações registram CrmAuditEvent (o apagamento precisa ser
# auditável mesmo depois que a PII some).
class Crm::DataSubjectRights
  ANONYMIZED_NAME = 'Titular anonimizado'.freeze

  def initialize(contact:, actor: nil)
    @contact = contact
    @account = contact.account
    @actor = actor
  end

  def export
    {
      contact: contact_payload,
      deals: @contact.crm_deals.order(:id).map { |d| deal_payload(d) },
      activities: activities_payload,
      exported_at: Time.current.iso8601
    }.tap { audit('lgpd_export') }
  end

  def erase!
    ActiveRecord::Base.transaction do
      @contact.update!(
        name: ANONYMIZED_NAME,
        email: nil,
        phone_number: nil,
        identifier: nil,
        custom_attributes: {},
        additional_attributes: @contact.additional_attributes.except(
          'social_profiles', 'screen_name', 'location', 'description', 'company_name',
          'city', 'country', 'country_code', 'referer'
        ).merge('lgpd_anonymized_at' => Time.current.iso8601)
      )
      @contact.avatar.purge if @contact.avatar.attached?
      audit('lgpd_erasure')
    end
    true
  end

  private

  def contact_payload
    @contact.as_json(only: %i[
                       id name email phone_number identifier custom_attributes
                       additional_attributes created_at updated_at
                     ])
  end

  def deal_payload(deal)
    deal.as_json(only: %i[
                   id title status operational_status value_estimate_cents score_total
                   urgency_level legal_area lgpd_basis consent_status consent_channel
                   consent_collected_at data_retention_until created_at updated_at
                 ])
  end

  def activities_payload
    deal_ids = @contact.crm_deals.select(:id)
    CrmActivity.where(account: @account)
               .where(contact_id: @contact.id)
               .or(CrmActivity.where(account: @account, crm_deal_id: deal_ids))
               .order(:id)
               .as_json(only: %i[id kind title notes due_at completed_at created_at])
  end

  def audit(action)
    Crm::AuditLogger.log(
      account: @account, action: action, target: @contact, actor: @actor,
      payload: { contact_id: @contact.id }
    )
  end
end

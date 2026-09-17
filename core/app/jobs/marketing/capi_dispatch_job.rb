# Fecha o loop: deal veio de Lead Ads -> mudança de estágio/status sobe
# um evento server-side para a Meta Conversions API.
class Marketing::CapiDispatchJob < ApplicationJob
  queue_as :low

  def perform(deal_id)
    deal = CrmDeal.includes(:crm_pipeline_stage, :contact).find_by(id: deal_id)
    return if deal.nil?
    return log_consent_block(deal) if deal.consent_status == 'denied'

    connection = ads_connection_for(deal)
    return if connection.nil?

    Marketing::Meta::CapiService.new(connection: connection)
                                .send_stage_event(
                                  deal: deal,
                                  lead: lead_for(deal),
                                  stage: deal.crm_pipeline_stage
                                )
  end

  private

  # LGPD: consentimento negado no deal impede envio de dados pessoais à Meta.
  # O bloqueio fica auditado — sem ele, um "não" do titular viraria evento
  # silenciosamente descartado e ninguém saberia por que o CAPI parou.
  def log_consent_block(deal)
    Crm::AuditLogger.log(
      account: deal.account,
      action: 'capi_blocked_no_consent',
      target: deal,
      payload: { consent_status: deal.consent_status, stage_slug: deal.crm_pipeline_stage&.slug }
    )
    nil
  end

  def lead_for(deal)
    deal.account.marketing_leads
        .where(contact_id: deal.contact_id)
        .where.not(crm_external_connection_id: nil)
        .recent_first
        .first
  end

  def ads_connection_for(deal)
    connection = lead_for(deal)&.crm_external_connection
    return unless connection&.provider == 'meta_ads' && connection.status == 'active'
    return if connection.metadata&.dig('capi_dataset_id').blank?

    connection
  end
end

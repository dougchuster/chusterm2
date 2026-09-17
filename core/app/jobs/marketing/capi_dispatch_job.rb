# Fecha o loop: deal veio de Lead Ads -> mudança de estágio/status sobe
# um evento server-side para a Meta Conversions API.
class Marketing::CapiDispatchJob < ApplicationJob
  queue_as :low

  def perform(deal_id)
    deal = CrmDeal.includes(:crm_pipeline_stage, :contact).find_by(id: deal_id)
    return if deal.nil?

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

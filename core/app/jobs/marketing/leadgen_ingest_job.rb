# Consome um leadgen_id do webhook Meta: busca os dados na Graph API,
# cria/atualiza Contact, cria MarketingLead e opcionalmente CrmDeal.
class Marketing::LeadgenIngestJob < ApplicationJob
  queue_as :default

  def perform(leadgen_id, context = {})
    return if leadgen_id.blank?

    connection = find_connection(context['page_id'])
    return log_drop(leadgen_id, 'no active meta_ads connection') if connection.nil?

    fields = fetch_fields(connection, leadgen_id)
    return log_drop(leadgen_id, 'lead not found on graph api') if fields.nil?

    Marketing::LeadToCrmService.new(
      account: connection.account,
      connection: connection,
      leadgen_id: leadgen_id,
      fields: fields,
      context: context
    ).perform
  end

  private

  def find_connection(page_id)
    scope = CrmExternalConnection.where(provider: 'meta_ads', status: 'active')
    return scope.find_by("metadata->>'page_id' = ?", page_id) if page_id.present?

    scope.first
  end

  def fetch_fields(connection, leadgen_id)
    Marketing::Meta::GraphClient.new(access_token: connection.access_token)
                                .leadgen_form_data(leadgen_id)
  rescue Marketing::Meta::GraphClient::ApiError, Marketing::Meta::GraphClient::RateLimited => e
    Rails.logger.warn("[Marketing::Leadgen] graph error for #{leadgen_id}: #{e.message}")
    nil
  end

  def log_drop(leadgen_id, reason)
    Rails.logger.warn("[Marketing::Leadgen] dropped #{leadgen_id}: #{reason}")
  end
end

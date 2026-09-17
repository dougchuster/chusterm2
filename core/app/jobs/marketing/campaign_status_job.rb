# Escrita governada na Meta: aplica status (PAUSED/ACTIVE) numa campanha
# somente quando a conexão tem ads_write_enabled. Toda tentativa vira um
# MarketingEvent outbound (sent/failed) — trilha de auditoria do lado de fora.
class Marketing::CampaignStatusJob < ApplicationJob
  queue_as :medium
  retry_on Marketing::Meta::GraphClient::RateLimited, wait: :polynomially_longer, attempts: 4

  ALLOWED_STATUSES = %w[PAUSED ACTIVE].freeze

  def perform(campaign_id, status)
    campaign = MarketingCampaign.includes(:crm_external_connection).find_by(id: campaign_id)
    return unless campaign && ALLOWED_STATUSES.include?(status)

    connection = campaign.crm_external_connection
    return unless writable_meta_connection?(connection)

    event = log_event(campaign, connection, status)
    Marketing::Meta::GraphClient.new(access_token: connection.access_token).update_campaign_status(campaign.external_id, status)
    campaign.update!(status: status)
    event.update!(status: 'sent', sent_at: Time.current)
  rescue Marketing::Meta::GraphClient::RateLimited
    raise
  rescue StandardError => e
    event&.update!(status: 'failed', response: { error: "#{e.class}: #{e.message}" })
    raise
  end

  private

  def writable_meta_connection?(connection)
    connection&.provider == 'meta_ads' && connection.status == 'active' &&
      connection.metadata&.dig('ads_write_enabled').present?
  end

  def log_event(campaign, connection, status)
    campaign.account.marketing_events.create!(
      crm_external_connection: connection,
      provider: 'meta_ads',
      direction: 'outbound',
      event_name: 'set_campaign_status',
      event_id: "set_status_#{campaign.id}_#{status}_#{SecureRandom.hex(6)}",
      status: 'pending',
      payload: { campaign_external_id: campaign.external_id, status: status }
    )
  end
end

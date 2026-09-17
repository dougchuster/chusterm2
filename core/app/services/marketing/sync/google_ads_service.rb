# Sync Google Ads: campanhas + metricas diarias via GAQL por customer id.
class Marketing::Sync::GoogleAdsService < Marketing::Sync::BaseService
  private

  def sync
    customer_ids.each do |customer_id|
      sync_campaigns_for(customer_id)
      sync_metrics_for(customer_id)
    end
    { campaigns: @account.marketing_campaigns.where(crm_external_connection_id: @connection.id).count }
  end

  def client
    @client ||= begin
      developer_token = GlobalConfigService.load('GOOGLE_ADS_DEVELOPER_TOKEN', nil)
      raise 'GOOGLE_ADS_DEVELOPER_TOKEN nao configurado' if developer_token.blank?

      Marketing::GoogleAds::Client.new(
        access_token: fresh_google_token,
        developer_token: developer_token,
        login_customer_id: @connection.metadata&.dig('login_customer_id')
      )
    end
  end

  def customer_ids
    stored = Array(@connection.metadata&.dig('customer_ids'))
    return stored if stored.present?

    ids = client.accessible_customers
    @connection.update!(metadata: @connection.metadata.merge('customer_ids' => ids))
    ids
  end

  def sync_campaigns_for(customer_id)
    client.campaigns(customer_id).each do |result|
      campaign = result['campaign'] || {}
      upsert_campaign(
        provider: 'google_ads',
        external_id: campaign['id'].to_s,
        level: 'campaign',
        name: campaign['name'],
        status: campaign['status'],
        objective: campaign['advertising_channel_type'],
        daily_budget: micros_to_units(result.dig('campaign_budget', 'amount_micros')),
        currency: nil,
        metadata: { 'customer_id' => customer_id }
      )
    end
  end

  def sync_metrics_for(customer_id)
    client.daily_metrics(customer_id, date_from: @date_from, date_to: @date_to).each do |result|
      campaign = find_campaign('google_ads', 'campaign', result.dig('campaign', 'id').to_s)
      next if campaign.nil?

      metrics = result['metrics'] || {}
      upsert_snapshot(campaign, result.dig('segments', 'date'),
                      impressions: metrics['impressions'],
                      clicks: metrics['clicks'],
                      spend: micros_to_units(metrics['cost_micros']),
                      leads: metrics['leads'],
                      conversions: metrics['conversions'],
                      conversion_value: metrics['conversions_value'])
    end
  end
end

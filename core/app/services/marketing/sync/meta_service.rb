# Sync Meta Ads: campanhas + insights diarios por ad account.
class Marketing::Sync::MetaService < Marketing::Sync::BaseService
  private

  def sync
    ad_accounts.each do |ad_account|
      sync_campaigns_for(ad_account)
      sync_insights_for(ad_account)
    end
    { campaigns: @account.marketing_campaigns.where(crm_external_connection_id: @connection.id).count }
  end

  def client
    @client ||= Marketing::Meta::GraphClient.new(access_token: @connection.access_token)
  end

  def ad_accounts
    stored = Array(@connection.metadata&.dig('ad_accounts'))
    return stored.map { |a| { 'id' => a['id'], 'currency' => a['currency'] } } if stored.present?

    client.get_all('/me/adaccounts', params: { fields: 'id,currency' })
  end

  def sync_campaigns_for(ad_account)
    client.campaigns_for(ad_account['id']).each do |raw|
      upsert_campaign(
        provider: 'meta_ads',
        external_id: raw['id'],
        level: 'campaign',
        name: raw['name'],
        status: raw['status'],
        objective: raw['objective'],
        daily_budget: micros_to_units(raw['daily_budget']),
        currency: ad_account['currency'] || raw['currency'],
        metadata: { 'ad_account_id' => ad_account['id'] }
      )
    end
  end

  def sync_insights_for(ad_account)
    rows = client.insights_for(ad_account['id'], level: 'campaign', date_from: @date_from, date_to: @date_to)
    rows.each do |row|
      campaign = find_campaign('meta_ads', 'campaign', row['campaign_id'])
      next if campaign.nil?

      upsert_snapshot(campaign, row['date_start'] || @date_to,
                      impressions: row['impressions'],
                      clicks: row['clicks'],
                      spend: row['spend'],
                      leads: action_count(row, 'lead'),
                      conversions: action_count(row, 'offsite_conversion'),
                      conversion_value: action_value(row))
    end
  end

  def action_count(row, wanted)
    Array(row['actions']).sum do |action|
      action['action_type'].to_s.include?(wanted) ? action['value'].to_i : 0
    end
  end

  def action_value(row)
    Array(row['action_values']).sum { |v| v['value'].to_d }
  end
end

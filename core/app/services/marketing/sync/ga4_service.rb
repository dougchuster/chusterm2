# Sync GA4: cada property vira uma linha "campaign" e o trafego diario
# por origem/midia fica em snapshot.metadata (GA4 nao tem spend/impressoes).
class Marketing::Sync::Ga4Service < Marketing::Sync::BaseService
  private

  def sync
    properties.each do |property|
      campaign = upsert_property(property)
      sync_report(property_id_for(property), campaign)
    end
    { campaigns: @account.marketing_campaigns.where(crm_external_connection_id: @connection.id).count }
  end

  def client
    @client ||= Marketing::Ga4::Client.new(access_token: fresh_google_token)
  end

  def properties
    stored = Array(@connection.metadata&.dig('properties'))
    return stored if stored.present?

    found = client.account_summaries.flat_map do |summary|
      Array(summary['propertySummaries']).map { |p| p.merge('account' => summary['account']) }
    end
    @connection.update!(metadata: @connection.metadata.merge('properties' => found))
    found
  end

  def property_id_for(property)
    property['propertyId'] || property['property'].to_s.split('/').last
  end

  def upsert_property(property)
    upsert_campaign(
      provider: 'ga4',
      external_id: property_id_for(property).to_s,
      level: 'campaign',
      name: property['displayName'] || "GA4 #{property_id_for(property)}",
      status: 'ACTIVE',
      objective: 'analytics_property',
      daily_budget: nil,
      currency: property['currencyCode'],
      metadata: { 'property' => "properties/#{property_id_for(property)}" }
    )
  end

  def sync_report(property_id, campaign)
    report = client.daily_traffic(property_id, date_from: @date_from, date_to: @date_to)
    Array(report['rows']).each { |row| merge_traffic_row(campaign, row) }
  end

  def merge_traffic_row(campaign, row)
    date = row.dig('dimensionValues', 0, 'value')
    source = "#{row.dig('dimensionValues', 1, 'value')}/#{row.dig('dimensionValues', 2, 'value')}"
    metrics = {
      'sessions' => row.dig('metricValues', 0, 'value').to_i,
      'conversions' => row.dig('metricValues', 1, 'value').to_d,
      'users' => row.dig('metricValues', 2, 'value').to_i
    }

    snapshot = campaign.metric_snapshots.find_or_initialize_by(account_id: @account.id, date: date)
    snapshot.metadata = (snapshot.metadata || {}).merge("source:#{source}" => metrics)
    snapshot.conversions += metrics['conversions']
    snapshot.save!
  end
end

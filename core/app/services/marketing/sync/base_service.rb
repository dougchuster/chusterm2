# Base dos syncers de marketing: upserts idempotentes + persistencia comum.
# Subclasses implementam `sync` devolvendo um resumo (ex.: { campaigns: n }).
class Marketing::Sync::BaseService
  DEFAULT_RANGE_DAYS = 30

  def initialize(connection:, date_from: nil, date_to: nil)
    @connection = connection
    @account = connection.account
    @date_to = date_to || Date.current
    @date_from = date_from || (@date_to - DEFAULT_RANGE_DAYS.days)
  end

  def perform!
    result = sync
    stamp_connection!(status: 'active', synced: true)
    result
  rescue StandardError => e
    stamp_connection!(status: 'error', error: e.message)
    ChusteRMExceptionTracker.new(e).capture_exception
    raise e
  end

  private

  def upsert_campaign(attrs)
    @account.marketing_campaigns
            .find_or_initialize_by(
              crm_external_connection_id: @connection.id,
              level: attrs[:level],
              external_id: attrs[:external_id]
            ).tap do |campaign|
      campaign.assign_attributes(
        provider: attrs[:provider], name: attrs[:name], status: attrs[:status],
        objective: attrs[:objective], daily_budget: attrs[:daily_budget],
        currency: attrs[:currency],
        metadata: (campaign.metadata || {}).merge(attrs[:metadata] || {})
      )
      campaign.save!
    end
  end

  def upsert_snapshot(campaign, date, metrics)
    campaign.metric_snapshots
            .find_or_initialize_by(account_id: @account.id, date: date)
            .tap do |snapshot|
      snapshot.assign_attributes(
        impressions: metrics[:impressions].to_i,
        clicks: metrics[:clicks].to_i,
        spend: metrics[:spend].to_d,
        leads: metrics[:leads].to_i,
        conversions: metrics[:conversions].to_i,
        conversion_value: metrics[:conversion_value].to_d
      )
      snapshot.save!
    end
  end

  def find_campaign(provider, level, external_id)
    @account.marketing_campaigns.find_by(crm_external_connection_id: @connection.id,
                                         provider: provider, level: level,
                                         external_id: external_id)
  end

  def fresh_google_token
    return @connection.access_token unless @connection.token_expired?

    refreshed = Marketing::GoogleTokenRefresher.new(connection: @connection).refresh!
    @connection.reload
    refreshed
  end

  def micros_to_units(value)
    return nil if value.blank?

    (value.to_d / 1_000_000).round(2)
  end

  def stamp_connection!(status:, synced: false, error: nil)
    metadata = (@connection.metadata || {}).merge('last_synced_at' => Time.current.iso8601)
    metadata['last_error'] = error if error
    metadata.delete('last_error') if synced
    @connection.update!(status: status, metadata: metadata)
  end
end

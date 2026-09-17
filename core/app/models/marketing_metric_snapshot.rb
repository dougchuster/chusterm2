class MarketingMetricSnapshot < ApplicationRecord
  belongs_to :account
  belongs_to :marketing_campaign

  validates :date, uniqueness: { scope: :marketing_campaign_id }

  scope :between, ->(from, to) { where(date: from..to) }

  def self.totals
    pick(
      Arel.sql('COALESCE(SUM(impressions), 0) AS impressions'),
      Arel.sql('COALESCE(SUM(clicks), 0) AS clicks'),
      Arel.sql('COALESCE(SUM(spend), 0) AS spend'),
      Arel.sql('COALESCE(SUM(leads), 0) AS leads'),
      Arel.sql('COALESCE(SUM(conversions), 0) AS conversions'),
      Arel.sql('COALESCE(SUM(conversion_value), 0) AS conversion_value')
    )
  end
end

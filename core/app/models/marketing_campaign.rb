class MarketingCampaign < ApplicationRecord
  LEVELS = %w[campaign adset ad].freeze

  belongs_to :account
  belongs_to :crm_external_connection
  has_many :metric_snapshots,
           class_name: 'MarketingMetricSnapshot',
           dependent: :delete_all,
           inverse_of: :marketing_campaign

  validates :provider, inclusion: { in: CrmExternalConnection::MARKETING_PROVIDERS }
  validates :level, inclusion: { in: LEVELS }
  validates :external_id, uniqueness: { scope: %i[crm_external_connection_id level] }

  scope :campaigns_only, -> { where(level: 'campaign') }
  scope :for_provider, ->(provider) { where(provider: provider) }
  scope :active, -> { where(status: %w[ACTIVE ENABLED]) }

  def ctr
    clicks_d = metric_snapshots.sum(:clicks)
    impressions = metric_snapshots.sum(:impressions)
    return 0 if impressions.zero?

    (clicks_d.to_f / impressions) * 100
  end
end

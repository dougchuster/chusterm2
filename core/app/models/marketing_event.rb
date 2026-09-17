class MarketingEvent < ApplicationRecord
  STATUSES = %w[pending sent failed skipped].freeze

  belongs_to :account
  belongs_to :crm_external_connection, optional: true
  belongs_to :crm_deal, optional: true
  belongs_to :marketing_lead, optional: true

  validates :provider, :event_name, :event_id, presence: true
  validates :event_id, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :outbound, -> { where(direction: 'outbound') }
end

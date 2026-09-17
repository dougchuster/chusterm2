class CrmExternalConnection < ApplicationRecord
  PROVIDERS = %w[google_workspace meta_ads google_ads ga4].freeze
  MARKETING_PROVIDERS = %w[meta_ads google_ads ga4].freeze
  STATUSES = %w[active disconnected error].freeze

  belongs_to :account
  belongs_to :user, optional: true
  has_many :marketing_campaigns, dependent: :delete_all

  encryption_enabled = defined?(::ChusteRM) &&
                       ::ChusteRM.respond_to?(:encryption_configured?) &&
                       ::ChusteRM.encryption_configured?
  encrypts :access_token if encryption_enabled
  encrypts :refresh_token if encryption_enabled

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }

  scope :marketing, -> { where(provider: MARKETING_PROVIDERS, user_id: nil) }

  def active?
    status == 'active'
  end

  def marketing?
    MARKETING_PROVIDERS.include?(provider)
  end

  def token_expired?
    expires_at.blank? || Time.current.utc >= expires_at - 5.minutes
  end
end

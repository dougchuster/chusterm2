class CrmExternalConnection < ApplicationRecord
  PROVIDERS = %w[google_workspace].freeze
  STATUSES = %w[active disconnected error].freeze

  belongs_to :account
  belongs_to :user, optional: true

  encryption_enabled = defined?(::ChusteRM) &&
                       ::ChusteRM.respond_to?(:encryption_configured?) &&
                       ::ChusteRM.encryption_configured?
  encrypts :access_token if encryption_enabled
  encrypts :refresh_token if encryption_enabled

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }

  def active?
    status == 'active'
  end

  def token_expired?
    expires_at.blank? || Time.current.utc >= expires_at - 5.minutes
  end
end

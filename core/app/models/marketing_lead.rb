class MarketingLead < ApplicationRecord
  STATUSES = %w[new converted discarded].freeze

  belongs_to :account
  belongs_to :crm_external_connection, optional: true
  belongs_to :contact, optional: true
  belongs_to :crm_deal, optional: true

  validates :leadgen_id, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: 'new') }
  scope :recent_first, -> { order(created_at: :desc) }

  def display_name
    field_data['full_name'].presence ||
      field_data['name'].presence ||
      field_data['email'].presence ||
      "Lead #{leadgen_id}"
  end

  def email
    field_data['email'].presence
  end

  def phone
    raw = field_data['phone_number'].presence || field_data['phone'].presence
    return if raw.blank?

    raw.to_s.gsub(/[^\d+]/, '')
  end
end

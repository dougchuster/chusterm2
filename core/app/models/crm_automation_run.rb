class CrmAutomationRun < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account
  belongs_to :crm_automation_rule
  belongs_to :crm_deal

  STATUSES = %w[executed skipped failed].freeze

  validates :account, :crm_automation_rule, :crm_deal, :status, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates_same_account_for :crm_automation_rule, :crm_deal

  scope :recent, -> { order(started_at: :desc) }
  scope :for_deal, ->(deal_id) { where(crm_deal_id: deal_id) }
  scope :for_rule, ->(rule_id) { where(crm_automation_rule_id: rule_id) }
end

class CrmAutomationRule < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account
  belongs_to :crm_pipeline_stage

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :for_stage, ->(stage_id) { where(crm_pipeline_stage_id: stage_id) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  validates :account, :crm_pipeline_stage, :name, :action_type, presence: true
  validates_same_account_for :crm_pipeline_stage
  validates :trigger_event, inclusion: { in: %w[stage_entered score_changed stale_detected handoff message_received] }
  validates :action_type, inclusion: { in: %w[create_activity set_captain_mode move_to_stage assign_owner] }
end

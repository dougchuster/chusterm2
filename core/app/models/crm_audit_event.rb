class CrmAuditEvent < ApplicationRecord
  self.record_timestamps = false

  belongs_to :account

  validates :account, :actor_type, :action, :target_type, :target_id, presence: true

  scope :for_target, ->(type, id) { where(target_type: type, target_id: id) }
end

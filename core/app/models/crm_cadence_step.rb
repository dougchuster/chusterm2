class CrmCadenceStep < ApplicationRecord
  ACTION_TYPES = %w[send_message create_activity wait].freeze

  belongs_to :account
  belongs_to :crm_cadence

  validates :account, :crm_cadence, :name, :channel, :action_type, presence: true
  validates :channel, inclusion: { in: CrmCadence::CHANNELS }
  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :wait_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
end

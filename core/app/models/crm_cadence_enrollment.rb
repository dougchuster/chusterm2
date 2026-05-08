class CrmCadenceEnrollment < ApplicationRecord
  STATUSES = %w[active paused completed cancelled].freeze

  belongs_to :account
  belongs_to :crm_cadence
  belongs_to :crm_deal

  validates :status, inclusion: { in: STATUSES }
  validates :crm_deal_id, uniqueness: { scope: :crm_cadence_id, message: 'ja inscrito nesta cadencia' }

  scope :active, -> { where(status: 'active') }
  scope :due, -> { active.where('next_step_at <= ?', Time.current) }
  scope :paused, -> { where(status: 'paused') }

  def current_step
    crm_cadence.crm_cadence_steps.active.ordered.find_by(position: current_step_position)
  end

  def advance!
    next_steps = crm_cadence.crm_cadence_steps.active.ordered.where('position > ?', current_step_position)
    next_step = next_steps.first

    if next_step
      update!(
        current_step_position: next_step.position,
        next_step_at: next_step.wait_hours.hours.from_now
      )
    else
      update!(status: 'completed', completed_at: Time.current)
    end
  end

  def pause!
    update!(status: 'paused', paused_at: Time.current)
  end

  def resume!
    update!(status: 'active', paused_at: nil, next_step_at: 1.hour.from_now)
  end

  def cancel!
    update!(status: 'cancelled', cancelled_at: Time.current)
  end
end

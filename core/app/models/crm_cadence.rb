class CrmCadence < ApplicationRecord
  STATUSES = %w[draft active paused archived].freeze
  CHANNELS = %w[whatsapp email sms task].freeze

  belongs_to :account
  has_many :crm_cadence_steps, -> { order(position: :asc, id: :asc) }, dependent: :destroy
  has_many :crm_cadence_enrollments, dependent: :destroy

  validates :account, :name, :status, :channel, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: CHANNELS }

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(position: :asc, id: :asc) }

  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end
end

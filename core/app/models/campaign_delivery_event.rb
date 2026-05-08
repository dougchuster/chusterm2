class CampaignDeliveryEvent < ApplicationRecord
  EVENT_TYPES = %w[sent skipped failed delivered read replied converted].freeze

  belongs_to :account
  belongs_to :campaign
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
end

# frozen_string_literal: true

class EvolutionWebhookEvent < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :evolution_instance, optional: true

  enum status: {
    received: 'received',
    processing: 'processing',
    processed: 'processed',
    failed: 'failed',
    duplicate: 'duplicate'
  }, _prefix: true

  validates :event_name, :status, presence: true

  before_validation :derive_event_uid

  def processed!
    update!(status: 'processed', processed_at: Time.current, error_message: nil)
  end

  def failed!(error)
    update!(status: 'failed', error_message: error.to_s.truncate(1000), processed_at: Time.current)
  end

  private

  def derive_event_uid
    self.event_uid ||= [event_name, instance_name, message_id, payload_hash].compact_blank.join(':')
  end

  def payload_hash
    Digest::SHA256.hexdigest(payload.to_json)
  end
end

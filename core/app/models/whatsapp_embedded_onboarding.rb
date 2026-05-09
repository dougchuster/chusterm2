# frozen_string_literal: true

class WhatsappEmbeddedOnboarding < ApplicationRecord
  STATUSES = %w[not_connected connecting needs_number_selection provisioning connected error].freeze

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :inbox, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :waba_id, presence: true

  scope :for_account, ->(account) { where(account: account) }
  scope :pending, -> { where(status: %w[connecting needs_number_selection provisioning]) }

  def mark_connecting!
    update!(status: 'connecting', last_error: nil)
  end

  def mark_needs_number_selection!(phone_numbers)
    update!(
      status: 'needs_number_selection',
      metadata: metadata.merge('available_numbers' => phone_numbers)
    )
  end

  def mark_provisioning!
    update!(status: 'provisioning')
  end

  def mark_connected!(inbox:)
    update!(status: 'connected', inbox: inbox, completed_at: Time.current, last_error: nil)
  end

  def mark_error!(message)
    update!(status: 'error', last_error: message)
  end
end

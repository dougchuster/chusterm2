# frozen_string_literal: true

class EvolutionInstance < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :channel_whatsapp, class_name: 'Channel::Whatsapp', optional: true
  belongs_to :configuration, class_name: 'EvolutionApiConfiguration', foreign_key: :evolution_api_configuration_id, inverse_of: :evolution_instances
  has_many :evolution_webhook_events, dependent: :destroy

  before_validation :ensure_webhook_token
  before_validation :normalize_instance_name

  validates :instance_name, :webhook_token, :connection_state, :provisioning_status, presence: true
  validates :instance_name, uniqueness: { scope: :account_id }
  validates :webhook_token, uniqueness: true

  scope :managed, -> { where.not(evolution_api_configuration_id: nil) }

  def connected?
    %w[open connected].include?(connection_state.to_s.downcase)
  end

  def disconnected?
    %w[close closed disconnected logout removed].include?(connection_state.to_s.downcase)
  end

  def store_qr!(qr)
    return if qr.blank?

    update!(
      latest_qr: qr,
      latest_qr_hash: Digest::SHA256.hexdigest(qr.to_s),
      latest_qr_at: Time.current,
      provisioning_status: 'waiting_qr'
    )
  end

  def update_connection!(state:, error: nil)
    attrs = {
      connection_state: state.presence || 'unknown',
      last_error: error,
      last_sync_at: Time.current
    }

    if %w[open connected].include?(state.to_s.downcase)
      attrs[:last_connected_at] = Time.current
      attrs[:provisioning_status] = 'connected'
      attrs[:failure_count] = 0
      attrs[:circuit_open_until] = nil
    elsif %w[close closed disconnected logout removed].include?(state.to_s.downcase)
      attrs[:last_disconnected_at] = Time.current
      attrs[:provisioning_status] = 'disconnected'
    end

    update!(attrs)
  end

  def record_failure!(error)
    count = failure_count.to_i + 1
    update!(
      failure_count: count,
      last_error: error.to_s.truncate(1000),
      circuit_open_until: count >= 5 ? 2.minutes.from_now : circuit_open_until
    )
  end

  def circuit_open?
    circuit_open_until.present? && circuit_open_until.future?
  end

  private

  def ensure_webhook_token
    self.webhook_token ||= SecureRandom.urlsafe_base64(32)
  end

  def normalize_instance_name
    self.instance_name = instance_name.to_s.strip
  end
end

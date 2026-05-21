# frozen_string_literal: true

class EvolutionApiConfiguration < ApplicationRecord
  belongs_to :account
  has_many :evolution_instances, dependent: :destroy

  encrypts :global_api_key if ChusteRM.encryption_configured?

  validates :account_id, uniqueness: true
  validates :base_url, :webhook_base_url, :global_api_key, presence: true

  before_validation :normalize_urls

  def api_headers
    {
      'apikey' => global_api_key,
      'Content-Type' => 'application/json'
    }
  end

  def mark_health!(status:, error: nil)
    update!(
      health_status: status,
      last_health_check_at: Time.current,
      last_health_error: error
    )
  end

  private

  def normalize_urls
    self.base_url = base_url.to_s.strip.chomp('/')
    self.webhook_base_url = webhook_base_url.to_s.strip.chomp('/')
  end
end

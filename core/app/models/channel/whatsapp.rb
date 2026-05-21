# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string           not null
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number  (phone_number) UNIQUE
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud evolution].freeze
  before_validation :ensure_webhook_verify_token
  before_validation :normalize_evolution_phone_number

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true
  validates :phone_number,
            format: { with: /\A\+[1-9]\d{6,14}\z/ },
            if: :evolution_provider?

  validate :validate_provider_config

  has_one :evolution_instance, foreign_key: :channel_whatsapp_id, dependent: :destroy, inverse_of: :channel_whatsapp

  after_create :sync_templates
  before_destroy :teardown_webhooks
  after_commit :setup_webhooks, on: :create, if: :should_auto_setup_webhooks?

  def name
    'Whatsapp'
  end

  # Evolution (Baileys): persist connection / session diagnostics in provider_config for UI + ops.
  def evolution_update_health!(state:, error: nil)
    return unless provider == 'evolution'

    evolution_instance&.update_connection!(state: state, error: error)

    config = provider_config.to_h
    config['last_connection_state'] = state
    config['last_connection_error'] = error
    config['last_connection_event_at'] = Time.current.iso8601
    update!(provider_config: config)
  end

  def evolution_record_session_warning!(code:, detail:)
    return unless provider == 'evolution'

    config = provider_config.to_h.merge(
      'evolution_last_warning_code' => code,
      'evolution_last_warning_detail' => detail.to_s.truncate(800),
      'evolution_last_warning_at' => Time.current.iso8601
    )
    update!(provider_config: config)
    Rails.logger.warn "[EVOLUTION][#{phone_number}] #{code}: #{detail}"
  end

  def evolution_clear_session_warnings!
    return unless provider == 'evolution'

    config = provider_config.to_h.except(
      'evolution_last_warning_code',
      'evolution_last_warning_detail',
      'evolution_last_warning_at'
    )
    update!(provider_config: config)
  end

  def evolution_health_for_api
    cfg = provider_config || {}
    managed = evolution_instance
    {
      evolution_instance_id: managed&.id,
      instance_name: managed&.instance_name || cfg['instance_name'],
      connection_state: managed&.connection_state,
      provisioning_status: managed&.provisioning_status,
      phone_number: managed&.phone_number || phone_number,
      profile_name: managed&.profile_name,
      profile_picture_url: managed&.profile_picture_url,
      last_sync_at: managed&.last_sync_at,
      last_error: managed&.last_error,
      last_connection_state: managed&.connection_state || cfg['last_connection_state'],
      last_connection_error: cfg['last_connection_error'],
      last_connection_event_at: cfg['last_connection_event_at'],
      last_warning_code: cfg['evolution_last_warning_code'],
      last_warning_detail: cfg['evolution_last_warning_detail'],
      last_warning_at: cfg['evolution_last_warning_at'],
      reauthorization_required: reauthorization_required?
    }
  end

  def provider_service
    case provider
    when 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    when 'evolution'
      Whatsapp::Providers::EvolutionService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service
  delegate :sync_templates, to: :provider_service
  delegate :media_url, to: :provider_service
  delegate :api_headers, to: :provider_service

  def setup_webhooks
    perform_webhook_setup
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup failed: #{e.message}"
    prompt_reauthorization!
  end

  private

  def evolution_provider?
    provider == 'evolution'
  end

  def normalize_evolution_phone_number
    return unless provider == 'evolution'
    return if phone_number.blank?

    raw = phone_number.to_s.strip.gsub(/\s+/, '')
    digits = raw.delete_prefix('+')
    return unless digits.match?(/\A[1-9]\d{6,14}\z/)

    self.phone_number = "+#{digits}"
  end

  def ensure_webhook_verify_token
    provider_config['webhook_verify_token'] ||= SecureRandom.hex(16) if %w[whatsapp_cloud evolution].include?(provider)
  end

  def validate_provider_config
    return if provider == 'evolution' && provider_config['source'] == 'managed_evolution' && account&.evolution_api_configuration.present?

    errors.add(:provider_config, 'Invalid Credentials') unless provider_service.validate_provider_config?
  end

  def perform_webhook_setup
    if provider == 'evolution'
      provider_service.setup_instance
      return
    end

    business_account_id = provider_config['business_account_id']
    api_key = provider_config['api_key']

    Whatsapp::WebhookSetupService.new(self, business_account_id, api_key).perform
  end

  def teardown_webhooks
    Whatsapp::WebhookTeardownService.new(self).perform
  end

  def should_auto_setup_webhooks?
    return false if provider == 'evolution' && provider_config['source'] == 'managed_evolution'

    # Only auto-setup webhooks for whatsapp_cloud provider with manual setup
    # Embedded signup calls setup_webhooks explicitly in EmbeddedSignupService
    return true if provider == 'evolution'

    provider == 'whatsapp_cloud' && provider_config['source'] != 'embedded_signup'
  end
end

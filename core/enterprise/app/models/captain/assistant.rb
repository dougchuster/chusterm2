# == Schema Information
#
# Table name: captain_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :string
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_captain_assistants_on_account_id  (account_id)
#
class Captain::Assistant < ApplicationRecord
  include Avatarable
  include Concerns::CaptainToolsHelpers
  include Concerns::Agentable

  self.table_name = 'captain_assistants'

  belongs_to :account
  has_many :documents, class_name: 'Captain::Document', dependent: :destroy_async
  has_many :playbooks, class_name: 'Captain::Playbook', foreign_key: :assistant_id, dependent: :nullify
  has_many :document_versions,
           class_name: 'Captain::DocumentVersion',
           foreign_key: :assistant_id,
           dependent: :destroy_async
  has_many :responses, class_name: 'Captain::AssistantResponse', dependent: :destroy_async
  has_many :captain_inboxes,
           class_name: 'CaptainInbox',
           foreign_key: :captain_assistant_id,
           dependent: :destroy_async
  has_many :inboxes,
           through: :captain_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :copilot_threads, dependent: :destroy_async
  has_many :scenarios, class_name: 'Captain::Scenario', dependent: :destroy_async

  LLM_CONFIG_KEYS = %w[
    llm_provider llm_main_model llm_fallback_model llm_classifier_model
    llm_summarizer_model llm_max_tokens llm_timeout_seconds llm_cost_limit_cents_per_conversation
  ].freeze

  store_accessor :config, :temperature, :feature_faq, :feature_memory, :feature_contact_attributes, :product_name
  store_accessor :config, :llm_provider, :llm_main_model, :llm_fallback_model, :llm_classifier_model,
                 :llm_summarizer_model, :llm_max_tokens, :llm_timeout_seconds,
                 :llm_cost_limit_cents_per_conversation

  after_update :log_llm_config_change, if: :llm_config_changed?

  validates :name, presence: true
  validates :description, presence: true
  validates :account_id, presence: true
  validates :llm_max_tokens, numericality: { greater_than_or_equal_to: 256, less_than_or_equal_to: 32_000 }, allow_blank: true
  validates :llm_timeout_seconds, numericality: { greater_than_or_equal_to: 5, less_than_or_equal_to: 120 }, allow_blank: true
  validates :llm_cost_limit_cents_per_conversation, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  scope :ordered, -> { order(created_at: :desc) }

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def available_name
    name
  end

  def available_agent_tools
    tools = self.class.built_in_agent_tools.dup

    custom_tools = if account.respond_to?(:captain_custom_tools)
                     account.captain_custom_tools.enabled.map(&:to_tool_metadata)
                   else
                     []
                   end
    tools.concat(custom_tools)

    tools
  end

  def available_tool_ids
    available_agent_tools.pluck(:id)
  end

  def llm_config_with_defaults
    main_model = config['llm_main_model'].presence || global_captain_model || account.captain_assistant_model
    {
      provider: config['llm_provider'].presence || default_llm_provider,
      main_model: main_model,
      fallback_model: config['llm_fallback_model'].presence,
      classifier_model: config['llm_classifier_model'].presence || account.captain_label_suggestion_model,
      summarizer_model: config['llm_summarizer_model'].presence || main_model,
      max_tokens: config['llm_max_tokens'].presence&.to_i || 4096,
      timeout_seconds: config['llm_timeout_seconds'].presence&.to_i || 30,
      cost_limit_cents_per_conversation: config['llm_cost_limit_cents_per_conversation'].presence&.to_i
    }
  end

  def push_event_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  private

  def llm_config_changed?
    return false unless saved_changes.key?('config')

    before, after = saved_changes['config']
    before = before || {}
    after  = after  || {}
    LLM_CONFIG_KEYS.any? { |k| before[k] != after[k] }
  end

  def log_llm_config_change
    before, after = saved_changes['config']
    before = before || {}
    after  = after  || {}
    changed_keys = LLM_CONFIG_KEYS.select { |k| before[k] != after[k] }

    Crm::AuditLogger.log(
      account: account,
      actor: Current.user,
      action: 'captain_llm_config_updated',
      target: self,
      payload: {
        changed_keys: changed_keys,
        before: before.slice(*changed_keys),
        after: after.slice(*changed_keys)
      }
    )
  end

  def agent_name
    name.parameterize(separator: '_')
  end

  def default_llm_provider
    'openrouter'
  end

  def global_captain_model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence
  end

  def agent_tools
    tools = []
    tools << self.class.resolve_tool_class('faq_lookup').new(self) if ActiveModel::Type::Boolean.new.cast(feature_faq)
    tools << self.class.resolve_tool_class('handoff').new(self)
    tools.compact
  end

  def prompt_context
    {
      name: name,
      **identity_prompt_context,
      description: description,
      instructions: config['instructions'],
      handoff_on_explicit_request_only: ActiveModel::Type::Boolean.new.cast(
        config['handoff_on_explicit_request_only']
      ),
      product_name: config['product_name'] || 'this product',
      scenarios: scenarios.enabled.map do |scenario|
        {
          title: scenario.title,
          key: scenario.handoff_key,
          description: scenario.description
        }
      end,
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || []
    }
  end

  def default_avatar_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/assets/images/dashboard/captain/logo.svg"
  end

  def professional_identity?
    ActiveModel::Type::Boolean.new.cast(config['professional_identity'])
  end

  def identity_prompt_context
    {
      public_identity: config['public_identity'].presence || name,
      professional_identity: professional_identity?
    }
  end
end

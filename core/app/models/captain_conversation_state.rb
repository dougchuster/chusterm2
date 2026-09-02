class CaptainConversationState < ApplicationRecord
  include AccountAssociationScoped

  AI_MODES = %w[auto supervised paused human_only].freeze
  HUMAN_MODES = %w[paused human_only].freeze
  HIGH_PRIORITY_SCORE_THRESHOLD = 80
  RESUME_SOURCE_MANUAL = 'manual'.freeze
  RESUME_SOURCE_AUTOMATIC = 'automatic'.freeze
  RESUME_SOURCES = [RESUME_SOURCE_MANUAL, RESUME_SOURCE_AUTOMATIC].freeze
  # BUG-03: rows anteriores à coluna resume_source marcavam a retomada manual
  # com este texto em handoff_reason. Mantido só como fallback de leitura.
  LEGACY_MANUAL_RESUME_REASON = 'IA retomada manualmente'.freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :contact, optional: true
  belongs_to :captain_assistant, class_name: 'Captain::Assistant', optional: true
  belongs_to :captain_flow, class_name: 'Captain::Flow', optional: true
  belongs_to :handoff_by, class_name: 'User', optional: true
  belongs_to :resumed_by, class_name: 'User', optional: true
  belongs_to :crm_deal, class_name: 'CrmDeal', optional: true

  validates :ai_mode, inclusion: { in: AI_MODES }
  validates :score_total, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates_same_account_for :conversation, :contact, :captain_assistant, :captain_flow, :crm_deal
  validate :account_memberships_are_valid
  validate :deal_matches_conversation

  before_validation :sync_account_and_contact
  before_validation :clamp_score_total

  after_save :notify_crm_handoff, if: :saved_change_to_ai_mode?

  def self.for_conversation!(conversation)
    state = find_or_initialize_by(conversation: conversation)
    state.account ||= conversation.account
    state.contact ||= conversation.contact
    state.crm_deal = nil if state.deal_linked_to_another_conversation?
    state.save! if state.new_record? || state.changed?
    state
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def human_controlled?
    HUMAN_MODES.include?(ai_mode)
  end

  def apply_ai_mode!(mode:, reason: nil, reason_code: nil, actor: nil)
    self.ai_mode = mode
    self.handoff_reason = reason if reason.present?
    # ARQ-04/UX-04: código estruturado do motivo, além do texto livre
    self.handoff_reason_code = reason_code if reason_code.present?

    if human_controlled?
      self.handoff_at ||= Time.current
      self.handoff_by = actor if actor.present?
      # Um novo handoff invalida qualquer retomada manual anterior (BUG-03)
      clear_resume_tracking
    else
      self.handoff_at = nil
      self.handoff_by = nil
    end

    save!
  end

  def mark_manual_resume!(actor: nil)
    self.resume_source = RESUME_SOURCE_MANUAL
    self.resumed_at = Time.current
    self.resumed_by = actor
  end

  def mark_automatic_resume!
    self.resume_source = RESUME_SOURCE_AUTOMATIC
    self.resumed_at = Time.current
    self.resumed_by = nil
  end

  def resumed_after?(timestamp)
    return false if human_controlled?
    return resumed_at > timestamp if resume_source.in?(RESUME_SOURCES) && resumed_at.present?

    # Fallback para rows criadas antes da migration 20260703000001
    handoff_reason == LEGACY_MANUAL_RESUME_REASON && updated_at > timestamp
  end

  # BUG-03: decisão estruturada — a IA foi retomada manualmente DEPOIS do
  # timestamp dado? Substitui a comparação com magic string nos call sites.
  def manually_resumed_after?(timestamp)
    return false if human_controlled?
    return resumed_at > timestamp if resume_source == RESUME_SOURCE_MANUAL && resumed_at.present?

    # Fallback para rows criadas antes da migration 20260703000001
    handoff_reason == LEGACY_MANUAL_RESUME_REASON && updated_at > timestamp
  end

  def deal_linked_to_another_conversation?
    return false if crm_deal.nil? || crm_deal.conversation_id.blank? || conversation_id.blank?

    crm_deal.conversation_id != conversation_id
  end

  private

  def account_memberships_are_valid
    return if account.nil?

    validate_account_user(:handoff_by, handoff_by_id)
    validate_account_user(:resumed_by, resumed_by_id)
  end

  def validate_account_user(attribute, user_id)
    return if user_id.blank? || account.account_users.exists?(user_id: user_id)

    errors.add(attribute, 'must belong to the same account')
  end

  def deal_matches_conversation
    return if crm_deal.nil? || crm_deal.conversation_id.blank? || conversation_id.blank?
    return if crm_deal.conversation_id == conversation_id

    errors.add(:crm_deal, 'must belong to the same conversation')
  end

  def clear_resume_tracking
    self.resume_source = nil
    self.resumed_at = nil
    self.resumed_by = nil
  end

  def sync_account_and_contact
    self.account ||= conversation&.account
    self.contact ||= conversation&.contact
  end

  def clamp_score_total
    return if score_total.blank?

    self.score_total = score_total.to_i.clamp(0, 100)
  end

  def notify_crm_handoff
    return unless human_controlled?
    return unless crm_deal

    existing = crm_deal.crm_activities.pending.where(kind: 'revisao_juridica', title: 'Handoff IA para humano')
    return if existing.exists?

    crm_deal.crm_activities.create!(
      account: account,
      contact_id: crm_deal.contact_id,
      conversation_id: conversation_id,
      kind: 'revisao_juridica',
      title: 'Handoff IA para humano',
      description: handoff_reason || "Capitao transferiu para humano (modo: #{ai_mode})",
      priority: 'alta',
      due_at: 2.hours.from_now,
      created_by_type: 'system'
    )

    Crm::AuditLogger.log(
      account: account,
      actor: handoff_by,
      action: 'captain_handoff',
      target: crm_deal,
      payload: { ai_mode: ai_mode, handoff_reason: handoff_reason }
    ) if defined?(Crm::AuditLogger)
  end
end

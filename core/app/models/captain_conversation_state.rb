class CaptainConversationState < ApplicationRecord
  AI_MODES = %w[auto supervised paused human_only].freeze
  HUMAN_MODES = %w[paused human_only].freeze
  AUTO_HANDOFF_SCORE_THRESHOLD = 90

  belongs_to :account
  belongs_to :conversation
  belongs_to :contact, optional: true
  belongs_to :captain_assistant, class_name: 'Captain::Assistant', optional: true
  belongs_to :captain_flow, class_name: 'Captain::Flow', optional: true
  belongs_to :handoff_by, class_name: 'User', optional: true
  belongs_to :crm_deal, class_name: 'CrmDeal', optional: true

  validates :ai_mode, inclusion: { in: AI_MODES }
  validates :score_total, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  before_validation :sync_account_and_contact
  before_validation :clamp_score_total

  after_save :check_score_handoff, if: :saved_change_to_score_total?
  after_save :notify_crm_handoff, if: :saved_change_to_ai_mode?

  def self.for_conversation!(conversation)
    create_or_find_by!(conversation: conversation) do |state|
      state.account = conversation.account
      state.contact = conversation.contact
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(conversation: conversation)
  end

  def human_controlled?
    HUMAN_MODES.include?(ai_mode)
  end

  def apply_ai_mode!(mode:, reason: nil, actor: nil)
    self.ai_mode = mode
    self.handoff_reason = reason if reason.present?

    if human_controlled?
      self.handoff_at ||= Time.current
      self.handoff_by = actor if actor.present?
    else
      self.handoff_at = nil
      self.handoff_by = nil
    end

    save!
  end

  private

  def check_score_handoff
    return if human_controlled?
    return if score_total.to_i < AUTO_HANDOFF_SCORE_THRESHOLD

    apply_ai_mode!(mode: 'human_only', reason: "Score #{score_total} atingiu prioridade alta — handoff automatico.")
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

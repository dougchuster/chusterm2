class CrmDeal < ApplicationRecord
  include Events::Types
  include AccountAssociationScoped

  OPERATIONAL_STATUSES = %w[active base_client converted_client returning_client invalid spam duplicated no_lead archived].freeze

  belongs_to :account
  belongs_to :crm_pipeline
  belongs_to :crm_pipeline_stage
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true
  belongs_to :crm_loss_reason, optional: true
  has_many :crm_activities, dependent: :destroy
  has_many :crm_intake_answers, dependent: :destroy
  has_many :crm_lead_scores, dependent: :destroy
  has_many :crm_audit_events, as: :target, dependent: :destroy
  has_many :crm_cadence_enrollments, dependent: :destroy

  validates :account, :crm_pipeline, :crm_pipeline_stage, :title, presence: true
  validates_same_account_for :crm_pipeline, :crm_pipeline_stage, :contact, :conversation, :inbox, :crm_loss_reason
  validate :stage_belongs_to_pipeline
  validate :account_memberships_are_valid
  validates :status, inclusion: { in: %w[open won lost archived] }
  validates :operational_status, inclusion: { in: OPERATIONAL_STATUSES }, allow_blank: true
  validates :value_estimate_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :probability_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, only_integer: true }
  validates :contact_id,
            uniqueness: {
              scope: [:account_id, :crm_pipeline_id],
              conditions: -> { where(status: 'open') },
              message: 'já possui um lead aberto neste kanban'
            },
            allow_blank: true,
            if: :open_status?

  scope :open_deals, -> { where(status: 'open') }
  scope :active_pipeline, -> { where(status: 'open', operational_status: ['active', 'returning_client']) }
  scope :base_clients, -> { where(operational_status: 'base_client') }
  scope :discarded, -> { where(operational_status: %w[invalid spam duplicated no_lead archived]) }
  scope :by_pipeline, ->(pipeline_id) { where(crm_pipeline_id: pipeline_id) }
  scope :by_stage, ->(stage_id) { where(crm_pipeline_stage_id: stage_id) }
  scope :by_legal_area, ->(area) { where(legal_area: area) }
  scope :retention_due, -> { where.not(data_retention_until: nil).where('data_retention_until <= ?', Date.current) }

  LGPD_FIELDS = %w[lgpd_basis consent_status consent_channel consent_collected_at data_retention_until].freeze

  after_commit :trigger_lifecycle_recalculation, if: :contact_id
  after_commit :track_campaign_conversion, if: :campaign_conversion_event?
  before_validation :normalize_legal_area

  # PERF-02: eventos crm_deal.* → ActionCableListener → board em realtime.
  # Callbacks no modelo (e não nos services) para cobrir todos os caminhos de
  # escrita: controller, bulk actions, DealMover/DealCreator e jobs.
  after_create_commit :dispatch_created_event
  after_update_commit :dispatch_updated_event
  after_destroy_commit :dispatch_deleted_event

  # Payload leve para o board (o front refaz o fetch para dados completos)
  def push_event_data
    {
      id: id,
      account_id: account_id,
      title: title,
      status: status,
      operational_status: operational_status,
      crm_pipeline_id: crm_pipeline_id,
      crm_pipeline_stage_id: crm_pipeline_stage_id,
      contact_id: contact_id,
      conversation_id: conversation_id,
      owner_id: owner_id,
      assignee_id: assignee_id,
      score_total: score_total,
      # F1.7: sem `position` a outra sessao nao sabe **onde** encaixar o card;
      # sem `stage_entered_at` nao consegue pintar o rotting sem refazer o fetch.
      position: position,
      stage_entered_at: stage_entered_at || created_at,
      updated_at: updated_at
    }
  end

  def mark_won!(actor: nil)
    update!(status: 'won', closed_at: Time.current, crm_loss_reason_id: nil, lost_reason_note: nil)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_marked_won', target: self)
  end

  def mark_lost!(loss_reason_id:, note: nil, actor: nil)
    update!(status: 'lost', closed_at: Time.current, crm_loss_reason_id: loss_reason_id, lost_reason_note: note)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_marked_lost', target: self)
  end

  def reopen!(actor: nil)
    update!(status: 'open', closed_at: nil, operational_status: 'active', archived_at: nil,
            disposed_at: nil, disposition_reason: nil, disposition_note: nil,
            crm_loss_reason_id: nil, lost_reason_note: nil)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_reopened', target: self)
  end

  def archive!(reason: nil, note: nil, actor: nil, operational_status: 'archived')
    update!(
      status: 'archived',
      operational_status: operational_status,
      disposition_reason: reason,
      disposition_note: note,
      disposed_at: Time.current,
      archived_at: Time.current,
      closed_at: Time.current
    )
    Crm::AuditLogger.log(
      account: account,
      actor: actor,
      action: 'deal_archived',
      target: self,
      payload: { reason: reason, note: note, operational_status: operational_status }
    )
  end

  def discard!(reason:, note: nil, actor: nil)
    archive!(reason: reason, note: note, actor: actor, operational_status: reason)
  end

  def mark_base_client!(note: nil, actor: nil)
    archive!(reason: 'base_client', note: note, actor: actor, operational_status: 'base_client')
  end

  def score_classification_label
    CrmScoreClassification.classify(score_total)
  end

  def lgpd_ready?
    lgpd_basis.present? && consent_status.present? && data_retention_until.present?
  end

  def retention_due?
    data_retention_until.present? && data_retention_until <= Date.current
  end

  private

  def stage_belongs_to_pipeline
    return if crm_pipeline_stage.nil? || crm_pipeline.nil?
    return if crm_pipeline_stage.crm_pipeline_id == crm_pipeline_id

    errors.add(:crm_pipeline_stage, 'must belong to the selected pipeline')
  end

  def account_memberships_are_valid
    return if account.nil?

    validate_account_user(:owner, owner_id)
    validate_account_user(:assignee, assignee_id)
    errors.add(:team, 'must belong to the same account') if team_id.present? && !account.teams.exists?(id: team_id)
  end

  def validate_account_user(attribute, user_id)
    return if user_id.blank? || account.account_users.exists?(user_id: user_id)

    errors.add(attribute, 'must belong to the same account')
  end

  def normalize_legal_area
    self.legal_area = Crm::DomainOptions.canonical_legal_area(legal_area) if legal_area.present?
  end

  def open_status?
    status == 'open'
  end

  def trigger_lifecycle_recalculation
    return unless contact
    return unless saved_change_to_status? || saved_change_to_contact_id? || previously_new_record?

    Crm::ContactLifecycleManager.recalculate(contact)
  rescue StandardError => e
    Rails.logger.warn("[CRM] lifecycle recalculation failed for contact #{contact_id}: #{e.message}")
  end

  def campaign_conversion_event?
    saved_change_to_status? && status == 'won' && conversation&.campaign.present?
  end

  def track_campaign_conversion
    Campaigns::DeliveryTracker.new(conversation.campaign).record!(
      :converted,
      contact: contact,
      conversation: conversation,
      provider: 'crm',
      metadata: { deal_id: id, value_estimate_cents: value_estimate_cents }
    )
  rescue StandardError => e
    Rails.logger.warn("[Campaign Tracking] conversion event failed for deal #{id}: #{e.message}")
  end

  def dispatch_created_event
    Rails.configuration.dispatcher.dispatch(CRM_DEAL_CREATED, Time.zone.now, deal: self)
  end

  def dispatch_updated_event
    # Só os nomes dos atributos alterados: valores podem não ser serializáveis
    # pelo AsyncDispatcher (ActiveJob) e o front refaz o fetch de qualquer forma.
    #
    # F1.7: a etapa anterior é a exceção. Ela é a única informação que o evento
    # carrega e que o receptor **não tem como descobrir sozinho** — sem ela,
    # uma sessão que não tinha o card carregado não sabe de qual coluna tirá-lo.
    Rails.configuration.dispatcher.dispatch(
      CRM_DEAL_UPDATED, Time.zone.now,
      deal: self,
      changed_attributes: previous_changes.keys,
      previous_stage_id: previous_changes['crm_pipeline_stage_id']&.first
    )
  end

  def dispatch_deleted_event
    # Registro destruído não pode ir para o dispatcher async (GlobalID não
    # resolve) — payload é um hash puro
    Rails.configuration.dispatcher.dispatch(CRM_DEAL_DELETED, Time.zone.now, deal_data: push_event_data)
  end
end

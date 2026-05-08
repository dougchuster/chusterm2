class CrmDeal < ApplicationRecord
  OPERATIONAL_STATUSES = %w[active base_client converted_client returning_client invalid spam duplicated no_lead archived].freeze

  belongs_to :account
  belongs_to :crm_pipeline
  belongs_to :crm_pipeline_stage
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :crm_loss_reason, optional: true
  has_many :crm_activities, dependent: :destroy
  has_many :crm_intake_answers, dependent: :destroy
  has_many :crm_lead_scores, dependent: :destroy
  has_many :crm_audit_events, as: :target, dependent: :destroy
  has_many :crm_cadence_enrollments, dependent: :destroy

  validates :account, :crm_pipeline, :crm_pipeline_stage, :title, presence: true
  validates :status, inclusion: { in: %w[open won lost archived] }
  validates :operational_status, inclusion: { in: OPERATIONAL_STATUSES }, allow_blank: true
  validates :value_estimate_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :probability_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, only_integer: true }

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

  def mark_won!(actor: nil)
    update!(status: 'won', closed_at: Time.current)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_marked_won', target: self)
  end

  def mark_lost!(loss_reason_id:, note: nil, actor: nil)
    update!(status: 'lost', closed_at: Time.current, crm_loss_reason_id: loss_reason_id, lost_reason_note: note)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_marked_lost', target: self)
  end

  def reopen!(actor: nil)
    update!(status: 'open', closed_at: nil, operational_status: 'active', archived_at: nil,
            disposed_at: nil, disposition_reason: nil, disposition_note: nil)
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
end

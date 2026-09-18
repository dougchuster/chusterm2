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
  has_many :crm_automation_runs, dependent: :destroy
  # 2.5: um negócio junta todas as conversas do contato (WhatsApp + Instagram =
  # um deal só). `conversation_id` segue como a conversa principal.
  has_many :crm_deal_conversations, dependent: :destroy
  has_many :conversations, through: :crm_deal_conversations

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
  # 2.6: o agente só vê negócios dos canais em que atende — o mesmo contrato
  # do ConversationPolicy (inbox/team). Deals sem canal (manuais) e deals em
  # que ele é responsável seguem visíveis; administrador vê tudo.
  scope :visible_to, lambda { |user, account|
    account_user = account.account_users.find_by(user_id: user.id)
    if account_user&.administrator? || user.is_a?(AgentBot)
      all
    else
      inbox_ids = user.inboxes.where(account_id: account.id).select(:id)
      team_ids = user.teams.where(account_id: account.id).select(:id)
      # 2.5/2.6: conversas extras anexadas ao deal também concedem acesso —
      # a conversa do WhatsApp pode estar num inbox do agente mesmo quando a
      # conversa principal do deal veio de outro canal.
      linked = CrmDealConversation.select(:crm_deal_id)
                                  .where(conversation_id: Conversation.where(account_id: account.id, inbox_id: inbox_ids).select(:id))
      where(inbox_id: inbox_ids)
        .or(where(team_id: team_ids))
        .or(where(inbox_id: nil))
        .or(where(owner_id: user.id))
        .or(where(id: linked))
    end
  }
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
  before_validation :sync_universal_category
  before_validation :normalize_legal_area
  before_validation :sync_single_owner

  # PERF-02: eventos crm_deal.* → ActionCableListener → board em realtime.
  # Callbacks no modelo (e não nos services) para cobrir todos os caminhos de
  # escrita: controller, bulk actions, DealMover/DealCreator e jobs.
  after_create_commit :dispatch_created_event
  after_update_commit :dispatch_updated_event
  after_destroy_commit :dispatch_deleted_event

  # Lead Ads → CAPI: eventos de estágio sobem para a Meta em tempo real.
  # B13: sem conexão Meta ativa na conta o job era enfileirado em todo save
  # para descartar sozinho — o guard cacheado evita o enfileiramento inútil.
  after_commit on: %i[create update],
               if: -> { previously_new_record? ? contact_id.present? : saved_change_to_crm_pipeline_stage_id? || saved_change_to_status? } do
    Marketing::CapiDispatchJob.perform_later(id) if capi_dispatchable?
  end

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

  # Anexa uma conversa extra ao negócio (o contato chegou por outro canal).
  # A conversa principal (`conversation_id`) não muda — o join é aditivo.
  def attach_conversation!(conversation, actor: nil)
    link = crm_deal_conversations.find_or_create_by!(conversation: conversation) do |row|
      row.account = account
    end
    if link.previously_new_record?
      Crm::AuditLogger.log(
        account: account,
        actor: actor,
        action: 'deal_conversation_attached',
        target: self,
        payload: { conversation_id: conversation.id }
      )
    end
    link
  end

  # D2/C6: título padrão da triagem ("Atendimento #53") não ajuda a reconhecer
  # o negócio no kanban — virou contato + categoria quando houver os dois.
  def default_title?
    title.blank? || title.match?(/\AAtendimento #\d+\z/)
  end

  def retitle!(actor: nil)
    return unless default_title?
    return if contact.blank?

    label = Crm::PackOptions.category_label_for(account, category.presence || legal_area)
    new_title = [contact.name.presence || "Contato ##{contact_id}", label].compact.join(' — ')
    update!(title: new_title)
    Crm::AuditLogger.log(
      account: account, actor: actor, action: 'deal_renamed', target: self, payload: { title: new_title }
    )
  end

  def mark_won!(actor: nil)
    update!(status: 'won', closed_at: Time.current, crm_loss_reason_id: nil, lost_reason_note: nil)
    move_to_terminal_stage!('won', actor: actor)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_marked_won', target: self)
  end

  def mark_lost!(loss_reason_id:, note: nil, actor: nil)
    update!(status: 'lost', closed_at: Time.current, crm_loss_reason_id: loss_reason_id, lost_reason_note: note)
    move_to_terminal_stage!('lost', actor: actor)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'deal_marked_lost', target: self)
  end

  def reopen!(actor: nil)
    update!(status: 'open', closed_at: nil, operational_status: 'active', archived_at: nil,
            disposed_at: nil, disposition_reason: nil, disposition_note: nil,
            crm_loss_reason_id: nil, lost_reason_note: nil)
    # D2: card parado na coluna terminal ("Ganho"/"Perdido") volta para o
    # início do funil ao reabrir.
    if crm_pipeline_stage&.terminal?
      first_open = crm_pipeline.crm_pipeline_stages.active.where(terminal_outcome: nil).order(:position).first
      Crm::DealMover.new(deal: self, stage_id: first_open.id, actor: actor).perform if first_open
    end
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

  # B13: só enfileira o dispatch CAPI quando a conta tem uma conexão Meta Ads
  # ativa com dataset configurado. Cache curto para não consultar a tabela a
  # cada save de deal; a invalidação por tempo basta porque conectar/desconectar
  # uma integração não precisa refletir no mesmo segundo.
  def capi_dispatchable?
    account_id = self.account_id
    Rails.cache.fetch("crm_capi_dispatchable/#{account_id}", expires_in: 5.minutes) do
      CrmExternalConnection.where(account_id: account_id, provider: 'meta_ads', status: 'active')
                           .where.not("metadata ->> 'capi_dataset_id' IS NULL")
                           .where.not("metadata ->> 'capi_dataset_id' = ''")
                           .exists?
    end
  end

  # D2: ganho/perdido saem da etapa operacional para a coluna terminal do
  # funil ("Ganho"/"Perdido"), quando ela existe — pipelines antigas sem
  # etapa terminal mantêm o card onde está (comportamento anterior).
  def move_to_terminal_stage!(outcome, actor: nil)
    terminal = crm_pipeline.crm_pipeline_stages.terminal_for(outcome).first
    return unless terminal
    return if crm_pipeline_stage_id == terminal.id

    Crm::DealMover.new(deal: self, stage_id: terminal.id, actor: actor).perform
  end

  # D3: `assignee_id` fica deprecado — `owner_id` é o dono único do negócio.
  # O espelho só preenche campo em branco: nunca sobrescreve um assignee
  # escolhido a dedo (DealOwnerAssigner: sync_assignee :if_unmanaged/:never).
  # O dono do relacionamento (`contacts.crm_owner_id`) é responsabilidade do
  # DealOwnerAssigner/ContactOwnerRouter — não do model.
  def sync_single_owner
    self.owner_id = assignee_id if owner_id.blank? && assignee_id.present?
    self.assignee_id = owner_id if assignee_id.blank? && owner_id.present?
  end

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

  # A0: category/subcategory são os campos universais; legal_area/case_type
  # seguem escritos para compat (triagem, checklists e dados antigos os leem).
  # O par alterado neste save é a fonte da verdade.
  def sync_universal_category
    pairs = if category_changed? || subcategory_changed?
              { category => :legal_area, subcategory => :case_type }
            elsif legal_area_changed? || case_type_changed?
              { legal_area => :category, case_type => :subcategory }
            else
              {}
            end
    pairs.each { |value, target| public_send("#{target}=", value) if value.present? }
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

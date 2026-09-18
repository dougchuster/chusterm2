class Crm::TriageFromConversation
  def initialize(conversation:, account:, actor:)
    @conversation = conversation
    @account = account
    @actor = actor
  end

  def perform
    deal = find_or_create_deal
    # 3.2: Crm::Classifier tenta o LLM com a taxonomia do pack e cai nas
    # regras do LegalTriageAnalyzer quando a IA não está habilitada.
    triage = Crm::Classifier.new(conversation: @conversation, account: @account).perform

    ActiveRecord::Base.transaction do
      apply_triage(deal, triage)
      deal.retitle!(actor: @actor)
      persist_intake_answers(deal, triage[:intake_answers])
      Crm::LeadScoreCalculator.new(deal.reload, actor: @actor).perform
      Crm::ContactOwnerRouter.new(deal: deal.reload, conversation: @conversation, triage: triage, actor: @actor).perform
      Crm::LegalLabelSync.new(conversation: @conversation, triage: triage, actor: @actor).perform
      move_after_triage(deal.reload, triage)
      if should_escalate?(deal.reload, triage)
        create_escalation_activity(deal.reload, triage)
      else
        clear_escalation_activity(deal.reload)
      end
    end

    sync_captain_state(deal)

    Crm::AuditLogger.log(
      account: @account,
      actor: @actor,
      action: 'triage_executed',
      target: deal,
      payload: triage.except(:intake_answers)
    )
    deal.reload
  end

  private

  def find_or_create_deal
    existing = @account.crm_deals.open_deals.find_by(conversation_id: @conversation.id)
    return align_deal_to_channel_pipeline(existing) if existing

    linked = open_deal_linked_to_conversation
    return linked if linked

    # 2.5: o contato já tem um negócio aberto — a conversa nova (outro canal,
    # retorno depois de resolvida etc.) anexa a ele em vez de criar outro card.
    by_contact = open_deal_for_contact
    if by_contact
      by_contact.attach_conversation!(@conversation, actor: @actor)
      return by_contact
    end

    create_deal_for_conversation
  end

  def open_deal_linked_to_conversation
    @account.crm_deals.open_deals
            .joins(:crm_deal_conversations)
            .find_by(crm_deal_conversations: { conversation_id: @conversation.id })
  end

  def open_deal_for_contact
    return nil if @conversation.contact_id.blank?

    @account.crm_deals.open_deals
            .where(contact_id: @conversation.contact_id)
            .order(updated_at: :desc)
            .first
  end

  def create_deal_for_conversation
    pipeline = pipeline_for_conversation
    raise 'No active pipeline found' unless pipeline

    first_stage = pipeline.crm_pipeline_stages.active.order(:position).first
    raise 'No active pipeline stage found' unless first_stage

    contact = @conversation.contact
    Crm::DealCreator.new(
      account: @account,
      actor: @actor,
      params: {
        title: "Atendimento ##{@conversation.display_id}",
        contact_id: contact&.id,
        conversation_id: @conversation.id,
        inbox_id: @conversation.inbox_id,
        crm_pipeline_id: pipeline.id,
        crm_pipeline_stage_id: first_stage.id
      }
    ).perform
  end

  def pipeline_for_conversation
    inbox = @conversation.inbox
    if inbox
      provisioned = Crm::ChannelPipelineProvisioner.new(
        account: @account,
        inbox: inbox,
        actor: @actor
      ).perform
      return provisioned if provisioned
    end

    @account.crm_pipelines.active.find_by(is_default: true) ||
      @account.crm_pipelines.active.first
  end

  def align_deal_to_channel_pipeline(deal)
    pipeline = pipeline_for_conversation
    return deal unless pipeline
    return deal if deal.crm_pipeline_id == pipeline.id

    current_stage_slug = deal.crm_pipeline_stage&.slug
    target_stage = pipeline.crm_pipeline_stages.active.find_by(slug: current_stage_slug) ||
                   pipeline.crm_pipeline_stages.active.order(:position).first
    return deal unless target_stage

    deal.update!(crm_pipeline: pipeline, crm_pipeline_stage: target_stage, inbox_id: @conversation.inbox_id)
    Crm::AuditLogger.log(
      account: @account,
      actor: @actor,
      action: 'deal_channel_pipeline_aligned',
      target: deal,
      payload: { inbox_id: @conversation.inbox_id, pipeline_id: pipeline.id }
    )
    deal
  end

  def apply_triage(deal, triage)
    captain_triage = triage.except(:intake_answers)

    deal.update!(
      legal_area: triage[:legal_area],
      case_type: triage[:case_type],
      urgency_level: triage[:urgency_level],
      conflict_check_status: triage[:conflict_check_status],
      documents_status: triage[:documents_status],
      lgpd_basis: triage[:lgpd_basis],
      consent_status: triage[:consent_status],
      data_retention_until: triage[:data_retention_until],
      summary: triage[:summary],
      next_best_action: triage[:next_best_action],
      score_reason: triage[:score_reason],
      triage: captain_triage.merge('classified_by' => triage[:classified_by]),
      custom_fields: (deal.custom_fields || {}).merge('captain_triage' => captain_triage),
      attribution: (deal.attribution || {}).merge('last_triage_source' => 'captain_rule_based')
    )
  end

  def persist_intake_answers(deal, answers)
    keys = answers.map { |answer| answer[:question_key] }
    deal.crm_intake_answers.where(question_key: keys).delete_all

    answers.each do |answer|
      deal.crm_intake_answers.create!(
        account: @account,
        contact_id: deal.contact_id,
        conversation_id: deal.conversation_id,
        collected_by: 'captain',
        **answer
      )
    end
  end

  def move_after_triage(deal, triage)
    target_stage = stage_for(deal, triage)
    return unless target_stage
    return if deal.crm_pipeline_stage_id == target_stage.id
    return if deal.crm_pipeline_stage.position.to_i > target_stage.position.to_i && !insufficient_triage?(triage)

    Crm::DealMover.new(deal: deal, stage_id: target_stage.id, actor: @actor).perform
  end

  def stage_for(deal, triage)
    return deal.crm_pipeline.crm_pipeline_stages.active.order(:position).first if insufficient_triage?(triage)

    slug = should_escalate?(deal, deal.custom_fields['captain_triage'] || {}) ? 'qualificado' : 'triagem-ia'
    deal.crm_pipeline.crm_pipeline_stages.active.find_by(slug: slug)
  end

  def should_escalate?(deal, triage)
    return false if insufficient_triage?(triage)

    deal.score_total.to_i >= 60 ||
      %w[alta critica].include?(triage[:urgency_level] || triage['urgency_level']) ||
      %w[contratacao orcamento].include?(triage[:intent] || triage['intent']) ||
      %w[parcial completo].include?(deal.documents_status)
  end

  def insufficient_triage?(triage)
    (triage[:data_quality] || triage['data_quality']) == 'insufficient'
  end

  def create_escalation_activity(deal, triage)
    return if deal.crm_activities.pending.where(kind: 'revisao_juridica', title: 'Revisar triagem do Capitao').exists?

    priority = %w[alta critica].include?(triage[:urgency_level]) ? triage[:urgency_level] : 'alta'
    deal.crm_activities.create!(
      account: @account,
      contact_id: deal.contact_id,
      conversation_id: deal.conversation_id,
      kind: 'revisao_juridica',
      title: 'Revisar triagem do Capitao',
      description: triage[:next_best_action],
      priority: priority,
      due_at: due_at_for(priority),
      created_by_type: 'system'
    )
  end

  def clear_escalation_activity(deal)
    deal.crm_activities.pending
        .where(kind: 'revisao_juridica', title: 'Revisar triagem do Capitao', created_by_type: 'system')
        .find_each do |activity|
      activity.complete!(
        outcome: 'Triagem automatica revisada: dados insuficientes para escalacao.',
        actor: @actor
      )
    end
  end

  def due_at_for(priority)
    return 2.hours.from_now if priority == 'critica'
    return 6.hours.from_now if priority == 'alta'

    1.day.from_now
  end

  def sync_captain_state(deal)
    captain_state = @account.captain_conversation_states.find_by(conversation_id: @conversation.id)
    return unless captain_state
    return if captain_state.crm_deal_id == deal.id

    captain_state.update!(crm_deal_id: deal.id)
  end
end

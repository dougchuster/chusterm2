class Crm::StageAutomation
  # Teto de moves encadeados: uma regra em A movendo para B somada a uma regra
  # em B movendo para A recursaria DealMover → StageAutomation sem fim.
  MAX_AUTOMATION_DEPTH = 5

  def initialize(deal:, actor: nil, automation_depth: 0)
    @deal = deal
    @actor = actor
    @automation_depth = automation_depth
  end

  def perform
    rules = CrmAutomationRule.active.for_stage(@deal.crm_pipeline_stage_id)
    return if rules.none?

    rules.each do |rule|
      config = rule.action_config&.with_indifferent_access || {}
      unless conditions_match?(config)
        log_skip(rule, 'automation_skipped_by_condition', config)
        next
      end

      case rule.action_type
      when 'create_activity'
        execute_create_activity(rule, config)
      when 'set_captain_mode'
        execute_set_captain_mode(rule, config)
      when 'move_to_stage'
        execute_move_to_stage(rule, config)
      when 'assign_owner'
        unless execute_assign_owner(rule, config)
          log_skip(rule, 'automation_skipped_invalid_owner', config)
          next
        end
      end

      Crm::AuditLogger.log(
        account: @deal.account,
        actor: @actor,
        action: "automation_executed_#{rule.action_type}",
        target: @deal,
        payload: { automation: 'stage', stage_slug: @deal.crm_pipeline_stage&.slug, rule_id: rule.id, action_type: rule.action_type }
      )
    end
  end

  private

  def log_skip(rule, action, config)
    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: action,
      target: @deal,
      payload: { automation: 'stage', rule_id: rule.id, conditions: config[:conditions] }
    )
  end

  def pending_activity_exists?(config)
    @deal.crm_activities.pending.where(kind: config[:kind], title: config[:title]).exists?
  end

  def conditions_match?(config)
    Crm::CadenceConditionEvaluator.new(
      deal: @deal,
      contact: @deal.contact,
      conditions: config[:conditions]
    ).matches?
  end

  def due_at_for(config)
    due_in_hours = [config[:due_in_hours].to_i, 1].max
    Time.current + due_in_hours.hours
  end

  def activity_kind_for(kind)
    normalized_kind = kind.to_s
    CrmActivity::KINDS.include?(normalized_kind) ? normalized_kind : 'follow_up'
  end

  def activity_priority_for(priority)
    normalized_priority = priority.to_s
    CrmActivity::PRIORITIES.include?(normalized_priority) ? normalized_priority : 'normal'
  end

  def execute_create_activity(rule, config)
    return if pending_activity_exists?(config)

    @deal.crm_activities.create!(
      account: @deal.account,
      contact_id: @deal.contact_id,
      conversation_id: @deal.conversation_id,
      kind: activity_kind_for(config[:kind]),
      title: config[:title],
      description: config[:description],
      priority: activity_priority_for(config[:priority]),
      due_at: due_at_for(config),
      created_by_type: @actor ? @actor.class.name : 'system',
      created_by_id: @actor.respond_to?(:id) ? @actor.id : nil
    )
  end

  def execute_set_captain_mode(_rule, config)
    conversation = @deal.conversation
    return unless conversation

    captain_state = @deal.account.captain_conversation_states.find_by(conversation: conversation)
    return unless captain_state

    mode = config[:ai_mode].to_s
    return unless CaptainConversationState::AI_MODES.include?(mode)

    captain_state.apply_ai_mode!(
      mode: mode,
      reason: config[:reason] || "Automacao CRM: deal entrou na etapa #{@deal.crm_pipeline_stage&.name}"
    )
  end

  def execute_move_to_stage(_rule, config)
    target_slug = config[:stage_slug].to_s
    return if target_slug.blank?

    target_stage = @deal.crm_pipeline.crm_pipeline_stages.active.find_by(slug: target_slug)
    return unless target_stage
    return if @deal.crm_pipeline_stage_id == target_stage.id

    # Guarda de ciclo: cada move encadeado incrementa a profundidade; ao
    # atingir o teto a automação é pulada (o comportamento de regras não
    # cíclicas, que nunca chegam perto do teto, não muda).
    if @automation_depth >= MAX_AUTOMATION_DEPTH
      Rails.logger.warn(
        "[CRM StageAutomation] move_to_stage ignorado: profundidade máxima #{MAX_AUTOMATION_DEPTH} " \
        "atingida (possível ciclo) deal=#{@deal.id} etapa_destino=#{target_slug}"
      )
      return
    end

    Crm::DealMover.new(
      deal: @deal,
      stage_id: target_stage.id,
      actor: @actor,
      automation_depth: @automation_depth + 1
    ).perform
  end

  # A coluna `assigned_to_id` nunca existiu em `crm_deals` (o schema tem
  # `owner_id` e `assignee_id`), entao a guarda antiga era sempre falsa e a regra
  # virava um no-op auditado como sucesso.
  #
  # O dono passa a ser gravado sempre. O responsavel acompanha o dono, como na
  # acao manual em massa (Api::V1::Accounts::Crm::DealsController#assign_owner),
  # exceto quando alguem o escolheu a dedo — ver `hand_picked_assignee?`.
  # Diferente da acao manual, nao mexemos em `contact.crm_owner_id`: isso
  # rerotearia todos os negocios futuros do contato.
  def execute_assign_owner(_rule, config)
    user = resolve_owner(config[:user_id])
    return false if user.nil?

    current_assignee_id = @deal.assignee_id
    keep_assignee = hand_picked_assignee?

    @deal.update!(owner_id: user.id, assignee_id: keep_assignee ? current_assignee_id : user.id)
    log_preserved_assignee(current_assignee_id) if keep_assignee
    true
  end

  # Um responsavel diferente do dono significa que alguem escolheu a dedo quem
  # esta tocando o caso agora. Automacao nunca tira esse trabalho da pessoa: so
  # sincroniza o responsavel quando ele esta vazio ou ja seguia o dono anterior.
  def hand_picked_assignee?
    @deal.assignee_id.present? && @deal.assignee_id != @deal.owner_id
  end

  def log_preserved_assignee(assignee_id)
    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: 'automation_preserved_assignee',
      target: @deal,
      payload: { automation: 'stage', assignee_id: assignee_id }
    )
  end

  def resolve_owner(user_id)
    return if user_id.blank?

    @deal.account.users.find_by(id: user_id)
  end
end

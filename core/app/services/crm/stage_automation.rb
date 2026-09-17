class Crm::StageAutomation
  # Teto de moves encadeados: uma regra em A movendo para B somada a uma regra
  # em B movendo para A recursaria DealMover → StageAutomation sem fim.
  MAX_AUTOMATION_DEPTH = 5

  def initialize(deal:, actor: nil, automation_depth: 0)
    @deal = deal
    @actor = actor
    @automation_depth = automation_depth
  end

  def perform(trigger: 'stage_entered')
    @trigger = trigger
    rules = CrmAutomationRule.active.for_stage(@deal.crm_pipeline_stage_id).where(trigger_event: trigger)
    return if rules.none?

    rules.each { |rule| process_rule(rule) }
  end

  private

  # Cada executor devolve :executed ou o motivo do skip — nunca logar
  # `automation_executed_*` quando a regra foi no-op, senão a trilha de
  # auditoria mente sobre o que aconteceu (B-03). Cada avaliação vira um
  # registro em crm_automation_runs (CRM-003).
  def process_rule(rule)
    config = rule.action_config&.with_indifferent_access || {}
    unless conditions_match?(config)
      record_run(rule, status: 'skipped', skip_reason: 'condition')
      log_skip(rule, 'automation_skipped_by_condition', config)
      return
    end

    started_at = Time.current
    result = begin
      case rule.action_type
      when 'create_activity' then execute_create_activity(config)
      when 'set_captain_mode' then execute_set_captain_mode(config)
      when 'move_to_stage' then execute_move_to_stage(config)
      when 'assign_owner' then execute_assign_owner(config)
      else :unknown_action_type
      end
    rescue StandardError => e
      record_run(rule, status: 'failed', error: "#{e.class}: #{e.message}", started_at: started_at)
      raise
    end

    if result == :executed
      record_run(rule, status: 'executed', started_at: started_at)
      Crm::AuditLogger.log(
        account: @deal.account,
        actor: @actor,
        action: "automation_executed_#{rule.action_type}",
        target: @deal,
        payload: { automation: @trigger || 'stage', stage_slug: @deal.crm_pipeline_stage&.slug, rule_id: rule.id, action_type: rule.action_type }
      )
    else
      record_run(rule, status: 'skipped', skip_reason: result.to_s, started_at: started_at)
      log_skip(rule, "automation_skipped_#{result}", config)
    end
  end

  def record_run(rule, status:, skip_reason: nil, error: nil, started_at: Time.current)
    CrmAutomationRun.create!(
      account: @deal.account,
      crm_automation_rule: rule,
      crm_deal: @deal,
      status: status,
      skip_reason: skip_reason,
      error: error,
      payload: { automation: @trigger || 'stage', stage_slug: @deal.crm_pipeline_stage&.slug, action_type: rule.action_type },
      started_at: started_at,
      finished_at: Time.current
    )
  rescue StandardError => e
    # A persistência do run nunca derruba a automação em si.
    Rails.logger.error("[CRM StageAutomation] falha ao gravar run da regra #{rule.id}: #{e.class}: #{e.message}")
    nil
  end

  def log_skip(rule, action, config)
    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: action,
      target: @deal,
      payload: { automation: @trigger || 'stage', rule_id: rule.id, conditions: config[:conditions] }
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

  def execute_create_activity(config)
    return :duplicate_activity if pending_activity_exists?(config)

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
    :executed
  end

  def execute_set_captain_mode(config)
    conversation = @deal.conversation
    return :no_conversation unless conversation

    captain_state = @deal.account.captain_conversation_states.find_by(conversation: conversation)
    return :no_captain_state unless captain_state

    mode = config[:ai_mode].to_s
    return :invalid_ai_mode unless CaptainConversationState::AI_MODES.include?(mode)

    captain_state.apply_ai_mode!(
      mode: mode,
      reason: config[:reason] || "Automacao CRM: deal entrou na etapa #{@deal.crm_pipeline_stage&.name}"
    )
    :executed
  end

  def execute_move_to_stage(config)
    target_slug = config[:stage_slug].to_s
    return :blank_stage_slug if target_slug.blank?

    target_stage = @deal.crm_pipeline.crm_pipeline_stages.active.find_by(slug: target_slug)
    return :stage_not_found unless target_stage
    return :same_stage if @deal.crm_pipeline_stage_id == target_stage.id

    # Guarda de ciclo: cada move encadeado incrementa a profundidade; ao
    # atingir o teto a automação é pulada (o comportamento de regras não
    # cíclicas, que nunca chegam perto do teto, não muda).
    if @automation_depth >= MAX_AUTOMATION_DEPTH
      Rails.logger.warn(
        "[CRM StageAutomation] move_to_stage ignorado: profundidade máxima #{MAX_AUTOMATION_DEPTH} " \
        "atingida (possível ciclo) deal=#{@deal.id} etapa_destino=#{target_slug}"
      )
      return :max_depth
    end

    Crm::DealMover.new(
      deal: @deal,
      stage_id: target_stage.id,
      actor: @actor,
      automation_depth: @automation_depth + 1
    ).perform
    :executed
  end

  # O dono é sempre gravado; o responsável acompanha o dono, exceto quando foi
  # escolhido a dedo — regra centralizada em Crm::DealOwnerAssigner.
  # Diferente da acao manual em massa, nao mexemos em `contact.crm_owner_id`:
  # isso rerotearia todos os negocios futuros do contato.
  def execute_assign_owner(config)
    user = resolve_owner(config[:user_id])
    return :invalid_owner if user.nil?

    result = Crm::DealOwnerAssigner.new(
      deal: @deal,
      owner: user,
      actor: @actor,
      sync_assignee: :if_unmanaged
    ).perform
    log_preserved_assignee(result.preserved_assignee_id) if result.preserved_assignee_id
    :executed
  end

  def log_preserved_assignee(assignee_id)
    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: 'automation_preserved_assignee',
      target: @deal,
      payload: { automation: @trigger || 'stage', assignee_id: assignee_id }
    )
  end

  def resolve_owner(user_id)
    return if user_id.blank?

    @deal.account.users.find_by(id: user_id)
  end
end

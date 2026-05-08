class Crm::StageAutomation
  def initialize(deal:, actor: nil)
    @deal = deal
    @actor = actor
  end

  def perform
    rules = CrmAutomationRule.active.for_stage(@deal.crm_pipeline_stage_id)
    return if rules.none?

    rules.each do |rule|
      config = rule.action_config&.with_indifferent_access || {}
      unless conditions_match?(config)
        Crm::AuditLogger.log(
          account: @deal.account,
          actor: @actor,
          action: 'automation_skipped_by_condition',
          target: @deal,
          payload: { automation: 'stage', rule_id: rule.id, conditions: config[:conditions] }
        )
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
        execute_assign_owner(rule, config)
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

    captain_state = CaptainConversationState.find_by(conversation: conversation)
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

    Crm::DealMover.new(deal: @deal, stage_id: target_stage.id, actor: @actor).perform
  end

  def execute_assign_owner(_rule, config)
    user_id = config[:user_id]
    return unless user_id

    user = @deal.account.users.find_by(id: user_id)
    return unless user

    @deal.update!(assigned_to_id: user.id) if @deal.respond_to?(:assigned_to_id)
  end
end

class Captain::FlowRuntime
  MAX_STEPS = 20

  def initialize(conversation:)
    @conversation = conversation
    @state = conversation.captain_conversation_state
  end

  def step(incoming_message: nil)
    return { action: :no_action } unless active?

    if awaiting_answer? && incoming_message.present?
      store_answer(current_node, incoming_message)
      advance_state(current_node)
    end

    MAX_STEPS.times do
      node = current_node
      return { action: :flow_complete } unless node

      case node.node_type
      when 'start'
        advance_state(node)
      when 'message'
        text = config_text(node)
        advance_state(node)
        return { action: :send_message, text: text }
      when 'question'
        text = config_text(node)
        mark_asked(node)
        return { action: :send_message, text: text }
      when 'condition'
        execute_condition(node)
      when 'score'
        execute_score(node)
        advance_state(node)
      when 'crm_action'
        execute_crm_action(node)
        advance_state(node)
      when 'handoff'
        execute_handoff(node)
        advance_state(node)
        return { action: :handoff }
      when 'end'
        @state.update!(current_node_id: nil)
        return { action: :flow_complete }
      else
        advance_state(node)
      end
    end

    { action: :no_action }
  end

  def active?
    @state&.captain_flow.present? && @state.current_node_id.present?
  end

  def awaiting_answer?
    active? && current_node&.node_type == 'question' && asked?(current_node)
  end

  private

  def current_node
    return nil unless @state&.captain_flow

    @state.captain_flow.flow_nodes.find_by(node_id: @state.current_node_id)
  end

  def advance_state(node)
    edge = @state.captain_flow.flow_edges.find_by(source_node_id: node.node_id)
    @state.update!(current_node_id: edge&.target_node_id)
  end

  def config_text(node)
    c = (node.config || {}).with_indifferent_access
    c['label'].presence || c['text'].presence || ''
  end

  def asked?(node)
    @state.score_payload&.dig('asked_nodes', node.node_id) == true
  end

  def mark_asked(node)
    payload = (@state.score_payload || {}).deep_dup
    payload['asked_nodes'] ||= {}
    payload['asked_nodes'][node.node_id] = true
    @state.update!(score_payload: payload)
  end

  def store_answer(node, answer)
    c = (node.config || {}).with_indifferent_access
    var = c['variable_name'].presence || "answer_#{node.node_id}"
    payload = (@state.score_payload || {}).deep_dup
    payload['answers'] ||= {}
    payload['answers'][var] = answer
    @state.update!(score_payload: payload)
  end

  def execute_condition(node)
    c = (node.config || {}).with_indifferent_access
    field    = c['field'].to_s
    operator = c['operator'].to_s
    value    = c['value']

    current_value = case field
                    when 'score_total' then @state.score_total.to_i
                    when 'ai_mode'     then @state.ai_mode.to_s
                    else 0
                    end

    matched = case operator
              when 'gte' then current_value >= value.to_i
              when 'gt'  then current_value > value.to_i
              when 'lte' then current_value <= value.to_i
              when 'lt'  then current_value < value.to_i
              when 'eq'  then current_value.to_s == value.to_s
              else false
              end

    branch = matched ? 'yes' : 'no'
    edge = @state.captain_flow.flow_edges.find_by(source_node_id: node.node_id, label: branch) ||
           @state.captain_flow.flow_edges.find_by(source_node_id: node.node_id)

    @state.update!(current_node_id: edge&.target_node_id)
  end

  def execute_score(node)
    c = (node.config || {}).with_indifferent_access
    points    = c['points'].to_i
    criterion = c['criterion'].presence || 'flow'
    reason    = c['reason'].presence || "Node #{node.node_id}"

    new_total = (@state.score_total.to_i + points).clamp(0, 100)
    payload   = (@state.score_payload || {}).deep_dup
    payload['reasons'] ||= []
    payload['reasons'] << { criterion: criterion, points: points, reason: reason }

    @state.update!(score_total: new_total, score_payload: payload)
  end

  def execute_crm_action(node)
    return unless @state.crm_deal_id.present?

    deal = CrmDeal.find_by(id: @state.crm_deal_id)
    return unless deal

    c = (node.config || {}).with_indifferent_access

    case c['action_type'].to_s
    when 'move_deal'
      stage = deal.crm_pipeline.crm_pipeline_stages.find_by(slug: c['stage_slug'])
      Crm::DealMover.new(deal: deal, stage_id: stage.id, actor: nil).perform if stage
    when 'create_activity'
      valid_kinds = CrmActivity::KINDS
      kind = c['kind'].presence.then { |k| valid_kinds.include?(k) ? k : 'follow_up' }
      deal.crm_activities.create!(
        account: deal.account,
        kind: kind,
        title: c['title'].presence || 'Atividade do fluxo',
        priority: c['priority'].presence.then { |p| CrmActivity::PRIORITIES.include?(p) ? p : 'normal' } || 'normal',
        due_at: Time.current + 24.hours
      )
    end
  end

  def execute_handoff(node)
    c = (node.config || {}).with_indifferent_access
    mode   = c['mode'].presence || 'human_only'
    reason = c['reason'].presence || 'Handoff configurado no fluxo'
    @state.apply_ai_mode!(mode: mode, reason: reason)
  end
end

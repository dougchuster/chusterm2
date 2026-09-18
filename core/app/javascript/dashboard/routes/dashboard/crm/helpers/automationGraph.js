export const DEFAULT_TRIGGER = {
  trigger_event: 'stage_entered',
  crm_pipeline_stage_id: '',
};

export const DEFAULT_ACTION = {
  action_type: 'create_activity',
  kind: 'follow_up',
  title: '',
  description: '',
  priority: 'normal',
  due_in_hours: 24,
  ai_mode: 'copilot',
  stage_slug: '',
  user_id: '',
  reason: '',
};

export const DEFAULT_CONDITION = {
  field: 'legal_area',
  operator: 'eq',
  value: '',
};

const NO_VALUE_OPERATORS = ['present', 'blank'];

export function cleanConditions(conditions = []) {
  return conditions
    .filter(cond => cond && cond.field && cond.operator)
    .map(cond => ({
      field: cond.field,
      operator: cond.operator,
      value: NO_VALUE_OPERATORS.includes(cond.operator)
        ? null
        : (cond.value ?? ''),
    }));
}

/**
 * Traverses edges in topological order starting from a trigger node.
 */
export function getOrderedNodes(nodes = [], edges = []) {
  if (!nodes.length) return [];

  const triggerNode = nodes.find(n => n.type === 'trigger');
  if (!triggerNode) return nodes;

  const nodeMap = new Map(nodes.map(n => [n.id, n]));
  const adjacency = new Map();
  edges.forEach(edge => {
    if (!adjacency.has(edge.source)) adjacency.set(edge.source, []);
    adjacency.get(edge.source).push(edge.target);
  });

  const ordered = [];
  const visited = new Set();
  const queue = [triggerNode.id];

  while (queue.length > 0) {
    const currentId = queue.shift();
    if (!visited.has(currentId)) {
      visited.add(currentId);

      const node = nodeMap.get(currentId);
      if (node) ordered.push(node);

      const neighbors = adjacency.get(currentId) || [];
      neighbors.forEach(neighborId => {
        if (!visited.has(neighborId)) {
          queue.push(neighborId);
        }
      });
    }
  }

  // Include any remaining disconnected nodes at the end
  nodes.forEach(node => {
    if (!visited.has(node.id)) {
      ordered.push(node);
    }
  });

  return ordered;
}

/**
 * Converts a backend rule into a visual node graph { nodes, edges }.
 */
export function rulesToGraph(rule = {}) {
  const name = rule.name || '';
  const triggerEvent = rule.trigger_event || DEFAULT_TRIGGER.trigger_event;
  const stageId =
    rule.crm_pipeline_stage_id ?? DEFAULT_TRIGGER.crm_pipeline_stage_id;
  const actionType = rule.action_type || DEFAULT_ACTION.action_type;
  const actionConfig = rule.action_config || {};
  const rawConditions = actionConfig.conditions || [];
  const conditions = cleanConditions(rawConditions);

  const nodes = [];
  const edges = [];

  const startX = 250;
  let currentY = 50;
  const ySpacing = 140;

  // 1. Trigger node
  const triggerNodeId = 'node-trigger-1';
  nodes.push({
    id: triggerNodeId,
    type: 'trigger',
    position: { x: startX, y: currentY },
    data: {
      name,
      trigger_event: triggerEvent,
      crm_pipeline_stage_id: stageId,
    },
  });

  let previousNodeId = triggerNodeId;

  // 2. Condition nodes (one per condition)
  conditions.forEach((condition, index) => {
    currentY += ySpacing;
    const condNodeId = `node-condition-${index + 1}`;
    nodes.push({
      id: condNodeId,
      type: 'condition',
      position: { x: startX, y: currentY },
      data: {
        field: condition.field,
        operator: condition.operator,
        value: condition.value,
      },
    });

    edges.push({
      id: `edge-${previousNodeId}-${condNodeId}`,
      source: previousNodeId,
      target: condNodeId,
      type: 'smoothstep',
      animated: true,
    });

    previousNodeId = condNodeId;
  });

  // 3. Action node
  currentY += ySpacing;
  const actionNodeId = 'node-action-1';
  nodes.push({
    id: actionNodeId,
    type: 'action',
    position: { x: startX, y: currentY },
    data: {
      action_type: actionType,
      kind: actionConfig.kind || DEFAULT_ACTION.kind,
      title: actionConfig.title || '',
      description: actionConfig.description || '',
      priority: actionConfig.priority || DEFAULT_ACTION.priority,
      due_in_hours: actionConfig.due_in_hours ?? DEFAULT_ACTION.due_in_hours,
      ai_mode: actionConfig.ai_mode || DEFAULT_ACTION.ai_mode,
      stage_slug: actionConfig.stage_slug || '',
      user_id: actionConfig.user_id || '',
      reason: actionConfig.reason || '',
      delay_minutes: actionConfig.delay_minutes || 0,
    },
  });

  edges.push({
    id: `edge-${previousNodeId}-${actionNodeId}`,
    source: previousNodeId,
    target: actionNodeId,
    type: 'smoothstep',
    animated: true,
  });

  return { nodes, edges };
}

/**
 * Converts a visual node graph { nodes, edges } back to the backend rule payload.
 */
export function graphToRules({ nodes = [], edges = [] } = {}) {
  const orderedNodes = getOrderedNodes(nodes, edges);

  const triggerNode =
    orderedNodes.find(n => n.type === 'trigger') ||
    nodes.find(n => n.type === 'trigger') ||
    nodes[0] ||
    {};

  const actionNode =
    [...orderedNodes].reverse().find(n => n.type === 'action') ||
    nodes.find(n => n.type === 'action') ||
    nodes[nodes.length - 1] ||
    {};

  const conditionNodes = orderedNodes.filter(n => n.type === 'condition');

  const conditions = cleanConditions(
    conditionNodes.map(cn => ({
      field: cn.data?.field,
      operator: cn.data?.operator,
      value: cn.data?.value,
    }))
  );

  const triggerData = triggerNode.data || {};
  const actionData = actionNode.data || {};

  const name = String(triggerData.name || '').trim();
  const triggerEvent =
    triggerData.trigger_event || DEFAULT_TRIGGER.trigger_event;
  const stageId = triggerData.crm_pipeline_stage_id ?? '';
  const actionType = actionData.action_type || DEFAULT_ACTION.action_type;

  let actionConfig = {};

  if (actionType === 'create_activity') {
    actionConfig = {
      kind: actionData.kind || DEFAULT_ACTION.kind,
      title: String(actionData.title || '').trim(),
      description: String(actionData.description || '').trim() || null,
      priority: actionData.priority || DEFAULT_ACTION.priority,
      due_in_hours: Number(
        actionData.due_in_hours ?? DEFAULT_ACTION.due_in_hours
      ),
      conditions,
    };
  } else if (actionType === 'set_captain_mode') {
    actionConfig = {
      ai_mode: actionData.ai_mode || DEFAULT_ACTION.ai_mode,
      reason: String(actionData.reason || '').trim() || null,
      conditions,
    };
  } else if (actionType === 'move_to_stage') {
    actionConfig = {
      stage_slug: actionData.stage_slug || '',
      conditions,
    };
  } else if (actionType === 'assign_owner') {
    actionConfig = {
      user_id: actionData.user_id || '',
      conditions,
    };
  } else {
    actionConfig = {
      ...actionData,
      conditions,
    };
  }

  // 5.3: delay_minutes > 0 agenda a ação (Crm::AutomationActionJob) em vez
  // de executar no gatilho. Vale para qualquer tipo de ação.
  const delayMinutes = Number(actionData.delay_minutes || 0);
  if (delayMinutes > 0) actionConfig.delay_minutes = delayMinutes;

  return {
    name,
    trigger_event: triggerEvent,
    crm_pipeline_stage_id: stageId,
    action_type: actionType,
    action_config: actionConfig,
  };
}

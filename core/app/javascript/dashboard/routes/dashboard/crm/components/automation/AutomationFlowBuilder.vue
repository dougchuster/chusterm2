<script setup>
import { computed, markRaw, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DsBadge from 'dashboard/design-system/components/DsBadge.vue';
import DsButton from 'dashboard/design-system/components/DsButton.vue';
import DsInput from 'dashboard/design-system/components/DsInput.vue';
import DsSelect from 'dashboard/design-system/components/DsSelect.vue';
import DsTextarea from 'dashboard/design-system/components/DsTextarea.vue';
import {
  DEFAULT_ACTION,
  DEFAULT_CONDITION,
  DEFAULT_TRIGGER,
  graphToRules,
  rulesToGraph,
} from '../../helpers/automationGraph';
import ActionNode from './nodes/ActionNode.vue';
import ConditionNode from './nodes/ConditionNode.vue';
import TriggerNode from './nodes/TriggerNode.vue';

const props = defineProps({
  initialRule: { type: Object, default: () => ({}) },
  pipelines: { type: Array, default: () => [] },
  saving: { type: Boolean, default: false },
});

const emit = defineEmits(['save', 'cancel']);

const { t } = useI18n();

const nodeTypes = {
  trigger: markRaw(TriggerNode),
  condition: markRaw(ConditionNode),
  action: markRaw(ActionNode),
};

const nodes = ref([]);
const edges = ref([]);
const selectedNodeId = ref(null);
const validationError = ref('');

const { fitView, zoomIn, zoomOut } = useVueFlow();

const allStages = computed(() =>
  props.pipelines.flatMap(pipeline =>
    (pipeline.stages || []).map(stage => ({
      id: stage.id,
      slug: stage.slug || String(stage.id),
      name: stage.name,
      pipelineName: pipeline.name,
    }))
  )
);

const stageOptions = computed(() =>
  allStages.value.map(stage => ({
    value: stage.id,
    label: `${stage.pipelineName} / ${stage.name}`,
  }))
);

const stageSlugOptions = computed(() =>
  allStages.value.map(stage => ({
    value: stage.slug,
    label: `${stage.pipelineName} / ${stage.name}`,
  }))
);

const triggerEventOptions = computed(() => [
  {
    value: 'stage_entered',
    label: t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.STAGE_ENTERED'),
  },
  {
    value: 'score_changed',
    label: t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.SCORE_CHANGED'),
  },
  {
    value: 'stale_detected',
    label: t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.STALE_DETECTED'),
  },
  {
    value: 'handoff',
    label: t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.HANDOFF'),
  },
  {
    value: 'message_received',
    label: t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.MESSAGE_RECEIVED'),
  },
  {
    value: 'marketing_lead_created',
    label: t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.MARKETING_LEAD_CREATED'),
  },
]);

const actionTypeOptions = computed(() => [
  {
    value: 'create_activity',
    label: t('CRM.AUTOMATION_RULES.ACTION_TYPES.CREATE_ACTIVITY'),
  },
  {
    value: 'set_captain_mode',
    label: t('CRM.AUTOMATION_RULES.ACTION_TYPES.SET_CAPTAIN_MODE'),
  },
  {
    value: 'move_to_stage',
    label: t('CRM.AUTOMATION_RULES.ACTION_TYPES.MOVE_TO_STAGE'),
  },
  {
    value: 'assign_owner',
    label: t('CRM.AUTOMATION_RULES.ACTION_TYPES.ASSIGN_OWNER'),
  },
]);

const actionKindOptions = computed(() => [
  { value: 'ligacao', label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.LIGACAO') },
  {
    value: 'solicitacao_documentos',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.SOLICITACAO_DOCUMENTOS'),
  },
  { value: 'follow_up', label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.FOLLOW_UP') },
  { value: 'reuniao', label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.REUNIAO') },
  {
    value: 'revisao_juridica',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.REVISAO_JURIDICA'),
  },
  {
    value: 'analise_documental',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ANALISE_DOCUMENTAL'),
  },
  {
    value: 'retorno_cliente',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.RETORNO_CLIENTE'),
  },
  {
    value: 'envio_proposta',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ENVIO_PROPOSTA'),
  },
  {
    value: 'envio_contrato',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ENVIO_CONTRATO'),
  },
  {
    value: 'arquivamento',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ARQUIVAMENTO'),
  },
]);

const priorityOptions = computed(() => [
  { value: 'baixa', label: t('CRM.AUTOMATION_RULES.PRIORITIES.BAIXA') },
  { value: 'normal', label: t('CRM.AUTOMATION_RULES.PRIORITIES.NORMAL') },
  { value: 'alta', label: t('CRM.AUTOMATION_RULES.PRIORITIES.ALTA') },
  { value: 'critica', label: t('CRM.AUTOMATION_RULES.PRIORITIES.CRITICA') },
]);

const aiModeOptions = computed(() => [
  {
    value: 'copilot',
    label: t('CRM.AUTOMATION_RULES.BUILDER.ACTION_AI_MODE_COPILOT'),
  },
  {
    value: 'autonomous',
    label: t('CRM.AUTOMATION_RULES.BUILDER.ACTION_AI_MODE_AUTONOMOUS'),
  },
  {
    value: 'disabled',
    label: t('CRM.AUTOMATION_RULES.BUILDER.ACTION_AI_MODE_DISABLED'),
  },
  {
    value: 'assist',
    label: t('CRM.AUTOMATION_RULES.BUILDER.ACTION_AI_MODE_ASSIST'),
  },
]);

const conditionFieldOptions = computed(() => [
  {
    value: 'legal_area',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.LEGAL_AREA'),
  },
  {
    value: 'case_type',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.CASE_TYPE'),
  },
  {
    value: 'urgency_level',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.URGENCY_LEVEL'),
  },
  {
    value: 'score_total',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.SCORE_TOTAL'),
  },
  {
    value: 'relationship_status',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.RELATIONSHIP_STATUS'),
  },
  {
    value: 'lifecycle_stage',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.LIFECYCLE_STAGE'),
  },
  {
    value: 'has_phone',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.HAS_PHONE'),
  },
  {
    value: 'campaign_opt_out',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.CAMPAIGN_OPT_OUT'),
  },
  {
    value: 'stage',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.STAGE'),
  },
  {
    value: 'status',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.STATUS'),
  },
]);

const conditionOperatorOptions = computed(() => [
  { value: 'eq', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.EQ') },
  { value: 'not_eq', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.NOT_EQ') },
  { value: 'present', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.PRESENT') },
  { value: 'blank', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.BLANK') },
  { value: 'gt', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.GT') },
  { value: 'gte', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.GTE') },
  { value: 'lt', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.LT') },
  { value: 'lte', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.LTE') },
  { value: 'in', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.IN') },
  { value: 'not_in', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.NOT_IN') },
]);

const selectedNode = computed(() =>
  nodes.value.find(node => node.id === selectedNodeId.value)
);

const triggerNode = computed(() =>
  nodes.value.find(node => node.type === 'trigger')
);

const actionNode = computed(() =>
  nodes.value.find(node => node.type === 'action')
);

const ruleName = computed({
  get: () => triggerNode.value?.data?.name || '',
  set: val => {
    if (triggerNode.value) {
      triggerNode.value.data.name = val;
    }
  },
});

function loadRule(rule) {
  const graph = rulesToGraph(rule || {});
  // Attach stage name helper for display on trigger
  if (graph.nodes[0] && graph.nodes[0].data) {
    const stage = allStages.value.find(
      s => String(s.id) === String(graph.nodes[0].data.crm_pipeline_stage_id)
    );
    if (stage) {
      graph.nodes[0].data.stageName = `${stage.pipelineName} / ${stage.name}`;
    }
  }
  nodes.value = graph.nodes;
  edges.value = graph.edges;
  if (nodes.value.length > 0) {
    selectedNodeId.value = nodes.value[0].id;
  }
}

function onNodeClick(event) {
  selectedNodeId.value = event.node.id;
}

function onConnect(connection) {
  edges.value.push({
    id: `edge-${connection.source}-${connection.target}`,
    source: connection.source,
    target: connection.target,
    type: 'smoothstep',
    animated: true,
  });
}

function autoLayout() {
  const startX = 250;
  let currentY = 50;
  const ySpacing = 150;

  const trigger = nodes.value.find(n => n.type === 'trigger');
  const conditions = nodes.value.filter(n => n.type === 'condition');
  const action = nodes.value.find(n => n.type === 'action');

  if (trigger) {
    trigger.position = { x: startX, y: currentY };
    currentY += ySpacing;
  }

  conditions.forEach(cond => {
    cond.position = { x: startX, y: currentY };
    currentY += ySpacing;
  });

  if (action) {
    action.position = { x: startX, y: currentY };
  }
}

function addTriggerNode() {
  if (triggerNode.value) return;
  const id = `node-trigger-${Date.now()}`;
  const newNode = {
    id,
    type: 'trigger',
    position: { x: 250, y: 50 },
    data: { ...DEFAULT_TRIGGER, name: '' },
  };
  nodes.value.unshift(newNode);
  selectedNodeId.value = id;
}

function addConditionNode() {
  const id = `node-condition-${Date.now()}`;
  const lastNode = nodes.value[nodes.value.length - 1];
  const newY = lastNode ? lastNode.position.y + 80 : 150;

  const newNode = {
    id,
    type: 'condition',
    position: { x: 250, y: newY },
    data: { ...DEFAULT_CONDITION },
  };

  nodes.value.push(newNode);
  selectedNodeId.value = id;
}

function addActionNode() {
  if (actionNode.value) return;
  const id = `node-action-${Date.now()}`;
  const lastNode = nodes.value[nodes.value.length - 1];
  const newY = lastNode ? lastNode.position.y + 150 : 300;

  const newNode = {
    id,
    type: 'action',
    position: { x: 250, y: newY },
    data: { ...DEFAULT_ACTION },
  };

  nodes.value.push(newNode);
  selectedNodeId.value = id;
}

function deleteNode(nodeId) {
  nodes.value = nodes.value.filter(node => node.id !== nodeId);
  edges.value = edges.value.filter(
    edge => edge.source !== nodeId && edge.target !== nodeId
  );
  if (selectedNodeId.value === nodeId) {
    selectedNodeId.value = nodes.value[0]?.id || null;
  }
}

function handleStageChange(stageId) {
  if (selectedNode.value && selectedNode.value.type === 'trigger') {
    selectedNode.value.data.crm_pipeline_stage_id = stageId;
    const stage = allStages.value.find(s => String(s.id) === String(stageId));
    selectedNode.value.data.stageName = stage
      ? `${stage.pipelineName} / ${stage.name}`
      : '';
  }
}

function validateAndSave() {
  validationError.value = '';

  const payload = graphToRules({
    nodes: nodes.value,
    edges: edges.value,
  });

  if (!payload.name) {
    validationError.value = t(
      'CRM.AUTOMATION_RULES.BUILDER.VALIDATION_NAME_REQUIRED'
    );
    return;
  }

  if (
    payload.trigger_event === 'stage_entered' &&
    !payload.crm_pipeline_stage_id
  ) {
    validationError.value = t(
      'CRM.AUTOMATION_RULES.BUILDER.VALIDATION_STAGE_REQUIRED'
    );
    return;
  }

  if (!triggerNode.value) {
    validationError.value = t(
      'CRM.AUTOMATION_RULES.BUILDER.VALIDATION_TRIGGER_REQUIRED'
    );
    return;
  }

  if (!actionNode.value) {
    validationError.value = t(
      'CRM.AUTOMATION_RULES.BUILDER.VALIDATION_ACTION_REQUIRED'
    );
    return;
  }

  if (
    payload.action_type === 'create_activity' &&
    !payload.action_config?.title
  ) {
    validationError.value = t(
      'CRM.AUTOMATION_RULES.BUILDER.VALIDATION_ACTION_TITLE_REQUIRED'
    );
    return;
  }

  emit('save', payload);
}

watch(
  () => props.initialRule,
  newRule => {
    loadRule(newRule);
  },
  { immediate: true }
);

onMounted(() => {
  if (props.initialRule && Object.keys(props.initialRule).length) {
    loadRule(props.initialRule);
  }
});
</script>

<template>
  <div class="flex h-full w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text">
    <!-- Header Toolbar -->
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-ui-border-subtle bg-ui-surface px-4 py-3 sm:px-6"
    >
      <div class="flex min-w-0 flex-1 items-center gap-3">
        <div
          class="grid size-9 place-items-center rounded-ui-control bg-ui-brand-soft text-ui-brand"
        >
          <Icon icon="i-lucide-workflow" class="size-5" />
        </div>
        <div class="min-w-0 flex-1">
          <DsInput
            v-model="ruleName"
            :label="$t('CRM.AUTOMATION_RULES.BUILDER.RULE_NAME_LABEL')"
            hide-label
            :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.RULE_NAME_PLACEHOLDER')"
            class="max-w-md font-manrope font-semibold"
          />
        </div>
      </div>

      <div class="flex items-center gap-2">
        <DsButton
          variant="ghost"
          :label="$t('CRM.AUTOMATION_RULES.BUILDER.CANCEL')"
          :disabled="saving"
          @click="$emit('cancel')"
        />
        <DsButton
          variant="primary"
          icon="i-lucide-check"
          :label="
            saving
              ? $t('CRM.AUTOMATION_RULES.BUILDER.SAVING')
              : $t('CRM.AUTOMATION_RULES.BUILDER.SAVE')
          "
          :loading="saving"
          @click="validateAndSave"
        />
      </div>
    </header>

    <!-- Error Alert -->
    <div
      v-if="validationError"
      role="alert"
      class="border-b border-ui-danger/20 bg-ui-danger-soft px-4 py-2 text-ui-body-sm text-ui-danger-foreground"
    >
      {{ validationError }}
    </div>

    <!-- Main Workspace: VueFlow Canvas + Side Properties Drawer -->
    <div class="relative flex min-h-0 flex-1 overflow-hidden">
      <!-- VueFlow Canvas -->
      <div class="relative min-h-0 flex-1 bg-ui-canvas">
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :node-types="nodeTypes"
          :default-viewport="{ zoom: 1 }"
          :min-zoom="0.2"
          :max-zoom="2"
          fit-view-on-init
          class="h-full w-full"
          @node-click="onNodeClick"
          @connect="onConnect"
        >
          <!-- Custom Toolbar Controls on Canvas -->
          <template #default>
            <div
              class="absolute left-4 top-4 z-10 flex flex-wrap items-center gap-2 rounded-ui-surface border border-ui-border-subtle bg-ui-surface/90 p-1.5 shadow-ui-overlay backdrop-blur-sm"
            >
              <DsButton
                v-if="!triggerNode"
                size="sm"
                variant="secondary"
                icon="i-lucide-zap"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ADD_TRIGGER')"
                @click="addTriggerNode"
              />
              <DsButton
                size="sm"
                variant="secondary"
                icon="i-lucide-filter"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ADD_CONDITION')"
                @click="addConditionNode"
              />
              <DsButton
                v-if="!actionNode"
                size="sm"
                variant="secondary"
                icon="i-lucide-play-circle"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ADD_ACTION')"
                @click="addActionNode"
              />
              <div class="h-4 w-px bg-ui-border-subtle" />
              <DsButton
                size="sm"
                variant="ghost"
                icon="i-lucide-layout-grid"
                :aria-label="$t('CRM.AUTOMATION_RULES.BUILDER.AUTO_LAYOUT')"
                @click="autoLayout"
              />
              <DsButton
                size="sm"
                variant="ghost"
                icon="i-lucide-zoom-in"
                :aria-label="$t('CRM.AUTOMATION_RULES.BUILDER.ZOOM_IN')"
                @click="() => zoomIn()"
              />
              <DsButton
                size="sm"
                variant="ghost"
                icon="i-lucide-zoom-out"
                :aria-label="$t('CRM.AUTOMATION_RULES.BUILDER.ZOOM_OUT')"
                @click="() => zoomOut()"
              />
              <DsButton
                size="sm"
                variant="ghost"
                icon="i-lucide-maximize-2"
                :aria-label="$t('CRM.AUTOMATION_RULES.BUILDER.FIT_VIEW')"
                @click="() => fitView()"
              />
            </div>
          </template>
        </VueFlow>
      </div>

      <!-- Properties Panel (Sidebar) -->
      <aside
        v-if="selectedNode"
        class="flex w-80 shrink-0 flex-col border-l border-ui-border-subtle bg-ui-surface shadow-ui-overlay sm:w-96"
        aria-label="Node Properties"
      >
        <div
          class="flex items-center justify-between border-b border-ui-border-subtle px-4 py-3"
        >
          <div class="flex items-center gap-2">
            <h3 class="m-0 font-manrope text-ui-label font-semibold text-ui-text">
              {{ $t('CRM.AUTOMATION_RULES.BUILDER.DRAWER_TITLE') }}
            </h3>
            <DsBadge
              :variant="
                selectedNode.type === 'trigger'
                  ? 'brand'
                  : selectedNode.type === 'condition'
                    ? 'warning'
                    : 'success'
              "
              :label="
                selectedNode.type === 'trigger'
                  ? $t('CRM.AUTOMATION_RULES.BUILDER.NODE_TRIGGER_LABEL')
                  : selectedNode.type === 'condition'
                    ? $t('CRM.AUTOMATION_RULES.BUILDER.NODE_CONDITION_LABEL')
                    : $t('CRM.AUTOMATION_RULES.BUILDER.NODE_ACTION_LABEL')
              "
            />
          </div>
          <DsButton
            size="sm"
            variant="ghost"
            icon="i-lucide-trash-2"
            :aria-label="$t('CRM.AUTOMATION_RULES.BUILDER.DELETE_NODE')"
            @click="deleteNode(selectedNode.id)"
          />
        </div>

        <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <!-- Trigger Properties -->
          <template v-if="selectedNode.type === 'trigger'">
            <DsInput
              v-model="selectedNode.data.name"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.RULE_NAME_LABEL')"
              :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.RULE_NAME_PLACEHOLDER')"
              required
            />
            <DsSelect
              v-model="selectedNode.data.trigger_event"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.TRIGGER_EVENT_LABEL')"
              :options="triggerEventOptions"
            />
            <DsSelect
              :model-value="selectedNode.data.crm_pipeline_stage_id"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.TRIGGER_STAGE_LABEL')"
              :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.TRIGGER_STAGE_PLACEHOLDER')"
              :options="stageOptions"
              required
              @update:model-value="handleStageChange"
            />
          </template>

          <!-- Condition Properties -->
          <template v-else-if="selectedNode.type === 'condition'">
            <DsSelect
              v-model="selectedNode.data.field"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.CONDITION_FIELD_LABEL')"
              :options="conditionFieldOptions"
            />
            <DsSelect
              v-model="selectedNode.data.operator"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.CONDITION_OPERATOR_LABEL')"
              :options="conditionOperatorOptions"
            />
            <DsInput
              v-if="!['present', 'blank'].includes(selectedNode.data.operator)"
              v-model="selectedNode.data.value"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.CONDITION_VALUE_LABEL')"
              :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.CONDITION_VALUE_PLACEHOLDER')"
            />
          </template>

          <!-- Action Properties -->
          <template v-else-if="selectedNode.type === 'action'">
            <DsSelect
              v-model="selectedNode.data.action_type"
              :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_TYPE_LABEL')"
              :options="actionTypeOptions"
            />

            <!-- create_activity fields -->
            <template
              v-if="
                selectedNode.data.action_type === 'create_activity' ||
                !selectedNode.data.action_type
              "
            >
              <DsSelect
                v-model="selectedNode.data.kind"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_KIND_LABEL')"
                :options="actionKindOptions"
              />
              <DsSelect
                v-model="selectedNode.data.priority"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_PRIORITY_LABEL')"
                :options="priorityOptions"
              />
              <DsInput
                v-model="selectedNode.data.title"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_TITLE_LABEL')"
                :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_TITLE_PLACEHOLDER')"
                required
              />
              <DsInput
                v-model="selectedNode.data.due_in_hours"
                type="number"
                min="1"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_DUE_HOURS_LABEL')"
              />
              <DsTextarea
                v-model="selectedNode.data.description"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_DESC_LABEL')"
                :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_DESC_PLACEHOLDER')"
              />
            </template>

            <!-- set_captain_mode fields -->
            <template
              v-else-if="selectedNode.data.action_type === 'set_captain_mode'"
            >
              <DsSelect
                v-model="selectedNode.data.ai_mode"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_AI_MODE_LABEL')"
                :options="aiModeOptions"
              />
              <DsInput
                v-model="selectedNode.data.reason"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_REASON_LABEL')"
                :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_REASON_PLACEHOLDER')"
              />
            </template>

            <!-- move_to_stage fields -->
            <template
              v-else-if="selectedNode.data.action_type === 'move_to_stage'"
            >
              <DsSelect
                v-model="selectedNode.data.stage_slug"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_TARGET_STAGE_LABEL')"
                :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_TARGET_STAGE_PLACEHOLDER')"
                :options="stageSlugOptions"
              />
            </template>

            <!-- assign_owner fields -->
            <template
              v-else-if="selectedNode.data.action_type === 'assign_owner'"
            >
              <DsInput
                v-model="selectedNode.data.user_id"
                :label="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_USER_LABEL')"
                :placeholder="$t('CRM.AUTOMATION_RULES.BUILDER.ACTION_USER_PLACEHOLDER')"
              />
            </template>
          </template>
        </div>
      </aside>
    </div>
  </div>
</template>

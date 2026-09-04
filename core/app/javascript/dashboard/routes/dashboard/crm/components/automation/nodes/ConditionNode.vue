<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DsBadge from 'dashboard/design-system/components/DsBadge.vue';
import DsButton from 'dashboard/design-system/components/DsButton.vue';

const props = defineProps({
  id: { type: String, required: true },
  data: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
});

const emit = defineEmits(['delete']);

const { t } = useI18n();

const fieldLabel = computed(() => {
  const field = props.data?.field || 'legal_area';
  switch (field) {
    case 'case_type':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.CASE_TYPE');
    case 'urgency_level':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.URGENCY_LEVEL');
    case 'score_total':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.SCORE_TOTAL');
    case 'relationship_status':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.RELATIONSHIP_STATUS');
    case 'lifecycle_stage':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.LIFECYCLE_STAGE');
    case 'has_phone':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.HAS_PHONE');
    case 'campaign_opt_out':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.CAMPAIGN_OPT_OUT');
    case 'stage':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.STAGE');
    case 'status':
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.STATUS');
    default:
      return t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.LEGAL_AREA');
  }
});

const operatorLabel = computed(() => {
  const op = props.data?.operator || 'eq';
  switch (op) {
    case 'not_eq':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.NOT_EQ');
    case 'present':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.PRESENT');
    case 'blank':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.BLANK');
    case 'gt':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.GT');
    case 'gte':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.GTE');
    case 'lt':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.LT');
    case 'lte':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.LTE');
    case 'in':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.IN');
    case 'not_in':
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.NOT_IN');
    default:
      return t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.EQ');
  }
});

const hasValue = computed(() => {
  return !['present', 'blank'].includes(props.data?.operator);
});

const handleDelete = event => {
  event.stopPropagation();
  emit('delete', props.id);
};
</script>

<template>
  <div
    class="min-w-64 max-w-xs rounded-ui-surface border bg-ui-surface p-3 text-ui-text shadow-ui-overlay transition-all"
    :class="[
      selected
        ? 'border-ui-warning ring-2 ring-ui-warning'
        : 'border-ui-border-subtle hover:border-ui-border',
    ]"
  >
    <Handle
      type="target"
      :position="Position.Top"
      class="!size-3 !border-2 !border-ui-surface !bg-ui-warning"
    />

    <div
      class="flex items-center justify-between gap-2 border-b border-ui-border-subtle pb-2"
    >
      <div class="flex items-center gap-2">
        <div
          class="grid size-7 place-items-center rounded-ui-control bg-ui-warning-soft text-ui-warning-foreground"
        >
          <Icon icon="i-lucide-filter" class="size-4" />
        </div>
        <DsBadge
          variant="warning"
          :label="$t('CRM.AUTOMATION_RULES.BUILDER.NODE_CONDITION_LABEL')"
        />
      </div>
      <DsButton
        icon="i-lucide-trash-2"
        variant="ghost"
        size="sm"
        :aria-label="$t('CRM.AUTOMATION_RULES.BUILDER.DELETE_NODE')"
        @click="handleDelete"
      />
    </div>

    <div class="mt-2.5 flex flex-col gap-1.5 text-ui-body-sm">
      <div class="flex flex-wrap items-center gap-1.5">
        <span class="font-medium text-ui-text">{{ fieldLabel }}</span>
        <span class="text-ui-caption text-ui-text-muted">{{
          operatorLabel
        }}</span>
      </div>
      <div
        v-if="hasValue"
        class="rounded-ui-control bg-ui-sunken px-2 py-1 font-mono text-ui-caption text-ui-text"
      >
        {{ data?.value ?? '-' }}
      </div>
    </div>

    <Handle
      type="source"
      :position="Position.Bottom"
      class="!size-3 !border-2 !border-ui-surface !bg-ui-warning"
    />
  </div>
</template>

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

const triggerEventLabel = computed(() => {
  const event = props.data?.trigger_event || 'stage_entered';
  switch (event) {
    case 'score_changed':
      return t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.SCORE_CHANGED');
    case 'stale_detected':
      return t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.STALE_DETECTED');
    case 'handoff':
      return t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.HANDOFF');
    case 'message_received':
      return t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.MESSAGE_RECEIVED');
    default:
      return t('CRM.AUTOMATION_RULES.TRIGGER_EVENTS.STAGE_ENTERED');
  }
});

const stageLabel = computed(() => {
  return props.data?.stageName || props.data?.crm_pipeline_stage_id || '';
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
        ? 'border-ui-brand ring-2 ring-ui-brand'
        : 'border-ui-border-subtle hover:border-ui-border',
    ]"
  >
    <div
      class="flex items-center justify-between gap-2 border-b border-ui-border-subtle pb-2"
    >
      <div class="flex items-center gap-2">
        <div
          class="grid size-7 place-items-center rounded-ui-control bg-ui-brand-soft text-ui-brand"
        >
          <Icon icon="i-lucide-zap" class="size-4" />
        </div>
        <DsBadge
          variant="brand"
          :label="$t('CRM.AUTOMATION_RULES.BUILDER.NODE_TRIGGER_LABEL')"
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

    <div class="mt-2.5 flex flex-col gap-1">
      <p
        class="m-0 truncate font-manrope text-ui-body-sm font-semibold text-ui-text"
      >
        {{
          data?.name || $t('CRM.AUTOMATION_RULES.BUILDER.RULE_NAME_PLACEHOLDER')
        }}
      </p>
      <p class="m-0 text-ui-caption text-ui-text-muted">
        {{ triggerEventLabel }}
      </p>
      <div
        v-if="stageLabel"
        class="mt-1 inline-flex items-center gap-1 rounded-ui-control bg-ui-sunken px-2 py-1 text-ui-caption text-ui-text-muted"
      >
        <Icon icon="i-lucide-kanban" class="size-3" />
        <span class="truncate font-medium text-ui-text">{{ stageLabel }}</span>
      </div>
    </div>

    <Handle
      type="source"
      :position="Position.Bottom"
      class="!size-3 !border-2 !border-ui-surface !bg-ui-brand"
    />
  </div>
</template>

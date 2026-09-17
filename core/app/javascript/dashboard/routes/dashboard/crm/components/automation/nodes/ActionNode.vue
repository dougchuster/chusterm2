<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';
import { packActivityKindLabel } from 'dashboard/helper/crmOptions';
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

const actionTypeLabel = computed(() => {
  const type = props.data?.action_type || 'create_activity';
  switch (type) {
    case 'set_captain_mode':
      return t('CRM.AUTOMATION_RULES.ACTION_TYPES.SET_CAPTAIN_MODE');
    case 'move_to_stage':
      return t('CRM.AUTOMATION_RULES.ACTION_TYPES.MOVE_TO_STAGE');
    case 'assign_owner':
      return t('CRM.AUTOMATION_RULES.ACTION_TYPES.ASSIGN_OWNER');
    default:
      return t('CRM.AUTOMATION_RULES.ACTION_TYPES.CREATE_ACTIVITY');
  }
});

const actionKindLabel = computed(() => {
  const kind = props.data?.kind || 'follow_up';
  // Pack types (ex.: 'demonstracao', 'email') não existem no mapa i18n —
  // o cache de options já está quente quando o builder renderiza.
  const packLabel = packActivityKindLabel(kind);
  if (packLabel) return packLabel;
  switch (kind) {
    case 'ligacao':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.LIGACAO');
    case 'solicitacao_documentos':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.SOLICITACAO_DOCUMENTOS');
    case 'reuniao':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.REUNIAO');
    case 'revisao_juridica':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.REVISAO_JURIDICA');
    case 'analise_documental':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.ANALISE_DOCUMENTAL');
    case 'retorno_cliente':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.RETORNO_CLIENTE');
    case 'envio_proposta':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.ENVIO_PROPOSTA');
    case 'envio_contrato':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.ENVIO_CONTRATO');
    case 'arquivamento':
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.ARQUIVAMENTO');
    default:
      return t('CRM.AUTOMATION_RULES.ACTION_KINDS.FOLLOW_UP');
  }
});

const priorityBadgeVariant = computed(() => {
  switch (props.data?.priority) {
    case 'critica':
      return 'danger';
    case 'alta':
      return 'warning';
    case 'baixa':
      return 'neutral';
    default:
      return 'brand';
  }
});

const priorityLabel = computed(() => {
  const priority = props.data?.priority || 'normal';
  switch (priority) {
    case 'baixa':
      return t('CRM.AUTOMATION_RULES.PRIORITIES.BAIXA');
    case 'alta':
      return t('CRM.AUTOMATION_RULES.PRIORITIES.ALTA');
    case 'critica':
      return t('CRM.AUTOMATION_RULES.PRIORITIES.CRITICA');
    default:
      return t('CRM.AUTOMATION_RULES.PRIORITIES.NORMAL');
  }
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
        ? 'border-ui-success ring-2 ring-ui-success'
        : 'border-ui-border-subtle hover:border-ui-border',
    ]"
  >
    <Handle
      type="target"
      :position="Position.Top"
      class="!size-3 !border-2 !border-ui-surface !bg-ui-success"
    />

    <div
      class="flex items-center justify-between gap-2 border-b border-ui-border-subtle pb-2"
    >
      <div class="flex items-center gap-2">
        <div
          class="grid size-7 place-items-center rounded-ui-control bg-ui-success-soft text-ui-success-foreground"
        >
          <Icon icon="i-lucide-check-circle" class="size-4" />
        </div>
        <DsBadge
          variant="success"
          :label="$t('CRM.AUTOMATION_RULES.BUILDER.NODE_ACTION_LABEL')"
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

    <div class="mt-2.5 flex flex-col gap-2">
      <div>
        <p
          class="m-0 text-ui-caption font-medium uppercase tracking-wide text-ui-text-muted"
        >
          {{ actionTypeLabel }}
        </p>
        <p
          v-if="data?.title"
          class="m-0 mt-0.5 truncate font-manrope text-ui-body-sm font-semibold text-ui-text"
        >
          {{ data.title }}
        </p>
      </div>

      <!-- Details for create_activity -->
      <div
        v-if="data?.action_type === 'create_activity' || !data?.action_type"
        class="flex flex-wrap items-center gap-1.5"
      >
        <DsBadge variant="brand" :label="actionKindLabel" />
        <DsBadge :variant="priorityBadgeVariant" :label="priorityLabel" />
        <DsBadge
          variant="neutral"
          :label="
            $t('CRM.AUTOMATION_RULES.CARD.DUE', {
              hours: data?.due_in_hours ?? 24,
            })
          "
        />
      </div>

      <!-- Details for set_captain_mode -->
      <div
        v-else-if="data?.action_type === 'set_captain_mode'"
        class="flex flex-col gap-1 text-ui-caption text-ui-text-muted"
      >
        <DsBadge
          variant="brand"
          :label="data?.ai_mode ? `AI: ${data.ai_mode}` : 'AI Mode'"
        />
        <p v-if="data?.reason" class="m-0 italic">
          {{ data.reason }}
        </p>
      </div>

      <!-- Details for move_to_stage -->
      <div
        v-else-if="data?.action_type === 'move_to_stage'"
        class="inline-flex items-center gap-1 text-ui-caption text-ui-text-muted"
      >
        <Icon icon="i-lucide-arrow-right" class="size-3 text-ui-brand" />
        <span class="font-medium text-ui-text">{{
          data?.stage_slug || '-'
        }}</span>
      </div>

      <!-- Details for assign_owner -->
      <div
        v-else-if="data?.action_type === 'assign_owner'"
        class="inline-flex items-center gap-1 text-ui-caption text-ui-text-muted"
      >
        <Icon icon="i-lucide-user" class="size-3 text-ui-brand" />
        <span>{{ data?.user_id ? `User #${data.user_id}` : '-' }}</span>
      </div>
    </div>
  </div>
</template>

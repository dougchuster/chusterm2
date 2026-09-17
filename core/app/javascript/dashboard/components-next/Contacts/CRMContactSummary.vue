<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
  compact: {
    type: Boolean,
    default: false,
  },
  editable: {
    type: Boolean,
    default: false,
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const lifecycleLabels = {
  visitor: 'Visitante',
  lead: 'Lead',
  qualified_lead: 'Lead qualificado',
  lead_qualified: 'Lead qualificado',
  triage: 'Em triagem',
  in_triage: 'Em triagem',
  consultation_scheduled: 'Consulta agendada',
  customer: 'Cliente',
  active_customer: 'Cliente ativo',
  recurring_customer: 'Recorrente',
  recurring: 'Recorrente',
  ex_customer: 'Ex-cliente',
  lost: 'Perdido',
};

const RELATIONSHIP_TEXT = {
  lead: 'Lead',
  customer: 'Cliente',
};

const getValue = (camelKey, snakeKey) =>
  props.contact?.[camelKey] ?? props.contact?.[snakeKey];

const relationshipStatus = computed(
  () => getValue('relationshipStatus', 'relationship_status') || 'lead'
);

const lifecycleStage = computed(
  () => getValue('lifecycleStage', 'lifecycle_stage') || 'lead'
);

const crmOwner = computed(() => getValue('crmOwner', 'crm_owner'));

const crmOwnerId = computed(() => getValue('crmOwnerId', 'crm_owner_id'));

const relationship = computed(() => {
  const isCustomer = relationshipStatus.value === 'customer';

  return {
    label: isCustomer ? 'Cliente' : 'Lead',
    icon: isCustomer ? 'i-lucide-handshake' : 'i-lucide-user-round',
    className: isCustomer
      ? 'bg-n-teal-3 text-n-teal-11 ring-n-teal-6'
      : 'bg-n-blue-3 text-n-blue-11 ring-n-blue-6 dark:bg-ds-bg-elevated dark:text-ds-fg-muted dark:ring-ds-border-subtle',
  };
});

const lifecycle = computed(() => ({
  label: lifecycleLabels[lifecycleStage.value] || lifecycleStage.value,
  icon: lifecycleStage.value?.includes('customer')
    ? 'i-lucide-briefcase-business'
    : 'i-lucide-activity',
}));

const ownerLabel = computed(() => {
  if (crmOwner.value?.name) return crmOwner.value.name;
  if (crmOwner.value?.email) return crmOwner.value.email;
  if (crmOwnerId.value) return `Responsável #${crmOwnerId.value}`;

  return 'Sem responsável';
});

const ownerClass = computed(() =>
  crmOwnerId.value
    ? 'bg-n-alpha-2 text-n-slate-11 ring-ui-border-subtle'
    : 'bg-n-ruby-3 text-n-ruby-11 ring-n-ruby-6'
);

const switchRelationship = status => {
  if (!props.editable || props.isUpdating) return;
  if (relationshipStatus.value === status) return;

  emit('update', {
    relationshipStatus: status,
    lifecycleStage: status === 'customer' ? 'customer' : 'lead',
  });
};
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-2"
    :class="{ 'text-xs': compact, 'text-sm': !compact }"
  >
    <div
      v-if="editable"
      class="inline-grid h-8 grid-cols-2 overflow-hidden rounded border border-ui-border-subtle bg-n-alpha-2 p-0.5"
      :class="{ 'h-7': compact }"
    >
      <button
        type="button"
        class="inline-flex min-w-16 items-center justify-center gap-1 rounded px-2 font-medium transition"
        :class="
          relationshipStatus === 'lead'
            ? 'bg-n-surface-1 text-n-blue-11 shadow-sm'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        :disabled="isUpdating"
        @click="switchRelationship('lead')"
      >
        <span class="i-lucide-user-round size-3.5 shrink-0" />
        <span>{{ RELATIONSHIP_TEXT.lead }}</span>
      </button>
      <button
        type="button"
        class="inline-flex min-w-20 items-center justify-center gap-1 rounded px-2 font-medium transition"
        :class="
          relationshipStatus === 'customer'
            ? 'bg-n-surface-1 text-n-teal-11 shadow-sm'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        :disabled="isUpdating"
        @click="switchRelationship('customer')"
      >
        <span class="i-lucide-handshake size-3.5 shrink-0" />
        <span>{{ RELATIONSHIP_TEXT.customer }}</span>
      </button>
    </div>
    <span
      v-else
      class="inline-flex h-6 max-w-full items-center gap-1 rounded px-2 font-medium ring-1"
      :class="relationship.className"
    >
      <span :class="relationship.icon" class="size-3.5 shrink-0" />
      <span class="truncate">{{ relationship.label }}</span>
    </span>
    <span
      class="inline-flex h-6 max-w-full items-center gap-1 rounded bg-n-alpha-2 px-2 font-medium text-n-slate-11 ring-1 ring-ui-border-subtle"
    >
      <span :class="lifecycle.icon" class="size-3.5 shrink-0" />
      <span class="truncate">{{ lifecycle.label }}</span>
    </span>
    <span
      class="inline-flex h-6 max-w-full items-center gap-1 rounded px-2 font-medium ring-1"
      :class="ownerClass"
    >
      <span class="i-lucide-user-check size-3.5 shrink-0" />
      <span class="truncate">{{ ownerLabel }}</span>
    </span>
  </div>
</template>

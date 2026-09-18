<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  contact: { type: Object, required: true },
  compact: { type: Boolean, default: false },
});

const { t } = useI18n();

const STAGES = [
  { key: 'visitor', icon: 'i-lucide-eye' },
  { key: 'lead', icon: 'i-lucide-user' },
  { key: 'lead_qualified', icon: 'i-lucide-star' },
  { key: 'in_triage', icon: 'i-lucide-search' },
  { key: 'consultation_scheduled', icon: 'i-lucide-calendar' },
  { key: 'customer', icon: 'i-lucide-handshake' },
  { key: 'active_customer', icon: 'i-lucide-briefcase' },
  { key: 'recurring', icon: 'i-lucide-refresh-cw' },
];

const STAGE_COLORS = {
  visitor: 'bg-ui-sunken text-ui-text-muted',
  lead: 'bg-ui-info-soft text-ui-info-foreground',
  lead_qualified: 'bg-ui-brand-soft text-ui-brand-foreground',
  in_triage: 'bg-ui-warning-soft text-ui-warning-foreground',
  consultation_scheduled: 'bg-ui-brand-soft text-ui-brand-foreground',
  customer: 'bg-ui-success-soft text-ui-success-foreground',
  active_customer: 'bg-ui-success-soft text-ui-success-foreground',
  recurring: 'bg-ui-success-soft text-ui-success-foreground',
  ex_customer: 'bg-ui-danger-soft text-ui-danger-foreground',
};

const stageLabels = computed(() => ({
  visitor: t('CRM.LIFECYCLE.STAGES.VISITOR'),
  lead: t('CRM.LIFECYCLE.STAGES.LEAD'),
  lead_qualified: t('CRM.LIFECYCLE.STAGES.LEAD_QUALIFIED'),
  in_triage: t('CRM.LIFECYCLE.STAGES.IN_TRIAGE'),
  consultation_scheduled: t('CRM.LIFECYCLE.STAGES.CONSULTATION_SCHEDULED'),
  customer: t('CRM.LIFECYCLE.STAGES.CUSTOMER'),
  active_customer: t('CRM.LIFECYCLE.STAGES.ACTIVE_CUSTOMER'),
  recurring: t('CRM.LIFECYCLE.STAGES.RECURRING'),
}));

const stage = computed(() => props.contact?.lifecycle_stage || 'visitor');
const currentStageData = computed(
  () => STAGES.find(s => s.key === stage.value) || STAGES[0]
);
const colorClass = computed(
  () => STAGE_COLORS[stage.value] || STAGE_COLORS.visitor
);
const currentStageLabel = computed(
  () => stageLabels.value[currentStageData.value.key]
);

const currentStageIndex = computed(() =>
  STAGES.findIndex(s => s.key === stage.value)
);

const becameCustomerAt = computed(() => {
  const date = props.contact?.became_customer_at;
  if (!date) return null;
  return new Date(date).toLocaleDateString(undefined, {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
});

const lifetimeValue = computed(() => {
  const cents = props.contact?.lifetime_value_cents || 0;
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100);
});

const lastInteraction = computed(() => {
  const date = props.contact?.last_crm_interaction_at;
  if (!date) return t('CRM.LIFECYCLE.NEVER');
  const diff = Math.floor((Date.now() - new Date(date).getTime()) / 86400000);
  if (diff === 0) return t('CRM.LIFECYCLE.TODAY');
  if (diff === 1) return t('CRM.LIFECYCLE.YESTERDAY');
  return t('CRM.LIFECYCLE.DAYS_AGO', { count: diff });
});
</script>

<template>
  <div v-if="compact" class="inline-flex items-center gap-1.5">
    <span
      class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-ui-caption font-medium"
      :class="colorClass"
    >
      <span :class="currentStageData.icon" class="size-3 shrink-0" />
      {{ currentStageLabel }}
    </span>
  </div>

  <div
    v-else
    class="rounded-ui-card border border-ui-border-subtle bg-ui-surface p-3"
  >
    <div class="mb-4 flex flex-wrap items-center gap-3">
      <span
        class="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-ui-body-sm font-semibold"
        :class="colorClass"
      >
        <span :class="currentStageData.icon" class="size-4 shrink-0" />
        {{ currentStageLabel }}
      </span>
      <span v-if="becameCustomerAt" class="text-ui-caption text-ui-text-subtle">
        {{ t('CRM.LIFECYCLE.CUSTOMER_SINCE', { date: becameCustomerAt }) }}
      </span>
    </div>

    <div class="mb-4 flex items-start overflow-x-auto pb-2">
      <div
        v-for="(s, idx) in STAGES"
        :key="s.key"
        class="relative flex min-w-[70px] shrink-0 flex-col items-center"
      >
        <div
          class="z-10 grid size-8 place-content-center rounded-full border-2 transition-all"
          :class="{
            'border-ui-success bg-ui-success text-ui-text-inverse':
              idx < currentStageIndex,
            'border-ui-brand bg-ui-brand text-ui-text-inverse ring-[3px] ring-ui-brand/25':
              idx === currentStageIndex,
            'border-ui-border bg-ui-sunken text-ui-text-subtle':
              idx > currentStageIndex,
          }"
        >
          <span :class="s.icon" class="size-3" />
        </div>
        <div
          class="mt-1.5 max-w-16 text-center text-[0.625rem] leading-tight"
          :class="{
            'font-semibold text-ui-brand': idx === currentStageIndex,
            'text-ui-success': idx < currentStageIndex,
            'text-ui-text-subtle': idx > currentStageIndex,
          }"
        >
          {{ stageLabels[s.key] }}
        </div>
        <div
          v-if="idx < STAGES.length - 1"
          class="absolute left-1/2 top-4 z-0 h-0.5 w-full"
          :class="idx < currentStageIndex ? 'bg-ui-success' : 'bg-ui-border'"
        />
      </div>
    </div>

    <div
      class="grid grid-cols-2 gap-2 border-t border-ui-border-subtle pt-3 min-[400px]:grid-cols-4"
    >
      <div class="flex flex-col gap-0.5">
        <span
          class="text-[0.625rem] uppercase tracking-wide text-ui-text-subtle"
        >
          {{ t('CRM.LIFECYCLE.LTV') }}
        </span>
        <span class="text-ui-body-sm font-bold text-ui-text">
          {{ lifetimeValue }}
        </span>
      </div>
      <div class="flex flex-col gap-0.5">
        <span
          class="text-[0.625rem] uppercase tracking-wide text-ui-text-subtle"
        >
          {{ t('CRM.LIFECYCLE.TOTAL_DEALS') }}
        </span>
        <span class="text-ui-body-sm font-bold text-ui-text">
          {{ contact.total_deals_count || 0 }}
        </span>
      </div>
      <div class="flex flex-col gap-0.5">
        <span
          class="text-[0.625rem] uppercase tracking-wide text-ui-text-subtle"
        >
          {{ t('CRM.LIFECYCLE.WON_DEALS') }}
        </span>
        <span class="text-ui-body-sm font-bold text-ui-success">
          {{ contact.won_deals_count || 0 }}
        </span>
      </div>
      <div class="flex flex-col gap-0.5">
        <span
          class="text-[0.625rem] uppercase tracking-wide text-ui-text-subtle"
        >
          {{ t('CRM.LIFECYCLE.LAST_INTERACTION') }}
        </span>
        <span class="text-ui-body-sm font-bold text-ui-text">
          {{ lastInteraction }}
        </span>
      </div>
    </div>
  </div>
</template>

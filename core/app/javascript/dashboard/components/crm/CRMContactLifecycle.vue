<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  contact: { type: Object, required: true },
  compact: { type: Boolean, default: false },
});

const STAGES = [
  { key: 'visitor', label: 'Visitante', icon: 'i-lucide-eye' },
  { key: 'lead', label: 'Lead', icon: 'i-lucide-user' },
  { key: 'lead_qualified', label: 'Lead Qualificado', icon: 'i-lucide-star' },
  { key: 'in_triage', label: 'Em Triagem', icon: 'i-lucide-search' },
  {
    key: 'consultation_scheduled',
    label: 'Consulta Agendada',
    icon: 'i-lucide-calendar',
  },
  { key: 'customer', label: 'Cliente', icon: 'i-lucide-handshake' },
  {
    key: 'active_customer',
    label: 'Cliente Ativo',
    icon: 'i-lucide-briefcase',
  },
  { key: 'recurring', label: 'Recorrente', icon: 'i-lucide-refresh-cw' },
];

const STAGE_COLORS = {
  visitor: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-300',
  lead: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300',
  lead_qualified:
    'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300',
  in_triage:
    'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
  consultation_scheduled:
    'bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300',
  customer:
    'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300',
  active_customer:
    'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300',
  recurring: 'bg-teal-100 text-teal-700 dark:bg-teal-900/40 dark:text-teal-300',
  ex_customer: 'bg-red-100 text-red-600 dark:bg-red-900/40 dark:text-red-300',
};

const stage = computed(() => props.contact?.lifecycle_stage || 'visitor');
const currentStageData = computed(
  () => STAGES.find(s => s.key === stage.value) || STAGES[0]
);
const colorClass = computed(
  () => STAGE_COLORS[stage.value] || STAGE_COLORS.visitor
);

const currentStageIndex = computed(() =>
  STAGES.findIndex(s => s.key === stage.value)
);

const becameCustomerAt = computed(() => {
  const date = props.contact?.became_customer_at;
  if (!date) return null;
  return new Date(date).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
});

const lifetimeValue = computed(() => {
  const cents = props.contact?.lifetime_value_cents || 0;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100);
});

const lastInteraction = computed(() => {
  const date = props.contact?.last_crm_interaction_at;
  if (!date) return 'Nunca';
  const diff = Math.floor((Date.now() - new Date(date).getTime()) / 86400000);
  if (diff === 0) return 'Hoje';
  if (diff === 1) return 'Ontem';
  return `há ${diff} dias`;
});
</script>

<template>
  <!-- Badge compacto -->
  <div v-if="compact" class="inline-flex items-center gap-1.5">
    <span
      class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium"
      :class="colorClass"
    >
      <span :class="currentStageData.icon" class="size-3 shrink-0" />
      {{ currentStageData.label }}
    </span>
  </div>

  <!-- Painel completo -->
  <div v-else class="crm-lifecycle-panel">
    <!-- Badge atual -->
    <div class="lifecycle-header">
      <span class="lifecycle-badge" :class="colorClass">
        <span :class="currentStageData.icon" class="size-4 shrink-0" />
        {{ currentStageData.label }}
      </span>
      <span v-if="becameCustomerAt" class="lifecycle-since">
        Cliente desde {{ becameCustomerAt }}
      </span>
    </div>

    <!-- Timeline horizontal -->
    <div class="lifecycle-timeline">
      <div
        v-for="(s, idx) in STAGES"
        :key="s.key"
        class="lifecycle-step"
        :class="{
          'step-done': idx < currentStageIndex,
          'step-current': idx === currentStageIndex,
          'step-future': idx > currentStageIndex,
        }"
      >
        <div class="step-dot">
          <span :class="s.icon" class="size-3" />
        </div>
        <div class="step-label">{{ s.label }}</div>
        <div v-if="idx < STAGES.length - 1" class="step-connector" />
      </div>
    </div>

    <!-- KPIs -->
    <div class="lifecycle-kpis">
      <div class="lifecycle-kpi">
        <span class="kpi-label">Lifetime value</span>
        <span class="kpi-value">{{ lifetimeValue }}</span>
      </div>
      <div class="lifecycle-kpi">
        <span class="kpi-label">Total de deals</span>
        <span class="kpi-value">{{ contact.total_deals_count || 0 }}</span>
      </div>
      <div class="lifecycle-kpi">
        <span class="kpi-label">Deals ganhos</span>
        <span class="kpi-value text-green-600 dark:text-green-400">{{
          contact.won_deals_count || 0
        }}</span>
      </div>
      <div class="lifecycle-kpi">
        <span class="kpi-label">Última interação</span>
        <span class="kpi-value">{{ lastInteraction }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.crm-lifecycle-panel {
  padding: 0.75rem;
  border-radius: 0.75rem;
  border: 1px solid var(--n-border, #e5e7eb);
  background: var(--n-surface-1, #fff);
}

.lifecycle-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.lifecycle-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.8125rem;
  font-weight: 600;
}

.lifecycle-since {
  font-size: 0.75rem;
  color: var(--n-slate-9, #6b7280);
}

/* Timeline */
.lifecycle-timeline {
  display: flex;
  align-items: flex-start;
  overflow-x: auto;
  padding-bottom: 0.5rem;
  margin-bottom: 1rem;
  gap: 0;
  scrollbar-width: thin;
}

.lifecycle-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  flex-shrink: 0;
  min-width: 70px;
}

.step-dot {
  width: 2rem;
  height: 2rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1;
  border: 2px solid transparent;
  transition: all 0.2s;
}

.step-done .step-dot {
  background: #16a34a;
  border-color: #16a34a;
  color: white;
}

.step-current .step-dot {
  background: var(--n-brand, #3b82f6);
  border-color: var(--n-brand, #3b82f6);
  color: white;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
}

.step-future .step-dot {
  background: var(--n-slate-3, #f3f4f6);
  border-color: var(--n-slate-5, #d1d5db);
  color: var(--n-slate-8, #9ca3af);
}

.step-label {
  font-size: 0.625rem;
  text-align: center;
  margin-top: 0.375rem;
  color: var(--n-slate-10, #6b7280);
  max-width: 64px;
  line-height: 1.3;
}

.step-current .step-label {
  color: var(--n-brand, #3b82f6);
  font-weight: 600;
}

.step-done .step-label {
  color: #16a34a;
}

.step-connector {
  position: absolute;
  top: 1rem;
  left: 50%;
  width: 100%;
  height: 2px;
  background: var(--n-slate-4, #e5e7eb);
  z-index: 0;
}

.step-done .step-connector {
  background: #16a34a;
}

/* KPIs */
.lifecycle-kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.5rem;
  border-top: 1px solid var(--n-border, #e5e7eb);
  padding-top: 0.75rem;
}

.lifecycle-kpi {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.kpi-label {
  font-size: 0.625rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--n-slate-9, #6b7280);
}

.kpi-value {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--n-slate-12, #111827);
}

@media (max-width: 400px) {
  .lifecycle-kpis {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>

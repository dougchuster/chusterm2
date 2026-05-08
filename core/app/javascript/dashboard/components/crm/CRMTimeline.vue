<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { ref, watch } from 'vue';
import CrmAPI from '../../api/crm';

const props = defineProps({
  dealId: { type: [Number, String], required: true },
});

const events = ref([]);
const loading = ref(false);
const error = ref('');

const ACTION_LABELS = {
  deal_created: 'Oportunidade criada',
  deal_updated: 'Oportunidade atualizada',
  deal_moved: 'Etapa alterada',
  deal_stage_changed: 'Etapa alterada',
  deal_marked_won: 'Marcada como ganha',
  deal_marked_lost: 'Marcada como perdida',
  deal_reopened: 'Reaberta',
  activity_created: 'Atividade criada',
  activity_completed: 'Atividade concluida',
  lead_score_recomputed: 'Score recalculado',
  score_recomputed: 'Score recalculado',
};

function actionLabel(action) {
  return ACTION_LABELS[action] || action || 'Evento';
}

function formatDate(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

function formatPayloadValue(value) {
  if (value === null || value === undefined) return '';
  if (['string', 'number', 'boolean'].includes(typeof value))
    return String(value);

  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function payloadSummary(payload) {
  if (!payload || typeof payload !== 'object') return '';
  const entries = Object.entries(payload).slice(0, 3);
  return entries
    .map(([key, value]) => `${key}: ${formatPayloadValue(value)}`)
    .join(' | ');
}

async function loadTimeline() {
  if (!props.dealId) return;
  loading.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.getAuditEvents({
      target_type: 'CrmDeal',
      target_id: props.dealId,
    });
    events.value = Array.isArray(data) ? data : [];
  } catch {
    error.value = 'Não foi possível carregar o histórico.';
  } finally {
    loading.value = false;
  }
}

watch(() => props.dealId, loadTimeline, { immediate: true });
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <section class="space-y-3">
    <div class="flex items-center justify-between">
      <h4 class="m-0 text-sm font-semibold text-n-slate-12">Histórico</h4>
      <button
        type="button"
        class="text-xs font-medium text-n-brand hover:underline"
        @click="loadTimeline"
      >
        Atualizar
      </button>
    </div>

    <div v-if="loading" class="text-sm text-n-slate-11">Carregando...</div>
    <div v-else-if="error" class="text-sm text-red-500">{{ error }}</div>
    <div
      v-else-if="!events.length"
      class="rounded-lg bg-n-slate-2 p-3 text-sm text-n-slate-11"
    >
      Nenhum evento registrado ainda.
    </div>

    <ol v-else class="relative space-y-3 border-l border-n-weak pl-4">
      <li v-for="event in events" :key="event.id" class="relative">
        <span
          class="absolute -left-[1.3125rem] top-1 grid size-2.5 rounded-full bg-n-brand ring-4 ring-n-background"
        />
        <p class="m-0 text-sm font-medium text-n-slate-12">
          {{ actionLabel(event.action) }}
        </p>
        <p class="m-0 text-xs text-n-slate-10">
          {{ formatDate(event.created_at) }}
        </p>
        <p
          v-if="payloadSummary(event.payload)"
          class="m-0 mt-1 text-xs text-n-slate-11"
        >
          {{ payloadSummary(event.payload) }}
        </p>
      </li>
    </ol>
  </section>
</template>

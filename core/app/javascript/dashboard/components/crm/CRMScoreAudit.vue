<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  score: { type: Object, default: null },
  compact: { type: Boolean, default: false },
});

const labels = {
  fit: 'Fit jurídico',
  urgency: 'Urgencia',
  economic: 'Potencial econômico',
  documents: 'Documentos',
  clarity: 'Clareza',
  engagement: 'Engajamento',
  payment_capacity: 'Capacidade de pagamento',
  conflict: 'Conflito',
};

const sourceLabels = {
  campaign_config: 'Campanha',
  pipeline_config: 'Pipeline',
  rule_based: 'Regra padrão',
};

const factors = computed(() => props.score?.factors || {});
const components = computed(() => factors.value.components || {});
const totalScore = computed(
  () => props.score?.total_score ?? factors.value.total_score ?? 0
);
const classification = computed(
  () => props.score?.classification || factors.value.classification || ''
);
const calculatedBy = computed(
  () => props.score?.calculated_by || factors.value.calculated_by || ''
);
const sourceLabel = computed(
  () =>
    sourceLabels[calculatedBy.value] || calculatedBy.value || 'Não informado'
);
const autoMoveLabel = computed(() =>
  factors.value.auto_move_on_score === false
    ? 'Automove desligado'
    : 'Automove ativo'
);

const sortedComponents = computed(() =>
  Object.entries(components.value)
    .map(([key, data]) => ({
      key,
      label: labels[key] || key,
      score: Number(data?.score || 0),
      maxScore: Number(data?.max_score || 0),
      signal: data?.signal,
      evidence: data?.evidence,
    }))
    .sort((a, b) => b.score - a.score)
);

const visibleComponents = computed(() =>
  props.compact ? sortedComponents.value.slice(0, 4) : sortedComponents.value
);
const hasComponents = computed(() => sortedComponents.value.length > 0);

function percent(item) {
  if (!item.maxScore) return 0;
  return Math.min(100, Math.round((item.score / item.maxScore) * 100));
}

function formatValue(value) {
  if (value === null || value === undefined || value === '') return 'Sem sinal';
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
}
</script>

<template>
  <section
    class="rounded-lg border border-ui-border-subtle bg-n-slate-1"
    :class="compact ? 'p-2' : 'p-4'"
  >
    <div class="mb-3 flex items-start justify-between gap-3">
      <div>
        <p class="m-0 text-xs font-semibold uppercase text-n-slate-10">
          Auditoria do score
        </p>
        <h4 class="m-0 mt-1 text-sm font-semibold text-n-slate-12">
          {{ totalScore }}pts
          <span v-if="classification" class="font-normal text-n-slate-10">
            - {{ classification }}
          </span>
        </h4>
      </div>
      <span
        class="shrink-0 rounded-full bg-n-slate-3 px-2 py-0.5 text-xs font-medium text-n-slate-11"
      >
        {{ sourceLabel }}
      </span>
    </div>

    <div v-if="!score" class="text-xs text-n-slate-10">
      Sem auditoria de score ainda.
    </div>

    <div v-else class="space-y-3">
      <p v-if="score.reason" class="m-0 text-xs leading-5 text-n-slate-11">
        {{ score.reason }}
      </p>

      <div v-if="hasComponents" class="space-y-2">
        <div
          v-for="item in visibleComponents"
          :key="item.key"
          class="rounded-lg bg-n-alpha-2 p-2"
        >
          <div class="mb-1 flex items-center justify-between gap-2 text-xs">
            <span class="font-medium text-n-slate-12">{{ item.label }}</span>
            <span class="text-n-slate-11">
              {{ item.score }}/{{ item.maxScore }}
            </span>
          </div>
          <div class="h-1.5 overflow-hidden rounded-full bg-n-slate-4">
            <div
              class="h-full rounded-full bg-n-brand"
              :style="{ width: `${percent(item)}%` }"
            />
          </div>
          <p
            v-if="!compact && item.evidence"
            class="m-0 mt-1 text-xs leading-5 text-n-slate-10"
          >
            {{ item.evidence }}
          </p>
          <p
            v-if="!compact"
            class="m-0 mt-1 truncate text-xs text-n-slate-9"
            :title="formatValue(item.signal)"
          >
            Sinal: {{ formatValue(item.signal) }}
          </p>
        </div>
      </div>

      <div v-else class="rounded-lg bg-n-alpha-2 p-2 text-xs text-n-slate-10">
        Detalhamento disponível no próximo recálculo do score.
      </div>

      <div
        v-if="!compact"
        class="grid grid-cols-1 gap-2 text-xs text-n-slate-11 sm:grid-cols-2"
      >
        <div class="rounded-lg bg-n-alpha-2 p-2">
          Origem: <span class="font-medium">{{ sourceLabel }}</span>
        </div>
        <div class="rounded-lg bg-n-alpha-2 p-2">
          Movimento: <span class="font-medium">{{ autoMoveLabel }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

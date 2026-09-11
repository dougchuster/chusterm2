<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed } from 'vue';

const props = defineProps({
  stages: {
    // Array de { name, slug, count, color? }
    type: Array,
    default: () => [],
  },
  title: {
    type: String,
    default: 'Funil de conversão',
  },
});

const STAGE_COLORS = {
  'novo-atendimento': '#6366f1',
  'triagem-ia': '#8b5cf6',
  qualificado: '#3b82f6',
  'consulta-reuniao': '#0ea5e9',
  'documentos-solicitados': '#14b8a6',
  'em-analise-juridica': '#10b981',
  'proposta-enviada': '#f59e0b',
  'contrato-fechado': '#22c55e',
};

const DEFAULT_COLOR = '#94a3b8';

const stageColor = slug => STAGE_COLORS[slug] || DEFAULT_COLOR;

const total = computed(() =>
  props.stages.reduce((sum, s) => sum + (s.count || 0), 0)
);

const maxCount = computed(() =>
  Math.max(...props.stages.map(s => s.count || 0), 1)
);

const pct = count => Math.round((count / maxCount.value) * 100);

const convRate = idx => {
  if (idx === 0 || props.stages[idx - 1]?.count === 0) return null;
  const rate = (
    (props.stages[idx].count / props.stages[idx - 1].count) *
    100
  ).toFixed(0);
  return `${rate}%`;
};
</script>

<template>
  <article
    class="rounded-xl border border-[rgb(var(--slate-4))] bg-[rgb(var(--slate-1))] px-6 py-5"
  >
    <header class="mb-[1.1rem] flex items-baseline justify-between gap-2">
      <h2
        class="m-0 text-[0.9375rem] font-semibold text-[rgb(var(--slate-12))]"
      >
        {{ title }}
      </h2>
      <span class="text-xs font-medium text-[rgb(var(--slate-9))] tabular-nums"
        >{{ total }} deal(s) total</span
      >
    </header>

    <div
      v-if="!stages.length"
      class="py-4 text-center text-sm text-[rgb(var(--slate-10))]"
    >
      Nenhuma etapa com dados para exibir.
    </div>

    <ul v-else class="m-0 flex list-none flex-col gap-2.5 p-0">
      <li
        v-for="(stage, idx) in stages"
        :key="stage.slug || stage.name"
        class="grid grid-cols-[11rem_1fr_2.5rem_3rem] items-center gap-2.5 max-[560px]:grid-cols-[7rem_1fr_2rem_2.5rem]"
      >
        <!-- Nome da etapa -->
        <span
          class="truncate text-[0.8125rem] font-medium text-[rgb(var(--slate-11))]"
          :title="stage.name"
        >
          {{ stage.name }}
        </span>

        <!-- Barra de progresso -->
        <div class="h-2 overflow-hidden rounded-full bg-[rgb(var(--slate-3))]">
          <div
            class="h-full min-w-1 rounded-full bg-[var(--crm-stage-color)] transition-[width] duration-[0.4s] ease-out dark:!bg-ui-text-muted"
            :style="{
              width: pct(stage.count) + '%',
              '--crm-stage-color': stageColor(stage.slug),
            }"
          />
        </div>

        <!-- Contagem -->
        <span
          class="text-right text-[0.8125rem] font-bold text-[rgb(var(--slate-12))] tabular-nums"
        >
          {{ stage.count }}
        </span>

        <!-- Taxa de conversão em relação à etapa anterior -->
        <span
          v-if="convRate(idx)"
          class="whitespace-nowrap rounded-full border border-[rgb(var(--teal-5))] bg-[rgb(var(--teal-2))] px-1.5 py-px text-center text-[0.6875rem] font-semibold text-[rgb(var(--teal-11))]"
          title="Conversão da etapa anterior"
        >
          {{ convRate(idx) }}
        </span>
        <span
          v-else
          class="whitespace-nowrap rounded-full border border-[rgb(var(--slate-4))] bg-[rgb(var(--slate-2))] px-1.5 py-px text-center text-[0.6875rem] font-semibold text-[rgb(var(--slate-9))]"
        >
          entrada
        </span>
      </li>
    </ul>
  </article>
</template>

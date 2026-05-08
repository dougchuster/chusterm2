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
  <article class="crm-funnel">
    <header class="crm-funnel__header">
      <h2 class="crm-funnel__title">{{ title }}</h2>
      <span class="crm-funnel__total">{{ total }} deal(s) total</span>
    </header>

    <div v-if="!stages.length" class="crm-funnel__empty">
      Nenhuma etapa com dados para exibir.
    </div>

    <ul v-else class="crm-funnel__list">
      <li
        v-for="(stage, idx) in stages"
        :key="stage.slug || stage.name"
        class="crm-funnel__row"
      >
        <!-- Nome da etapa -->
        <span class="crm-funnel__label" :title="stage.name">
          {{ stage.name }}
        </span>

        <!-- Barra de progresso -->
        <div class="crm-funnel__bar-track">
          <div
            class="crm-funnel__bar-fill"
            :style="{
              width: pct(stage.count) + '%',
              background: stageColor(stage.slug),
            }"
          />
        </div>

        <!-- Contagem -->
        <span class="crm-funnel__count">
          {{ stage.count }}
        </span>

        <!-- Taxa de conversão em relação à etapa anterior -->
        <span
          v-if="convRate(idx)"
          class="crm-funnel__conv"
          title="Conversão da etapa anterior"
        >
          {{ convRate(idx) }}
        </span>
        <span v-else class="crm-funnel__conv crm-funnel__conv--start">
          entrada
        </span>
      </li>
    </ul>
  </article>
</template>

<style scoped>
.crm-funnel {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 0.75rem;
  background: rgb(var(--slate-1));
  padding: 1.25rem 1.5rem;
}

.crm-funnel__header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 1.1rem;
}

.crm-funnel__title {
  margin: 0;
  font-size: 0.9375rem;
  font-weight: 600;
  color: rgb(var(--slate-12));
}

.crm-funnel__total {
  font-size: 0.75rem;
  color: rgb(var(--slate-9));
  font-weight: 500;
}

.crm-funnel__empty {
  padding: 1rem 0;
  font-size: 0.875rem;
  color: rgb(var(--slate-10));
  text-align: center;
}

.crm-funnel__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.crm-funnel__row {
  display: grid;
  grid-template-columns: 11rem 1fr 2.5rem 3rem;
  align-items: center;
  gap: 0.625rem;
}

.crm-funnel__label {
  font-size: 0.8125rem;
  color: rgb(var(--slate-11));
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-weight: 500;
}

.crm-funnel__bar-track {
  height: 0.5rem;
  border-radius: 9999px;
  background: rgb(var(--slate-3));
  overflow: hidden;
}

.crm-funnel__bar-fill {
  height: 100%;
  border-radius: 9999px;
  transition: width 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  min-width: 0.25rem;
}

.crm-funnel__count {
  font-size: 0.8125rem;
  font-weight: 700;
  color: rgb(var(--slate-12));
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.crm-funnel__conv {
  font-size: 0.6875rem;
  font-weight: 600;
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
  border: 1px solid rgb(var(--teal-5));
  border-radius: 9999px;
  padding: 0.1rem 0.4rem;
  text-align: center;
  white-space: nowrap;
}

.crm-funnel__conv--start {
  color: rgb(var(--slate-9));
  background: rgb(var(--slate-2));
  border-color: rgb(var(--slate-4));
}

/* responsivo: colapsa label em telas pequenas */
@media (max-width: 560px) {
  .crm-funnel__row {
    grid-template-columns: 7rem 1fr 2rem 2.5rem;
  }
}
</style>

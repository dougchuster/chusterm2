<!-- eslint-disable vue/prefer-separate-static-class -->
<script setup>
import { computed } from 'vue';
import { LEGAL_AREA_LABELS } from 'dashboard/helper/crmOptions';

const props = defineProps({
  area: { type: String, default: '' },
  compact: { type: Boolean, default: false },
});

// O domínio histórico usa civel/criminal/outro. Os aliases abaixo mantêm
// compatibilidade com valores gravados durante a execução do plano descartado.
const AREA_ALIASES = {
  civil: 'civel',
  penal: 'criminal',
  outros: 'outro',
};

const AREA_COLORS = {
  trabalhista:
    'border-blue-200 bg-blue-50 text-blue-700 dark:border-blue-900 dark:bg-blue-950 dark:text-blue-200',
  previdenciario:
    'border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200',
  civel:
    'border-purple-200 bg-purple-50 text-purple-700 dark:border-purple-900 dark:bg-purple-950 dark:text-purple-200',
  familia:
    'border-pink-200 bg-pink-50 text-pink-700 dark:border-pink-900 dark:bg-pink-950 dark:text-pink-200',
  consumidor:
    'border-amber-200 bg-amber-50 text-amber-700 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200',
  empresarial:
    'border-slate-200 bg-slate-50 text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200',
  tributario:
    'border-cyan-200 bg-cyan-50 text-cyan-700 dark:border-cyan-900 dark:bg-cyan-950 dark:text-cyan-200',
  imobiliario:
    'border-lime-200 bg-lime-50 text-lime-700 dark:border-lime-900 dark:bg-lime-950 dark:text-lime-200',
  criminal:
    'border-red-200 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950 dark:text-red-200',
};

const normalizedArea = computed(() => {
  const raw = String(props.area || '').toLowerCase();
  return AREA_ALIASES[raw] || raw;
});
const label = computed(
  () => LEGAL_AREA_LABELS[normalizedArea.value] || props.area || 'Sem área'
);
const colorClass = computed(
  () =>
    AREA_COLORS[normalizedArea.value] ||
    'border-n-weak bg-n-slate-2 text-n-slate-11'
);
</script>

<template>
  <span
    class="inline-flex items-center rounded-full border font-medium leading-none"
    :class="[
      compact ? 'px-1.5 py-0.5 text-[0.6875rem]' : 'px-2 py-1 text-xs',
      colorClass,
    ]"
  >
    {{ label }}
  </span>
</template>

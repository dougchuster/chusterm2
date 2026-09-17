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
    'border-n-blue-6 bg-n-blue-3 text-n-blue-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  previdenciario:
    'border-n-teal-6 bg-n-teal-3 text-n-teal-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  civel:
    'border-n-violet-6 bg-n-violet-3 text-n-violet-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  familia:
    'border-n-ruby-6 bg-n-ruby-3 text-n-ruby-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  consumidor:
    'border-n-amber-6 bg-n-amber-3 text-n-amber-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  empresarial:
    'border-n-slate-6 bg-n-slate-3 text-n-slate-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  tributario:
    'border-n-blue-6 bg-n-blue-3 text-n-blue-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  imobiliario:
    'border-n-teal-6 bg-n-teal-3 text-n-teal-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  criminal:
    'border-n-ruby-6 bg-n-ruby-3 text-n-ruby-11 dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
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
    'border-ui-border-subtle bg-n-slate-2 text-n-slate-11'
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

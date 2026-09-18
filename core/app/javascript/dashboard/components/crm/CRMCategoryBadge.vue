<!-- eslint-disable vue/prefer-separate-static-class -->
<script setup>
import { computed } from 'vue';
import { categoryLabel } from 'dashboard/helper/crmOptions';

const props = defineProps({
  // A0: 'category' é o nome universal; 'area' permanece para callers legados.
  category: { type: String, default: '' },
  area: { type: String, default: '' },
  label: { type: String, default: '' },
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
    'border-ui-info bg-ui-info-soft text-ui-info-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  previdenciario:
    'border-ui-success bg-ui-success-soft text-ui-success-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  civel:
    'border-ui-brand bg-ui-brand-soft text-ui-brand dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  familia:
    'border-ui-danger bg-ui-danger-soft text-ui-danger-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  consumidor:
    'border-ui-warning bg-ui-warning-soft text-ui-warning-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  empresarial:
    'border-ui-border-strong bg-ui-sunken text-ui-text-muted dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  tributario:
    'border-ui-info bg-ui-info-soft text-ui-info-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  imobiliario:
    'border-ui-success bg-ui-success-soft text-ui-success-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
  criminal:
    'border-ui-danger bg-ui-danger-soft text-ui-danger-foreground dark:border-ui-border dark:bg-ui-elevated dark:text-ui-text-muted',
};

const normalizedArea = computed(() => {
  const raw = String(props.category || props.area || '').toLowerCase();
  return AREA_ALIASES[raw] || raw;
});
// Prioridade: label serializado pelo backend (pack-aware) > categorias do
// pack/mapa legado > slug cru.
const label = computed(
  () =>
    props.label ||
    categoryLabel(normalizedArea.value) ||
    props.category ||
    props.area ||
    'Sem categoria'
);
const colorClass = computed(
  () =>
    AREA_COLORS[normalizedArea.value] ||
    'border-ui-border-subtle bg-ui-sunken text-ui-text-muted'
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

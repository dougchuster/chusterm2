<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-static-inline-styles -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  score: {
    type: Number,
    default: 0,
  },
  classification: {
    type: String,
    default: '',
  },
  showLabel: {
    type: Boolean,
    default: false,
  },
  size: {
    type: String,
    default: 'md', // sm | md | lg
  },
});

const tier = computed(() => {
  const s = Number(props.score || 0);
  if (s === 0) return 'sem_score';
  if (s >= 80) return 'prioridade_alta';
  if (s >= 60) return 'qualificado';
  if (s >= 40) return 'medio_potencial';
  return 'baixo_potencial';
});

const tierConfig = computed(() => {
  const configs = {
    sem_score: {
      label: 'Score pendente',
      bg: 'bg-n-slate-3',
      text: 'text-n-slate-11',
      border: 'border-n-slate-5',
      pulse: false,
      icon: 'i-lucide-sparkles',
    },
    prioridade_alta: {
      label: 'Alta prioridade',
      bg: 'bg-red-100 dark:bg-red-950',
      text: 'text-red-700 dark:text-red-300',
      border: 'border-red-200 dark:border-red-900',
      pulse: true,
      icon: 'i-lucide-zap',
    },
    qualificado: {
      label: 'Qualificado',
      bg: 'bg-green-100 dark:bg-green-950',
      text: 'text-green-700 dark:text-green-300',
      border: 'border-green-200 dark:border-green-900',
      pulse: false,
      icon: 'i-lucide-star',
    },
    medio_potencial: {
      label: 'Médio potencial',
      bg: 'bg-amber-100 dark:bg-amber-950',
      text: 'text-amber-700 dark:text-amber-300',
      border: 'border-amber-200 dark:border-amber-900',
      pulse: false,
      icon: 'i-lucide-trending-up',
    },
    baixo_potencial: {
      label: 'Baixo potencial',
      bg: 'bg-n-slate-3',
      text: 'text-n-slate-11',
      border: 'border-n-slate-5',
      pulse: false,
      icon: 'i-lucide-minus-circle',
    },
  };
  return configs[tier.value] || configs.baixo_potencial;
});

const displayLabel = computed(() => {
  return props.classification || tierConfig.value.label;
});

const sizeClasses = computed(() => {
  const sizes = {
    sm: 'text-[0.6875rem] px-1.5 py-0.5',
    md: 'text-xs px-2 py-1',
    lg: 'text-sm px-2.5 py-1.5',
  };
  return sizes[props.size] || sizes.md;
});

const iconSize = computed(() => {
  const sizes = {
    sm: 'size-2.5',
    md: 'size-3',
    lg: 'size-3.5',
  };
  return sizes[props.size] || sizes.md;
});
</script>

<template>
  <span
    class="inline-flex items-center gap-1 rounded-full border font-semibold leading-none whitespace-nowrap flex-shrink-0"
    :class="[
      sizeClasses,
      tierConfig.bg,
      tierConfig.text,
      tierConfig.border,
      tier === 'prioridade_alta' ? 'ring-2 ring-red-400 dark:ring-red-700' : '',
    ]"
    :title="`Score: ${score} - ${displayLabel}`"
  >
    <span class="shrink-0" :class="[tierConfig.icon, iconSize]" />
    <span>{{ score === 0 ? '—' : score }}</span>
    <span v-if="showLabel" class="ml-0.5">{{ displayLabel }}</span>
  </span>
</template>

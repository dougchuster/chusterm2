<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-static-inline-styles -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  action: {
    type: String,
    default: '',
  },
  urgencyLevel: {
    type: String,
    default: '',
  },
  compact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['schedule']);

const actionIcon = computed(() => {
  const text = (props.action || '').toLowerCase();
  if (
    text.includes('document') ||
    text.includes('enviar') ||
    text.includes('solicitar')
  ) {
    return 'i-lucide-file-check';
  }
  if (
    text.includes('consult') ||
    text.includes('reunia') ||
    text.includes('agendar')
  ) {
    return 'i-lucide-calendar-clock';
  }
  if (
    text.includes('proposta') ||
    text.includes('contrato') ||
    text.includes('honorar')
  ) {
    return 'i-lucide-file-signature';
  }
  if (
    text.includes('analis') ||
    text.includes('revisar') ||
    text.includes('juridi')
  ) {
    return 'i-lucide-scale';
  }
  if (
    text.includes('ligar') ||
    text.includes('telefo') ||
    text.includes('retorno')
  ) {
    return 'i-lucide-phone-call';
  }
  if (text.includes('escalonar') || text.includes('encaminhar')) {
    return 'i-lucide-arrow-up-right';
  }
  return 'i-lucide-circle-arrow-right';
});

const isUrgent = computed(() =>
  ['critica', 'alta'].includes((props.urgencyLevel || '').toLowerCase())
);
</script>

<template>
  <div
    v-if="action"
    class="flex flex-col gap-2 rounded-xl border border-n-weak bg-n-slate-2 p-3"
    :class="{
      'border-n-ruby-6 bg-n-ruby-2': isUrgent,
    }"
  >
    <div class="flex items-center justify-between gap-2">
      <span
        class="inline-flex items-center gap-1 text-[0.6875rem] font-semibold uppercase tracking-wider"
        :class="isUrgent ? 'text-n-ruby-10' : 'text-n-slate-10'"
      >
        <span class="i-lucide-lightbulb size-3" />
        Próxima ação
      </span>
      <span
        v-if="isUrgent"
        class="rounded-full bg-n-ruby-9 px-1.5 py-0.5 text-[0.625rem] font-bold uppercase tracking-wider text-white"
      >
        Urgente
      </span>
    </div>

    <div class="flex items-start gap-2" :class="compact ? 'flex-row' : ''">
      <span
        class="mt-0.5 size-4 shrink-0"
        :class="[actionIcon, isUrgent ? 'text-n-ruby-9' : 'text-n-brand']"
      />
      <p class="m-0 text-sm leading-snug text-n-slate-12">{{ action }}</p>
    </div>

    <button
      v-if="!compact"
      type="button"
      class="mt-0.5 inline-flex items-center gap-1.5 self-start rounded-lg border border-n-slate-6 bg-n-slate-1 px-3 py-1 text-xs font-medium text-n-slate-11 transition-colors duration-150 hover:border-n-brand-8 hover:bg-n-slate-3 hover:text-n-brand-11"
      @click="emit('schedule')"
    >
      <span class="i-lucide-calendar-plus size-3" />
      Agendar tarefa
    </button>
  </div>

  <div
    v-else
    class="flex flex-row items-center gap-2 rounded-xl border border-dashed border-n-weak bg-transparent p-3 text-sm text-n-slate-10"
  >
    <span class="i-lucide-info size-4 shrink-0" />
    <span>Nenhuma próxima ação definida ainda.</span>
  </div>
</template>

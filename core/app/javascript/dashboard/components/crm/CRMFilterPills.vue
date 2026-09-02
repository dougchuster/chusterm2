<script setup>
/**
 * Barra de filtros do board — F2.6 do PLANO-KANBAN-CRM-2026.md.
 *
 * O ponto da barra não é filtrar: é o atendente **ver o que está filtrado**.
 * Um board com filtro invisível mente sobre o tamanho da fila — a coluna diz
 * "3" e o atendente conclui que só há três, quando há trezentos escondidos.
 *
 * Ela é burra de propósito: recebe as pills já descritas por
 * `crmBoardFilters.describeFilters` e devolve qual remover. Quem sabe traduzir
 * id de etapa em nome é o helper, que é testável sem montar componente.
 */
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  pills: { type: Array, default: () => [] },
  resultCount: { type: Number, default: null },
});

const emit = defineEmits(['remove', 'clear']);
</script>

<template>
  <div
    v-if="pills.length"
    data-testid="crm-filter-bar"
    class="flex flex-wrap items-center gap-2 border-b border-ui-border-subtle px-3 py-2"
  >
    <span
      v-for="pill in pills"
      :key="pill.key"
      data-testid="crm-filter-pill"
      class="flex items-center gap-1 rounded-ui-control bg-ui-sunken py-0.5 pl-2 pr-0.5 text-ui-caption text-ui-text"
    >
      <span class="text-ui-text-muted">{{ $t(pill.labelKey) }}</span>
      <span v-if="pill.value" class="max-w-48 truncate font-medium">
        {{ pill.value }}
      </span>
      <button
        data-testid="crm-filter-remove"
        type="button"
        class="rounded-ui-control p-0.5 text-ui-text-muted hover:bg-ui-hover hover:text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
        :aria-label="$t('CRM.FILTERS.REMOVE', { filter: $t(pill.labelKey) })"
        @click="emit('remove', pill.key)"
      >
        <Icon icon="i-lucide-x" class="size-3.5" />
      </button>
    </span>

    <button
      data-testid="crm-filter-clear"
      type="button"
      class="rounded-ui-control px-2 py-0.5 text-ui-caption text-ui-text-muted underline hover:text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
      @click="emit('clear')"
    >
      {{ $t('CRM.FILTERS.CLEAR_ALL') }}
    </button>

    <span
      v-if="resultCount !== null"
      data-testid="crm-filter-count"
      class="ml-auto text-ui-caption text-ui-text-muted"
      aria-live="polite"
    >
      <template v-if="resultCount === 0">
        {{ $t('CRM.FILTERS.NO_RESULTS') }}
      </template>
      <template v-else>
        {{ $t('CRM.FILTERS.RESULT_COUNT', { count: resultCount }) }}
      </template>
    </span>
  </div>
</template>

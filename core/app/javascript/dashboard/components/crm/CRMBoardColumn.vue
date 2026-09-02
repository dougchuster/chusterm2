<script setup>
/**
 * Coluna do Kanban.
 *
 * Extraída do `CrmIndexOperational.vue` na F2.2, por dois motivos:
 *
 * 1. O board passou de 800 linhas (regra 6 do prompt de execução).
 * 2. A dívida B-12: depois que o board passou a receber 25 cards por coluna do
 *    endpoint da F1.5, quem tinha 1.200 negócios na coluna via 25 e não tinha
 *    como pedir o resto. Quem sabe que está sendo rolado é a coluna, então é
 *    ela quem pede mais.
 *
 * O cabeçalho mostra o total que o **servidor** contou, não o tamanho da lista
 * que chegou — contar `deals.length` diria 25 de 1.200.
 *
 * `:sort="false"` de propósito: arrastar **dentro** da coluna reordenava só
 * na tela, sem persistir, e a ordem voltava sozinha no próximo refresh.
 * Fingir que funcionou é pior do que não deixar. A reordenação de verdade é
 * a F2.10, que usa o `before_id`/`after_id` que a F1.3 construiu.
 */
import { computed, ref } from 'vue';

import Draggable from 'vuedraggable';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DsBadge, DsButton } from 'dashboard/design-system/components';

const props = defineProps({
  column: { type: Object, required: true },
  loading: { type: Boolean, default: false },
  // F2.8: so o agrupamento por etapa aceita arrasto ? mover entre faixas de
  // score nao teria o que persistir.
  movable: { type: Boolean, default: true },
});

const emit = defineEmits([
  'create',
  'loadMore',
  'dragStart',
  'dragEnd',
  'change',
]);

// Quantos pixels antes do fim já contam como "chegou lá". Menos do que isso e o
// atendente vê a lista acabar antes de a próxima página chegar.
const LOAD_MORE_THRESHOLD_PX = 240;

const scroller = ref(null);

const loadedEverything = computed(
  () => props.column.deals.length >= Number(props.column.count || 0)
);

const money = computed(() => {
  const cents = Number(props.column.sum_value_cents || 0);
  if (!cents) return '';

  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100);
});

const averageAge = computed(() => {
  const days = Number(props.column.avg_days_in_stage || 0);
  if (!days) return '';
  return `${days.toFixed(1)}d`;
});

const onScroll = event => {
  if (props.loading || loadedEverything.value) return;

  const { scrollTop, clientHeight, scrollHeight } = event.target;
  if (scrollHeight - (scrollTop + clientHeight) > LOAD_MORE_THRESHOLD_PX) {
    return;
  }

  emit('loadMore');
};
</script>

<template>
  <article
    class="flex h-full max-h-full w-[calc(100vw-3rem)] shrink-0 flex-col rounded-ui-surface border border-ui-border-subtle bg-ui-sunken sm:w-80"
  >
    <header
      class="flex min-h-12 shrink-0 flex-wrap items-center gap-x-2 gap-y-1 border-b border-ui-border-subtle px-3 py-2"
    >
      <h2 class="m-0 min-w-0 flex-1 truncate text-ui-body-sm font-semibold">
        {{ column.name }}
      </h2>
      <DsBadge
        data-testid="crm-column-count"
        :label="String(column.count ?? column.deals.length)"
        variant="neutral"
      />
      <!-- Criar so faz sentido numa coluna que e uma etapa: agrupado por
           responsavel ou faixa de score nao ha etapa para o negocio nascer. -->
      <DsButton
        v-if="column.stage_id"
        data-testid="crm-column-create"
        icon="i-lucide-plus"
        variant="ghost"
        size="sm"
        :aria-label="$t('CRM.COLUMN.CREATE_IN_STAGE', { stage: column.name })"
        @click="emit('create')"
      />
      <div
        class="flex w-full items-center gap-2 text-ui-caption text-ui-text-muted"
      >
        <span v-if="money">{{ money }}</span>
        <span v-if="averageAge" :title="$t('CRM.COLUMN.AVERAGE_AGE')">
          ⏱ {{ averageAge }}
        </span>
        <span
          v-if="column.wip_limit"
          data-testid="crm-column-wip"
          class="ml-auto rounded-ui-control px-1.5"
          :class="
            column.over_wip
              ? 'bg-ui-danger-subtle text-ui-danger'
              : 'text-ui-text-muted'
          "
          :title="$t('CRM.COLUMN.WIP_TITLE')"
        >
          {{
            $t('CRM.COLUMN.WIP', {
              current: column.open_count ?? column.count,
              limit: column.wip_limit,
            })
          }}
        </span>
      </div>
    </header>

    <div
      ref="scroller"
      data-testid="crm-column-scroll"
      class="min-h-24 flex-1 overflow-y-auto"
      @scroll="onScroll"
    >
      <Draggable
        :model-value="column.deals"
        item-key="id"
        group="crm-pipeline"
        :sort="false"
        :disabled="!movable"
        class="space-y-2 p-2"
        ghost-class="opacity-40"
        drag-class="shadow-ui-overlay"
        :delay="120"
        delay-on-touch-only
        @update:model-value="emit('change', { deals: $event })"
        @start="emit('dragStart', $event)"
        @end="emit('dragEnd', $event)"
        @change="emit('change', { event: $event })"
      >
        <template #item="{ element: deal }">
          <slot name="card" :deal="deal" />
        </template>
      </Draggable>

      <p
        v-if="loading"
        class="flex items-center justify-center gap-2 py-3 text-ui-caption text-ui-text-muted"
      >
        <Icon icon="i-lucide-loader-circle" class="size-4 animate-spin" />
        {{ $t('CRM.COLUMN.LOADING_MORE') }}
      </p>
    </div>
  </article>
</template>

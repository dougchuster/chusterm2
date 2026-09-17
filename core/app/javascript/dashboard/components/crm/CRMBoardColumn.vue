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
import { computed, nextTick, onMounted, ref, watch } from 'vue';

import Draggable from 'vuedraggable';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DsButton } from 'dashboard/design-system/components';

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
  'nativeDrop',
  'change',
]);

// Quantos pixels antes do fim já contam como "chegou lá". Menos do que isso e o
// atendente vê a lista acabar antes de a próxima página chegar.
const LOAD_MORE_THRESHOLD_PX = 240;

const scroller = ref(null);

// A sombra no pé da coluna é o único sinal de que ainda há cards abaixo —
// sem ela a lista parece acabar no corte do viewport.
const canScrollBelow = ref(false);

const updateScrollFade = async () => {
  await nextTick();
  const el = scroller.value;
  canScrollBelow.value =
    !!el && el.scrollHeight - (el.scrollTop + el.clientHeight) > 8;
};

watch(
  () => props.column.deals.length,
  () => updateScrollFade()
);
onMounted(updateScrollFade);

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

const weightedMoney = computed(() => {
  if (props.column.weighted_value_cents != null) {
    const cents = Number(props.column.weighted_value_cents || 0);
    if (!cents) return '';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(cents / 100);
  }

  let prob = null;
  if (props.column.probability_pct != null) {
    prob = Number(props.column.probability_pct);
  } else if (props.column.probability != null) {
    prob = Number(props.column.probability);
  }

  if (prob != null && prob > 0) {
    const cents = Math.round(
      Number(props.column.sum_value_cents || 0) * (prob / 100)
    );
    if (!cents) return '';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(cents / 100);
  }

  if (
    props.column.deals?.length &&
    props.column.deals.some(
      d => d.probability_pct != null && Number(d.probability_pct) > 0
    )
  ) {
    const cents = props.column.deals.reduce((sum, d) => {
      const p = Number(d.probability_pct || 0);
      const val = Number(d.value_estimate_cents || 0);
      return sum + Math.round(val * (p / 100));
    }, 0);
    if (!cents) return '';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(cents / 100);
  }

  return '';
});

const averageAge = computed(() => {
  const days = Number(props.column.avg_days_in_stage || 0);
  if (!days) return '';
  return `${days.toFixed(1)}d`;
});

const onScroll = event => {
  updateScrollFade();
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
    data-testid="crm-board-column"
    class="flex h-full max-h-full w-[calc(100vw-3rem)] shrink-0 flex-col overflow-hidden rounded-xl bg-ui-sunken sm:w-[21rem]"
    :style="{ '--crm-stage-color': column.color || 'transparent' }"
  >
    <header
      class="flex min-h-12 shrink-0 flex-wrap items-center gap-x-2 gap-y-1 bg-[color-mix(in_srgb,var(--crm-stage-color)_9%,transparent)] px-3.5 py-2.5"
    >
      <div
        v-if="column.color"
        class="size-2.5 rounded-full bg-[var(--crm-stage-color)] shadow-[0_0_0_3px_color-mix(in_srgb,var(--crm-stage-color)_22%,transparent)]"
      />
      <h2
        class="m-0 min-w-0 flex-1 truncate font-manrope text-ui-body-sm font-semibold tracking-tight text-ui-text"
      >
        {{ column.name }}
      </h2>
      <span
        data-testid="crm-column-count"
        class="rounded-full bg-ui-surface/80 px-2 py-0.5 text-ui-caption font-semibold tabular-nums text-ui-text-muted"
      >
        {{ column.count ?? column.deals.length }}
      </span>
      <!-- Criar so faz sentido numa coluna que e uma etapa: agrupado por
           responsavel ou faixa de score nao ha etapa para o negocio nascer. -->
      <DsButton
        v-if="column.stage_id"
        data-testid="crm-column-create"
        icon="i-lucide-plus"
        variant="ghost"
        size="sm"
        class="text-ui-text-muted hover:text-ui-brand"
        :aria-label="$t('CRM.COLUMN.CREATE_IN_STAGE', { stage: column.name })"
        @click="emit('create')"
      />
      <div
        class="flex w-full items-center gap-2 pt-0.5 text-ui-caption text-ui-text-muted"
      >
        <span v-if="money" class="font-semibold tabular-nums text-ui-text">{{
          money
        }}</span>
        <span
          v-if="weightedMoney"
          data-testid="crm-column-weighted"
          class="font-medium text-ui-text-muted"
          :title="$t('CRM.COLUMN.WEIGHTED_VALUE', { value: weightedMoney })"
        >
          ({{ weightedMoney }})
        </span>
        <span
          v-if="averageAge"
          class="flex items-center gap-1 font-medium"
          :title="$t('CRM.COLUMN.AVERAGE_AGE')"
        >
          <Icon icon="i-lucide-clock" class="size-3 opacity-70" />
          {{ averageAge }}
        </span>
        <span
          v-if="column.wip_limit"
          data-testid="crm-column-wip"
          class="ml-auto rounded-ui-control px-2 py-0.5 font-medium"
          :class="
            column.over_wip
              ? 'border border-ui-danger/25 bg-ui-danger-soft text-ui-danger-foreground'
              : 'bg-ui-surface/50 text-ui-text-muted'
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
      @dragover.prevent
      @drop.stop.prevent="emit('nativeDrop', $event)"
      @scroll="onScroll"
    >
      <Draggable
        :model-value="column.deals"
        item-key="id"
        group="crm-pipeline"
        handle=".crm-drag-handle"
        :sort="false"
        :disabled="!movable"
        class="space-y-2.5 p-2.5"
        ghost-class="opacity-40"
        drag-class="rotate-[1.5deg] scale-[1.02] shadow-ui-overlay"
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

      <div
        v-if="!column.deals.length && !loading"
        data-testid="crm-column-empty"
        class="m-2.5 flex min-h-24 items-center justify-center rounded-lg border border-dashed border-ui-border-subtle/80 px-3 text-center text-ui-caption font-medium text-ui-text-muted"
      >
        {{ $t('CRM.COLUMN.EMPTY') }}
      </div>

      <p
        v-if="loading"
        class="flex items-center justify-center gap-2 py-3 text-ui-caption text-ui-text-muted"
      >
        <Icon
          icon="i-lucide-loader-circle"
          class="size-4 animate-spin text-ui-brand"
        />
        {{ $t('CRM.COLUMN.LOADING_MORE') }}
      </p>

      <div
        v-if="canScrollBelow"
        aria-hidden="true"
        class="pointer-events-none sticky bottom-0 -mb-1 h-8 shrink-0 bg-gradient-to-t from-ui-sunken to-transparent"
      />
    </div>
  </article>
</template>

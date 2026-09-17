<script setup>
/**
 * Card do Kanban — F2.4 do PLANO-KANBAN-CRM-2026.md, §7.
 *
 * As quatro regras de hierarquia que o desenho obedece:
 *
 * 1. O olho bate primeiro no **nome do contato**, depois na **próxima ação**.
 *    Nada mais compete. A referência do negócio só aparece quando diz algo que
 *    o nome não diz.
 * 2. Negócio aberto **sem próxima ação** é o estado mais alarmante do board:
 *    bloco vermelho e um botão que agenda em um clique. É a meta de "<10% sem
 *    próxima ação" do plano, transformada em interface.
 * 3. No máximo dois badges visíveis + "+N". O resto vive no drawer.
 * 4. A densidade é do atendente: compacta esconde valor e categoria, detalhada
 *    acrescenta a próxima melhor ação.
 *
 * Ele é deliberadamente burro: recebe o negócio e a etapa, decide **sinal**
 * (via `crmCardSignals`, que é testável sem montar componente) e devolve
 * intenções. Quem busca dono, chama API e move card é o board.
 */
import { computed } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DsButton, DsDropdown } from 'dashboard/design-system/components';
import {
  nextActionSignal,
  rottingSignal,
  visibleBadges,
} from 'dashboard/helper/crmCardSignals';

import CRMScoreBadge from './CRMScoreBadge.vue';

const props = defineProps({
  deal: { type: Object, required: true },
  stage: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  ownerName: { type: String, default: '' },
  density: { type: String, default: 'normal' },
  href: { type: String, default: '' },
  stageOptions: { type: Array, default: () => [] },
  canDrag: { type: Boolean, default: true },
  // Injetável para o teste não depender do relógio da máquina.
  now: { type: [Date, String], default: () => new Date() },
});

const emit = defineEmits([
  'open',
  'attend',
  'select',
  'recompute',
  'markBaseClient',
  'discard',
  'scheduleNextAction',
  'moveToStage',
  'nativeDragStart',
  'nativeDragEnd',
]);

const contactName = computed(
  () => props.deal.contact_name || props.deal.contact_phone_number || ''
);

// A referência só ganha espaço quando acrescenta: repetir o nome gastaria a
// linha mais valiosa do card com redundância.
const reference = computed(() => {
  const title = props.deal.title;
  if (!title || title === contactName.value) return '';
  return title;
});

const nextAction = computed(() => nextActionSignal(props.deal, props.now));
const rotting = computed(() =>
  rottingSignal(props.deal, props.stage, props.now)
);

const badges = computed(() =>
  visibleBadges([
    props.deal.captain_ai_mode === 'auto' ? 'ai' : null,
    props.deal.is_stale ? 'stale' : null,
    props.deal.operational_status === 'returning_client' ? 'returning' : null,
    props.deal.legal_area || null,
  ])
);

const money = computed(() => {
  const cents = Number(props.deal.value_estimate_cents || 0);
  if (!cents) return '';

  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100);
});

const dueLabel = computed(() => {
  if (!nextAction.value.dueAt) return '';

  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(nextAction.value.dueAt));
});

const isCompact = computed(() => props.density === 'compact');
const isDetailed = computed(() => props.density === 'detailed');

const displayName = computed(() => contactName.value);
const label = computed(
  () => props.deal.title || contactName.value || String(props.deal.id)
);
const availableStageOptions = computed(() =>
  props.stageOptions.filter(
    option => String(option.value) !== String(props.deal.crm_pipeline_stage_id)
  )
);
</script>

<template>
  <article
    data-testid="crm-board-card"
    :data-rotting="rotting.level"
    :style="{ '--crm-stage-color': stage.color || 'transparent' }"
    class="group relative rounded-ui-surface border border-l-4 border-l-[color:var(--crm-stage-color)] bg-ui-surface p-3.5 shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:shadow-md dark:!border-l-ui-border-strong"
    :class="{
      'cursor-default': !canDrag,
      'cursor-grab active:cursor-grabbing': canDrag,
      'border-ui-border hover:border-ui-border-strong hover:shadow-ui-brand/5':
        rotting.level !== 'late' && rotting.level !== 'warning',
      'border-ui-warning shadow-amber-500/5': rotting.level === 'warning',
      'border-ui-danger shadow-rose-500/10': rotting.level === 'late',
      'ring-2 ring-ui-border-focus': selected,
    }"
  >
    <div class="flex items-start gap-2">
      <span
        v-if="canDrag"
        data-testid="crm-card-drag-handle"
        class="crm-drag-handle -ml-2 mt-0.5 inline-flex min-h-7 w-5 shrink-0 cursor-grab touch-none items-center justify-center rounded-ui-control text-ui-text-subtle transition-colors hover:bg-ui-hover hover:text-ui-text active:cursor-grabbing"
        draggable="true"
        aria-hidden="true"
        @dragstart.stop="emit('nativeDragStart', $event)"
        @dragend.stop="emit('nativeDragEnd', $event)"
      >
        <Icon icon="i-lucide-grip-vertical" class="size-4" />
      </span>
      <input
        type="checkbox"
        :checked="selected"
        :aria-label="$t('CRM.CARD.SELECT', { name: label })"
        class="mt-1 size-4 shrink-0 cursor-pointer rounded border-ui-border accent-ui-brand transition-transform hover:scale-110"
        @click.stop
        @change="emit('select', $event.target.checked)"
      />
      <button
        data-testid="crm-card-open"
        type="button"
        class="min-w-0 flex-1 text-left focus-visible:rounded-ui-control focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
        @click="emit('open')"
      >
        <span
          data-testid="crm-card-name"
          class="block truncate text-ui-body-sm font-semibold text-ui-text transition-colors group-hover:text-ui-brand"
        >
          {{ displayName || $t('CRM.CARD.NO_CONTACT') }}
        </span>
        <span
          v-if="reference"
          data-testid="crm-card-reference"
          class="mt-0.5 block truncate text-ui-caption text-ui-text-muted"
        >
          {{ reference }}
        </span>
      </button>
      <DsButton
        data-testid="crm-card-attend"
        icon="i-lucide-message-circle"
        variant="ghost"
        size="sm"
        class="text-ui-text-muted transition-colors hover:text-ui-brand"
        :aria-label="$t('CRM.CARD.ATTEND', { name: label })"
        @click.stop="emit('attend')"
      />
      <DsDropdown :aria-label="$t('CRM.CARD.MORE_ACTIONS', { name: label })">
        <button
          v-for="option in availableStageOptions"
          :key="option.value"
          data-testid="crm-card-move-stage"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text transition-colors hover:bg-ui-hover"
          @click="emit('moveToStage', option.value)"
        >
          <Icon icon="i-lucide-arrow-right" class="size-4 text-ui-text-muted" />
          {{ $t('CRM.FILTERS.STAGE') }}: {{ option.label }}
        </button>
        <button
          data-testid="crm-card-recompute"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text transition-colors hover:bg-ui-hover"
          @click="emit('recompute')"
        >
          <Icon icon="i-lucide-refresh-cw" class="size-4 text-ui-text-muted" />
          {{ $t('CRM.CARD.RECOMPUTE_SCORE') }}
        </button>
        <button
          data-testid="crm-card-base-client"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text transition-colors hover:bg-ui-hover"
          @click="emit('markBaseClient')"
        >
          <Icon
            icon="i-lucide-contact-round"
            class="size-4 text-ui-text-muted"
          />
          {{ $t('CRM.CARD.MARK_BASE_CLIENT') }}
        </button>
        <button
          v-if="deal.status === 'open'"
          data-testid="crm-card-discard"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-danger transition-colors hover:bg-ui-hover"
          @click="emit('discard')"
        >
          <Icon icon="i-lucide-ban" class="size-4 text-ui-danger" />
          {{ $t('CRM.CARD.DISCARD') }}
        </button>
      </DsDropdown>
    </div>

    <!-- Regra 2: o bloco mais alto do card, porque é o estado mais alarmante. -->
    <div
      v-if="nextAction.tone === 'missing'"
      data-testid="crm-card-no-next-action"
      class="mt-2.5 flex items-center gap-2 rounded-ui-control border border-ui-danger/25 bg-ui-danger-soft px-2.5 py-1.5 text-ui-caption font-medium text-ui-danger-foreground"
    >
      <Icon icon="i-lucide-circle-alert" class="size-4 shrink-0" />
      <span class="min-w-0 flex-1 truncate">
        {{ $t('CRM.CARD.NO_NEXT_ACTION') }}
      </span>
      <button
        data-testid="crm-card-schedule"
        type="button"
        class="shrink-0 rounded-ui-control px-2 py-0.5 underline transition-opacity hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
        :aria-label="$t('CRM.CARD.SCHEDULE_NEXT_ACTION', { name: label })"
        @click.stop="emit('scheduleNextAction')"
      >
        {{ $t('CRM.CARD.SCHEDULE') }}
      </button>
    </div>

    <div
      v-else-if="nextAction.tone !== 'none'"
      data-testid="crm-card-next-action"
      :data-tone="nextAction.tone"
      class="mt-2 flex items-center gap-2 text-ui-caption font-medium"
      :class="{
        'text-ui-danger-foreground': nextAction.tone === 'overdue',
        'text-ui-warning-foreground': nextAction.tone === 'today',
        'text-ui-text-muted':
          nextAction.tone === 'future' || nextAction.tone === 'undated',
      }"
    >
      <Icon
        icon="i-lucide-calendar-clock"
        class="size-3.5 shrink-0 opacity-80"
      />
      <span class="min-w-0 flex-1 truncate">
        {{ dueLabel || $t('CRM.CARD.UNDATED') }}
      </span>
    </div>

    <div
      class="mt-3 flex items-center justify-between gap-2 border-t border-ui-border-subtle pt-2.5"
    >
      <div class="flex min-w-0 items-center gap-1.5">
        <CRMScoreBadge
          :score="Number(deal.score_total || 0)"
          :classification="deal.score_classification || ''"
          size="sm"
        />
        <span
          v-for="badge in badges.shown"
          :key="badge"
          data-testid="crm-card-badge"
          class="truncate rounded-ui-control border border-ui-border-subtle bg-ui-sunken px-2 py-0.5 text-ui-caption font-medium text-ui-text-muted"
        >
          <template v-if="badge === 'ai'">{{
            $t('CRM.CARD.AI_ACTIVE')
          }}</template>
          <template v-else>{{ badge }}</template>
        </span>
        <span
          v-if="badges.overflow"
          data-testid="crm-card-badge-overflow"
          class="shrink-0 text-ui-caption font-medium text-ui-text-subtle"
        >
          {{ $t('CRM.CARD.MORE_BADGES', { count: badges.overflow }) }}
        </span>
      </div>
      <span
        v-if="!isCompact && money"
        data-testid="crm-card-value"
        class="shrink-0 text-ui-caption font-semibold text-ui-text"
      >
        {{ money }}
      </span>
    </div>

    <div
      class="mt-2.5 flex items-center gap-2 text-ui-caption text-ui-text-muted"
    >
      <span
        v-if="!isCompact && deal.legal_area"
        data-testid="crm-card-area"
        class="truncate rounded bg-ui-sunken/60 px-1.5 py-0.5"
      >
        {{ deal.legal_area }}
      </span>
      <span
        v-if="rotting.level === 'late'"
        data-testid="crm-card-stale"
        class="shrink-0 font-medium text-ui-danger-foreground"
      >
        {{ $t('CRM.CARD.STALE', { days: rotting.daysInStage }) }}
      </span>
      <span class="ml-auto min-w-0 shrink-0 truncate font-medium">
        {{ ownerName || $t('CRM.CARD.NO_OWNER') }}
      </span>
      <a
        :href="href"
        :aria-label="$t('CRM.CARD.OPEN_RECORD', { name: label })"
        class="shrink-0 rounded-ui-control p-1 text-ui-text-muted transition-colors hover:bg-ui-hover hover:text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
        @click.stop
      >
        <Icon icon="i-lucide-arrow-up-right" class="size-4" />
      </a>
    </div>

    <p
      v-if="isDetailed && deal.next_best_action"
      data-testid="crm-card-next-best-action"
      class="mt-2 line-clamp-2 border-t border-ui-border-subtle pt-2 text-ui-caption text-ui-text-muted"
    >
      {{ deal.next_best_action }}
    </p>
  </article>
</template>

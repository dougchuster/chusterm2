<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import CRMScoreBadge from 'dashboard/components/crm/CRMScoreBadge.vue';
import {
  DsBadge,
  DsButton,
  DsTable,
} from 'dashboard/design-system/components';
import { formatCurrencyFromCents } from 'dashboard/helper/crmMoney';
import { calculateDealRotting } from '../helpers/dealRotting';

const props = defineProps({
  deals: { type: Array, default: () => [] },
  stages: { type: [Array, Object], default: () => [] },
  agents: { type: [Array, Object], default: () => [] },
  loading: { type: Boolean, default: false },
  selectedIds: { type: Array, default: () => [] },
  now: { type: [Date, String], default: () => new Date() },
});

const emit = defineEmits(['open', 'attend', 'select']);

const { t } = useI18n();

const headers = computed(() => [
  { key: 'select', label: '', class: 'w-10' },
  { key: 'title', label: t('CRM.TABLE.DEAL') },
  { key: 'contact', label: t('CRM.TABLE.CONTACT') },
  { key: 'stage', label: t('CRM.TABLE.STAGE') },
  { key: 'value', label: t('CRM.TABLE.VALUE'), class: 'text-right' },
  { key: 'owner', label: t('CRM.TABLE.OWNER') },
  { key: 'expected_close', label: t('CRM.TABLE.EXPECTED_CLOSE') },
  { key: 'days_inactive', label: t('CRM.TABLE.DAYS_INACTIVE') },
  { key: 'actions', label: t('CRM.TABLE.ACTIONS'), class: 'w-24 text-right' },
]);

const stageById = computed(() => {
  const map = {};
  const list = Array.isArray(props.stages)
    ? props.stages
    : props.stages?.value || [];
  list.forEach(stage => {
    map[String(stage.id)] = stage;
  });
  return map;
});

const agentById = computed(() => {
  const map = {};
  const list = Array.isArray(props.agents)
    ? props.agents
    : props.agents?.value || [];
  list.forEach(agent => {
    map[String(agent.id)] =
      agent.name || agent.email || t('CRM.CARD.NO_OWNER');
  });
  return map;
});

const stageForDeal = deal =>
  stageById.value[String(deal.crm_pipeline_stage_id)] || deal.stage || null;

const ownerNameForDeal = deal =>
  agentById.value[String(deal.owner_id)] || t('CRM.CARD.NO_OWNER');

const rottingForDeal = deal => {
  const stage = stageForDeal(deal);
  return calculateDealRotting(deal, stage, props.now);
};

const formatMoney = cents => formatCurrencyFromCents(cents);

const formatDate = dateValue => {
  if (!dateValue) return t('CRM.TABLE.NO_DATE');
  try {
    return new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(new Date(dateValue));
  } catch {
    return t('CRM.TABLE.NO_DATE');
  }
};
</script>

<template>
  <div class="w-full">
    <DsTable
      caption="Lista de negócios do CRM"
      :headers="headers"
      :items="deals"
      :loading="loading"
      :empty-title="$t('CRM.FILTERS.NO_RESULTS')"
      min-width-class="min-w-[56rem]"
    >
      <template #row="{ item: deal }">
        <tr
          data-testid="crm-table-row"
          class="group transition-colors duration-ui-fast hover:bg-ui-hover"
          :class="{ 'bg-ui-sunken/40': selectedIds.includes(deal.id) }"
        >
          <!-- Seleção -->
          <td class="w-10 px-3 py-2.5 align-middle">
            <input
              type="checkbox"
              :checked="selectedIds.includes(deal.id)"
              :aria-label="$t('CRM.CARD.SELECT', { name: deal.title || deal.id })"
              class="size-4 cursor-pointer rounded border-ui-border accent-ui-brand"
              @click.stop
              @change="emit('select', deal, $event.target.checked)"
            />
          </td>

          <!-- Título do Negócio & Score -->
          <td class="px-3 py-2.5 align-middle">
            <div class="flex items-center gap-2">
              <CRMScoreBadge
                v-if="deal.score_total"
                :score="Number(deal.score_total || 0)"
                :classification="deal.score_classification || ''"
                size="sm"
              />
              <button
                type="button"
                data-testid="crm-table-open-deal"
                class="min-w-0 truncate text-left text-ui-body-sm font-semibold text-ui-text hover:text-ui-brand focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ui-border-focus"
                @click="emit('open', deal)"
              >
                {{ deal.title || deal.contact_name || $t('CRM.CARD.FALLBACK_TITLE', { id: deal.id }) }}
              </button>
            </div>
          </td>

          <!-- Contato / Empresa -->
          <td class="px-3 py-2.5 align-middle text-ui-body-sm text-ui-text">
            <div class="min-w-0">
              <span class="block truncate font-medium">
                {{ deal.contact_name || deal.contact_phone_number || $t('CRM.CARD.NO_CONTACT') }}
              </span>
              <span
                v-if="deal.contact_email || (deal.contact_name && deal.contact_phone_number)"
                class="block truncate text-ui-caption text-ui-text-muted"
              >
                {{ deal.contact_email || deal.contact_phone_number }}
              </span>
            </div>
          </td>

          <!-- Etapa -->
          <td class="px-3 py-2.5 align-middle">
            <div class="flex items-center gap-1.5">
              <div
                v-if="stageForDeal(deal)?.color"
                class="size-2 shrink-0 rounded-full shadow-sm"
                :style="{ backgroundColor: stageForDeal(deal).color }"
              />
              <span class="truncate text-ui-body-sm font-medium text-ui-text">
                {{ stageForDeal(deal)?.name || deal.stage?.name || '-' }}
              </span>
            </div>
          </td>

          <!-- Valor Financeiro -->
          <td class="px-3 py-2.5 text-right align-middle font-medium tabular-nums text-ui-text">
            {{ formatMoney(deal.value_estimate_cents) }}
          </td>

          <!-- Responsável -->
          <td class="px-3 py-2.5 align-middle text-ui-body-sm text-ui-text-muted">
            <span class="truncate">
              {{ ownerNameForDeal(deal) }}
            </span>
          </td>

          <!-- Data de Fechamento Prevista / Prazo -->
          <td class="px-3 py-2.5 align-middle text-ui-body-sm text-ui-text-muted">
            <span>{{ formatDate(deal.closed_at || deal.next_activity_due_at || deal.expected_close_date) }}</span>
          </td>

          <!-- Dias Parado / Deal Rotting -->
          <td class="px-3 py-2.5 align-middle text-ui-body-sm">
            <DsBadge
              v-if="rottingForDeal(deal).isRotting"
              variant="warning"
              data-testid="crm-table-rotting-badge"
              :title="$t('CRM.ROTTING.TOOLTIP', { days: rottingForDeal(deal).daysInactive, threshold: rottingForDeal(deal).threshold })"
            >
              <span class="flex items-center gap-1">
                <span class="size-1.5 rounded-full bg-ui-warning animate-pulse" />
                {{ $t('CRM.ROTTING.BADGE', { days: rottingForDeal(deal).daysInactive }) }}
              </span>
            </DsBadge>
            <span v-else class="tabular-nums text-ui-text-muted">
              {{ rottingForDeal(deal).daysInactive }}d
            </span>
          </td>

          <!-- Ações Rápidas -->
          <td class="w-24 px-3 py-2.5 text-right align-middle">
            <div class="flex items-center justify-end gap-1">
              <DsButton
                data-testid="crm-table-attend"
                icon="i-lucide-message-circle"
                variant="ghost"
                size="sm"
                class="text-ui-text-muted hover:text-ui-brand"
                :aria-label="$t('CRM.CARD.ATTEND', { name: deal.title || deal.id })"
                @click="emit('attend', deal)"
              />
              <DsButton
                data-testid="crm-table-open"
                icon="i-lucide-arrow-up-right"
                variant="ghost"
                size="sm"
                class="text-ui-text-muted hover:text-ui-text"
                :aria-label="$t('CRM.CARD.OPEN_RECORD', { name: deal.title || deal.id })"
                @click="emit('open', deal)"
              />
            </div>
          </td>
        </tr>
      </template>
    </DsTable>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import CrmAPI from 'dashboard/api/crm';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsEmptyState,
  DsInput,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';
import {
  CRM_OPTIONS_FALLBACK,
  fetchCrmOptions,
} from 'dashboard/helper/crmOptions';

// 6.1: quando embutida no hub de relatórios, esconde o DsPageHeader
// (o hub já provê header + tabs).
defineProps({ embedded: { type: Boolean, default: false } });
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const filters = reactive({
  status: route.query.status || 'open',
  operational_status: route.query.operational_status || '',
  source: route.query.source || '',
  legal_area: route.query.legal_area || '',
  urgency_level: route.query.urgency_level || '',
  from: route.query.from || '',
  to: route.query.to || '',
});

const stats = ref(null);
const loading = ref(false);
const error = ref('');

const exporting = ref(false);
const exportError = ref('');
const exportSuccess = ref('');

// Larguras quantizadas em passos de 5%: as classes precisam existir de forma
// estatica para o Tailwind, entao barras nao usam style inline.
const BAR_WIDTH_CLASSES = [
  'w-0',
  'w-[5%]',
  'w-[10%]',
  'w-[15%]',
  'w-[20%]',
  'w-[25%]',
  'w-[30%]',
  'w-[35%]',
  'w-[40%]',
  'w-[45%]',
  'w-1/2',
  'w-[55%]',
  'w-[60%]',
  'w-[65%]',
  'w-[70%]',
  'w-[75%]',
  'w-[80%]',
  'w-[85%]',
  'w-[90%]',
  'w-[95%]',
  'w-full',
];

const KPI_ICON_TONES = {
  brand: 'text-ui-brand',
  blue: 'text-ui-info',
  ruby: 'text-ui-danger',
  amber: 'text-ui-warning',
  teal: 'text-ui-success',
  slate: 'text-ui-text-muted',
};

const INSIGHT_TONE_CLASSES = {
  danger: 'bg-ui-danger-soft text-ui-danger-foreground',
  warning: 'bg-ui-warning-soft text-ui-warning-foreground',
  info: 'bg-ui-info-soft text-ui-info-foreground',
  good: 'bg-ui-success-soft text-ui-success-foreground',
};

const statusOptions = computed(() => [
  { value: '', label: t('CRM.REPORTS.OPTIONS.STATUS.ALL') },
  { value: 'open', label: t('CRM.REPORTS.OPTIONS.STATUS.OPEN') },
  { value: 'won', label: t('CRM.REPORTS.OPTIONS.STATUS.WON') },
  { value: 'lost', label: t('CRM.REPORTS.OPTIONS.STATUS.LOST') },
  { value: 'archived', label: t('CRM.REPORTS.OPTIONS.STATUS.ARCHIVED') },
]);

// UX-05: listas de domínio vêm do backend via helper compartilhado
// com as chaves históricas já usadas pela triagem e pelos registros existentes.
const crmOptions = ref(CRM_OPTIONS_FALLBACK);

const legalAreaOptions = computed(() => [
  { value: '', label: t('CRM.REPORTS.OPTIONS.LEGAL_AREA_ALL') },
  ...crmOptions.value.legal_areas,
]);

const urgencyOptions = computed(() => [
  { value: '', label: t('CRM.REPORTS.OPTIONS.URGENCY_ALL') },
  ...crmOptions.value.urgency_levels,
]);

const operationalStatusOptions = computed(() => [
  { value: '', label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.ALL') },
  { value: 'active', label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.ACTIVE') },
  {
    value: 'returning_client',
    label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.RETURNING_CLIENT'),
  },
  {
    value: 'base_client',
    label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.BASE_CLIENT'),
  },
  {
    value: 'converted_client',
    label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.CONVERTED_CLIENT'),
  },
  { value: 'invalid', label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.INVALID') },
  { value: 'spam', label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.SPAM') },
  {
    value: 'duplicated',
    label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.DUPLICATED'),
  },
  { value: 'no_lead', label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.NO_LEAD') },
  { value: 'archived', label: t('CRM.REPORTS.OPTIONS.OPERATIONAL.ARCHIVED') },
]);

const sourceOptions = computed(() => [
  { value: '', label: t('CRM.REPORTS.OPTIONS.SOURCE.ALL') },
  { value: 'whatsapp', label: t('CRM.REPORTS.OPTIONS.SOURCE.WHATSAPP') },
  { value: 'jusbrasil', label: t('CRM.REPORTS.OPTIONS.SOURCE.JUSBRASIL') },
  { value: 'instagram', label: t('CRM.REPORTS.OPTIONS.SOURCE.INSTAGRAM') },
  { value: 'facebook', label: t('CRM.REPORTS.OPTIONS.SOURCE.FACEBOOK') },
  { value: 'google_ads', label: t('CRM.REPORTS.OPTIONS.SOURCE.GOOGLE_ADS') },
  { value: 'indicacao', label: t('CRM.REPORTS.OPTIONS.SOURCE.INDICACAO') },
  { value: 'site', label: t('CRM.REPORTS.OPTIONS.SOURCE.SITE') },
  {
    value: 'lista_importada',
    label: t('CRM.REPORTS.OPTIONS.SOURCE.LISTA_IMPORTADA'),
  },
  { value: 'cliente_base', label: t('CRM.REPORTS.OPTIONS.SOURCE.CLIENTE_BASE') },
  { value: 'outros', label: t('CRM.REPORTS.OPTIONS.SOURCE.OUTROS') },
]);

const priorityLabels = computed(() => ({
  baixa: t('CRM.REPORTS.PRIORITY.BAIXA'),
  normal: t('CRM.REPORTS.PRIORITY.NORMAL'),
  alta: t('CRM.REPORTS.PRIORITY.ALTA'),
  critica: t('CRM.REPORTS.PRIORITY.CRITICA'),
}));

const cleanFilters = () =>
  Object.fromEntries(
    Object.entries(filters).filter(([, value]) => value !== '')
  );

const persistFilters = () => {
  // Preserva ?tab= quando embutida no hub de relatórios
  const { tab } = route.query;
  router.replace({
    query: { ...cleanFilters(), ...(tab ? { tab } : {}) },
  });
};

const openDeals = computed(() => stats.value?.open_deals || 0);
const wonDeals = computed(() => stats.value?.won_deals || 0);
const totalDeals = computed(() => openDeals.value + wonDeals.value);

const conversionRate = computed(() => {
  if (!totalDeals.value) return '0.0%';
  return `${((wonDeals.value / totalDeals.value) * 100).toFixed(1)}%`;
});

const qualificationRate = computed(() => {
  if (!openDeals.value) return '0.0%';
  return `${(((stats.value?.qualified_deals || 0) / openDeals.value) * 100).toFixed(1)}%`;
});

const metricCards = computed(() => [
  {
    key: 'open',
    label: t('CRM.REPORTS.KPI.OPEN_LEADS.LABEL'),
    value: openDeals.value,
    hint: t('CRM.REPORTS.KPI.OPEN_LEADS.HINT'),
    icon: 'i-lucide-layers',
    iconClass: KPI_ICON_TONES.brand,
  },
  {
    key: 'qualification',
    label: t('CRM.REPORTS.KPI.QUALIFICATION.LABEL'),
    value: qualificationRate.value,
    hint: t('CRM.REPORTS.KPI.QUALIFICATION.HINT', {
      count: stats.value?.qualified_deals || 0,
    }),
    icon: 'i-lucide-badge-check',
    iconClass: KPI_ICON_TONES.blue,
  },
  {
    key: 'priority',
    label: t('CRM.REPORTS.KPI.HIGH_PRIORITY.LABEL'),
    value: stats.value?.priority_deals || 0,
    hint: t('CRM.REPORTS.KPI.HIGH_PRIORITY.HINT'),
    icon: 'i-lucide-alert-triangle',
    iconClass: KPI_ICON_TONES.ruby,
  },
  {
    key: 'overdue',
    label: t('CRM.REPORTS.KPI.OVERDUE.LABEL'),
    value: stats.value?.overdue_activities || 0,
    hint: t('CRM.REPORTS.KPI.OVERDUE.HINT'),
    icon: 'i-lucide-alarm-clock',
    iconClass: KPI_ICON_TONES.amber,
  },
  {
    key: 'won',
    label: t('CRM.REPORTS.KPI.WON.LABEL'),
    value: wonDeals.value,
    hint: t('CRM.REPORTS.KPI.WON.HINT', {
      count: stats.value?.won_deals_this_month || 0,
    }),
    icon: 'i-lucide-trophy',
    iconClass: KPI_ICON_TONES.teal,
  },
  {
    key: 'score',
    label: t('CRM.REPORTS.KPI.AVG_SCORE.LABEL'),
    value: stats.value?.average_score || 0,
    hint: t('CRM.REPORTS.KPI.AVG_SCORE.HINT'),
    icon: 'i-lucide-sparkles',
    iconClass: KPI_ICON_TONES.slate,
  },
  {
    key: 'conversion',
    label: t('CRM.REPORTS.KPI.CONVERSION.LABEL'),
    value: conversionRate.value,
    hint: t('CRM.REPORTS.KPI.CONVERSION.HINT'),
    icon: 'i-lucide-trending-up',
    iconClass: KPI_ICON_TONES.brand,
  },
  {
    key: 'base',
    label: t('CRM.REPORTS.KPI.BASE_CLIENTS.LABEL'),
    value: stats.value?.base_clients || 0,
    hint: t('CRM.REPORTS.KPI.BASE_CLIENTS.HINT'),
    icon: 'i-lucide-archive',
    iconClass: KPI_ICON_TONES.teal,
  },
  {
    key: 'discarded',
    label: t('CRM.REPORTS.KPI.DISCARDED.LABEL'),
    value: stats.value?.discarded_deals || 0,
    hint: t('CRM.REPORTS.KPI.DISCARDED.HINT'),
    icon: 'i-lucide-ban',
    iconClass: KPI_ICON_TONES.ruby,
  },
]);

const funnelStages = computed(() => {
  const raw = stats.value?.deals_by_stage;
  if (!raw) return [];
  return (Array.isArray(raw) ? raw : Object.values(raw))
    .sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
    .filter(stage => Number(stage.count) > 0);
});

const funnelTotal = computed(() =>
  funnelStages.value.reduce((sum, stage) => sum + (stage.count || 0), 0)
);

const maxFunnelCount = computed(() =>
  Math.max(...funnelStages.value.map(stage => stage.count || 0), 1)
);

const areaRows = computed(() =>
  objectRows(stats.value?.deals_by_legal_area, t('CRM.REPORTS.EMPTY_LABELS.AREA'))
);

const urgencyRows = computed(() =>
  objectRows(
    stats.value?.deals_by_urgency,
    t('CRM.REPORTS.EMPTY_LABELS.URGENCY')
  )
);

const priorityRows = computed(() =>
  objectRows(
    stats.value?.activities_by_priority,
    t('CRM.REPORTS.EMPTY_LABELS.PRIORITY')
  ).map(row => ({
    ...row,
    label: priorityLabels.value[row.key] || row.label,
  }))
);

const sourceRows = computed(() =>
  objectRows(
    stats.value?.deals_by_source,
    t('CRM.REPORTS.EMPTY_LABELS.SOURCE')
  )
);

const operationalRows = computed(() =>
  objectRows(
    stats.value?.deals_by_operational_status,
    t('CRM.REPORTS.EMPTY_LABELS.OPERATIONAL')
  )
);

const breakdownPanels = computed(() => [
  {
    key: 'area',
    title: t('CRM.REPORTS.AREA.TITLE'),
    rows: areaRows.value,
    empty: t('CRM.REPORTS.AREA.EMPTY'),
  },
  {
    key: 'urgency',
    title: t('CRM.REPORTS.URGENCY_PANEL.TITLE'),
    rows: urgencyRows.value,
    empty: t('CRM.REPORTS.URGENCY_PANEL.EMPTY'),
  },
  {
    key: 'priority',
    title: t('CRM.REPORTS.PRIORITY_PANEL.TITLE'),
    rows: priorityRows.value,
    empty: t('CRM.REPORTS.PRIORITY_PANEL.EMPTY'),
  },
  {
    key: 'source',
    title: t('CRM.REPORTS.SOURCE_PANEL.TITLE'),
    rows: sourceRows.value,
    empty: t('CRM.REPORTS.SOURCE_PANEL.EMPTY'),
  },
  {
    key: 'sanitation',
    title: t('CRM.REPORTS.SANITATION.TITLE'),
    rows: operationalRows.value,
    empty: t('CRM.REPORTS.SANITATION.EMPTY'),
  },
]);

const insights = computed(() => {
  const items = [];
  if ((stats.value?.overdue_activities || 0) > 0) {
    items.push({
      title: t('CRM.REPORTS.INSIGHTS.OVERDUE.TITLE'),
      body: t('CRM.REPORTS.INSIGHTS.OVERDUE.BODY'),
      tone: 'danger',
      icon: 'i-lucide-alarm-clock',
    });
  }
  if ((stats.value?.priority_deals || 0) > 0) {
    items.push({
      title: t('CRM.REPORTS.INSIGHTS.HOT_LEADS.TITLE'),
      body: t('CRM.REPORTS.INSIGHTS.HOT_LEADS.BODY'),
      tone: 'warning',
      icon: 'i-lucide-flame',
    });
  }
  if (openDeals.value > 0 && (stats.value?.qualified_deals || 0) === 0) {
    items.push({
      title: t('CRM.REPORTS.INSIGHTS.WEAK_QUALIFICATION.TITLE'),
      body: t('CRM.REPORTS.INSIGHTS.WEAK_QUALIFICATION.BODY'),
      tone: 'info',
      icon: 'i-lucide-filter',
    });
  }
  if (items.length === 0) {
    items.push({
      title: t('CRM.REPORTS.INSIGHTS.NO_ALERTS.TITLE'),
      body: t('CRM.REPORTS.INSIGHTS.NO_ALERTS.BODY'),
      tone: 'good',
      icon: 'i-lucide-circle-check',
    });
  }
  return items;
});

function objectRows(source, emptyLabel) {
  return Object.entries(source || {})
    .map(([key, count]) => ({
      key,
      label: humanize(key || emptyLabel),
      count,
    }))
    .sort((a, b) => b.count - a.count);
}

function humanize(value) {
  return String(value || '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase());
}

function funnelPct(count) {
  return Math.round((count / maxFunnelCount.value) * 100);
}

function barWidthClass(pct) {
  const step = Math.min(20, Math.max(0, Math.round(pct / 5)));
  return BAR_WIDTH_CLASSES[step];
}

function conversionFromPrevious(idx) {
  if (idx === 0 || funnelStages.value[idx - 1]?.count === 0) return null;
  const rate = (
    (funnelStages.value[idx].count / funnelStages.value[idx - 1].count) *
    100
  ).toFixed(0);
  return `${rate}%`;
}

async function loadStats() {
  loading.value = true;
  error.value = '';
  persistFilters();
  try {
    const { data } = await CrmAPI.getDashboard(cleanFilters());
    stats.value = data;
  } catch {
    error.value = t('CRM.REPORTS.ERROR_LOAD');
  } finally {
    loading.value = false;
  }
}

function resetFilters() {
  filters.status = 'open';
  filters.operational_status = '';
  filters.source = '';
  filters.legal_area = '';
  filters.urgency_level = '';
  filters.from = '';
  filters.to = '';
  loadStats();
}

// PERF-04: o export roda em background no servidor; o CSV chega por email.
async function triggerExport() {
  exporting.value = true;
  exportError.value = '';
  exportSuccess.value = '';

  try {
    const response = await CrmAPI.exportDeals(cleanFilters());
    exportSuccess.value =
      response?.data?.message || t('CRM.REPORTS.EXPORT.SUCCESS_FALLBACK');
  } catch (err) {
    if (err?.response?.status === 403) {
      exportError.value = t('CRM.REPORTS.EXPORT.ERROR_FORBIDDEN');
    } else {
      exportError.value =
        err?.response?.data?.error || t('CRM.REPORTS.EXPORT.ERROR_GENERIC');
    }
  } finally {
    exporting.value = false;
  }
}

watch(
  () => route.query.pipeline_id,
  () => loadStats()
);

onMounted(() => {
  fetchCrmOptions().then(options => {
    crmOptions.value = options;
  });
  loadStats();
});
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      v-if="!embedded"
      :title="$t('CRM.REPORTS.TITLE')"
      :breadcrumbs="[
        { label: $t('CRM.REPORTS.EYEBROW') },
        { label: $t('CRM.REPORTS.TITLE') },
      ]"
    >
      <template #actions>
        <DsButton
          variant="secondary"
          icon="i-lucide-download"
          :label="
            exporting
              ? $t('CRM.REPORTS.EXPORT.EXPORTING')
              : $t('CRM.REPORTS.EXPORT.LABEL')
          "
          :loading="exporting"
          @click="triggerExport"
        />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <p class="m-0 max-w-3xl text-ui-body-sm text-ui-text-muted">
        {{ $t('CRM.REPORTS.SUBTITLE') }}
      </p>

      <DsCard as="section" :aria-label="$t('CRM.REPORTS.FILTERS.APPLY')">
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <DsSelect
            v-model="filters.status"
            :label="$t('CRM.REPORTS.FILTERS.STATUS')"
            :options="statusOptions"
          />
          <DsSelect
            v-model="filters.operational_status"
            :label="$t('CRM.REPORTS.FILTERS.OPERATIONAL_STATUS')"
            :options="operationalStatusOptions"
          />
          <DsSelect
            v-model="filters.source"
            :label="$t('CRM.REPORTS.FILTERS.SOURCE')"
            :options="sourceOptions"
          />
          <DsSelect
            v-model="filters.legal_area"
            :label="$t('CRM.REPORTS.FILTERS.LEGAL_AREA')"
            :options="legalAreaOptions"
          />
          <DsSelect
            v-model="filters.urgency_level"
            :label="$t('CRM.REPORTS.FILTERS.URGENCY')"
            :options="urgencyOptions"
          />
          <DsInput
            v-model="filters.from"
            type="date"
            :label="$t('CRM.REPORTS.FILTERS.FROM')"
          />
          <DsInput
            v-model="filters.to"
            type="date"
            :label="$t('CRM.REPORTS.FILTERS.TO')"
          />
          <div class="flex items-end gap-2">
            <DsButton
              variant="primary"
              icon="i-lucide-filter"
              :label="$t('CRM.REPORTS.FILTERS.APPLY')"
              class="min-w-0 flex-1"
              @click="loadStats"
            />
            <DsButton
              variant="ghost"
              :label="$t('CRM.REPORTS.FILTERS.RESET')"
              @click="resetFilters"
            />
          </div>
        </div>
      </DsCard>

      <div aria-live="polite" class="flex flex-col gap-2">
        <div
          v-if="exportError"
          role="alert"
          class="flex items-center gap-2 rounded-ui-surface bg-ui-danger-soft p-3 text-ui-body-sm text-ui-danger-foreground"
        >
          <Icon
            icon="i-lucide-circle-alert"
            class="size-4 shrink-0"
            aria-hidden="true"
          />
          {{ exportError }}
        </div>
        <div
          v-else-if="exportSuccess"
          role="status"
          class="flex items-center gap-2 rounded-ui-surface bg-ui-success-soft p-3 text-ui-body-sm text-ui-success-foreground"
        >
          <Icon
            icon="i-lucide-mail-check"
            class="size-4 shrink-0"
            aria-hidden="true"
          />
          {{ exportSuccess }}
        </div>
      </div>

      <div
        v-if="error"
        role="alert"
        class="flex items-center gap-2 rounded-ui-surface bg-ui-danger-soft p-3 text-ui-body-sm text-ui-danger-foreground"
      >
        <Icon
          icon="i-lucide-circle-alert"
          class="size-4 shrink-0"
          aria-hidden="true"
        />
        {{ error }}
      </div>

      <div
        v-if="loading"
        role="status"
        :aria-label="$t('CRM.REPORTS.LOADING')"
        class="flex flex-col gap-4"
      >
        <span class="sr-only">{{ $t('CRM.REPORTS.LOADING') }}</span>
        <DsSkeleton shape="block" class="h-24" />
        <div class="grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          <DsSkeleton
            v-for="panel in 6"
            :key="panel"
            shape="block"
            class="h-56"
          />
        </div>
      </div>

      <template v-else-if="stats">
        <DsCard
          as="section"
          padding="none"
          :aria-label="$t('CRM.REPORTS.KPI.ARIA_LABEL')"
        >
          <dl
            class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-9"
          >
            <div
              v-for="card in metricCards"
              :key="card.key"
              class="flex min-w-0 flex-col gap-1 p-3 sm:p-4"
            >
              <dt
                class="flex items-center justify-between gap-2 text-ui-caption font-medium uppercase tracking-wide text-ui-text-muted"
              >
                <span class="truncate">{{ card.label }}</span>
                <Icon
                  :icon="card.icon"
                  class="size-4 shrink-0"
                  :class="card.iconClass"
                  aria-hidden="true"
                />
              </dt>
              <dd
                class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
                :title="String(card.value)"
              >
                {{ card.value }}
              </dd>
              <dd
                class="m-0 truncate text-ui-caption text-ui-text-subtle"
                :title="card.hint"
              >
                {{ card.hint }}
              </dd>
            </div>
          </dl>
        </DsCard>

        <div class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          <article
            v-for="insight in insights"
            :key="insight.title"
            class="flex min-w-0 gap-3 rounded-ui-surface p-4"
            :class="INSIGHT_TONE_CLASSES[insight.tone]"
          >
            <Icon
              :icon="insight.icon"
              class="mt-0.5 size-4 shrink-0"
              aria-hidden="true"
            />
            <div class="min-w-0">
              <h2 class="m-0 font-manrope text-ui-label font-semibold">
                {{ insight.title }}
              </h2>
              <p class="m-0 mt-1 text-ui-body-sm">
                {{ insight.body }}
              </p>
            </div>
          </article>
        </div>

        <div class="grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          <DsCard
            as="section"
            aria-labelledby="crm-reports-funnel-title"
            class="lg:col-span-2 xl:col-span-3"
          >
            <div class="mb-4 flex items-start justify-between gap-4">
              <div class="min-w-0">
                <h2
                  id="crm-reports-funnel-title"
                  class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
                >
                  {{ $t('CRM.REPORTS.FUNNEL.TITLE') }}
                </h2>
                <p class="m-0 mt-1 text-ui-caption text-ui-text-muted">
                  {{
                    $t('CRM.REPORTS.FUNNEL.SUBTITLE', {
                      count: funnelStages.length,
                    })
                  }}
                </p>
              </div>
              <DsBadge
                variant="neutral"
                :label="
                  $t('CRM.REPORTS.FUNNEL.TOTAL', { count: funnelTotal })
                "
              />
            </div>
            <DsEmptyState
              v-if="!funnelStages.length"
              :title="$t('CRM.REPORTS.FUNNEL.EMPTY')"
            />
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="(stage, idx) in funnelStages"
                :key="stage.slug || stage.name"
                class="flex items-center gap-3"
              >
                <span
                  class="w-24 shrink-0 truncate text-right text-ui-caption text-ui-text-muted sm:w-40"
                  :title="stage.name"
                >
                  {{ stage.name }}
                </span>
                <div
                  class="h-5 min-w-0 flex-1 overflow-hidden rounded-ui-control bg-ui-sunken"
                >
                  <div
                    aria-hidden="true"
                    class="h-full rounded-ui-control bg-ui-chart-brand transition-[width] duration-500"
                    :class="barWidthClass(funnelPct(stage.count))"
                  />
                </div>
                <span
                  class="w-10 shrink-0 text-right text-ui-caption font-semibold text-ui-text"
                >
                  {{ stage.count }}
                </span>
                <DsBadge
                  class="w-16 shrink-0 justify-center"
                  :variant="conversionFromPrevious(idx) ? 'success' : 'neutral'"
                  :label="
                    conversionFromPrevious(idx) ||
                    $t('CRM.REPORTS.FUNNEL.ENTRY')
                  "
                  :title="
                    conversionFromPrevious(idx)
                      ? $t('CRM.REPORTS.FUNNEL.CONV_RATE_TITLE')
                      : undefined
                  "
                />
              </div>
            </div>
          </DsCard>

          <DsCard
            v-for="panel in breakdownPanels"
            :key="panel.key"
            as="section"
            :aria-labelledby="`crm-reports-panel-${panel.key}`"
          >
            <h2
              :id="`crm-reports-panel-${panel.key}`"
              class="m-0 mb-4 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ panel.title }}
            </h2>
            <div
              v-if="panel.rows.length"
              class="divide-y divide-ui-border-subtle"
            >
              <div
                v-for="row in panel.rows"
                :key="row.key || row.label"
                class="flex items-center justify-between gap-4 py-2.5"
              >
                <span
                  class="min-w-0 truncate text-ui-body-sm text-ui-text-muted"
                >
                  {{ row.label }}
                </span>
                <strong
                  class="shrink-0 text-ui-body-sm font-semibold text-ui-text"
                >
                  {{ row.count }}
                </strong>
              </div>
            </div>
            <div
              v-else
              class="rounded-ui-control border border-dashed border-ui-border p-4 text-center text-ui-body-sm text-ui-text-muted"
            >
              {{ panel.empty }}
            </div>
          </DsCard>
        </div>
      </template>
    </div>
  </section>
</template>

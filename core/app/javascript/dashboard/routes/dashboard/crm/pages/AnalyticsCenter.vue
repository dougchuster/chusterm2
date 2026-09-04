<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import {
  startOfDay,
  endOfDay,
  subDays,
  startOfMonth,
  differenceInDays,
  format,
} from 'date-fns';

import CrmAPI from 'dashboard/api/crm';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import SLAReportsAPI from 'dashboard/api/slaReports';
import { useUISettings } from 'dashboard/composables/useUISettings';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsEmptyState,
  DsInput,
  DsSelect,
  DsTable,
  DsTabs,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

// --- Estados Globais ---
const loading = ref(true);
const refreshing = ref(false);
const exportLoading = ref(false);
const exportMessage = ref('');
const exportError = ref('');

// Tab ativa (executive | funnel | support)
const activeTab = ref(route.query.tab || 'executive');

// Período selecionado
const selectedPeriod = ref(
  route.query.period || uiSettings.value?.analytics_period || '30'
);
const customStartDate = ref(
  route.query.from || format(subDays(new Date(), 29), 'yyyy-MM-dd')
);
const customEndDate = ref(
  route.query.to || format(new Date(), 'yyyy-MM-dd')
);

// --- Dados das Fontes Reais ---
const overview = ref({});
const funnel = ref([]);
const winLoss = ref([]);
const lossReasons = ref([]);
const scoreByStage = ref([]);
const areaDistribution = ref([]);
const topDeals = ref([]);
const staleDeals = ref([]);
const timeInStage = ref([]);
const dashboardStats = ref({});
const supportSummary = ref({});
const csatMetrics = ref({});
const slaMetrics = ref({});
const inboxReports = ref([]);

// AI Analyst state
const analystQuestion = ref('');
const analystLoading = ref(false);
const analystResult = ref(null);

// Quantização de larguras para classes estáticas do Tailwind (sem style inline)
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

const URGENCY_DOT_CLASSES = {
  critica: 'bg-ui-chart-danger',
  alta: 'bg-ui-chart-warning-strong',
  media: 'bg-ui-chart-warning',
  normal: 'bg-ui-chart-neutral',
  baixa: 'bg-ui-chart-info',
};

// --- Opções de Abas e Períodos ---
const tabList = computed(() => [
  {
    value: 'executive',
    label: t('CRM.ANALYTICS.TABS.EXECUTIVE'),
    icon: 'i-lucide-layout-dashboard',
  },
  {
    value: 'funnel',
    label: t('CRM.ANALYTICS.TABS.FUNNEL'),
    icon: 'i-lucide-filter',
  },
  {
    value: 'support',
    label: t('CRM.ANALYTICS.TABS.SUPPORT'),
    icon: 'i-lucide-headphones',
  },
]);

const periodOptions = computed(() => [
  { value: 'today', label: t('CRM.ANALYTICS.PERIOD.TODAY') },
  { value: '7', label: t('CRM.ANALYTICS.PERIOD.LAST_7_DAYS') },
  { value: '30', label: t('CRM.ANALYTICS.PERIOD.LAST_30_DAYS') },
  { value: 'this_month', label: t('CRM.ANALYTICS.PERIOD.THIS_MONTH') },
  { value: 'custom', label: t('CRM.ANALYTICS.PERIOD.CUSTOM') },
]);

// --- Cálculos de Datas ---
const dateRange = computed(() => {
  const now = new Date();
  let start = subDays(now, 29);
  let end = now;
  let days = 30;

  if (selectedPeriod.value === 'today') {
    start = startOfDay(now);
    end = endOfDay(now);
    days = 1;
  } else if (selectedPeriod.value === '7') {
    start = startOfDay(subDays(now, 6));
    end = endOfDay(now);
    days = 7;
  } else if (selectedPeriod.value === '30') {
    start = startOfDay(subDays(now, 29));
    end = endOfDay(now);
    days = 30;
  } else if (selectedPeriod.value === 'this_month') {
    start = startOfDay(startOfMonth(now));
    end = endOfDay(now);
    days = Math.max(1, differenceInDays(now, startOfMonth(now)) + 1);
  } else if (selectedPeriod.value === 'custom') {
    const s = customStartDate.value ? new Date(customStartDate.value) : subDays(now, 29);
    const e = customEndDate.value ? new Date(customEndDate.value) : now;
    start = startOfDay(s);
    end = endOfDay(e);
    days = Math.max(1, differenceInDays(end, start) + 1);
  }

  const since = Math.floor(start.getTime() / 1000);
  const until = Math.floor(end.getTime() / 1000);

  return { start, end, days, since, until };
});

// --- Funções de Formatação ---
function formatCurrency(cents) {
  if (!cents && cents !== 0) return 'R$ 0,00';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100);
}

function formatDuration(seconds) {
  const sec = Number(seconds);
  if (!sec || isNaN(sec)) return '-';
  if (sec < 60) return `${Math.round(sec)}s`;
  if (sec < 3600) return `${Math.round(sec / 60)}m`;
  if (sec < 86400) return `${(sec / 3600).toFixed(1)}h`;
  return `${(sec / 86400).toFixed(1)}d`;
}

function formatHours(h) {
  if (!h && h !== 0) return '-';
  if (h < 24) return `${h}h`;
  return `${(h / 24).toFixed(1)}d`;
}

function barWidthClass(pct) {
  const safePct = Math.min(100, Math.max(0, Number(pct) || 0));
  const step = Math.min(20, Math.max(0, Math.round(safePct / 5)));
  return BAR_WIDTH_CLASSES[step];
}

function urgencyClass(level) {
  return URGENCY_DOT_CLASSES[level] || URGENCY_DOT_CLASSES.normal;
}

function urgencyLabel(level) {
  const labels = {
    critica: t('CRM.METRICS.URGENCY.CRITICA'),
    alta: t('CRM.METRICS.URGENCY.ALTA'),
    media: t('CRM.METRICS.URGENCY.MEDIA'),
    normal: t('CRM.METRICS.URGENCY.NORMAL'),
    baixa: t('CRM.METRICS.URGENCY.BAIXA'),
  };
  return labels[level] || labels.normal;
}

// --- Indicadores Calculados ---
const maxFunnelCount = computed(() =>
  Math.max(1, ...funnel.value.map(f => f.deal_count || 0))
);

const maxWinLossCount = computed(() =>
  Math.max(1, ...winLoss.value.map(d => (d.won || 0) + (d.lost || 0)))
);

const totalFunnelDeals = computed(() =>
  funnel.value.reduce((sum, stage) => sum + (stage.deal_count || 0), 0)
);

// CSAT Calculations
const csatTotalResponses = computed(
  () => csatMetrics.value?.totalResponseCount || 0
);

const csatSatisfactionScore = computed(() => {
  const total = csatTotalResponses.value;
  if (!total) return '0%';
  const ratings = csatMetrics.value?.ratingsCount || {};
  const positive = (ratings[4] || 0) + (ratings[5] || 0);
  return `${((positive / total) * 100).toFixed(1)}%`;
});

const csatResponseRate = computed(() => {
  const totalSent = csatMetrics.value?.totalSentMessagesCount || 0;
  const totalResp = csatTotalResponses.value;
  if (!totalSent || !totalResp) return '0%';
  return `${((totalResp / totalSent) * 100).toFixed(1)}%`;
});

const csatRatingRows = computed(() => {
  const total = csatTotalResponses.value;
  const ratings = csatMetrics.value?.ratingsCount || {};
  return [5, 4, 3, 2, 1].map(stars => {
    const count = ratings[stars] || 0;
    const pct = total > 0 ? Math.round((count / total) * 100) : 0;
    return { stars, count, pct };
  });
});

// SLA Calculations
const slaHitRate = computed(() => {
  if (slaMetrics.value?.hitRate !== undefined) {
    return String(slaMetrics.value.hitRate);
  }
  return '0%';
});

const slaBreaches = computed(
  () => slaMetrics.value?.numberOfSLAMisses ?? 0
);

const slaConversationsCount = computed(
  () => slaMetrics.value?.numberOfConversations ?? 0
);

// Executive KPIs
const executiveKpis = computed(() => {
  const o = overview.value || {};
  const s = supportSummary.value || {};
  return [
    {
      key: 'revenue',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.REVENUE_WON'),
      value: formatCurrency(o.won_value),
      valueClass: 'text-ui-success',
      icon: 'i-lucide-circle-dollar-sign',
    },
    {
      key: 'conversations',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.CONVERSATIONS'),
      value: s.conversations_count || 0,
      icon: 'i-lucide-messages-square',
    },
    {
      key: 'win_rate',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.CONVERSION_RATE'),
      value: `${o.win_rate || 0}%`,
      valueClass: 'text-ui-brand',
      icon: 'i-lucide-trending-up',
    },
    {
      key: 'frt',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.AVG_FIRST_RESPONSE'),
      value: formatDuration(s.avg_first_response_time),
      icon: 'i-lucide-clock',
    },
    {
      key: 'avg_time',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.AVG_TIME_TO_CLOSE'),
      value: o.avg_time_to_close ? `${o.avg_time_to_close}d` : '-',
      icon: 'i-lucide-timer',
    },
    {
      key: 'open_deals',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.OPEN_DEALS'),
      value: o.open_deals || 0,
      icon: 'i-lucide-layers',
    },
    {
      key: 'pipeline',
      label: t('CRM.ANALYTICS.EXECUTIVE.KPIS.PIPELINE_VALUE'),
      value: formatCurrency(o.total_value),
      icon: 'i-lucide-briefcase',
    },
  ];
});

// Support & SLA KPIs
const supportKpis = computed(() => {
  const s = supportSummary.value || {};
  return [
    {
      key: 'csat_score',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.CSAT_SCORE'),
      value: csatSatisfactionScore.value,
      valueClass: 'text-ui-success',
      icon: 'i-lucide-smile',
    },
    {
      key: 'csat_responses',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.CSAT_RESPONSES'),
      value: csatTotalResponses.value,
      icon: 'i-lucide-message-circle-check',
    },
    {
      key: 'csat_rate',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.CSAT_RESPONSE_RATE'),
      value: csatResponseRate.value,
      icon: 'i-lucide-percent',
    },
    {
      key: 'sla_hit',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.SLA_HIT_RATE'),
      value: slaHitRate.value,
      valueClass: 'text-ui-brand',
      icon: 'i-lucide-shield-check',
    },
    {
      key: 'sla_breaches',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.SLA_MISSES'),
      value: slaBreaches.value,
      valueClass: slaBreaches.value > 0 ? 'text-ui-danger' : 'text-ui-text',
      icon: 'i-lucide-alert-octagon',
    },
    {
      key: 'sla_convs',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.SLA_CONVERSATIONS'),
      value: slaConversationsCount.value,
      icon: 'i-lucide-shield-alert',
    },
    {
      key: 'frt',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.FRT'),
      value: formatDuration(s.avg_first_response_time),
      icon: 'i-lucide-zap',
    },
    {
      key: 'resolution_time',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.RESOLUTION_TIME'),
      value: formatDuration(s.avg_resolution_time),
      icon: 'i-lucide-check-circle-2',
    },
    {
      key: 'resolutions_count',
      label: t('CRM.ANALYTICS.SUPPORT.KPIS.RESOLUTIONS_COUNT'),
      value: s.resolutions_count || 0,
      icon: 'i-lucide-sparkles',
    },
  ];
});

// Operational Insights
const operationalInsights = computed(() => {
  const items = [];
  const overdue = dashboardStats.value?.overdue_activities || 0;
  const priority = dashboardStats.value?.priority_deals || 0;
  const qualified = dashboardStats.value?.qualified_deals || 0;
  const openCount = overview.value?.open_deals || 0;

  if (overdue > 0) {
    items.push({
      key: 'overdue',
      title: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.OVERDUE_TITLE'),
      body: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.OVERDUE_BODY', { count: overdue }),
      badge: 'danger',
      icon: 'i-lucide-alarm-clock',
    });
  }
  if (priority > 0) {
    items.push({
      key: 'hot_leads',
      title: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.HOT_LEADS_TITLE'),
      body: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.HOT_LEADS_BODY', { count: priority }),
      badge: 'warning',
      icon: 'i-lucide-flame',
    });
  }
  if (openCount > 0 && qualified === 0) {
    items.push({
      key: 'weak_qual',
      title: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.QUALIFICATION_TITLE'),
      body: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.QUALIFICATION_BODY'),
      badge: 'info',
      icon: 'i-lucide-filter',
    });
  }
  if (items.length === 0) {
    items.push({
      key: 'healthy',
      title: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.HEALTHY_TITLE'),
      body: t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.HEALTHY_BODY'),
      badge: 'success',
      icon: 'i-lucide-check-circle',
    });
  }
  return items;
});

// Table Headers
const topDealsHeaders = computed(() => [
  { key: 'title', label: t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.DEAL') },
  { key: 'contact', label: t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.CONTACT') },
  { key: 'stage', label: t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.STAGE') },
  { key: 'score', label: t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.SCORE'), class: 'w-16' },
  { key: 'urgency', label: t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.URGENCY'), class: 'w-24' },
]);

const lossReasonsHeaders = computed(() => [
  { key: 'rank', label: t('CRM.ANALYTICS.FUNNEL.LOSS_REASONS.RANK'), class: 'w-12' },
  { key: 'reason', label: t('CRM.ANALYTICS.FUNNEL.LOSS_REASONS.REASON') },
  { key: 'count', label: t('CRM.ANALYTICS.FUNNEL.LOSS_REASONS.COUNT'), class: 'w-24 text-right' },
]);

const timeInStageHeaders = computed(() => [
  { key: 'stage', label: t('CRM.ANALYTICS.FUNNEL.TIME_IN_STAGE.STAGE') },
  { key: 'avg', label: t('CRM.ANALYTICS.FUNNEL.TIME_IN_STAGE.AVG_TIME'), class: 'w-28' },
  { key: 'detail', label: t('CRM.METRICS.TIME_IN_STAGE.DETAIL') },
]);

const inboxesHeaders = computed(() => [
  { key: 'name', label: t('CRM.ANALYTICS.SUPPORT.INBOXES.INBOX') },
  { key: 'conversations', label: t('CRM.ANALYTICS.SUPPORT.INBOXES.CONVERSATIONS'), class: 'w-28 text-right' },
  { key: 'frt', label: t('CRM.ANALYTICS.SUPPORT.INBOXES.FRT'), class: 'w-36 text-right' },
  { key: 'res', label: t('CRM.ANALYTICS.SUPPORT.INBOXES.RESOLUTION_TIME'), class: 'w-36 text-right' },
]);

// --- Funil: cálculo de conversão entre etapas ---
function funnelConversionRate(idx) {
  if (idx === 0 || !funnel.value[idx - 1]?.deal_count) return null;
  const current = funnel.value[idx].deal_count || 0;
  const prev = funnel.value[idx - 1].deal_count || 0;
  return `${((current / prev) * 100).toFixed(0)}%`;
}

// --- Carregamento Unificado de Dados ---
async function fetchAll() {
  loading.value = true;
  exportMessage.value = '';
  exportError.value = '';

  const { days, since, until } = dateRange.value;
  const params = {
    period_days: days,
    months: Math.max(6, Math.ceil(days / 30)),
  };

  const results = await Promise.allSettled([
    CrmAPI.getMetricsOverview(params),
    CrmAPI.getMetricsStageFunnel(params),
    CrmAPI.getMetricsWinLossTrend(params),
    CrmAPI.getMetricsTopLossReasons(params),
    CrmAPI.getMetricsScoreByStage(params),
    CrmAPI.getMetricsAreaDistribution(params),
    CrmAPI.getMetricsTopDeals(params),
    CrmAPI.getMetricsStaleDeals(params),
    CrmAPI.getMetricsTimeInStage(params),
    CrmAPI.getDashboard({
      from: format(dateRange.value.start, 'yyyy-MM-dd'),
      to: format(dateRange.value.end, 'yyyy-MM-dd'),
    }),
    ReportsAPI.getSummary(since, until, 'account'),
    CSATReportsAPI.getMetrics({ from: since, to: until }),
    SLAReportsAPI.getMetrics({ from: since, to: until }),
    ReportsAPI.getInboxReports({ from: since, to: until }),
  ]);

  if (results[0].status === 'fulfilled') overview.value = results[0].value.data || {};
  if (results[1].status === 'fulfilled') funnel.value = results[1].value.data || [];
  if (results[2].status === 'fulfilled') winLoss.value = results[2].value.data || [];
  if (results[3].status === 'fulfilled') lossReasons.value = results[3].value.data || [];
  if (results[4].status === 'fulfilled') scoreByStage.value = results[4].value.data || [];
  if (results[5].status === 'fulfilled') areaDistribution.value = results[5].value.data || [];
  if (results[6].status === 'fulfilled') topDeals.value = results[6].value.data || [];
  if (results[7].status === 'fulfilled') staleDeals.value = results[7].value.data || [];
  if (results[8].status === 'fulfilled') timeInStage.value = results[8].value.data || [];
  if (results[9].status === 'fulfilled') dashboardStats.value = results[9].value.data || {};
  if (results[10].status === 'fulfilled') supportSummary.value = results[10].value.data || {};
  if (results[11].status === 'fulfilled') csatMetrics.value = results[11].value.data || {};
  if (results[12].status === 'fulfilled') slaMetrics.value = results[12].value.data || {};
  if (results[13].status === 'fulfilled') inboxReports.value = results[13].value.data || [];

  loading.value = false;
  refreshing.value = false;
}

// Troca de Período com Persistência
function onPeriodChange() {
  updateUISettings({ analytics_period: selectedPeriod.value });
  router.replace({
    query: {
      ...route.query,
      period: selectedPeriod.value,
      tab: activeTab.value,
      ...(selectedPeriod.value === 'custom'
        ? { from: customStartDate.value, to: customEndDate.value }
        : { from: undefined, to: undefined }),
    },
  });
  fetchAll();
}

function onCustomDateChange() {
  if (selectedPeriod.value === 'custom') {
    onPeriodChange();
  }
}

// Troca de Aba com Atualização de URL
function onTabChange(newTab) {
  activeTab.value = newTab;
  router.replace({
    query: {
      ...route.query,
      tab: newTab,
    },
  });
}

function refreshAll() {
  refreshing.value = true;
  fetchAll();
}

function goBack() {
  router.push({ name: 'crm_dashboard', params: { accountId: route.params.accountId } });
}

function dealUrl(deal) {
  return `/app/accounts/${route.params.accountId}/crm/deals/${deal.id}`;
}

function openDeal(deal) {
  router.push(dealUrl(deal));
}

// AI Analyst Call
async function askAnalyst() {
  const query = String(analystQuestion.value || '').trim();
  if (!query) return;

  analystLoading.value = true;
  analystResult.value = null;
  try {
    const response = await CrmAPI.askAnalyst({
      question: query,
      period_days: dateRange.value.days,
    });
    analystResult.value = response.data;
  } catch {
    analystResult.value = {
      answer: t('CRM.ANALYTICS.FUNNEL.ANALYST.ERROR'),
      metrics: {},
    };
  } finally {
    analystLoading.value = false;
  }
}

// Exportação em Background
async function triggerExport() {
  exportLoading.value = true;
  exportMessage.value = '';
  exportError.value = '';

  try {
    const response = await CrmAPI.exportDeals({
      from: format(dateRange.value.start, 'yyyy-MM-dd'),
      to: format(dateRange.value.end, 'yyyy-MM-dd'),
    });
    exportMessage.value =
      response?.data?.message || t('CRM.ANALYTICS.EXPORT.SUCCESS');
  } catch {
    exportError.value = t('CRM.ANALYTICS.EXPORT.ERROR');
  } finally {
    exportLoading.value = false;
  }
}

onMounted(fetchAll);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <!-- Header com Breadcrumbs, Título e Filtro Global de Período -->
    <DsPageHeader
      :title="$t('CRM.ANALYTICS.TITLE')"
      :breadcrumbs="[
        { label: $t('CRM.ANALYTICS.BREADCRUMB') },
        { label: $t('CRM.ANALYTICS.TITLE') },
      ]"
    >
      <template #actions>
        <DsButton
          icon="i-lucide-arrow-left"
          variant="ghost"
          :aria-label="$t('CRM.ANALYTICS.BACK')"
          @click="goBack"
        />

        <DsButton
          icon="i-lucide-rotate-cw"
          variant="secondary"
          :loading="refreshing"
          :aria-label="$t('CRM.ANALYTICS.REFRESH')"
          @click="refreshAll"
        />

        <DsButton
          icon="i-lucide-download"
          variant="secondary"
          :loading="exportLoading"
          :label="$t('CRM.ANALYTICS.EXPORT.BUTTON')"
          @click="triggerExport"
        />

        <!-- Filtro Global Reativo de Período -->
        <div class="flex items-center gap-2">
          <DsSelect
            v-model="selectedPeriod"
            :label="$t('CRM.ANALYTICS.PERIOD.LABEL')"
            hide-label
            :options="periodOptions"
            class="min-w-36"
            @change="onPeriodChange"
          />

          <!-- Inputs de Data Personalizada quando 'custom' ativo -->
          <template v-if="selectedPeriod === 'custom'">
            <DsInput
              v-model="customStartDate"
              type="date"
              :label="$t('CRM.ANALYTICS.PERIOD.START_DATE')"
              hide-label
              class="w-36"
              @change="onCustomDateChange"
            />
            <DsInput
              v-model="customEndDate"
              type="date"
              :label="$t('CRM.ANALYTICS.PERIOD.END_DATE')"
              hide-label
              class="w-36"
              @change="onCustomDateChange"
            />
          </template>
        </div>
      </template>
    </DsPageHeader>

    <!-- Feedback de Exportação -->
    <div
      v-if="exportMessage"
      class="border-b border-ui-success bg-ui-success-soft px-4 py-2 text-ui-body-sm text-ui-success-foreground"
      role="status"
    >
      {{ exportMessage }}
    </div>
    <div
      v-if="exportError"
      class="border-b border-ui-danger bg-ui-danger-soft px-4 py-2 text-ui-body-sm text-ui-danger-foreground"
      role="alert"
    >
      {{ exportError }}
    </div>

    <!-- Navegação de Abas Unificada -->
    <div class="border-b border-ui-border-subtle bg-ui-surface px-4 pt-2 sm:px-6">
      <DsTabs
        v-model="activeTab"
        :tabs="tabList"
        :label="$t('CRM.ANALYTICS.TABS.LABEL')"
        @change="onTabChange"
      />
    </div>

    <!-- Conteúdo Principal com Scroll -->
    <div class="flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto p-4 sm:p-6">
      <!-- Skeletons durante carregamento inicial -->
      <div v-if="loading && !overview.total_deals" class="flex flex-col gap-4">
        <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <DsCard v-for="i in 4" :key="i" loading />
        </div>
        <DsCard loading class="h-64" />
      </div>

      <template v-else>
        <!-- ========================================== -->
        <!-- ABA 1: VISÃO EXECUTIVA                     -->
        <!-- ========================================== -->
        <section
          v-if="activeTab === 'executive'"
          aria-labelledby="tab-executive-heading"
          class="flex flex-col gap-6"
        >
          <h2 id="tab-executive-heading" class="sr-only">
            {{ $t('CRM.ANALYTICS.EXECUTIVE.TITLE') }}
          </h2>

          <!-- Grid de KPIs Executivos Unificados -->
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-7">
            <DsCard
              v-for="kpi in executiveKpis"
              :key="kpi.key"
              padding="sm"
              class="flex flex-col gap-1"
            >
              <div class="flex items-center justify-between text-ui-text-muted">
                <span class="truncate text-ui-caption font-medium">{{ kpi.label }}</span>
                <Icon :icon="kpi.icon" class="h-4 w-4 shrink-0 opacity-70" />
              </div>
              <span
                class="truncate text-ui-title font-semibold"
                :class="kpi.valueClass || 'text-ui-text'"
              >
                {{ kpi.value }}
              </span>
            </DsCard>
          </div>

          <!-- Tendência Mensal de Fechamentos (Win/Loss) -->
          <DsCard class="flex flex-col gap-4">
            <div class="flex items-center justify-between">
              <div class="flex flex-col">
                <h3 class="text-ui-heading font-semibold text-ui-text">
                  {{ $t('CRM.ANALYTICS.EXECUTIVE.TRENDS.TITLE') }}
                </h3>
                <span class="text-ui-caption text-ui-text-muted">
                  {{ $t('CRM.ANALYTICS.EXECUTIVE.SUBTITLE') }}
                </span>
              </div>
              <div class="flex items-center gap-4 text-ui-caption">
                <div class="flex items-center gap-1.5">
                  <span class="h-2.5 w-2.5 rounded-full bg-ui-chart-success" />
                  <span>{{ $t('CRM.ANALYTICS.EXECUTIVE.TRENDS.WON_LABEL') }}</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="h-2.5 w-2.5 rounded-full bg-ui-chart-danger" />
                  <span>{{ $t('CRM.ANALYTICS.EXECUTIVE.TRENDS.LOST_LABEL') }}</span>
                </div>
              </div>
            </div>

            <div v-if="!winLoss.length" class="py-8">
              <DsEmptyState
                icon="i-lucide-bar-chart"
                :title="$t('CRM.ANALYTICS.EXECUTIVE.TRENDS.EMPTY')"
              />
            </div>

            <div v-else class="flex flex-col gap-3">
              <div
                v-for="row in winLoss"
                :key="row.month"
                class="flex flex-col gap-1 text-ui-body-sm"
              >
                <div class="flex items-center justify-between text-ui-caption text-ui-text-muted">
                  <span class="font-medium text-ui-text">{{ row.month }}</span>
                  <span>{{ row.won || 0 }} won / {{ row.lost || 0 }} lost</span>
                </div>
                <div class="flex h-3 w-full gap-1 overflow-hidden rounded-ui-control bg-ui-sunken">
                  <div
                    class="h-full bg-ui-chart-success transition-all duration-ui-fast"
                    :class="barWidthClass(((row.won || 0) / maxWinLossCount) * 100)"
                  />
                  <div
                    class="h-full bg-ui-chart-danger transition-all duration-ui-fast"
                    :class="barWidthClass(((row.lost || 0) / maxWinLossCount) * 100)"
                  />
                </div>
              </div>
            </div>
          </DsCard>

          <!-- Grid: Alertas Operacionais & Top Oportunidades -->
          <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <!-- Alertas & Insights Executivos -->
            <DsCard class="flex flex-col gap-4">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.EXECUTIVE.INSIGHTS.TITLE') }}
              </h3>
              <div class="flex flex-col gap-3">
                <div
                  v-for="insight in operationalInsights"
                  :key="insight.key"
                  class="flex items-start gap-3 rounded-ui-control border border-ui-border-subtle bg-ui-surface p-3"
                >
                  <Icon
                    :icon="insight.icon"
                    class="mt-0.5 h-5 w-5 shrink-0"
                    :class="{
                      'text-ui-danger': insight.badge === 'danger',
                      'text-ui-warning': insight.badge === 'warning',
                      'text-ui-info': insight.badge === 'info',
                      'text-ui-success': insight.badge === 'success',
                    }"
                  />
                  <div class="flex flex-1 flex-col">
                    <span class="text-ui-body-sm font-semibold text-ui-text">
                      {{ insight.title }}
                    </span>
                    <span class="text-ui-caption text-ui-text-muted">
                      {{ insight.body }}
                    </span>
                  </div>
                </div>
              </div>
            </DsCard>

            <!-- Oportunidades em Destaque -->
            <DsCard class="flex flex-col gap-4">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.TITLE') }}
              </h3>

              <div v-if="!topDeals.length" class="py-6">
                <DsEmptyState
                  icon="i-lucide-trophy"
                  :title="$t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.EMPTY')"
                />
              </div>

              <div v-else class="overflow-x-auto">
                <DsTable
                  :caption="$t('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.TITLE')"
                  :headers="topDealsHeaders"
                  :items="topDeals"
                  min-width-class="min-w-0"
                >
                  <template #cell-title="{ item }">
                    <button
                      type="button"
                      class="text-left font-medium text-ui-text hover:text-ui-brand focus:underline"
                      @click="openDeal(item)"
                    >
                      {{ item.title }}
                    </button>
                  </template>

                  <template #cell-contact="{ item }">
                    <span class="text-ui-caption text-ui-text-muted">
                      {{ item.contact_name || '-' }}
                    </span>
                  </template>

                  <template #cell-stage="{ item }">
                    <span class="text-ui-caption text-ui-text-muted">
                      {{ item.stage_name || '-' }}
                    </span>
                  </template>

                  <template #cell-score="{ item }">
                    <DsBadge
                      :label="String(item.score_total ?? 0)"
                      variant="brand"
                    />
                  </template>

                  <template #cell-urgency="{ item }">
                    <div class="flex items-center gap-1.5">
                      <span
                        class="h-2 w-2 rounded-full"
                        :class="urgencyClass(item.urgency_level)"
                      />
                      <span class="text-ui-caption">
                        {{ urgencyLabel(item.urgency_level) }}
                      </span>
                    </div>
                  </template>
                </DsTable>
              </div>
            </DsCard>
          </div>
        </section>

        <!-- ========================================== -->
        <!-- ABA 2: FUNIL DE VENDAS & EFICIÊNCIA        -->
        <!-- ========================================== -->
        <section
          v-if="activeTab === 'funnel'"
          aria-labelledby="tab-funnel-heading"
          class="flex flex-col gap-6"
        >
          <h2 id="tab-funnel-heading" class="sr-only">
            {{ $t('CRM.ANALYTICS.FUNNEL.TITLE') }}
          </h2>

          <!-- Gráfico do Funil de Conversão e Passagem entre Etapas -->
          <DsCard class="flex flex-col gap-4">
            <div class="flex items-center justify-between">
              <div class="flex flex-col">
                <h3 class="text-ui-heading font-semibold text-ui-text">
                  {{ $t('CRM.ANALYTICS.FUNNEL.TITLE') }}
                </h3>
                <span class="text-ui-caption text-ui-text-muted">
                  {{ $t('CRM.ANALYTICS.FUNNEL.SUBTITLE') }}
                </span>
              </div>
              <span class="text-ui-caption font-medium text-ui-text-muted">
                {{ $t('CRM.ANALYTICS.FUNNEL.TOTAL_DEALS', { count: totalFunnelDeals }) }}
              </span>
            </div>

            <div v-if="!funnel.length" class="py-8">
              <DsEmptyState
                icon="i-lucide-filter"
                :title="$t('CRM.ANALYTICS.FUNNEL.EMPTY')"
              />
            </div>

            <div v-else class="flex flex-col gap-4">
              <div
                v-for="(stage, idx) in funnel"
                :key="stage.stage_id || stage.stage_name"
                class="flex flex-col gap-1.5"
              >
                <div class="flex items-center justify-between text-ui-body-sm">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-ui-text">{{ stage.stage_name }}</span>
                    <DsBadge
                      v-if="funnelConversionRate(idx)"
                      :label="funnelConversionRate(idx)"
                      variant="brand"
                    />
                    <DsBadge
                      v-else
                      :label="$t('CRM.ANALYTICS.FUNNEL.ENTRY_STAGE')"
                      variant="neutral"
                    />
                  </div>
                  <div class="flex items-center gap-3 text-ui-caption text-ui-text-muted">
                    <span>{{ stage.deal_count || 0 }} deals</span>
                    <span>{{ formatCurrency(stage.deal_value) }}</span>
                  </div>
                </div>

                <!-- Barra de Progresso Quantizada -->
                <div class="h-3 w-full overflow-hidden rounded-ui-control bg-ui-sunken">
                  <div
                    class="h-full bg-ui-chart-brand transition-all duration-ui-fast"
                    :class="barWidthClass(((stage.deal_count || 0) / maxFunnelCount) * 100)"
                  />
                </div>
              </div>
            </div>
          </DsCard>

          <!-- Grid: Tempo Médio por Etapa & Motivos de Perda -->
          <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <!-- Velocidade / Duração por Etapa -->
            <DsCard class="flex flex-col gap-4">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.FUNNEL.TIME_IN_STAGE.TITLE') }}
              </h3>

              <div v-if="!timeInStage.length" class="py-6">
                <DsEmptyState
                  icon="i-lucide-clock"
                  :title="$t('CRM.ANALYTICS.FUNNEL.TIME_IN_STAGE.EMPTY')"
                />
              </div>

              <div v-else class="overflow-x-auto">
                <DsTable
                  :caption="$t('CRM.ANALYTICS.FUNNEL.TIME_IN_STAGE.TITLE')"
                  :headers="timeInStageHeaders"
                  :items="timeInStage"
                  min-width-class="min-w-0"
                >
                  <template #cell-stage="{ item }">
                    <span class="font-medium text-ui-text">{{ item.stage_name }}</span>
                  </template>

                  <template #cell-avg="{ item }">
                    <span class="text-ui-caption font-semibold text-ui-text">
                      {{ formatHours(item.avg_hours) }}
                    </span>
                  </template>

                  <template #cell-detail="{ item }">
                    <span class="text-ui-caption text-ui-text-muted">
                      {{
                        $t('CRM.ANALYTICS.FUNNEL.TIME_IN_STAGE.SAMPLES', {
                          count: item.deal_count || 0,
                          min: formatHours(item.min_hours),
                          max: formatHours(item.max_hours),
                        })
                      }}
                    </span>
                  </template>
                </DsTable>
              </div>
            </DsCard>

            <!-- Principais Motivos de Perda -->
            <DsCard class="flex flex-col gap-4">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.FUNNEL.LOSS_REASONS.TITLE') }}
              </h3>

              <div v-if="!lossReasons.length" class="py-6">
                <DsEmptyState
                  icon="i-lucide-thumbs-down"
                  :title="$t('CRM.ANALYTICS.FUNNEL.LOSS_REASONS.EMPTY')"
                />
              </div>

              <div v-else class="overflow-x-auto">
                <DsTable
                  :caption="$t('CRM.ANALYTICS.FUNNEL.LOSS_REASONS.TITLE')"
                  :headers="lossReasonsHeaders"
                  :items="lossReasons"
                  min-width-class="min-w-0"
                >
                  <template #cell-rank="{ index }">
                    <span class="text-ui-caption font-semibold text-ui-text-muted">
                      #{{ index + 1 }}
                    </span>
                  </template>

                  <template #cell-reason="{ item }">
                    <span class="font-medium text-ui-text">
                      {{ item.reason || item.loss_reason || '-' }}
                    </span>
                  </template>

                  <template #cell-count="{ item }">
                    <span class="font-semibold text-ui-danger">
                      {{ item.count || item.deal_count || 0 }}
                    </span>
                  </template>
                </DsTable>
              </div>
            </DsCard>
          </div>

          <!-- Distribuição por Área & Leads Estagnados -->
          <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <!-- Distribuição por Área Jurídica -->
            <DsCard class="flex flex-col gap-4">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.FUNNEL.AREA_DISTRIBUTION.TITLE') }}
              </h3>

              <div v-if="!areaDistribution.length" class="py-6">
                <DsEmptyState
                  icon="i-lucide-scale"
                  :title="$t('CRM.ANALYTICS.FUNNEL.AREA_DISTRIBUTION.EMPTY')"
                />
              </div>

              <div v-else class="flex flex-col gap-2">
                <div
                  v-for="area in areaDistribution"
                  :key="area.area || area.name"
                  class="flex items-center justify-between rounded-ui-control border border-ui-border-subtle bg-ui-surface p-2.5 text-ui-body-sm"
                >
                  <span class="font-medium text-ui-text">{{ area.area || area.name }}</span>
                  <div class="flex items-center gap-2">
                    <DsBadge :label="String(area.count || 0)" variant="brand" />
                    <span class="text-ui-caption text-ui-text-muted">{{ formatCurrency(area.total_value) }}</span>
                  </div>
                </div>
              </div>
            </DsCard>

            <!-- Negócios Estagnados (7+ dias) -->
            <DsCard class="flex flex-col gap-4">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.FUNNEL.STALE_DEALS.TITLE') }}
              </h3>

              <div v-if="!staleDeals.length" class="py-6">
                <DsEmptyState
                  icon="i-lucide-clock-alert"
                  :title="$t('CRM.ANALYTICS.FUNNEL.STALE_DEALS.EMPTY')"
                />
              </div>

              <div v-else class="flex flex-col gap-2">
                <div
                  v-for="deal in staleDeals"
                  :key="deal.id"
                  class="flex cursor-pointer items-center justify-between rounded-ui-control border border-ui-border-subtle bg-ui-surface p-2.5 text-ui-body-sm transition-colors hover:border-ui-border-strong hover:bg-ui-hover"
                  @click="openDeal(deal)"
                >
                  <div class="flex flex-col">
                    <span class="font-medium text-ui-text">{{ deal.title }}</span>
                    <span class="text-ui-caption text-ui-text-muted">
                      {{ deal.stage_name || '-' }} • {{ deal.contact_name || '-' }}
                    </span>
                  </div>
                  <DsBadge
                    :label="deal.days_stale ? $t('CRM.ANALYTICS.FUNNEL.STALE_DEALS.DAYS', { days: deal.days_stale }) : $t('CRM.ANALYTICS.FUNNEL.STALE_DEALS.NEVER')"
                    variant="warning"
                  />
                </div>
              </div>
            </DsCard>
          </div>

          <!-- Assistente de IA Analítico -->
          <DsCard class="flex flex-col gap-3">
            <div class="flex flex-col">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.FUNNEL.ANALYST.TITLE') }}
              </h3>
              <span class="text-ui-caption text-ui-text-muted">
                {{ $t('CRM.ANALYTICS.FUNNEL.ANALYST.SUBTITLE') }}
              </span>
            </div>

            <div class="flex gap-2">
              <DsInput
                v-model="analystQuestion"
                :label="$t('CRM.ANALYTICS.FUNNEL.ANALYST.QUESTION_LABEL')"
                hide-label
                :placeholder="$t('CRM.ANALYTICS.FUNNEL.ANALYST.PLACEHOLDER')"
                class="flex-1"
                @keydown.enter="askAnalyst"
              />
              <DsButton
                variant="primary"
                :loading="analystLoading"
                :label="analystLoading ? $t('CRM.ANALYTICS.FUNNEL.ANALYST.ASKING') : $t('CRM.ANALYTICS.FUNNEL.ANALYST.ASK')"
                icon="i-lucide-sparkles"
                @click="askAnalyst"
              />
            </div>

            <div
              v-if="analystResult"
              class="mt-2 rounded-ui-control border border-ui-brand/30 bg-ui-brand-soft p-4 text-ui-body-sm text-ui-text"
            >
              <div class="font-medium leading-relaxed">{{ analystResult.answer }}</div>
            </div>
          </DsCard>
        </section>

        <!-- ========================================== -->
        <!-- ABA 3: ATENDIMENTO & SLA                   -->
        <!-- ========================================== -->
        <section
          v-if="activeTab === 'support'"
          aria-labelledby="tab-support-heading"
          class="flex flex-col gap-6"
        >
          <h2 id="tab-support-heading" class="sr-only">
            {{ $t('CRM.ANALYTICS.SUPPORT.TITLE') }}
          </h2>

          <!-- Grid de KPIs de Suporte & SLA -->
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
            <DsCard
              v-for="kpi in supportKpis"
              :key="kpi.key"
              padding="sm"
              class="flex flex-col gap-1"
            >
              <div class="flex items-center justify-between text-ui-text-muted">
                <span class="truncate text-ui-caption font-medium">{{ kpi.label }}</span>
                <Icon :icon="kpi.icon" class="h-4 w-4 shrink-0 opacity-70" />
              </div>
              <span
                class="truncate text-ui-title font-semibold"
                :class="kpi.valueClass || 'text-ui-text'"
              >
                {{ kpi.value }}
              </span>
            </DsCard>
          </div>

          <!-- Distribuição de Avaliações CSAT (1 a 5 estrelas) -->
          <DsCard class="flex flex-col gap-4">
            <div class="flex flex-col">
              <h3 class="text-ui-heading font-semibold text-ui-text">
                {{ $t('CRM.ANALYTICS.SUPPORT.CSAT_DISTRIBUTION.TITLE') }}
              </h3>
              <span class="text-ui-caption text-ui-text-muted">
                {{ $t('CRM.ANALYTICS.SUPPORT.SUBTITLE') }}
              </span>
            </div>

            <div v-if="!csatTotalResponses" class="py-6">
              <DsEmptyState
                icon="i-lucide-star-off"
                :title="$t('CRM.ANALYTICS.SUPPORT.CSAT_DISTRIBUTION.EMPTY')"
              />
            </div>

            <div v-else class="flex flex-col gap-3">
              <div
                v-for="row in csatRatingRows"
                :key="row.stars"
                class="flex flex-col gap-1"
              >
                <div class="flex items-center justify-between text-ui-caption">
                  <div class="flex items-center gap-1 font-medium text-ui-text">
                    <span>{{ $t('CRM.ANALYTICS.SUPPORT.CSAT_DISTRIBUTION.STARS', { rating: row.stars }) }}</span>
                    <Icon icon="i-lucide-star" class="h-3.5 w-3.5 text-ui-warning" />
                  </div>
                  <span class="text-ui-text-muted">
                    {{
                      $t('CRM.ANALYTICS.SUPPORT.CSAT_DISTRIBUTION.RESPONSES', {
                        count: row.count,
                        pct: row.pct,
                      })
                    }}
                  </span>
                </div>

                <div class="h-2.5 w-full overflow-hidden rounded-ui-control bg-ui-sunken">
                  <div
                    class="h-full transition-all duration-ui-fast"
                    :class="[
                      barWidthClass(row.pct),
                      row.stars >= 4 ? 'bg-ui-chart-success' : row.stars === 3 ? 'bg-ui-chart-warning' : 'bg-ui-chart-danger',
                    ]"
                  />
                </div>
              </div>
            </div>
          </DsCard>

          <!-- Tabela de Desempenho por Canal / Inbox -->
          <DsCard class="flex flex-col gap-4">
            <h3 class="text-ui-heading font-semibold text-ui-text">
              {{ $t('CRM.ANALYTICS.SUPPORT.INBOXES.TITLE') }}
            </h3>

            <div v-if="!inboxReports.length" class="py-6">
              <DsEmptyState
                icon="i-lucide-inbox"
                :title="$t('CRM.ANALYTICS.SUPPORT.INBOXES.EMPTY')"
              />
            </div>

            <div v-else class="overflow-x-auto">
              <DsTable
                :caption="$t('CRM.ANALYTICS.SUPPORT.INBOXES.TITLE')"
                :headers="inboxesHeaders"
                :items="inboxReports"
                min-width-class="min-w-0"
              >
                <template #cell-name="{ item }">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-ui-text">{{ item.name }}</span>
                    <DsBadge
                      v-if="item.channel_type"
                      :label="item.channel_type.replace('Channel::', '')"
                      variant="neutral"
                    />
                  </div>
                </template>

                <template #cell-conversations="{ item }">
                  <span class="font-semibold text-ui-text">
                    {{ item.conversations_count || 0 }}
                  </span>
                </template>

                <template #cell-frt="{ item }">
                  <span class="text-ui-caption text-ui-text-muted">
                    {{ formatDuration(item.avg_first_response_time) }}
                  </span>
                </template>

                <template #cell-res="{ item }">
                  <span class="text-ui-caption text-ui-text-muted">
                    {{ formatDuration(item.avg_resolution_time) }}
                  </span>
                </template>
              </DsTable>
            </div>
          </DsCard>
        </section>
      </template>
    </div>
  </section>
</template>

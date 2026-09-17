<script setup>
import { computed, onMounted, ref } from 'vue';
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
  DsTable,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const loading = ref(true);
const periodDays = ref(parseInt(route.query.period, 10) || 30);
const pipelines = ref([]);
const selectedPipelineId = ref(route.query.pipeline || '');

const overview = ref({});
const funnel = ref([]);
const winLoss = ref([]);
const lossReasons = ref([]);
const scoreByStage = ref([]);
const areaDistribution = ref([]);
const topDeals = ref([]);
const staleDeals = ref([]);
const timeInStage = ref([]);
const analystQuestion = ref('');
const analystLoading = ref(false);
const analystResult = ref(null);

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

const URGENCY_DOT_CLASSES = {
  critica: 'bg-ui-chart-danger',
  alta: 'bg-ui-chart-warning-strong',
  media: 'bg-ui-chart-warning',
  normal: 'bg-ui-chart-neutral',
  baixa: 'bg-ui-chart-info',
};

const periodOptions = computed(() => [
  { value: 7, label: t('CRM.METRICS.PERIODS.DAYS_7') },
  { value: 30, label: t('CRM.METRICS.PERIODS.DAYS_30') },
  { value: 90, label: t('CRM.METRICS.PERIODS.DAYS_90') },
  { value: 180, label: t('CRM.METRICS.PERIODS.MONTHS_6') },
  { value: 365, label: t('CRM.METRICS.PERIODS.YEAR_1') },
]);

// Funil default da conta quando nenhum esta selecionado — o backend nunca
// mistura etapas de funis diferentes no mesmo grafico.
const pipelineOptions = computed(() => [
  { value: '', label: t('CRM.METRICS.DEFAULT_PIPELINE') },
  ...pipelines.value.map(pipeline => ({
    value: String(pipeline.id),
    label: pipeline.name,
  })),
]);

const analystExamples = computed(() => [
  t('CRM.METRICS.ANALYST.EXAMPLES.INSS'),
  t('CRM.METRICS.ANALYST.EXAMPLES.UNASSIGNED_HOT'),
  t('CRM.METRICS.ANALYST.EXAMPLES.TOP_LIST'),
  t('CRM.METRICS.ANALYST.EXAMPLES.WAITING_DOCS'),
  t('CRM.METRICS.ANALYST.EXAMPLES.BEST_OWNER'),
  t('CRM.METRICS.ANALYST.EXAMPLES.CAMPAIGNS'),
]);

const maxFunnelCount = computed(() =>
  Math.max(1, ...funnel.value.map(f => f.deal_count))
);
const maxWinLossCount = computed(() =>
  Math.max(1, ...winLoss.value.map(d => d.total))
);

const kpis = computed(() => {
  const o = overview.value;
  return [
    { key: 'total', label: t('CRM.METRICS.KPI.TOTAL'), value: o.total_deals || 0 },
    {
      key: 'open',
      label: t('CRM.METRICS.KPI.OPEN'),
      value: o.open_deals || 0,
      valueClass: 'text-ui-brand',
    },
    {
      key: 'won',
      label: t('CRM.METRICS.KPI.WON'),
      value: o.won_deals || 0,
      valueClass: 'text-ui-success',
    },
    {
      key: 'lost',
      label: t('CRM.METRICS.KPI.LOST'),
      value: o.lost_deals || 0,
      valueClass: 'text-ui-danger',
    },
    {
      key: 'win_rate',
      label: t('CRM.METRICS.KPI.WIN_RATE'),
      value: `${o.win_rate || 0}%`,
    },
    {
      key: 'avg_score',
      label: t('CRM.METRICS.KPI.AVG_SCORE'),
      value: o.avg_score || 0,
      unit: t('CRM.METRICS.KPI.SCORE_UNIT'),
    },
    {
      key: 'pipeline',
      label: t('CRM.METRICS.KPI.PIPELINE'),
      value: formatCurrency(o.total_value),
    },
    {
      key: 'won_value',
      label: t('CRM.METRICS.KPI.WON_VALUE'),
      value: formatCurrency(o.won_value),
      valueClass: 'text-ui-success',
    },
    {
      key: 'avg_time',
      label: t('CRM.METRICS.KPI.AVG_TIME'),
      value: o.avg_time_to_close || 0,
      unit: t('CRM.METRICS.KPI.DAY_UNIT'),
    },
  ];
});

const lossReasonHeaders = computed(() => [
  { key: 'rank', label: t('CRM.METRICS.LOSS_REASONS.RANK'), class: 'w-10' },
  { key: 'reason', label: t('CRM.METRICS.LOSS_REASONS.REASON') },
  {
    key: 'count',
    label: t('CRM.METRICS.LOSS_REASONS.COUNT'),
    class: 'w-16 text-right',
  },
]);

const timeInStageHeaders = computed(() => [
  { key: 'stage', label: t('CRM.METRICS.TIME_IN_STAGE.STAGE') },
  { key: 'avg', label: t('CRM.METRICS.TIME_IN_STAGE.AVG'), class: 'w-20' },
  { key: 'detail', label: t('CRM.METRICS.TIME_IN_STAGE.DETAIL') },
]);

const topDealsHeaders = computed(() => [
  { key: 'title', label: t('CRM.METRICS.TOP_DEALS.DEAL') },
  { key: 'contact', label: t('CRM.METRICS.TOP_DEALS.CONTACT') },
  { key: 'stage', label: t('CRM.METRICS.TOP_DEALS.STAGE') },
  { key: 'score', label: t('CRM.METRICS.TOP_DEALS.SCORE'), class: 'w-16' },
  { key: 'urgency', label: t('CRM.METRICS.TOP_DEALS.URGENCY'), class: 'w-24' },
]);

const staleDealsHeaders = computed(() => [
  { key: 'title', label: t('CRM.METRICS.TOP_DEALS.DEAL') },
  { key: 'stage', label: t('CRM.METRICS.TOP_DEALS.STAGE') },
  { key: 'contact', label: t('CRM.METRICS.TOP_DEALS.CONTACT') },
  { key: 'days', label: t('CRM.METRICS.STALE_DEALS.STALE_FOR'), class: 'w-20' },
]);

function changePeriod() {
  const days = Number(periodDays.value) || 30;
  periodDays.value = days;
  router.replace({ query: { ...route.query, period: days } });
  fetchAll();
}

function changePipeline() {
  const query = { ...route.query };
  if (selectedPipelineId.value) {
    query.pipeline = selectedPipelineId.value;
  } else {
    delete query.pipeline;
  }
  router.replace({ query });
  fetchAll();
}

async function fetchAll() {
  loading.value = true;
  try {
    const params = {
      period_days: periodDays.value,
      months: Math.max(6, Math.ceil(periodDays.value / 30)),
    };
    if (selectedPipelineId.value) {
      params.pipeline_id = selectedPipelineId.value;
    }
    const [ovRes, flRes, wlRes, lrRes, ssRes, adRes, tdRes, stRes, tsRes] =
      await Promise.all([
        CrmAPI.getMetricsOverview(params),
        CrmAPI.getMetricsStageFunnel(params),
        CrmAPI.getMetricsWinLossTrend(params),
        CrmAPI.getMetricsTopLossReasons(params),
        CrmAPI.getMetricsScoreByStage(params),
        CrmAPI.getMetricsAreaDistribution(params),
        CrmAPI.getMetricsTopDeals(params),
        CrmAPI.getMetricsStaleDeals(params),
        CrmAPI.getMetricsTimeInStage(params),
      ]);
    overview.value = ovRes.data;
    funnel.value = flRes.data;
    winLoss.value = wlRes.data;
    lossReasons.value = lrRes.data;
    scoreByStage.value = ssRes.data;
    areaDistribution.value = adRes.data;
    topDeals.value = tdRes.data;
    staleDeals.value = stRes.data;
    timeInStage.value = tsRes.data;
  } catch {
    // Mantem a pagina aberta mesmo quando algum endpoint de metrica falha.
  } finally {
    loading.value = false;
  }
}

function formatCurrency(cents) {
  if (!cents) return 'R$ 0';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100);
}

function formatHours(h) {
  if (!h) return '-';
  if (h < 24) return `${h}h`;
  return `${(h / 24).toFixed(1)}d`;
}

function funnelBarPct(count) {
  return Math.round((count / maxFunnelCount.value) * 100);
}

function winLossBarPct(count) {
  return Math.round((count / maxWinLossCount.value) * 100);
}

function barWidthClass(pct) {
  const step = Math.min(20, Math.max(0, Math.round(pct / 5)));
  return BAR_WIDTH_CLASSES[step];
}

function scoreBarClass(score) {
  if (score >= 75) return 'bg-ui-chart-danger';
  if (score >= 50) return 'bg-ui-chart-warning-strong';
  if (score >= 25) return 'bg-ui-chart-warning';
  return 'bg-ui-chart-neutral';
}

function urgencyDotClass(level) {
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

function goBack() {
  router.push({ name: 'crm', params: { accountId: route.params.accountId } });
}

const dealUrl = deal =>
  `/app/accounts/${route.params.accountId}/crm/deals/${deal.id}`;

function openDeal(deal) {
  router.push(dealUrl(deal));
}

async function askAnalyst(question = analystQuestion.value) {
  const value = String(question || '').trim();
  if (!value) return;

  analystQuestion.value = value;
  analystLoading.value = true;
  analystResult.value = null;
  try {
    const response = await CrmAPI.askAnalyst({
      question: value,
      period_days: periodDays.value,
    });
    analystResult.value = response.data;
  } catch {
    analystResult.value = {
      answer: t('CRM.METRICS.ANALYST.ERROR'),
      metrics: {},
    };
  } finally {
    analystLoading.value = false;
  }
}

async function fetchPipelines() {
  try {
    const response = await CrmAPI.getPipelines();
    pipelines.value = response.data || [];
  } catch {
    pipelines.value = [];
  }
}

onMounted(() => {
  fetchPipelines();
  fetchAll();
});
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="$t('CRM.METRICS.TITLE')"
      :breadcrumbs="[
        { label: $t('CRM.METRICS.BREADCRUMB') },
        { label: $t('CRM.METRICS.TITLE') },
      ]"
    >
      <template #actions>
        <DsButton
          icon="i-lucide-arrow-left"
          variant="ghost"
          :aria-label="$t('CRM.METRICS.BACK')"
          @click="goBack"
        />
        <DsSelect
          v-if="pipelines.length > 1"
          v-model="selectedPipelineId"
          :label="$t('CRM.METRICS.PIPELINE_LABEL')"
          hide-label
          :options="pipelineOptions"
          class="min-w-44"
          @change="changePipeline"
        />
        <DsSelect
          v-model="periodDays"
          :label="$t('CRM.METRICS.PERIOD_LABEL')"
          hide-label
          :options="periodOptions"
          class="min-w-36"
          @change="changePeriod"
        />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <DsCard as="section" aria-labelledby="crm-analyst-title">
        <h2
          id="crm-analyst-title"
          class="m-0 font-manrope text-ui-heading font-semibold text-ui-text"
        >
          {{ $t('CRM.METRICS.ANALYST.TITLE') }}
        </h2>
        <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
          {{ $t('CRM.METRICS.ANALYST.SUBTITLE') }}
        </p>
        <form
          class="mt-4 flex flex-col gap-2 sm:flex-row"
          @submit.prevent="askAnalyst()"
        >
          <DsInput
            v-model="analystQuestion"
            type="search"
            :label="$t('CRM.METRICS.ANALYST.QUESTION_LABEL')"
            hide-label
            :placeholder="$t('CRM.METRICS.ANALYST.PLACEHOLDER')"
            class="min-w-0 flex-1"
          >
            <template #prefix>
              <Icon icon="i-lucide-search" class="size-4" />
            </template>
          </DsInput>
          <DsButton
            type="submit"
            variant="primary"
            :label="
              analystLoading
                ? $t('CRM.METRICS.ANALYST.ASKING')
                : $t('CRM.METRICS.ANALYST.ASK')
            "
            :loading="analystLoading"
            :disabled="!analystQuestion.trim()"
          />
        </form>
        <div class="mt-3 flex flex-wrap gap-2">
          <DsButton
            v-for="example in analystExamples"
            :key="example"
            size="sm"
            variant="secondary"
            :label="example"
            @click="askAnalyst(example)"
          />
        </div>
        <div
          v-if="analystResult"
          aria-live="polite"
          class="mt-4 rounded-ui-control bg-ui-sunken p-3"
        >
          <p class="m-0 text-ui-body text-ui-text">
            {{ analystResult.answer }}
          </p>
          <pre
            v-if="analystResult.metrics"
            class="m-0 mt-3 max-h-56 overflow-auto rounded-ui-control bg-ui-surface p-3 text-ui-caption text-ui-text-muted"
          >{{ JSON.stringify(analystResult.metrics, null, 2) }}</pre>
        </div>
      </DsCard>

      <div
        v-if="loading"
        role="status"
        :aria-label="$t('CRM.METRICS.LOADING')"
        class="flex flex-col gap-4"
      >
        <span class="sr-only">{{ $t('CRM.METRICS.LOADING') }}</span>
        <DsSkeleton shape="block" class="h-28" />
        <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
          <DsSkeleton
            v-for="card in 4"
            :key="card"
            shape="block"
            class="h-64"
          />
        </div>
      </div>

      <DsEmptyState
        v-else-if="!overview.total_deals"
        :title="$t('CRM.METRICS.EMPTY_TITLE')"
      >
        <template #action>
          <p class="m-0 max-w-md text-ui-body-sm text-ui-text-muted">
            {{ $t('CRM.METRICS.EMPTY_DESCRIPTION') }}
          </p>
        </template>
      </DsEmptyState>

      <div v-else class="flex flex-col gap-4">
        <DsCard
          as="section"
          padding="none"
          :aria-label="$t('CRM.METRICS.KPI.TITLE')"
        >
          <dl
            class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 2xl:grid-cols-9"
          >
            <div
              v-for="kpi in kpis"
              :key="kpi.key"
              class="flex min-w-0 flex-col gap-1 p-3 sm:p-4"
            >
              <dt
                class="truncate text-ui-caption font-medium uppercase tracking-wide text-ui-text-muted"
              >
                {{ kpi.label }}
              </dt>
              <dd
                class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
                :class="kpi.valueClass"
                :title="String(kpi.value) + (kpi.unit || '')"
              >
                {{ kpi.value
                }}<span
                  v-if="kpi.unit"
                  class="text-ui-caption font-normal text-ui-text-muted"
                  >{{ kpi.unit }}</span
                >
              </dd>
            </div>
          </dl>
        </DsCard>

        <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
          <DsCard as="section" aria-labelledby="funnel-title">
            <h3
              id="funnel-title"
              class="m-0 mb-4 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.FUNNEL.TITLE') }}
            </h3>
            <DsEmptyState
              v-if="!funnel.length"
              :title="$t('CRM.METRICS.FUNNEL.EMPTY')"
            />
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="stage in funnel"
                :key="stage.stage_id"
                class="flex items-center gap-3"
              >
                <span
                  class="w-24 shrink-0 truncate text-right text-ui-caption text-ui-text-muted sm:w-32"
                >
                  {{ stage.stage_name }}
                </span>
                <div
                  class="h-5 min-w-0 flex-1 overflow-hidden rounded-ui-control bg-ui-sunken"
                >
                  <div
                    aria-hidden="true"
                    class="h-full rounded-ui-control bg-ui-chart-brand transition-[width] duration-500"
                    :class="barWidthClass(funnelBarPct(stage.deal_count))"
                  />
                </div>
                <span
                  class="w-10 shrink-0 text-right text-ui-caption font-semibold text-ui-text"
                >
                  {{ stage.deal_count }}
                </span>
              </div>
            </div>
          </DsCard>

          <DsCard as="section" aria-labelledby="winloss-title">
            <h3
              id="winloss-title"
              class="m-0 mb-4 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.WIN_LOSS.TITLE') }}
            </h3>
            <DsEmptyState
              v-if="!winLoss.length || winLoss.every(m => !m.won && !m.lost)"
              :title="$t('CRM.METRICS.WIN_LOSS.EMPTY')"
            />
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="m in winLoss"
                :key="m.month"
                class="flex items-center gap-3"
              >
                <span
                  class="w-16 shrink-0 truncate text-right text-ui-caption text-ui-text-muted"
                >
                  {{ m.month_label }}
                </span>
                <div class="flex h-5 min-w-0 flex-1 gap-0.5">
                  <div
                    aria-hidden="true"
                    class="h-full rounded-ui-control bg-ui-chart-success transition-[width] duration-500"
                    :class="barWidthClass(winLossBarPct(m.won))"
                  />
                  <div
                    aria-hidden="true"
                    class="h-full rounded-ui-control bg-ui-chart-danger transition-[width] duration-500"
                    :class="barWidthClass(winLossBarPct(m.lost))"
                  />
                </div>
                <span
                  class="w-10 shrink-0 text-right text-ui-caption font-semibold text-ui-text"
                  >{{ m.win_rate }}%</span
                >
                <span class="sr-only">
                  {{
                    $t('CRM.METRICS.WIN_LOSS.SUMMARY', {
                      won: m.won,
                      lost: m.lost,
                    })
                  }}
                </span>
              </div>
            </div>
          </DsCard>
        </div>

        <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
          <section aria-labelledby="loss-reasons-title">
            <h3
              id="loss-reasons-title"
              class="m-0 mb-2 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.LOSS_REASONS.TITLE') }}
            </h3>
            <DsTable
              :caption="$t('CRM.METRICS.LOSS_REASONS.TITLE')"
              :headers="lossReasonHeaders"
              :items="lossReasons"
              :empty-title="$t('CRM.METRICS.LOSS_REASONS.EMPTY')"
              min-width-class="min-w-[20rem]"
            >
              <template #row="{ item: reason, index }">
                <tr class="bg-ui-surface">
                  <td class="px-3 py-2 text-ui-caption text-ui-text-subtle">
                    #{{ index + 1 }}
                  </td>
                  <td class="px-3 py-2 text-ui-body-sm text-ui-text">
                    {{ reason.reason }}
                  </td>
                  <td
                    class="px-3 py-2 text-right text-ui-body-sm font-semibold text-ui-text"
                  >
                    {{ reason.count }}
                  </td>
                </tr>
              </template>
            </DsTable>
          </section>

          <DsCard as="section" aria-labelledby="area-title">
            <h3
              id="area-title"
              class="m-0 mb-4 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.AREA.TITLE') }}
            </h3>
            <DsEmptyState
              v-if="!areaDistribution.length"
              :title="$t('CRM.METRICS.AREA.EMPTY')"
            />
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="(a, i) in areaDistribution"
                :key="i"
                class="flex items-center gap-3"
              >
                <span
                  class="w-24 shrink-0 truncate text-right text-ui-caption text-ui-text-muted sm:w-32"
                >
                  {{ a.area }}
                </span>
                <div
                  class="h-5 min-w-0 flex-1 overflow-hidden rounded-ui-control bg-ui-sunken"
                >
                  <div
                    aria-hidden="true"
                    class="h-full rounded-ui-control bg-ui-chart-violet transition-[width] duration-500"
                    :class="barWidthClass(funnelBarPct(a.count))"
                  />
                </div>
                <span
                  class="w-10 shrink-0 text-right text-ui-caption font-semibold text-ui-text"
                >
                  {{ a.count }}
                </span>
              </div>
            </div>
          </DsCard>
        </div>

        <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
          <DsCard as="section" aria-labelledby="score-stage-title">
            <h3
              id="score-stage-title"
              class="m-0 mb-4 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.SCORE_BY_STAGE.TITLE') }}
            </h3>
            <DsEmptyState
              v-if="!scoreByStage.length"
              :title="$t('CRM.METRICS.SCORE_BY_STAGE.EMPTY')"
            />
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="(s, i) in scoreByStage"
                :key="i"
                class="flex items-center gap-3"
              >
                <span
                  class="w-24 shrink-0 truncate text-right text-ui-caption text-ui-text-muted sm:w-32"
                >
                  {{ s.stage_name }}
                </span>
                <div
                  class="h-5 min-w-0 flex-1 overflow-hidden rounded-ui-control bg-ui-sunken"
                >
                  <div
                    aria-hidden="true"
                    class="h-full rounded-ui-control transition-[width] duration-500"
                    :class="[
                      barWidthClass(s.avg_score),
                      scoreBarClass(s.avg_score),
                    ]"
                  />
                </div>
                <span
                  class="w-10 shrink-0 text-right text-ui-caption font-semibold text-ui-text"
                >
                  {{ s.avg_score }}
                </span>
              </div>
            </div>
          </DsCard>

          <section aria-labelledby="time-stage-title">
            <h3
              id="time-stage-title"
              class="m-0 mb-2 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.TIME_IN_STAGE.TITLE') }}
            </h3>
            <DsTable
              :caption="$t('CRM.METRICS.TIME_IN_STAGE.TITLE')"
              :headers="timeInStageHeaders"
              :items="timeInStage"
              :empty-title="$t('CRM.METRICS.TIME_IN_STAGE.EMPTY')"
              min-width-class="min-w-[24rem]"
            >
              <template #row="{ item: s }">
                <tr class="bg-ui-surface">
                  <td class="px-3 py-2 text-ui-body-sm font-medium text-ui-text">
                    {{ s.stage_name }}
                  </td>
                  <td
                    class="px-3 py-2 text-ui-body-sm font-semibold text-ui-text"
                  >
                    {{ formatHours(s.avg_hours) }}
                  </td>
                  <td class="px-3 py-2 text-ui-caption text-ui-text-muted">
                    <span v-if="s.sample_size > 0">
                      {{
                        $t('CRM.METRICS.TIME_IN_STAGE.SAMPLES', {
                          count: s.sample_size,
                          min: formatHours(s.min_hours),
                          max: formatHours(s.max_hours),
                        })
                      }}
                    </span>
                    <span v-else>
                      {{ $t('CRM.METRICS.TIME_IN_STAGE.NO_DATA') }}
                    </span>
                  </td>
                </tr>
              </template>
            </DsTable>
          </section>
        </div>

        <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
          <section aria-labelledby="top-deals-title">
            <h3
              id="top-deals-title"
              class="m-0 mb-2 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.TOP_DEALS.TITLE') }}
            </h3>
            <DsTable
              :caption="$t('CRM.METRICS.TOP_DEALS.TITLE')"
              :headers="topDealsHeaders"
              :items="topDeals"
              :empty-title="$t('CRM.METRICS.TOP_DEALS.EMPTY')"
              min-width-class="min-w-[36rem]"
            >
              <template #row="{ item: deal }">
                <tr
                  tabindex="0"
                  class="cursor-pointer bg-ui-surface transition-colors duration-ui-fast hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
                  :aria-label="
                    $t('CRM.METRICS.TOP_DEALS.OPEN', { title: deal.title })
                  "
                  @click="openDeal(deal)"
                  @keydown.enter="openDeal(deal)"
                >
                  <td class="px-3 py-2 text-ui-body-sm font-medium text-ui-text">
                    {{ deal.title }}
                  </td>
                  <td class="px-3 py-2 text-ui-body-sm text-ui-text-muted">
                    {{ deal.contact || '-' }}
                  </td>
                  <td class="px-3 py-2 text-ui-body-sm text-ui-text-muted">
                    {{ deal.stage || '-' }}
                  </td>
                  <td
                    class="px-3 py-2 text-ui-body-sm font-semibold text-ui-text"
                  >
                    {{ deal.score }}
                  </td>
                  <td class="px-3 py-2">
                    <span
                      class="inline-flex items-center gap-1.5 text-ui-caption font-medium text-ui-text"
                    >
                      <span
                        aria-hidden="true"
                        class="size-2 shrink-0 rounded-full"
                        :class="urgencyDotClass(deal.urgency)"
                      />
                      {{ urgencyLabel(deal.urgency) }}
                    </span>
                  </td>
                </tr>
              </template>
            </DsTable>
          </section>

          <section aria-labelledby="stale-deals-title">
            <h3
              id="stale-deals-title"
              class="m-0 mb-2 font-manrope text-ui-label font-semibold text-ui-text"
            >
              {{ $t('CRM.METRICS.STALE_DEALS.TITLE') }}
            </h3>
            <DsTable
              :caption="$t('CRM.METRICS.STALE_DEALS.TITLE')"
              :headers="staleDealsHeaders"
              :items="staleDeals"
              :empty-title="$t('CRM.METRICS.STALE_DEALS.EMPTY')"
              min-width-class="min-w-[28rem]"
            >
              <template #row="{ item: deal }">
                <tr
                  tabindex="0"
                  class="cursor-pointer bg-ui-surface transition-colors duration-ui-fast hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
                  :aria-label="
                    $t('CRM.METRICS.STALE_DEALS.OPEN', { title: deal.title })
                  "
                  @click="openDeal(deal)"
                  @keydown.enter="openDeal(deal)"
                >
                  <td class="px-3 py-2 text-ui-body-sm font-medium text-ui-text">
                    {{ deal.title }}
                  </td>
                  <td class="px-3 py-2 text-ui-body-sm text-ui-text-muted">
                    {{ deal.stage || '-' }}
                  </td>
                  <td class="px-3 py-2 text-ui-body-sm text-ui-text-muted">
                    {{ deal.contact || '-' }}
                  </td>
                  <td class="px-3 py-2">
                    <DsBadge
                      variant="danger"
                      :label="
                        deal.days_stale
                          ? $t('CRM.METRICS.STALE_DEALS.DAYS', {
                              days: deal.days_stale,
                            })
                          : $t('CRM.METRICS.STALE_DEALS.NEVER')
                      "
                    />
                  </td>
                </tr>
              </template>
            </DsTable>
          </section>
        </div>
      </div>
    </div>
  </section>
</template>

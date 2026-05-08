<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CrmAPI from 'dashboard/api/crm';
const route = useRoute();
const router = useRouter();

const loading = ref(true);
const periodDays = ref(parseInt(route.query.period, 10) || 30);

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

const analystExamples = [
  'Quantos leads INSS entraram essa semana?',
  'Quais leads quentes estão sem responsável?',
  'Qual lista importada tem mais contatos?',
  'Quais contatos estão aguardando documento há mais de 3 dias?',
  'Qual responsável converte mais?',
  'Como foram as campanhas recentes?',
];

const periodOptions = [
  { value: 7, label: '7 dias' },
  { value: 30, label: '30 dias' },
  { value: 90, label: '90 dias' },
  { value: 180, label: '6 meses' },
  { value: 365, label: '1 ano' },
];

const maxFunnelCount = computed(() =>
  Math.max(1, ...funnel.value.map(f => f.deal_count))
);
const maxWinLossCount = computed(() =>
  Math.max(1, ...winLoss.value.map(d => d.total))
);

function setPeriod(days) {
  periodDays.value = days;
  router.replace({ query: { ...route.query, period: days } });
  fetchAll();
}

async function fetchAll() {
  loading.value = true;
  try {
    const params = {
      period_days: periodDays.value,
      months: Math.max(6, Math.ceil(periodDays.value / 30)),
    };
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

function urgencyColor(level) {
  const map = {
    critica: '#dc2626',
    alta: '#ea580c',
    media: '#f59e0b',
    normal: '#6b7280',
    baixa: '#3b82f6',
  };
  return map[level] || '#6b7280';
}

function goBack() {
  router.push({ name: 'crm', params: { accountId: route.params.accountId } });
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
      answer: 'Não foi possível consultar o analista CRM agora.',
      metrics: {},
    };
  } finally {
    analystLoading.value = false;
  }
}

onMounted(fetchAll);
</script>

<template>
  <div class="crm-metrics-page min-h-full bg-n-background">
    <!-- Header -->
    <header class="metrics-header">
      <div class="flex items-center gap-3">
        <button
          type="button"
          class="h-9 w-9 inline-flex items-center justify-center rounded-lg hover:bg-n-slate-3"
          @click="goBack"
        >
          <span
            class="i-lucide-arrow-left"
            style="width: 1.25rem; height: 1.25rem"
          />
        </button>
        <h1 class="text-xl font-semibold text-n-slate-12">Métricas do CRM</h1>
      </div>
      <div class="flex items-center gap-2">
        <button
          v-for="opt in periodOptions"
          :key="opt.value"
          type="button"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :class="
            periodDays === opt.value
              ? 'bg-n-brand text-white'
              : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4'
          "
          @click="setPeriod(opt.value)"
        >
          {{ opt.label }}
        </button>
      </div>
    </header>

    <section class="analyst-card">
      <div class="analyst-card__header">
        <div>
          <h2 class="analyst-card__title">Analista CRM</h2>
          <p class="analyst-card__subtitle">
            Consulte contatos, listas, campanhas e funil usando dados do Core.
          </p>
        </div>
      </div>
      <form class="analyst-card__form" @submit.prevent="askAnalyst()">
        <input
          v-model="analystQuestion"
          type="search"
          class="analyst-card__input"
          placeholder="Ex.: Quais leads quentes estão sem responsável?"
        />
        <button
          type="submit"
          class="analyst-card__button"
          :disabled="analystLoading || !analystQuestion.trim()"
        >
          {{ analystLoading ? 'Consultando...' : 'Perguntar' }}
        </button>
      </form>
      <div class="analyst-card__examples">
        <button
          v-for="example in analystExamples"
          :key="example"
          type="button"
          class="analyst-card__example"
          @click="askAnalyst(example)"
        >
          {{ example }}
        </button>
      </div>
      <div v-if="analystResult" class="analyst-card__answer">
        <p>{{ analystResult.answer }}</p>
        <pre v-if="analystResult.metrics">{{
          JSON.stringify(analystResult.metrics, null, 2)
        }}</pre>
      </div>
    </section>

    <!-- Loading -->
    <div v-if="loading" class="py-20 text-center">
      <span
        class="i-lucide-loader-2 animate-spin"
        style="width: 2rem; height: 2rem"
      />
      <p class="mt-3 text-sm text-n-slate-10">Carregando métricas...</p>
    </div>

    <!-- Empty state geral -->
    <div v-else-if="!overview.total_deals" class="empty-state-global">
      <span class="i-lucide-bar-chart-2 empty-state-icon" />
      <h3 class="empty-state-title">Nenhum dado ainda</h3>
      <p class="empty-state-desc">
        As métricas aparecerão aqui conforme você criar e movimentar deals no
        pipeline.
      </p>
    </div>

    <!-- Content -->
    <div v-else class="metrics-grid">
      <!-- KPIs compactos -->
      <div class="kpi-strip">
        <div class="kpi-item">
          <span class="kpi-item-label">Total</span>
          <span class="kpi-item-value">{{ overview.total_deals || 0 }}</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Abertos</span>
          <span class="kpi-item-value text-n-brand">{{
            overview.open_deals || 0
          }}</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Ganhos</span>
          <span class="kpi-item-value" style="color: #16a34a">{{
            overview.won_deals || 0
          }}</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Perdidos</span>
          <span class="kpi-item-value" style="color: #ef4444">{{
            overview.lost_deals || 0
          }}</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Taxa de ganho</span>
          <span class="kpi-item-value">{{ overview.win_rate || 0 }}%</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Score médio</span>
          <span class="kpi-item-value"
            >{{ overview.avg_score || 0
            }}<span class="kpi-item-unit">/100</span></span
          >
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Pipeline</span>
          <span class="kpi-item-value">{{
            formatCurrency(overview.total_value)
          }}</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Valor ganho</span>
          <span class="kpi-item-value" style="color: #16a34a">{{
            formatCurrency(overview.won_value)
          }}</span>
        </div>
        <div class="kpi-divider" />
        <div class="kpi-item">
          <span class="kpi-item-label">Tempo médio</span>
          <span class="kpi-item-value"
            >{{ overview.avg_time_to_close || 0
            }}<span class="kpi-item-unit">d</span></span
          >
        </div>
      </div>

      <!-- Funil de conversão + Win/Loss -->
      <div class="charts-row">
        <!-- Funil -->
        <div class="chart-card">
          <h3 class="chart-title">Funil de Conversão</h3>
          <div v-if="funnel.length === 0" class="empty-chart">
            <span
              class="i-lucide-filter"
              style="
                display: block;
                margin: 0 auto 0.5rem;
                width: 1.5rem;
                height: 1.5rem;
                opacity: 0.3;
              "
            />
            Crie etapas no pipeline para ver o funil
          </div>
          <div v-else class="funnel-chart">
            <div
              v-for="stage in funnel"
              :key="stage.stage_id"
              class="funnel-row"
            >
              <div class="funnel-label">{{ stage.stage_name }}</div>
              <div class="funnel-bar-track">
                <div
                  class="funnel-bar"
                  :style="{ width: funnelBarPct(stage.deal_count) + '%' }"
                />
              </div>
              <div class="funnel-count">{{ stage.deal_count }}</div>
            </div>
          </div>
        </div>

        <!-- Win/Loss Trend -->
        <div class="chart-card">
          <h3 class="chart-title">Ganhos vs Perdidos (mensal)</h3>
          <div
            v-if="winLoss.length === 0 || winLoss.every(m => !m.won && !m.lost)"
            class="empty-chart"
          >
            <span
              class="i-lucide-trending-up"
              style="
                display: block;
                margin: 0 auto 0.5rem;
                width: 1.5rem;
                height: 1.5rem;
                opacity: 0.3;
              "
            />
            Nenhum deal ganho ou perdido no período
          </div>
          <div v-else class="winloss-chart">
            <div v-for="m in winLoss" :key="m.month" class="winloss-row">
              <div class="winloss-label">{{ m.month_label }}</div>
              <div class="winloss-bars">
                <div
                  class="winloss-bar won"
                  :style="{ width: winLossBarPct(m.won) + '%' }"
                  :title="`Ganhos: ${m.won}`"
                />
                <div
                  class="winloss-bar lost"
                  :style="{ width: winLossBarPct(m.lost) + '%' }"
                  :title="`Perdidos: ${m.lost}`"
                />
              </div>
              <div class="winloss-rate">{{ m.win_rate }}%</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Motivos de perda + Distribuição por área -->
      <div class="charts-row">
        <div class="chart-card">
          <h3 class="chart-title">Top Motivos de Perda</h3>
          <div v-if="lossReasons.length === 0" class="empty-chart">
            Nenhum motivo de perda registrado
          </div>
          <div v-else class="loss-reasons-list">
            <div v-for="(r, i) in lossReasons" :key="i" class="loss-reason-row">
              <span class="loss-reason-rank">#{{ i + 1 }}</span>
              <span class="loss-reason-name">{{ r.reason }}</span>
              <span class="loss-reason-count">{{ r.count }}</span>
            </div>
          </div>
        </div>

        <div class="chart-card">
          <h3 class="chart-title">Distribuição por Área Jurídica</h3>
          <div v-if="areaDistribution.length === 0" class="empty-chart">
            Nenhum deal com área jurídica definida
          </div>
          <div v-else class="area-list">
            <div v-for="(a, i) in areaDistribution" :key="i" class="area-row">
              <span class="area-name">{{ a.area }}</span>
              <div class="area-bar-track">
                <div
                  class="area-bar"
                  :style="{ width: funnelBarPct(a.count) + '%' }"
                />
              </div>
              <span class="area-count">{{ a.count }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Score por estágio + Tempo por estágio -->
      <div class="charts-row">
        <div class="chart-card">
          <h3 class="chart-title">Score Médio por Estágio</h3>
          <div v-if="scoreByStage.length === 0" class="empty-chart">
            Sem dados
          </div>
          <div v-else class="score-stage-list">
            <div
              v-for="(s, i) in scoreByStage"
              :key="i"
              class="score-stage-row"
            >
              <span class="score-stage-name">{{ s.stage_name }}</span>
              <div class="score-stage-bar-track">
                <div
                  class="score-stage-bar"
                  :style="{ width: s.avg_score + '%' }"
                  :class="{
                    'bg-red-500': s.avg_score >= 75,
                    'bg-orange-400': s.avg_score >= 50 && s.avg_score < 75,
                    'bg-yellow-400': s.avg_score >= 25 && s.avg_score < 50,
                    'bg-gray-300': s.avg_score < 25,
                  }"
                />
              </div>
              <span class="score-stage-value">{{ s.avg_score }}</span>
            </div>
          </div>
        </div>

        <div class="chart-card">
          <h3 class="chart-title">Tempo Médio por Estágio</h3>
          <div v-if="timeInStage.length === 0" class="empty-chart">
            Sem dados de transição
          </div>
          <div v-else class="time-stage-list">
            <div v-for="(s, i) in timeInStage" :key="i" class="time-stage-row">
              <span class="time-stage-name">{{ s.stage_name }}</span>
              <span class="time-stage-value">{{
                formatHours(s.avg_hours)
              }}</span>
              <span v-if="s.sample_size > 0" class="time-stage-detail">
                ({{ s.sample_size }} amostras, min
                {{ formatHours(s.min_hours) }}, max
                {{ formatHours(s.max_hours) }})
              </span>
              <span v-else class="time-stage-detail text-n-slate-8">
                Sem dados
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Top deals + Stale deals -->
      <div class="charts-row">
        <div class="chart-card">
          <h3 class="chart-title">Top Deals por Score</h3>
          <div v-if="topDeals.length === 0" class="empty-chart">
            Nenhum deal aberto
          </div>
          <div v-else class="top-deals-table">
            <div class="top-deals-header">
              <span>Título</span>
              <span>Contato</span>
              <span>Etapa</span>
              <span>Score</span>
              <span>Urgência</span>
            </div>
            <div
              v-for="deal in topDeals"
              :key="deal.id"
              class="top-deals-row cursor-pointer hover:bg-n-slate-2"
              @click="
                router.push({
                  name: 'crm_deal_details',
                  params: {
                    accountId: route.params.accountId,
                    dealId: deal.id,
                  },
                })
              "
            >
              <span class="font-medium">{{ deal.title }}</span>
              <span>{{ deal.contact || '-' }}</span>
              <span>{{ deal.stage || '-' }}</span>
              <span class="font-semibold">{{ deal.score }}</span>
              <span>
                <span
                  class="inline-block px-2 py-0.5 rounded text-xs font-medium text-white"
                  :style="{ backgroundColor: urgencyColor(deal.urgency) }"
                >
                  {{ deal.urgency || 'normal' }}
                </span>
              </span>
            </div>
          </div>
        </div>

        <div class="chart-card">
          <h3 class="chart-title">Deals Stale (sem atividade há 7+ dias)</h3>
          <div v-if="staleDeals.length === 0" class="empty-chart">
            Nenhum deal stale
          </div>
          <div v-else class="stale-deals-list">
            <div
              v-for="deal in staleDeals"
              :key="deal.id"
              class="stale-deal-row cursor-pointer hover:bg-n-slate-2"
              @click="
                router.push({
                  name: 'crm_deal_details',
                  params: {
                    accountId: route.params.accountId,
                    dealId: deal.id,
                  },
                })
              "
            >
              <span class="font-medium">{{ deal.title }}</span>
              <span class="text-n-slate-10">{{ deal.stage || '-' }}</span>
              <span class="text-n-slate-10">{{ deal.contact || '-' }}</span>
              <span
                class="inline-block px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-700"
              >
                {{ deal.days_stale ? deal.days_stale + 'd' : 'Nunca' }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.crm-metrics-page {
  width: 100%;
  min-width: 0;
  padding: 1rem;
  max-width: 100%;
  overflow-x: hidden;
}

.crm-metrics-page * {
  min-width: 0;
}

.metrics-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
  gap: 1rem;
}

.metrics-header > * {
  min-width: 0;
}

.analyst-card {
  background: var(--n-surface-1, #fff);
  border: 1px solid var(--n-border, #e5e7eb);
  border-radius: 0.75rem;
  margin-bottom: 1rem;
  padding: 1rem;
}

.analyst-card__header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.analyst-card__title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--n-slate-12, #111827);
}

.analyst-card__subtitle {
  margin: 0.2rem 0 0;
  font-size: 0.8125rem;
  color: var(--n-slate-9, #6b7280);
}

.analyst-card__form {
  display: flex;
  min-width: 0;
  gap: 0.5rem;
}

.analyst-card__input {
  min-width: 0;
  flex: 1;
  height: 2.5rem;
  border: 1px solid var(--n-border, #e5e7eb);
  border-radius: 0.625rem;
  background: var(--n-surface-2, #f9fafb);
  color: var(--n-slate-12, #111827);
  padding: 0 0.75rem;
  font-size: 0.875rem;
  outline: none;
}

.analyst-card__button {
  height: 2.5rem;
  border: 0;
  border-radius: 0.625rem;
  background: var(--n-brand, #3b82f6);
  color: #fff;
  font-size: 0.8125rem;
  font-weight: 700;
  padding: 0 1rem;
}

.analyst-card__button:disabled {
  opacity: 0.55;
}

.analyst-card__examples {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.75rem;
}

.analyst-card__example {
  border: 1px solid var(--n-border, #e5e7eb);
  border-radius: 999px;
  background: var(--n-surface-2, #f9fafb);
  color: var(--n-slate-11, #374151);
  font-size: 0.75rem;
  padding: 0.3rem 0.6rem;
}

.analyst-card__answer {
  margin-top: 0.75rem;
  border-radius: 0.625rem;
  background: var(--n-slate-2, #f8fafc);
  padding: 0.75rem;
}

.analyst-card__answer p {
  margin: 0;
  color: var(--n-slate-12, #111827);
  font-size: 0.875rem;
}

.analyst-card__answer pre {
  max-height: 14rem;
  overflow: auto;
  margin: 0.65rem 0 0;
  border-radius: 0.5rem;
  background: var(--n-slate-1, #fff);
  color: var(--n-slate-11, #374151);
  padding: 0.65rem;
  font-size: 0.75rem;
}

/* Empty state global */
.empty-state-global {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 4rem 1rem;
  text-align: center;
}
.empty-state-icon {
  width: 3rem;
  height: 3rem;
  opacity: 0.25;
  margin-bottom: 1rem;
}
.empty-state-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--n-slate-12, #111827);
  margin-bottom: 0.5rem;
}
.empty-state-desc {
  font-size: 0.875rem;
  color: var(--n-slate-9, #6b7280);
  max-width: 28rem;
}

/* KPI strip compacto */
.kpi-strip {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0;
  background: var(--n-surface-1, #fff);
  border: 1px solid var(--n-border, #e5e7eb);
  border-radius: 0.75rem;
  margin-bottom: 1.25rem;
  overflow: hidden;
}
.kpi-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0.75rem 1rem;
  flex: 1;
  min-width: 90px;
}
.kpi-item-label {
  font-size: 0.6875rem;
  color: var(--n-slate-9, #6b7280);
  white-space: nowrap;
  margin-bottom: 0.2rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.kpi-item-value {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--n-slate-12, #111827);
}
.kpi-item-unit {
  font-size: 0.75rem;
  font-weight: 400;
  color: var(--n-slate-9, #6b7280);
}
.kpi-divider {
  width: 1px;
  height: 2.5rem;
  background: var(--n-border, #e5e7eb);
  flex-shrink: 0;
}

.charts-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 400px), 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.chart-card {
  background: var(--n-surface-1, #fff);
  border: 1px solid var(--n-border, #e5e7eb);
  border-radius: 0.75rem;
  padding: 1.25rem;
}

.chart-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--n-slate-12, #111827);
  margin-bottom: 1rem;
}

.empty-chart {
  text-align: center;
  padding: 2rem;
  color: var(--n-slate-8, #9ca3af);
  font-size: 0.8125rem;
}

/* Funnel */
.funnel-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.funnel-label {
  width: 140px;
  font-size: 0.75rem;
  color: var(--n-slate-11, #4b5563);
  text-align: right;
  flex-shrink: 0;
}

.funnel-bar-track {
  flex: 1;
  height: 1.25rem;
  background: var(--n-slate-3, #f3f4f6);
  border-radius: 0.375rem;
  overflow: hidden;
}

.funnel-bar {
  height: 100%;
  background: var(--n-brand, #3b82f6);
  border-radius: 0.375rem;
  transition: width 0.5s ease;
  min-width: 2px;
}

.funnel-count {
  width: 40px;
  text-align: right;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--n-slate-12, #111827);
}

/* Win/Loss */
.winloss-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.winloss-label {
  width: 70px;
  font-size: 0.75rem;
  color: var(--n-slate-11, #4b5563);
  text-align: right;
  flex-shrink: 0;
}

.winloss-bars {
  flex: 1;
  display: flex;
  gap: 2px;
  height: 1.25rem;
}

.winloss-bar {
  height: 100%;
  border-radius: 0.25rem;
  transition: width 0.5s ease;
  min-width: 2px;
}

.winloss-bar.won {
  background: #10b981;
}
.winloss-bar.lost {
  background: #ef4444;
}

.winloss-rate {
  width: 40px;
  text-align: right;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--n-slate-12, #111827);
}

/* Loss reasons */
.loss-reason-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--n-slate-3, #f3f4f6);
}

.loss-reason-row:last-child {
  border-bottom: none;
}

.loss-reason-rank {
  font-size: 0.75rem;
  color: var(--n-slate-8, #9ca3af);
  width: 24px;
}

.loss-reason-name {
  flex: 1;
  font-size: 0.8125rem;
  color: var(--n-slate-12, #111827);
}

.loss-reason-count {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--n-slate-12, #111827);
}

/* Área distribution */
.area-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.area-name {
  width: 120px;
  font-size: 0.75rem;
  color: var(--n-slate-11, #4b5563);
  text-align: right;
  flex-shrink: 0;
}

.area-bar-track {
  flex: 1;
  height: 1.25rem;
  background: var(--n-slate-3, #f3f4f6);
  border-radius: 0.375rem;
  overflow: hidden;
}

.area-bar {
  height: 100%;
  background: #8b5cf6;
  border-radius: 0.375rem;
  transition: width 0.5s ease;
  min-width: 2px;
}

.area-count {
  width: 32px;
  text-align: right;
  font-size: 0.75rem;
  font-weight: 600;
}

/* Score by stage */
.score-stage-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.score-stage-name {
  width: 120px;
  font-size: 0.75rem;
  color: var(--n-slate-11, #4b5563);
  text-align: right;
  flex-shrink: 0;
}

.score-stage-bar-track {
  flex: 1;
  height: 1.25rem;
  background: var(--n-slate-3, #f3f4f6);
  border-radius: 0.375rem;
  overflow: hidden;
}

.score-stage-bar {
  height: 100%;
  border-radius: 0.375rem;
  transition: width 0.5s ease;
  min-width: 2px;
}

.score-stage-value {
  width: 32px;
  text-align: right;
  font-size: 0.75rem;
  font-weight: 600;
}

/* Time in stage */
.time-stage-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--n-slate-3, #f3f4f6);
}

.time-stage-row:last-child {
  border-bottom: none;
}

.time-stage-name {
  width: 120px;
  font-size: 0.8125rem;
  color: var(--n-slate-12, #111827);
  font-weight: 500;
  flex-shrink: 0;
}

.time-stage-value {
  font-size: 1rem;
  font-weight: 700;
  color: var(--n-slate-12, #111827);
  width: 60px;
}

.time-stage-detail {
  font-size: 0.6875rem;
  color: var(--n-slate-8, #9ca3af);
}

/* Top deals table */
.top-deals-header {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 60px 80px;
  gap: 0.5rem;
  padding: 0.5rem 0;
  border-bottom: 2px solid var(--n-border, #e5e7eb);
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--n-slate-10, #6b7280);
  text-transform: uppercase;
}

.top-deals-row {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 60px 80px;
  gap: 0.5rem;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--n-slate-3, #f3f4f6);
  font-size: 0.8125rem;
  color: var(--n-slate-12, #111827);
}

/* Stale deals */
.stale-deal-row {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 80px;
  gap: 0.5rem;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--n-slate-3, #f3f4f6);
  font-size: 0.8125rem;
  color: var(--n-slate-12, #111827);
}

@media (max-width: 768px) {
  .crm-metrics-page {
    padding: 0.75rem;
  }

  .charts-row {
    grid-template-columns: 1fr;
  }

  .kpi-row {
    grid-template-columns: repeat(2, 1fr);
  }

  .metrics-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .metrics-header > div:last-child {
    flex-wrap: wrap;
  }

  .analyst-card__form {
    flex-direction: column;
  }

  .analyst-card__button {
    width: 100%;
  }

  .top-deals-header,
  .top-deals-row {
    grid-template-columns: 1.5fr 1fr 60px;
  }

  .top-deals-header span:nth-child(3),
  .top-deals-header span:nth-child(5),
  .top-deals-row span:nth-child(3),
  .top-deals-row span:nth-child(5) {
    display: none;
  }

  .stale-deal-row {
    grid-template-columns: 2fr 1fr 80px;
  }

  .stale-deal-row span:nth-child(3) {
    display: none;
  }

  .funnel-label,
  .winloss-label,
  .area-name,
  .score-stage-name,
  .time-stage-name {
    width: 80px;
    font-size: 0.6875rem;
  }
}

@media (max-width: 480px) {
  .kpi-row {
    grid-template-columns: 1fr;
  }

  .kpi-value {
    font-size: 1.25rem;
  }
}
</style>

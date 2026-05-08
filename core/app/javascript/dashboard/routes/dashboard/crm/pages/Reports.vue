<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CrmAPI from '../../../../api/crm';
import CRMExportButton from 'dashboard/components/crm/CRMExportButton.vue';
import CRMFunnelChart from 'dashboard/components/crm/CRMFunnelChart.vue';

const route = useRoute();
const router = useRouter();

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

const STATUS_OPTIONS = [
  { value: '', label: 'Todos os status' },
  { value: 'open', label: 'Abertos' },
  { value: 'won', label: 'Ganhos' },
  { value: 'lost', label: 'Perdidos' },
  { value: 'archived', label: 'Arquivados' },
];

const LEGAL_AREAS = [
  { value: '', label: 'Todas as áreas' },
  { value: 'previdenciario', label: 'Previdenciário' },
  { value: 'trabalhista', label: 'Trabalhista' },
  { value: 'familia', label: 'Família' },
  { value: 'consumidor', label: 'Consumidor' },
  { value: 'civil', label: 'Civil' },
  { value: 'criminal', label: 'Criminal' },
  { value: 'tributario', label: 'Tributário' },
  { value: 'empresarial', label: 'Empresarial' },
  { value: 'imobiliario', label: 'Imobiliário' },
];

const URGENCY_OPTIONS = [
  { value: '', label: 'Toda urgência' },
  { value: 'baixa', label: 'Baixa' },
  { value: 'media', label: 'Média' },
  { value: 'alta', label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
];

const OPERATIONAL_STATUS_OPTIONS = [
  { value: '', label: 'Todos os tipos' },
  { value: 'active', label: 'Lead ativo' },
  { value: 'returning_client', label: 'Retorno de Cliente' },
  { value: 'base_client', label: 'Cliente Base' },
  { value: 'converted_client', label: 'Cliente Convertido' },
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
  { value: 'archived', label: 'Arquivado' },
];

const SOURCE_OPTIONS = [
  { value: '', label: 'Todas as origens' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'jusbrasil', label: 'JusBrasil' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'facebook', label: 'Facebook' },
  { value: 'google_ads', label: 'Google Ads' },
  { value: 'indicacao', label: 'Indicação' },
  { value: 'site', label: 'Site' },
  { value: 'lista_importada', label: 'Lista importada' },
  { value: 'cliente_base', label: 'Cliente Base' },
  { value: 'outros', label: 'Outros' },
];

const priorityLabels = {
  baixa: 'Baixa',
  normal: 'Normal',
  alta: 'Alta',
  critica: 'Crítica',
};

const cleanFilters = () =>
  Object.fromEntries(
    Object.entries(filters).filter(([, value]) => value !== '')
  );

const persistFilters = () => {
  router.replace({ query: cleanFilters() });
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
    label: 'Leads abertos',
    value: openDeals.value,
    hint: 'Casos ainda em operação',
    icon: 'i-lucide-layers',
    tone: 'brand',
  },
  {
    label: 'Qualificação',
    value: qualificationRate.value,
    hint: `${stats.value?.qualified_deals || 0} lead(s) com score forte`,
    icon: 'i-lucide-badge-check',
    tone: 'blue',
  },
  {
    label: 'Alta prioridade',
    value: stats.value?.priority_deals || 0,
    hint: 'Score ou urgência pedem ação',
    icon: 'i-lucide-alert-triangle',
    tone: 'ruby',
  },
  {
    label: 'Atividades vencidas',
    value: stats.value?.overdue_activities || 0,
    hint: 'Próximas ações atrasadas',
    icon: 'i-lucide-alarm-clock',
    tone: 'amber',
  },
  {
    label: 'Fechados',
    value: wonDeals.value,
    hint: `${stats.value?.won_deals_this_month || 0} este mês`,
    icon: 'i-lucide-trophy',
    tone: 'teal',
  },
  {
    label: 'Score médio',
    value: stats.value?.average_score || 0,
    hint: 'Média dos leads abertos',
    icon: 'i-lucide-sparkles',
    tone: 'slate',
  },
  {
    label: 'Conversão',
    value: conversionRate.value,
    hint: 'Ganhos sobre pipeline aberto + ganho',
    icon: 'i-lucide-trending-up',
    tone: 'brand',
  },
  {
    label: 'Cliente Base',
    value: stats.value?.base_clients || 0,
    hint: 'Clientes preservados fora da conversão nova',
    icon: 'i-lucide-archive',
    tone: 'teal',
  },
  {
    label: 'Descartados',
    value: stats.value?.discarded_deals || 0,
    hint: 'Spam, inválidos, duplicados ou não leads',
    icon: 'i-lucide-ban',
    tone: 'ruby',
  },
]);

const funnelStages = computed(() => {
  const raw = stats.value?.deals_by_stage;
  if (!raw) return [];
  return (Array.isArray(raw) ? raw : Object.values(raw))
    .sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
    .filter(stage => Number(stage.count) > 0);
});

const areaRows = computed(() =>
  objectRows(stats.value?.deals_by_legal_area, 'Sem área')
);

const urgencyRows = computed(() =>
  objectRows(stats.value?.deals_by_urgency, 'Sem urgência')
);

const priorityRows = computed(() =>
  objectRows(stats.value?.activities_by_priority, 'Sem prioridade').map(
    row => ({
      ...row,
      label: priorityLabels[row.key] || row.label,
    })
  )
);

const sourceRows = computed(() =>
  objectRows(stats.value?.deals_by_source, 'Sem origem')
);

const operationalRows = computed(() =>
  objectRows(stats.value?.deals_by_operational_status, 'Sem status')
);

const insights = computed(() => {
  const items = [];
  if ((stats.value?.overdue_activities || 0) > 0) {
    items.push({
      title: 'Recuperar atividades vencidas',
      body: 'Há próximas ações atrasadas. Entre em Atividades e conclua ou reagende antes de novos disparos.',
      tone: 'danger',
      icon: 'i-lucide-alarm-clock',
    });
  }
  if ((stats.value?.priority_deals || 0) > 0) {
    items.push({
      title: 'Priorizar leads quentes',
      body: 'Leads de prioridade alta devem ter responsável e próxima ação definida.',
      tone: 'warning',
      icon: 'i-lucide-flame',
    });
  }
  if (openDeals.value > 0 && (stats.value?.qualified_deals || 0) === 0) {
    items.push({
      title: 'Qualificação fraca no funil',
      body: 'Revise etiquetas, área jurídica e score para separar leads frios de oportunidades reais.',
      tone: 'info',
      icon: 'i-lucide-filter',
    });
  }
  if (items.length === 0) {
    items.push({
      title: 'Operação sem alertas críticos',
      body: 'Os principais indicadores não apontam gargalos imediatos para os filtros atuais.',
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

async function loadStats() {
  loading.value = true;
  error.value = '';
  persistFilters();
  try {
    const { data } = await CrmAPI.getDashboard(cleanFilters());
    stats.value = data;
  } catch {
    error.value = 'Não foi possível carregar os relatórios do CRM.';
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

watch(
  () => route.query.pipeline_id,
  () => loadStats()
);

onMounted(loadStats);
</script>

<template>
  <main class="crm-reports-page">
    <header class="crm-page-header">
      <div>
        <p class="crm-eyebrow">Inteligência CRM</p>
        <h1>Relatórios CRM</h1>
        <p>
          Acompanhe conversão, gargalos de follow-up, distribuição por área e
          prioridade jurídica.
        </p>
      </div>
      <CRMExportButton :filters="cleanFilters()" label="Exportar CSV" />
    </header>

    <section class="crm-filter-panel">
      <label>
        <span>Status</span>
        <select v-model="filters.status" class="crm-select">
          <option
            v-for="option in STATUS_OPTIONS"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </label>
      <label>
        <span>Tipo CRM</span>
        <select v-model="filters.operational_status" class="crm-select">
          <option
            v-for="option in OPERATIONAL_STATUS_OPTIONS"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </label>
      <label>
        <span>Origem</span>
        <select v-model="filters.source" class="crm-select">
          <option
            v-for="option in SOURCE_OPTIONS"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </label>
      <label>
        <span>Área jurídica</span>
        <select v-model="filters.legal_area" class="crm-select">
          <option
            v-for="option in LEGAL_AREAS"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </label>
      <label>
        <span>Urgência</span>
        <select v-model="filters.urgency_level" class="crm-select">
          <option
            v-for="option in URGENCY_OPTIONS"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </label>
      <label>
        <span>De</span>
        <input v-model="filters.from" type="date" class="crm-input" />
      </label>
      <label>
        <span>Até</span>
        <input v-model="filters.to" type="date" class="crm-input" />
      </label>
      <div class="crm-filter-actions">
        <button class="crm-primary-button" @click="loadStats">
          <span class="i-lucide-filter size-4" />
          Filtrar
        </button>
        <button class="crm-ghost-button" @click="resetFilters">Limpar</button>
      </div>
    </section>

    <div v-if="error" class="crm-alert">
      <span class="i-lucide-circle-alert size-4" />
      {{ error }}
    </div>

    <section v-if="loading" class="crm-state">
      <span class="i-lucide-loader-circle size-5 animate-spin" />
      Carregando relatórios...
    </section>

    <template v-else-if="stats">
      <section class="crm-kpi-grid" aria-label="Indicadores CRM">
        <article
          v-for="card in metricCards"
          :key="card.label"
          class="crm-kpi-card"
          :class="`crm-kpi-card--${card.tone}`"
        >
          <span :class="[card.icon, 'size-4']" />
          <strong>{{ card.value }}</strong>
          <small>{{ card.label }}</small>
          <p>{{ card.hint }}</p>
        </article>
      </section>

      <section class="crm-insights-grid">
        <article
          v-for="insight in insights"
          :key="insight.title"
          class="crm-insight"
          :class="`crm-insight--${insight.tone}`"
        >
          <span :class="[insight.icon, 'size-4']" />
          <div>
            <h2>{{ insight.title }}</h2>
            <p>{{ insight.body }}</p>
          </div>
        </article>
      </section>

      <section class="crm-main-grid">
        <div class="crm-panel crm-panel--wide">
          <div class="crm-panel__header">
            <div>
              <h2>Funil por etapa</h2>
              <p>{{ funnelStages.length }} etapa(s) com oportunidades</p>
            </div>
          </div>
          <CRMFunnelChart
            v-if="funnelStages.length"
            :stages="funnelStages"
            title="Distribuição do funil"
          />
          <div v-else class="crm-empty-inline">
            Nenhuma oportunidade encontrada para os filtros atuais.
          </div>
        </div>

        <div class="crm-panel">
          <div class="crm-panel__header">
            <h2>Por área jurídica</h2>
          </div>
          <div v-if="areaRows.length" class="crm-breakdown">
            <div v-for="row in areaRows" :key="row.key || row.label">
              <span>{{ row.label }}</span>
              <strong>{{ row.count }}</strong>
            </div>
          </div>
          <div v-else class="crm-empty-inline">Sem dados de área.</div>
        </div>

        <div class="crm-panel">
          <div class="crm-panel__header">
            <h2>Por urgência</h2>
          </div>
          <div v-if="urgencyRows.length" class="crm-breakdown">
            <div v-for="row in urgencyRows" :key="row.key || row.label">
              <span>{{ row.label }}</span>
              <strong>{{ row.count }}</strong>
            </div>
          </div>
          <div v-else class="crm-empty-inline">Sem dados de urgência.</div>
        </div>

        <div class="crm-panel">
          <div class="crm-panel__header">
            <h2>Atividades por prioridade</h2>
          </div>
          <div v-if="priorityRows.length" class="crm-breakdown">
            <div v-for="row in priorityRows" :key="row.key || row.label">
              <span>{{ row.label }}</span>
              <strong>{{ row.count }}</strong>
            </div>
          </div>
          <div v-else class="crm-empty-inline">
            Sem atividades pendentes nos filtros atuais.
          </div>
        </div>

        <div class="crm-panel">
          <div class="crm-panel__header">
            <h2>Por origem</h2>
          </div>
          <div v-if="sourceRows.length" class="crm-breakdown">
            <div v-for="row in sourceRows" :key="row.key || row.label">
              <span>{{ row.label }}</span>
              <strong>{{ row.count }}</strong>
            </div>
          </div>
          <div v-else class="crm-empty-inline">Sem dados de origem.</div>
        </div>

        <div class="crm-panel">
          <div class="crm-panel__header">
            <h2>Saneamento do funil</h2>
          </div>
          <div v-if="operationalRows.length" class="crm-breakdown">
            <div v-for="row in operationalRows" :key="row.key || row.label">
              <span>{{ row.label }}</span>
              <strong>{{ row.count }}</strong>
            </div>
          </div>
          <div v-else class="crm-empty-inline">Sem dados de saneamento.</div>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.crm-reports-page {
  display: flex;
  width: 100%;
  min-width: 0;
  min-height: 100%;
  flex-direction: column;
  gap: 1rem;
  overflow-x: hidden;
  padding: clamp(1rem, 2vw, 1.5rem);
  background: rgb(var(--bg-app));
  color: rgb(var(--slate-12));
}

.crm-page-header {
  display: flex;
  min-width: 0;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.crm-page-header > * {
  min-width: 0;
}

.crm-eyebrow {
  margin: 0 0 0.25rem;
  color: rgb(var(--brand-9));
  font-size: 0.75rem;
  font-weight: 800;
  text-transform: uppercase;
}

.crm-page-header h1,
.crm-panel h2,
.crm-insight h2 {
  margin: 0;
}

.crm-page-header h1 {
  font-size: 1.5rem;
  font-weight: 800;
}

.crm-page-header p:last-child {
  max-width: 54rem;
  margin: 0.25rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.875rem;
  line-height: 1.5;
}

.crm-filter-panel {
  display: grid;
  min-width: 0;
  grid-template-columns: repeat(auto-fit, minmax(10.5rem, 1fr));
  gap: 0.75rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 1rem;
  background: rgb(var(--slate-1));
}

.crm-filter-panel label {
  display: grid;
  min-width: 0;
  gap: 0.35rem;
}

.crm-filter-panel label span {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
  font-weight: 800;
}

.crm-filter-actions {
  display: flex;
  min-width: 0;
  align-items: end;
  gap: 0.5rem;
}

.crm-input,
.crm-select {
  width: 100%;
  min-width: 0;
  height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  padding: 0 0.75rem;
  color: rgb(var(--slate-12));
  background: rgb(var(--slate-2));
  outline: none;
}

.crm-select {
  appearance: none;
  background-image: linear-gradient(
      45deg,
      transparent 50%,
      rgb(var(--slate-10)) 50%
    ),
    linear-gradient(135deg, rgb(var(--slate-10)) 50%, transparent 50%);
  background-position:
    calc(100% - 1rem) 1.05rem,
    calc(100% - 0.68rem) 1.05rem;
  background-repeat: no-repeat;
  background-size: 0.32rem 0.32rem;
  padding-right: 2rem;
}

.crm-input:focus,
.crm-select:focus {
  border-color: rgb(var(--brand-8));
  box-shadow: 0 0 0 3px rgb(var(--brand-4) / 0.25);
}

.crm-primary-button,
.crm-ghost-button {
  display: inline-flex;
  height: 2.5rem;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  border-radius: 8px;
  padding: 0 0.85rem;
  font-size: 0.875rem;
  font-weight: 800;
}

.crm-primary-button {
  color: white;
  background: rgb(var(--brand-9));
}

.crm-primary-button:hover {
  background: rgb(var(--brand-10));
}

.crm-ghost-button {
  border: 1px solid rgb(var(--slate-5));
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-2));
}

.crm-ghost-button:hover {
  background: rgb(var(--slate-3));
}

.crm-alert,
.crm-state,
.crm-kpi-card,
.crm-insight,
.crm-panel {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  background: rgb(var(--slate-1));
}

.crm-alert {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border-color: rgb(var(--ruby-7));
  padding: 0.85rem 1rem;
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-state {
  display: grid;
  min-height: 16rem;
  place-items: center;
  gap: 0.6rem;
  padding: 2rem;
  color: rgb(var(--slate-10));
}

.crm-kpi-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-kpi-card {
  display: grid;
  gap: 0.35rem;
  min-width: 0;
  min-height: 8rem;
  padding: 1rem;
}

.crm-kpi-card > span {
  color: rgb(var(--slate-9));
}

.crm-kpi-card strong {
  color: rgb(var(--slate-12));
  font-size: 1.55rem;
  line-height: 1;
}

.crm-kpi-card small {
  color: rgb(var(--slate-10));
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
}

.crm-kpi-card p {
  margin: 0;
  color: rgb(var(--slate-9));
  font-size: 0.78rem;
  line-height: 1.35;
}

.crm-kpi-card--brand {
  border-color: rgb(var(--brand-5));
}

.crm-kpi-card--ruby {
  border-color: rgb(var(--ruby-6));
}

.crm-kpi-card--amber {
  border-color: rgb(var(--amber-6));
}

.crm-kpi-card--teal {
  border-color: rgb(var(--teal-6));
}

.crm-insights-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-insight {
  display: flex;
  min-width: 0;
  gap: 0.75rem;
  padding: 1rem;
}

.crm-insight > span {
  flex-shrink: 0;
  margin-top: 0.15rem;
}

.crm-insight h2 {
  font-size: 0.95rem;
  font-weight: 800;
}

.crm-insight p {
  margin: 0.25rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.82rem;
  line-height: 1.45;
}

.crm-insight--danger {
  border-color: rgb(var(--ruby-6));
  background: rgb(var(--ruby-1));
}

.crm-insight--warning {
  border-color: rgb(var(--amber-6));
  background: rgb(var(--amber-1));
}

.crm-insight--good {
  border-color: rgb(var(--teal-6));
  background: rgb(var(--teal-1));
}

.crm-main-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-panel {
  min-width: 0;
  padding: 1rem;
}

.crm-panel--wide {
  grid-column: 1 / -1;
}

.crm-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 0.8rem;
}

.crm-panel__header h2 {
  font-size: 0.95rem;
  font-weight: 800;
}

.crm-panel__header p {
  margin: 0.2rem 0 0;
  color: rgb(var(--slate-9));
  font-size: 0.78rem;
}

.crm-breakdown {
  display: grid;
}

.crm-breakdown div {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  border-top: 1px solid rgb(var(--slate-4));
  padding: 0.75rem 0;
}

.crm-breakdown div:first-child {
  border-top: 0;
}

.crm-breakdown span {
  color: rgb(var(--slate-11));
  font-size: 0.875rem;
}

.crm-breakdown strong {
  color: rgb(var(--slate-12));
}

.crm-empty-inline {
  border: 1px dashed rgb(var(--slate-5));
  border-radius: 8px;
  padding: 1.3rem;
  color: rgb(var(--slate-9));
  text-align: center;
}

@media (max-width: 1440px) {
  .crm-kpi-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .crm-filter-panel {
    grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr));
  }
}

@media (max-width: 1024px) {
  .crm-page-header {
    flex-direction: column;
  }

  .crm-kpi-grid,
  .crm-insights-grid,
  .crm-main-grid {
    grid-template-columns: 1fr 1fr;
  }

  .crm-filter-actions {
    align-items: stretch;
  }
}

@media (max-width: 720px) {
  .crm-kpi-grid,
  .crm-insights-grid,
  .crm-main-grid {
    grid-template-columns: 1fr;
  }

  .crm-filter-actions {
    align-items: stretch;
    flex-direction: column;
  }

  .crm-filter-actions button {
    width: 100%;
  }
}
</style>

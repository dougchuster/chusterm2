<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class -->
<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CrmAPI from 'dashboard/api/crm';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CRMScoreBadge from 'dashboard/components/crm/CRMScoreBadge.vue';
import CRMLegalAreaBadge from 'dashboard/components/crm/CRMLegalAreaBadge.vue';
import CRMDealDrawer from 'dashboard/components/crm/CRMDealDrawer.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const agents = useMapGetter('agents/getVerifiedAgents');
const labels = useMapGetter('labels/getLabels');

const PER_PAGE = 100;

const STATUS_OPTIONS = [
  { value: '', label: 'Todos os status' },
  { value: 'open', label: 'Abertos' },
  { value: 'won', label: 'Ganhos' },
  { value: 'lost', label: 'Perdidos' },
  { value: 'archived', label: 'Arquivados' },
];

const OPERATIONAL_STATUS_OPTIONS = [
  { value: '', label: 'Todas as situações' },
  { value: 'active', label: 'Lead ativo' },
  { value: 'returning_client', label: 'Retorno' },
  { value: 'base_client', label: 'Cliente base' },
  { value: 'converted_client', label: 'Cliente convertido' },
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
  { value: 'archived', label: 'Arquivado' },
];

const LEGAL_AREAS = [
  { value: '', label: 'Todas as áreas' },
  { value: 'previdenciario', label: 'Previdenciário' },
  { value: 'trabalhista', label: 'Trabalhista' },
  { value: 'civil', label: 'Cível' },
  { value: 'familia', label: 'Família' },
  { value: 'consumidor', label: 'Consumidor' },
  { value: 'empresarial', label: 'Empresarial' },
  { value: 'tributario', label: 'Tributário' },
  { value: 'imobiliario', label: 'Imobiliário' },
  { value: 'penal', label: 'Penal' },
  { value: 'outros', label: 'Outros' },
];

const URGENCY_OPTIONS = [
  { value: '', label: 'Todas as urgências' },
  { value: 'critica', label: 'Crítica' },
  { value: 'alta', label: 'Alta' },
  { value: 'media', label: 'Média' },
  { value: 'baixa', label: 'Baixa' },
];

const LEAD_SOURCES = [
  { value: '', label: 'Todas as origens' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'jusbrasil', label: 'JusBrasil' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'facebook', label: 'Facebook' },
  { value: 'google_ads', label: 'Google Ads' },
  { value: 'meta_ads', label: 'Meta Ads' },
  { value: 'indicacao', label: 'Indicação' },
  { value: 'site', label: 'Site' },
  { value: 'lista_importada', label: 'Lista importada' },
  { value: 'cliente_base', label: 'Cliente base' },
  { value: 'outros', label: 'Outros' },
];

const SCORE_BUCKETS = [
  { value: '', label: 'Todos os scores' },
  { value: 'hot', label: 'Quentes', min: 80 },
  { value: 'qualified', label: 'Qualificados', min: 60, max: 79 },
  { value: 'medium', label: 'Médios', min: 40, max: 59 },
  { value: 'cold', label: 'Frios', max: 39 },
];

const BULK_ACTIONS = [
  { value: 'move', label: 'Mover etapa' },
  { value: 'assign_owner', label: 'Atribuir responsável' },
  { value: 'update_source', label: 'Atualizar origem' },
  { value: 'apply_label', label: 'Aplicar etiqueta' },
  { value: 'mark_base_client', label: 'Cliente base' },
  { value: 'discard', label: 'Descartar' },
  { value: 'archive', label: 'Arquivar' },
  { value: 'destroy', label: 'Excluir do sistema' },
];

const DISPOSITION_REASONS = [
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
];

const accountId = computed(() => Number(route.params.accountId));
const pipelines = ref([]);
const stages = ref([]);
const deals = ref([]);
const activities = ref([]);
const selectedDealIds = ref([]);
const selectAllFiltered = ref(false);
const loading = ref(true);
const refreshing = ref(false);
const savingId = ref('');
const deletingId = ref('');
const scoreRefreshingId = ref('');
const creatingLead = ref(false);
const showCreateLeadModal = ref(false);
const showDealDrawer = ref(false);
const bulkSaving = ref(false);
const error = ref('');
const selectedDrawerDealId = ref(null);
const meta = ref({
  total: 0,
  page: Number(route.query.page || 1),
  per_page: PER_PAGE,
  total_pages: 1,
});

const selectedPipelineId = ref(route.query.pipeline_id || '');
const pageNumber = ref(Number(route.query.page || 1));
const search = ref(route.query.search || '');
const statusFilter = ref(route.query.status || 'open');
const stageFilter = ref(route.query.stage_id || '');
const legalAreaFilter = ref(route.query.legal_area || '');
const urgencyFilter = ref(route.query.urgency || '');
const ownerFilter = ref(route.query.owner_id || '');
const sourceFilter = ref(route.query.source || '');
const operationalFilter = ref(route.query.operational_status || '');
const scoreBucket = ref(route.query.score || '');

const bulkAction = ref('move');
const bulkStageId = ref('');
const bulkOwnerId = ref('');
const bulkSource = ref('');
const bulkSourceDetail = ref('');
const bulkLabelTitle = ref('');
const bulkDispositionReason = ref('invalid');
const newLead = ref({
  title: '',
  contact_name: '',
  contact_phone_number: '',
  contact_email: '',
  crm_pipeline_stage_id: '',
  legal_area: '',
  urgency_level: '',
  source: '',
  source_detail: '',
  owner_id: '',
  value_estimate: '',
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const extractMeta = response => response?.data?.meta || {};

const visibleDealIds = computed(() => deals.value.map(deal => deal.id));

const selectedDealsCount = computed(() =>
  selectAllFiltered.value
    ? Number(meta.value.total || selectedDealIds.value.length)
    : selectedDealIds.value.length
);

const allVisibleSelected = computed(
  () =>
    visibleDealIds.value.length > 0 &&
    visibleDealIds.value.every(id => selectedDealIds.value.includes(id))
);

const canSelectAllFiltered = computed(
  () =>
    allVisibleSelected.value &&
    !selectAllFiltered.value &&
    Number(meta.value.total || 0) > selectedDealIds.value.length
);

const selectedPipeline = computed(() =>
  pipelines.value.find(
    pipeline => String(pipeline.id) === String(selectedPipelineId.value)
  )
);

const selectedPipelineChannel = computed(
  () => selectedPipeline.value?.inbox?.name || ''
);

const stageById = computed(() => {
  const map = {};
  stages.value.forEach(stage => {
    map[String(stage.id)] = stage;
  });
  return map;
});

const activitiesByDeal = computed(() => {
  const map = {};
  activities.value.forEach(activity => {
    if (!activity.crm_deal_id) return;
    const key = String(activity.crm_deal_id);
    if (!map[key]) map[key] = [];
    map[key].push(activity);
  });
  return map;
});

const overdueActivityIds = computed(
  () =>
    new Set(
      activities.value
        .filter(activity => activity.is_overdue)
        .map(activity => String(activity.crm_deal_id))
    )
);

const stageSummaries = computed(() =>
  stages.value.map(stage => {
    const count = deals.value.filter(
      deal => String(deal.crm_pipeline_stage_id) === String(stage.id)
    ).length;

    return {
      ...stage,
      count,
      value: deals.value
        .filter(deal => String(deal.crm_pipeline_stage_id) === String(stage.id))
        .reduce((sum, deal) => sum + Number(deal.value_estimate_cents || 0), 0),
    };
  })
);

const totalValue = computed(() =>
  deals.value.reduce(
    (sum, deal) => sum + Number(deal.value_estimate_cents || 0),
    0
  )
);

const hotLeads = computed(
  () => deals.value.filter(deal => Number(deal.score_total || 0) >= 80).length
);

const openLeads = computed(
  () => deals.value.filter(deal => deal.status === 'open').length
);

const withoutOwner = computed(
  () => deals.value.filter(deal => !deal.owner_id).length
);

const kpis = computed(() => [
  {
    label: 'Leads carregados',
    value: deals.value.length,
    hint: `${meta.value.total || deals.value.length} no filtro`,
    icon: 'i-lucide-users',
    tone: 'blue',
  },
  {
    label: 'Abertos',
    value: openLeads.value,
    hint: selectedPipelineChannel.value || selectedPipeline.value?.name || 'Todos os pipelines',
    icon: 'i-lucide-radio-tower',
    tone: 'teal',
  },
  {
    label: 'Leads quentes',
    value: hotLeads.value,
    hint: 'Score 80+',
    icon: 'i-lucide-flame',
    tone: 'amber',
  },
  {
    label: 'Sem responsável',
    value: withoutOwner.value,
    hint: 'Precisam de dono',
    icon: 'i-lucide-user-x',
    tone: 'brand',
  },
  {
    label: 'Valor estimado',
    value: formatCurrency(totalValue.value),
    hint: 'Na lista carregada',
    icon: 'i-lucide-banknote',
    tone: 'teal-strong',
  },
]);

const totalPages = computed(() => Number(meta.value.total_pages || 1));

const hasPreviousPage = computed(() => pageNumber.value > 1);
const hasNextPage = computed(() => pageNumber.value < totalPages.value);

const isBulkActionValid = computed(() => {
  if (!selectedDealsCount.value) return false;
  if (bulkAction.value === 'move') return !!bulkStageId.value;
  if (bulkAction.value === 'assign_owner') return !!bulkOwnerId.value;
  if (bulkAction.value === 'update_source') return !!bulkSource.value;
  if (bulkAction.value === 'apply_label') return !!bulkLabelTitle.value;
  if (bulkAction.value === 'discard') return !!bulkDispositionReason.value;
  return true;
});

const bulkSubmitLabel = computed(() => {
  if (bulkSaving.value) return 'Aplicando...';
  return bulkAction.value === 'destroy' ? 'Excluir definitivamente' : 'Aplicar';
});

function formatCurrency(cents) {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(cents || 0) / 100);
}

function formatDate(value) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
  }).format(new Date(value));
}

function compactPhone(value) {
  return value || '-';
}

function sourceLabel(value) {
  if (!value) return '-';
  return (
    LEAD_SOURCES.find(source => source.value === value)?.label || value || '-'
  );
}

function statusLabel(value) {
  if (!value) return '-';
  return (
    STATUS_OPTIONS.find(status => status.value === value)?.label || value || '-'
  );
}

function operationalLabel(value) {
  if (!value) return '-';
  return (
    OPERATIONAL_STATUS_OPTIONS.find(status => status.value === value)?.label ||
    value ||
    '-'
  );
}

function urgencyLabel(value) {
  if (!value) return '-';
  return (
    URGENCY_OPTIONS.find(item => item.value === value)?.label || value || '-'
  );
}

function ownerName(ownerId) {
  if (!ownerId) return 'Sem responsável';
  const owner = agents.value.find(
    agent => String(agent.id) === String(ownerId)
  );
  return owner?.name || owner?.email || 'Sem responsável';
}

function dealStageName(deal) {
  return (
    deal.stage?.name ||
    stageById.value[String(deal.crm_pipeline_stage_id)]?.name ||
    'Sem etapa'
  );
}

function pipelineOptionLabel(pipeline) {
  return pipeline.inbox?.name
    ? `${pipeline.inbox.name} - ${pipeline.name}`
    : pipeline.name;
}

function contactUrl(deal) {
  return deal.contact_id
    ? `/app/accounts/${accountId.value}/contacts/${deal.contact_id}`
    : '';
}

function conversationUrl(deal) {
  return deal.conversation_id
    ? `/app/accounts/${accountId.value}/conversations/${deal.conversation_id}`
    : '';
}

function dealDetailsUrl(deal) {
  return `/app/accounts/${accountId.value}/crm/deals/${deal.id}`;
}

function buildQuery() {
  return {
    page: pageNumber.value,
    pipeline_id: selectedPipelineId.value || undefined,
    search: search.value || undefined,
    status: statusFilter.value || undefined,
    stage_id: stageFilter.value || undefined,
    legal_area: legalAreaFilter.value || undefined,
    urgency: urgencyFilter.value || undefined,
    owner_id: ownerFilter.value || undefined,
    source: sourceFilter.value || undefined,
    operational_status: operationalFilter.value || undefined,
    score: scoreBucket.value || undefined,
  };
}

function syncQuery() {
  router.replace({ query: buildQuery() });
}

function scoreParams() {
  const bucket = SCORE_BUCKETS.find(item => item.value === scoreBucket.value);
  if (!bucket) return {};

  return {
    score_min: bucket.min,
    score_max: bucket.max,
  };
}

function dealParams() {
  return {
    per_page: PER_PAGE,
    page: pageNumber.value,
    pipeline_id: selectedPipelineId.value || undefined,
    search: search.value || undefined,
    status: statusFilter.value || undefined,
    stage_id: stageFilter.value || undefined,
    legal_area: legalAreaFilter.value || undefined,
    urgency: urgencyFilter.value || undefined,
    operational_status: operationalFilter.value || undefined,
    owner_id: ownerFilter.value || undefined,
    source: sourceFilter.value || undefined,
    ...scoreParams(),
  };
}

function bulkFilterParams() {
  const params = { ...dealParams() };
  delete params.page;
  delete params.per_page;
  return params;
}

async function loadPipelines() {
  const response = await CrmAPI.getPipelines();
  pipelines.value = extractData(response);

  if (!selectedPipelineId.value && pipelines.value.length) {
    selectedPipelineId.value =
      pipelines.value.find(pipeline => pipeline.inbox_id || pipeline.inbox)
        ?.id ||
      pipelines.value.find(
        pipeline => pipeline.is_default || pipeline.isDefault
      )?.id || pipelines.value[0].id;
  }
}

async function loadStages() {
  if (!selectedPipelineId.value) {
    stages.value = [];
    return;
  }

  const response = await CrmAPI.getPipelineStages(selectedPipelineId.value);
  stages.value = extractData(response);
}

async function loadDeals({ silent = false } = {}) {
  if (silent) refreshing.value = true;
  else loading.value = true;

  error.value = '';

  try {
    const [dealsResponse, activitiesResponse] = await Promise.all([
      CrmAPI.getDeals(dealParams()),
      CrmAPI.getActivities({ status: 'pending' }),
    ]);

    deals.value = extractData(dealsResponse);
    activities.value = extractData(activitiesResponse);
    meta.value = {
      total: deals.value.length,
      page: pageNumber.value,
      per_page: PER_PAGE,
      total_pages: 1,
      ...extractMeta(dealsResponse),
    };
    selectedDealIds.value = selectedDealIds.value.filter(id =>
      deals.value.some(deal => deal.id === id)
    );
    syncQuery();
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível carregar todos os leads.';
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
}

async function loadAll({ silent = false } = {}) {
  if (!silent) loading.value = true;
  error.value = '';

  try {
    await loadPipelines();
    await loadStages();
    await loadDeals({ silent });
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível carregar o CRM.';
    loading.value = false;
    refreshing.value = false;
  }
}

async function applyFilters() {
  pageNumber.value = 1;
  clearSelection();
  await loadDeals({ silent: true });
}

async function clearFilters() {
  search.value = '';
  statusFilter.value = 'open';
  stageFilter.value = '';
  legalAreaFilter.value = '';
  urgencyFilter.value = '';
  ownerFilter.value = '';
  sourceFilter.value = '';
  operationalFilter.value = '';
  scoreBucket.value = '';
  pageNumber.value = 1;
  clearSelection();
  await loadDeals({ silent: true });
}

async function onPipelineChange() {
  pageNumber.value = 1;
  stageFilter.value = '';
  clearSelection();
  await loadStages();
  await loadDeals({ silent: true });
}

async function goToPage(nextPage) {
  if (nextPage < 1 || nextPage > totalPages.value) return;
  pageNumber.value = nextPage;
  clearSelection();
  await loadDeals({ silent: true });
}

function toggleDeal(deal) {
  selectAllFiltered.value = false;

  if (selectedDealIds.value.includes(deal.id)) {
    selectedDealIds.value = selectedDealIds.value.filter(id => id !== deal.id);
  } else {
    selectedDealIds.value = [...selectedDealIds.value, deal.id];
  }
}

function toggleAllVisible() {
  selectAllFiltered.value = false;

  if (allVisibleSelected.value) {
    selectedDealIds.value = selectedDealIds.value.filter(
      id => !visibleDealIds.value.includes(id)
    );
  } else {
    selectedDealIds.value = [
      ...new Set([...selectedDealIds.value, ...visibleDealIds.value]),
    ];
  }
}

function selectAllMatchingDeals() {
  selectedDealIds.value = [
    ...new Set([...selectedDealIds.value, ...visibleDealIds.value]),
  ];
  selectAllFiltered.value = true;
}

function clearSelection() {
  selectedDealIds.value = [];
  selectAllFiltered.value = false;
  bulkAction.value = 'move';
  bulkStageId.value = '';
  bulkOwnerId.value = '';
  bulkSource.value = '';
  bulkSourceDetail.value = '';
  bulkLabelTitle.value = '';
  bulkDispositionReason.value = 'invalid';
}

function openCreateLeadModal() {
  newLead.value = {
    title: '',
    contact_name: '',
    contact_phone_number: '',
    contact_email: '',
    crm_pipeline_stage_id: stages.value[0]?.id || '',
    legal_area: '',
    urgency_level: '',
    source: '',
    source_detail: '',
    owner_id: '',
    value_estimate: '',
  };
  showCreateLeadModal.value = true;
}

async function moveDeal(deal, stageId) {
  if (!deal?.id || !stageId) return;

  const previousStageId = deal.crm_pipeline_stage_id;
  savingId.value = `stage-${deal.id}`;
  deal.crm_pipeline_stage_id = stageId;
  deal.stage = stageById.value[String(stageId)] || deal.stage;

  try {
    const response = await CrmAPI.moveDeal(deal.id, stageId);
    Object.assign(deal, response?.data || {});
  } catch (err) {
    deal.crm_pipeline_stage_id = previousStageId;
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível mover o lead.';
  } finally {
    savingId.value = '';
  }
}

async function updateOwner(deal, ownerId) {
  if (!deal?.id) return;

  const previousOwnerId = deal.owner_id;
  savingId.value = `owner-${deal.id}`;
  deal.owner_id = ownerId || null;

  try {
    const response = await CrmAPI.updateDeal(deal.id, {
      owner_id: ownerId || null,
    });
    Object.assign(deal, response?.data || {});
  } catch (err) {
    deal.owner_id = previousOwnerId;
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível atualizar o responsável.';
  } finally {
    savingId.value = '';
  }
}

async function recomputeScore(deal) {
  if (!deal?.id) return;
  scoreRefreshingId.value = deal.id;

  try {
    await CrmAPI.recomputeScore(deal.id);
    window.setTimeout(() => loadDeals({ silent: true }), 1000);
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível recalcular o score.';
  } finally {
    scoreRefreshingId.value = '';
  }
}

async function markWon(deal) {
  if (!deal?.id) return;
  savingId.value = `won-${deal.id}`;

  try {
    const response = await CrmAPI.markDealWon(deal.id);
    Object.assign(deal, response?.data || {});
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível marcar o lead como ganho.';
  } finally {
    savingId.value = '';
  }
}

async function discardDeal(deal) {
  if (!deal?.id) return;
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(`Descartar "${deal.title || 'este lead'}"?`);
  if (!confirmed) return;

  savingId.value = `discard-${deal.id}`;

  try {
    await CrmAPI.discardDeal(deal.id, { reason: 'no_lead' });
    await loadDeals({ silent: true });
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível descartar o lead.';
  } finally {
    savingId.value = '';
  }
}

async function markBaseClient(deal) {
  if (!deal?.id) return;
  savingId.value = `base-${deal.id}`;

  try {
    await CrmAPI.markDealBaseClient(deal.id);
    await loadDeals({ silent: true });
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível marcar como cliente base.';
  } finally {
    savingId.value = '';
  }
}

function openDealDrawer(deal) {
  if (!deal?.id) return;
  selectedDrawerDealId.value = deal.id;
  showDealDrawer.value = true;
}

function onDrawerDealSaved(updatedDeal) {
  if (!updatedDeal?.id) {
    loadDeals({ silent: true });
    return;
  }

  const index = deals.value.findIndex(deal => deal.id === updatedDeal.id);
  if (index >= 0) {
    deals.value[index] = { ...deals.value[index], ...updatedDeal };
  } else {
    loadDeals({ silent: true });
  }
}

function removeDealFromList(dealId) {
  deals.value = deals.value.filter(deal => Number(deal.id) !== Number(dealId));
  selectedDealIds.value = selectedDealIds.value.filter(
    id => Number(id) !== Number(dealId)
  );
  meta.value = {
    ...meta.value,
    total: Math.max(Number(meta.value.total || 0) - 1, 0),
  };
}

function onDrawerDealDeleted(dealId) {
  removeDealFromList(dealId);
  showDealDrawer.value = false;
  selectedDrawerDealId.value = null;
}

async function deleteDealPermanently(deal) {
  if (!deal?.id) return;
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    `Excluir definitivamente "${deal.title || 'este lead'}" do sistema?\nEssa ação não pode ser desfeita.`
  );
  if (!confirmed) return;

  deletingId.value = deal.id;
  error.value = '';

  try {
    await CrmAPI.deleteDeal(deal.id);
    removeDealFromList(deal.id);
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível excluir o lead do sistema.';
  } finally {
    deletingId.value = '';
  }
}

async function applyBulkAction() {
  if (!isBulkActionValid.value) return;

  if (bulkAction.value === 'destroy') {
    // eslint-disable-next-line no-alert
    const confirmed = window.confirm(
      `Excluir definitivamente ${selectedDealsCount.value} lead(s) do sistema?\nEssa ação remove os registros do CRM e não pode ser desfeita.`
    );
    if (!confirmed) return;
  }

  bulkSaving.value = true;
  error.value = '';

  try {
    await CrmAPI.bulkActionDeals({
      ...(selectAllFiltered.value
        ? { select_all: true, filters: bulkFilterParams() }
        : { deal_ids: selectedDealIds.value }),
      bulk_action: bulkAction.value,
      stage_id: bulkStageId.value || undefined,
      owner_id: bulkOwnerId.value || undefined,
      source: bulkSource.value || undefined,
      source_detail: bulkSourceDetail.value || undefined,
      label_title: bulkLabelTitle.value || undefined,
      disposition_reason: bulkDispositionReason.value || undefined,
      reason: bulkDispositionReason.value || undefined,
    });
    clearSelection();
    await loadDeals({ silent: true });
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível aplicar a ação em massa.';
  } finally {
    bulkSaving.value = false;
  }
}

function moneyToCents(value) {
  const normalized = String(value || '')
    .replace(/\./g, '')
    .replace(',', '.')
    .replace(/[^\d.]/g, '');
  return Math.round(Number(normalized || 0) * 100);
}

async function createLeadFromModal() {
  if (!selectedPipelineId.value || !stages.value.length) return;
  if (!newLead.value.title?.trim()) return;

  creatingLead.value = true;
  error.value = '';

  try {
    const response = await CrmAPI.createDeal({
      title: newLead.value.title.trim(),
      contact_name: newLead.value.contact_name?.trim() || undefined,
      contact_phone_number:
        newLead.value.contact_phone_number?.trim() || undefined,
      contact_email: newLead.value.contact_email?.trim() || undefined,
      crm_pipeline_id: selectedPipelineId.value,
      inbox_id: selectedPipeline.value?.inbox_id || undefined,
      crm_pipeline_stage_id:
        newLead.value.crm_pipeline_stage_id || stages.value[0].id,
      operational_status: 'active',
      legal_area: newLead.value.legal_area || undefined,
      urgency_level: newLead.value.urgency_level || undefined,
      source: newLead.value.source || undefined,
      source_detail: newLead.value.source_detail || undefined,
      owner_id: newLead.value.owner_id || undefined,
      value_estimate_cents: moneyToCents(newLead.value.value_estimate),
    });
    const deal = response?.data;
    showCreateLeadModal.value = false;
    if (deal?.id) {
      router.push({
        name: 'crm_deal_details',
        params: { accountId: accountId.value, dealId: deal.id },
      });
    } else {
      await loadDeals({ silent: true });
    }
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Não foi possível criar o lead.';
  } finally {
    creatingLead.value = false;
  }
}

onMounted(async () => {
  store.dispatch('agents/get');
  store.dispatch('labels/get');
  await loadAll();
});
</script>

<template>
  <div class="crm-leads-page flex h-full min-w-0 flex-col overflow-hidden">
    <header class="crm-leads-header">
      <div class="min-w-0">
        <div class="flex items-center gap-3">
          <span class="crm-leads-header__icon">
            <span class="i-lucide-list-filter size-5" />
          </span>
          <div class="min-w-0">
            <h1 class="m-0 truncate text-xl font-semibold text-n-slate-12">
              Todos os Leads
            </h1>
            <p class="m-0 text-sm text-n-slate-11">
              Visão ampla de etapas, categorias, responsáveis e próximas ações.
            </p>
          </div>
        </div>
      </div>

      <div class="crm-leads-header__actions">
        <select
          v-model="selectedPipelineId"
          class="crm-leads-control crm-leads-control--pipeline"
          :disabled="loading || refreshing"
          @change="onPipelineChange"
        >
          <option value="">Todos os pipelines</option>
        <option
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          :value="pipeline.id"
        >
          {{ pipelineOptionLabel(pipeline) }}
        </option>
      </select>
        <button
          type="button"
          class="crm-leads-button"
          :disabled="refreshing"
          @click="loadAll({ silent: true })"
        >
          <span class="i-lucide-refresh-cw size-4" />
          {{ refreshing ? 'Atualizando...' : 'Atualizar' }}
        </button>
        <button
          type="button"
          class="crm-leads-button"
          @click="
            router.push({
              name: 'crm_automation_rules',
              params: { accountId },
            })
          "
        >
          <span class="i-lucide-zap size-4" />
          Automatizar
        </button>
        <button
          type="button"
          class="crm-leads-button crm-leads-button--primary"
          :disabled="creatingLead || !selectedPipelineId || !stages.length"
          @click="openCreateLeadModal"
        >
          <span class="i-lucide-plus size-4" />
          Novo lead
        </button>
      </div>
    </header>

    <section class="crm-leads-filters">
      <label class="crm-leads-search">
        <span class="crm-leads-search__icon" aria-hidden="true">
          <span class="i-lucide-search size-4" />
        </span>
        <input
          v-model="search"
          type="search"
          placeholder="Buscar por lead, contato, telefone, área..."
          @keydown.enter.prevent="applyFilters"
        />
      </label>

      <select v-model="statusFilter" class="crm-leads-control">
        <option
          v-for="option in STATUS_OPTIONS"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>

      <select v-model="stageFilter" class="crm-leads-control">
        <option value="">Todas as etapas</option>
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>

      <select v-model="legalAreaFilter" class="crm-leads-control">
        <option
          v-for="option in LEGAL_AREAS"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>

      <select v-model="urgencyFilter" class="crm-leads-control">
        <option
          v-for="option in URGENCY_OPTIONS"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>

      <select v-model="ownerFilter" class="crm-leads-control">
        <option value="">Todos os responsáveis</option>
        <option value="__unassigned">Sem responsável</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name || agent.email }}
        </option>
      </select>

      <select v-model="sourceFilter" class="crm-leads-control">
        <option
          v-for="option in LEAD_SOURCES"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>

      <select v-model="operationalFilter" class="crm-leads-control">
        <option
          v-for="option in OPERATIONAL_STATUS_OPTIONS"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>

      <select v-model="scoreBucket" class="crm-leads-control">
        <option
          v-for="option in SCORE_BUCKETS"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>

      <div class="crm-leads-filters__actions">
        <button
          type="button"
          class="crm-leads-button crm-leads-button--primary"
          @click="applyFilters"
        >
          Filtrar
        </button>
        <button type="button" class="crm-leads-button" @click="clearFilters">
          Limpar
        </button>
      </div>
    </section>

    <div v-if="selectedDealsCount" class="crm-leads-bulk">
      <div class="crm-leads-bulk__summary">
        <span class="i-lucide-check-square size-4" />
        <strong>{{ selectedDealsCount }} lead(s) selecionado(s)</strong>
        <span v-if="selectAllFiltered" class="crm-leads-bulk__hint">
          todos os leads do filtro
        </span>
      </div>

      <button
        v-if="canSelectAllFiltered"
        type="button"
        class="crm-leads-button"
        @click="selectAllMatchingDeals"
      >
        Selecionar todos os {{ meta.total }} do filtro
      </button>

      <select v-model="bulkAction" class="crm-leads-control">
        <option
          v-for="action in BULK_ACTIONS"
          :key="action.value"
          :value="action.value"
        >
          {{ action.label }}
        </option>
      </select>

      <select
        v-if="bulkAction === 'move'"
        v-model="bulkStageId"
        class="crm-leads-control"
      >
        <option value="">Escolha a etapa</option>
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>

      <select
        v-if="bulkAction === 'assign_owner'"
        v-model="bulkOwnerId"
        class="crm-leads-control"
      >
        <option value="">Escolha o responsável</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name || agent.email }}
        </option>
      </select>

      <template v-if="bulkAction === 'update_source'">
        <select v-model="bulkSource" class="crm-leads-control">
          <option
            v-for="source in LEAD_SOURCES"
            :key="source.value"
            :value="source.value"
          >
            {{ source.label }}
          </option>
        </select>
        <input
          v-model="bulkSourceDetail"
          class="crm-leads-control"
          type="text"
          placeholder="Campanha, anúncio, planilha..."
        />
      </template>

      <select
        v-if="bulkAction === 'apply_label'"
        v-model="bulkLabelTitle"
        class="crm-leads-control"
      >
        <option value="">Escolha a etiqueta</option>
        <option v-for="label in labels" :key="label.id" :value="label.title">
          {{ label.display_title || label.title }}
        </option>
      </select>

      <select
        v-if="bulkAction === 'discard'"
        v-model="bulkDispositionReason"
        class="crm-leads-control"
      >
        <option
          v-for="reason in DISPOSITION_REASONS"
          :key="reason.value"
          :value="reason.value"
        >
          {{ reason.label }}
        </option>
      </select>

      <button
        type="button"
        class="crm-leads-button"
        :class="
          bulkAction === 'destroy'
            ? 'crm-leads-button--danger'
            : 'crm-leads-button--primary'
        "
        :disabled="!isBulkActionValid || bulkSaving"
        @click="applyBulkAction"
      >
        {{ bulkSubmitLabel }}
      </button>
      <button type="button" class="crm-leads-button" @click="clearSelection">
        Limpar seleção
      </button>
    </div>

    <section class="crm-leads-content">
      <div
        v-if="loading"
        class="grid min-h-[24rem] place-content-center rounded-xl border border-n-weak bg-n-slate-1 text-sm text-n-slate-11"
      >
        Carregando leads...
      </div>

      <div
        v-else-if="error"
        class="grid min-h-[24rem] place-content-center rounded-xl border border-n-ruby-7 bg-n-ruby-2 p-6 text-center"
      >
        <p class="mb-3 text-sm font-medium text-n-ruby-11">{{ error }}</p>
        <button
          type="button"
          class="crm-leads-button crm-leads-button--primary mx-auto"
          @click="loadAll()"
        >
          Tentar novamente
        </button>
      </div>

      <template v-else>
        <div class="crm-leads-kpis">
          <article
            v-for="kpi in kpis"
            :key="kpi.label"
            class="crm-leads-kpi"
            :class="`crm-leads-kpi--${kpi.tone}`"
          >
            <span class="crm-leads-kpi__icon-box" aria-hidden="true">
              <span class="crm-leads-kpi__icon" :class="kpi.icon" />
            </span>
            <div class="min-w-0">
              <p>{{ kpi.label }}</p>
              <strong>{{ kpi.value }}</strong>
              <span>{{ kpi.hint }}</span>
            </div>
          </article>
        </div>

        <div class="crm-leads-stage-strip">
          <article
            v-for="stage in stageSummaries"
            :key="stage.id"
            class="crm-leads-stage"
            :style="{ '--stage-color': stage.color || '#38bdf8' }"
          >
            <span
              class="crm-leads-stage__color"
              :style="{ backgroundColor: stage.color || '#38bdf8' }"
            />
            <div class="min-w-0">
              <strong>{{ stage.name }}</strong>
              <span>{{ stage.count }} lead(s) nesta página</span>
            </div>
            <em>{{ formatCurrency(stage.value) }}</em>
          </article>
        </div>

        <div class="crm-leads-table-wrap">
          <table class="crm-leads-table">
            <thead>
              <tr>
                <th class="crm-leads-table__check">
                  <input
                    type="checkbox"
                    :checked="allVisibleSelected"
                    :indeterminate="
                      selectedDealIds.length > 0 && !allVisibleSelected
                    "
                    title="Selecionar todos nesta página"
                    @change="toggleAllVisible"
                  />
                </th>
                <th>Lead</th>
                <th>Contato principal</th>
                <th>Categoria</th>
                <th>Etapa do lead</th>
                <th>Responsável</th>
                <th>Score</th>
                <th>Tarefas</th>
                <th class="text-right">Venda, R$</th>
                <th class="text-right">Ações</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!deals.length">
                <td colspan="10" class="crm-leads-table__empty">
                  Nenhum lead encontrado para os filtros atuais.
                </td>
              </tr>
              <tr
                v-for="deal in deals"
                :key="deal.id"
                :class="{
                  'crm-leads-table__row--selected': selectedDealIds.includes(
                    deal.id
                  ),
                }"
              >
                <td class="crm-leads-table__check">
                  <input
                    type="checkbox"
                    :checked="selectedDealIds.includes(deal.id)"
                    @change="toggleDeal(deal)"
                  />
                </td>
                <td>
                  <div class="crm-leads-title">
                    <RouterLink :to="dealDetailsUrl(deal)">
                      {{ deal.title || `Lead #${deal.id}` }}
                    </RouterLink>
                    <span>{{ statusLabel(deal.status) }}</span>
                  </div>
                </td>
                <td>
                  <div class="crm-leads-contact">
                    <a
                      v-if="contactUrl(deal)"
                      :href="contactUrl(deal)"
                      class="crm-leads-link"
                    >
                      {{ deal.contact_name || '-' }}
                    </a>
                    <span v-else>{{ deal.contact_name || '-' }}</span>
                    <small>{{ compactPhone(deal.contact_phone_number) }}</small>
                    <a
                      v-if="deal.contact_email"
                      class="crm-leads-link"
                      :href="`mailto:${deal.contact_email}`"
                    >
                      {{ deal.contact_email }}
                    </a>
                  </div>
                </td>
                <td>
                  <div class="crm-leads-tags">
                    <CRMLegalAreaBadge
                      v-if="deal.legal_area"
                      :area="deal.legal_area"
                      compact
                    />
                    <span v-else class="crm-leads-pill">Sem área</span>
                    <span class="crm-leads-pill">
                      {{ urgencyLabel(deal.urgency_level) }}
                    </span>
                    <span class="crm-leads-pill">
                      {{ sourceLabel(deal.source) }}
                    </span>
                    <span class="crm-leads-pill">
                      {{ operationalLabel(deal.operational_status) }}
                    </span>
                  </div>
                </td>
                <td>
                  <select
                    class="crm-leads-inline-select"
                    :value="deal.crm_pipeline_stage_id"
                    :disabled="savingId === `stage-${deal.id}`"
                    @change="moveDeal(deal, $event.target.value)"
                  >
                    <option
                      v-for="stage in stages"
                      :key="stage.id"
                      :value="stage.id"
                    >
                      {{ stage.name }}
                    </option>
                  </select>
                  <small class="crm-leads-muted">
                    {{ dealStageName(deal) }}
                  </small>
                </td>
                <td>
                  <select
                    class="crm-leads-inline-select"
                    :value="deal.owner_id || ''"
                    :disabled="savingId === `owner-${deal.id}`"
                    @change="updateOwner(deal, $event.target.value)"
                  >
                    <option value="">Sem responsável</option>
                    <option
                      v-for="agent in agents"
                      :key="agent.id"
                      :value="agent.id"
                    >
                      {{ agent.name || agent.email }}
                    </option>
                  </select>
                  <small class="crm-leads-muted">
                    {{ ownerName(deal.owner_id) }}
                  </small>
                </td>
                <td>
                  <CRMScoreBadge
                    :score="Number(deal.score_total || 0)"
                    :classification="deal.score_classification || ''"
                    show-label
                    size="sm"
                  />
                </td>
                <td>
                  <div class="crm-leads-activities">
                    <strong>{{ deal.pending_activities_count || 0 }}</strong>
                    <span
                      :class="{
                        'text-n-ruby-10': overdueActivityIds.has(
                          String(deal.id)
                        ),
                      }"
                    >
                      {{
                        overdueActivityIds.has(String(deal.id))
                          ? 'Vencida'
                          : 'Pendentes'
                      }}
                    </span>
                    <small
                      v-if="activitiesByDeal[String(deal.id)]?.[0]?.due_at"
                    >
                      {{
                        formatDate(activitiesByDeal[String(deal.id)][0].due_at)
                      }}
                    </small>
                  </div>
                </td>
                <td class="text-right font-semibold text-n-slate-12">
                  {{ formatCurrency(deal.value_estimate_cents) }}
                </td>
                <td>
                  <div class="crm-leads-actions">
                    <button
                      type="button"
                      class="crm-leads-action crm-leads-action--score"
                      title="Recalcular score"
                      :disabled="scoreRefreshingId === deal.id"
                      @click="recomputeScore(deal)"
                    >
                      <span class="i-lucide-sparkles size-4" />
                    </button>
                    <button
                      type="button"
                      class="crm-leads-action crm-leads-action--edit"
                      title="Editar lead"
                      @click="openDealDrawer(deal)"
                    >
                      <span class="i-lucide-pencil size-4" />
                    </button>
                    <a
                      class="crm-leads-action crm-leads-action--link"
                      :href="dealDetailsUrl(deal)"
                      title="Abrir ficha 360"
                    >
                      <span class="i-lucide-external-link size-4" />
                    </a>
                    <a
                      v-if="conversationUrl(deal)"
                      class="crm-leads-action crm-leads-action--conversation"
                      :href="conversationUrl(deal)"
                      title="Abrir conversa"
                    >
                      <span class="i-lucide-message-square size-4" />
                    </a>
                    <button
                      type="button"
                      class="crm-leads-action crm-leads-action--won"
                      title="Marcar como ganho"
                      :disabled="savingId === `won-${deal.id}`"
                      @click="markWon(deal)"
                    >
                      <span class="i-lucide-circle-check size-4" />
                    </button>
                    <button
                      type="button"
                      class="crm-leads-action crm-leads-action--base"
                      title="Cliente base"
                      :disabled="savingId === `base-${deal.id}`"
                      @click="markBaseClient(deal)"
                    >
                      <span class="i-lucide-archive size-4" />
                    </button>
                    <button
                      type="button"
                      class="crm-leads-action crm-leads-action--discard"
                      title="Descartar"
                      :disabled="savingId === `discard-${deal.id}`"
                      @click="discardDeal(deal)"
                    >
                      <span class="i-lucide-ban size-4" />
                    </button>
                    <button
                      type="button"
                      class="crm-leads-action crm-leads-action--destroy"
                      title="Excluir do sistema"
                      :disabled="deletingId === deal.id"
                      @click="deleteDealPermanently(deal)"
                    >
                      <span class="i-lucide-trash-2 size-4" />
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <footer class="crm-leads-pagination">
          <span>
            Exibindo página {{ pageNumber }} de {{ totalPages }} -
            {{ meta.total || deals.length }} lead(s)
          </span>
          <div class="flex items-center gap-2">
            <button
              type="button"
              class="crm-leads-button"
              :disabled="!hasPreviousPage"
              @click="goToPage(pageNumber - 1)"
            >
              Anterior
            </button>
            <button
              type="button"
              class="crm-leads-button"
              :disabled="!hasNextPage"
              @click="goToPage(pageNumber + 1)"
            >
              Próxima
            </button>
          </div>
        </footer>
      </template>
    </section>

    <div v-if="showCreateLeadModal" class="crm-leads-modal">
      <form
        class="crm-leads-modal__panel"
        @submit.prevent="createLeadFromModal"
      >
        <header class="crm-leads-modal__header">
          <div>
            <h2>Novo lead</h2>
            <p>Crie o lead direto no pipeline atual.</p>
          </div>
          <button
            type="button"
            class="crm-leads-actions-button"
            @click="showCreateLeadModal = false"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </header>

        <div class="crm-leads-modal__grid">
          <label class="crm-leads-field crm-leads-field--wide">
            <span>Título do lead</span>
            <input
              v-model="newLead.title"
              type="text"
              placeholder="Ex: Revisão de benefício INSS"
              required
            />
          </label>

          <label class="crm-leads-field">
            <span>Nome do contato</span>
            <input
              v-model="newLead.contact_name"
              type="text"
              placeholder="Nome do cliente"
            />
          </label>

          <label class="crm-leads-field">
            <span>Telefone do contato</span>
            <input
              v-model="newLead.contact_phone_number"
              type="tel"
              placeholder="+55 61 99999-9999"
            />
          </label>

          <label class="crm-leads-field crm-leads-field--wide">
            <span>E-mail do contato</span>
            <input
              v-model="newLead.contact_email"
              type="email"
              placeholder="cliente@email.com"
            />
          </label>

          <label class="crm-leads-field">
            <span>Etapa</span>
            <select v-model="newLead.crm_pipeline_stage_id" required>
              <option v-for="stage in stages" :key="stage.id" :value="stage.id">
                {{ stage.name }}
              </option>
            </select>
          </label>

          <label class="crm-leads-field">
            <span>Responsável</span>
            <select v-model="newLead.owner_id">
              <option value="">Sem responsável</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name || agent.email }}
              </option>
            </select>
          </label>

          <label class="crm-leads-field">
            <span>Área jurídica</span>
            <select v-model="newLead.legal_area">
              <option
                v-for="option in LEGAL_AREAS"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label class="crm-leads-field">
            <span>Urgência</span>
            <select v-model="newLead.urgency_level">
              <option
                v-for="option in URGENCY_OPTIONS"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label class="crm-leads-field">
            <span>Origem</span>
            <select v-model="newLead.source">
              <option
                v-for="option in LEAD_SOURCES"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>

          <label class="crm-leads-field">
            <span>Detalhe da origem</span>
            <input
              v-model="newLead.source_detail"
              type="text"
              placeholder="Campanha, anúncio, indicação..."
            />
          </label>

          <label class="crm-leads-field">
            <span>Valor estimado</span>
            <input
              v-model="newLead.value_estimate"
              type="text"
              inputmode="decimal"
              placeholder="0,00"
            />
          </label>
        </div>

        <footer class="crm-leads-modal__footer">
          <button
            type="button"
            class="crm-leads-button"
            @click="showCreateLeadModal = false"
          >
            Cancelar
          </button>
          <button
            type="submit"
            class="crm-leads-button crm-leads-button--primary"
            :disabled="creatingLead || !newLead.title"
          >
            {{ creatingLead ? 'Criando...' : 'Criar lead' }}
          </button>
        </footer>
      </form>
    </div>

    <CRMDealDrawer
      v-if="showDealDrawer && selectedDrawerDealId"
      v-model:show="showDealDrawer"
      :deal-id="selectedDrawerDealId"
      @saved="onDrawerDealSaved"
      @deal-deleted="onDrawerDealDeleted"
    />
  </div>
</template>

<style scoped>
.crm-leads-page {
  background: radial-gradient(
      circle at top right,
      rgb(var(--blue-3) / 0.34),
      transparent 25rem
    ),
    radial-gradient(
      circle at 8% 22%,
      rgb(var(--teal-3) / 0.22),
      transparent 22rem
    ),
    rgb(var(--slate-2));
}

.crm-leads-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  border-bottom: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-1));
  padding: 1.15rem 1.25rem;
}

.crm-leads-header__actions {
  display: flex;
  flex: 1 1 34rem;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 0.5rem;
  min-width: min(100%, 28rem);
}

.crm-leads-header__icon {
  display: grid;
  width: 2.75rem;
  height: 2.75rem;
  flex-shrink: 0;
  place-content: center;
  border: 1px solid rgb(var(--blue-5));
  border-radius: 0.5rem;
  background: linear-gradient(135deg, rgb(var(--blue-2)), rgb(var(--teal-2)));
  color: rgb(var(--blue-11));
}

.crm-leads-control,
.crm-leads-inline-select {
  min-width: 0;
  height: 2.375rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
  outline: none;
  transition:
    border-color 160ms ease,
    box-shadow 160ms ease,
    background 160ms ease;
}

.crm-leads-control {
  flex: 1 1 11rem;
  max-width: 18rem;
  padding: 0 0.75rem;
}

.crm-leads-control--pipeline {
  flex: 1 1 24rem;
  max-width: 36rem;
}

.crm-leads-inline-select {
  width: 12rem;
  padding: 0 0.625rem;
}

.crm-leads-control:focus,
.crm-leads-inline-select:focus {
  border-color: rgb(var(--blue-7));
  box-shadow: 0 0 0 3px rgb(var(--blue-4) / 0.26);
}

.crm-leads-button {
  display: inline-flex;
  min-height: 2.375rem;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  padding: 0 0.875rem;
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
  font-weight: 800;
  transition:
    background 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease,
    transform 0.15s ease;
}

.crm-leads-button:hover:not(:disabled) {
  border-color: rgb(var(--blue-6));
  background: rgb(var(--blue-2));
  color: rgb(var(--blue-11));
  transform: translateY(-1px);
}

.crm-leads-button:disabled {
  cursor: not-allowed;
  opacity: 0.68;
}

.crm-leads-button--primary {
  border-color: rgb(var(--blue-7));
  background: linear-gradient(135deg, rgb(var(--blue-7)), rgb(var(--brand-9)));
  color: white;
  box-shadow: 0 10px 24px rgb(var(--blue-9) / 0.2);
}

.crm-leads-button--primary:hover:not(:disabled) {
  border-color: rgb(var(--blue-8));
  background: linear-gradient(135deg, rgb(var(--blue-8)), rgb(var(--brand-10)));
  color: white;
}

.crm-leads-button--danger {
  border-color: rgb(var(--ruby-7));
  background: rgb(var(--ruby-9));
  color: white;
  box-shadow: 0 10px 24px rgb(var(--ruby-9) / 0.18);
}

.crm-leads-button--danger:hover:not(:disabled) {
  border-color: rgb(var(--ruby-8));
  background: rgb(var(--ruby-10));
  color: white;
}

.crm-leads-filters,
.crm-leads-bulk {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.625rem;
  border-bottom: 1px solid rgb(var(--slate-5));
  padding: 0.75rem 1.25rem;
}

.crm-leads-filters {
  background: rgb(var(--slate-1));
}

.crm-leads-filters .crm-leads-control {
  flex: 1 1 12.5rem;
  width: auto;
  max-width: none;
}

.crm-leads-bulk {
  background: rgb(var(--brand-2));
}

.crm-leads-bulk__summary {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  color: rgb(var(--brand-11));
}

.crm-leads-bulk__hint {
  border-radius: 999px;
  background: rgb(var(--brand-3));
  padding: 0.15rem 0.5rem;
  color: rgb(var(--brand-11));
  font-size: 0.75rem;
  font-weight: 700;
}

.crm-leads-search {
  position: relative;
  display: block;
  flex: 999 1 28rem;
  min-width: 0;
  height: 2.375rem;
  overflow: hidden;
  border: 1px solid rgb(var(--blue-6));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  color: rgb(var(--blue-10));
}

.crm-leads-search__icon {
  position: absolute;
  inset-block: 0;
  left: 0;
  z-index: 1;
  display: grid;
  width: 2.75rem;
  place-items: center;
  border-right: 1px solid rgb(var(--slate-4));
  background: rgb(var(--blue-2));
  pointer-events: none;
}

.crm-leads-search__icon > span {
  width: 1rem;
  height: 1rem;
}

.crm-leads-search input {
  display: block;
  width: 100%;
  height: 100%;
  min-width: 0;
  border: 0;
  background: transparent;
  color: rgb(var(--slate-12));
  outline: none;
  padding: 0 0.85rem 0 3.35rem;
  line-height: 2.375rem;
}

.crm-leads-search:focus-within {
  border-color: rgb(var(--blue-7));
  box-shadow: 0 0 0 3px rgb(var(--blue-4) / 0.26);
}

.crm-leads-search input::placeholder {
  color: rgb(var(--slate-10));
}

.crm-leads-filters__actions {
  display: flex;
  flex: 0 0 auto;
  margin-left: auto;
  gap: 0.5rem;
}

.crm-leads-content {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
  padding: 1rem 1.25rem;
}

.crm-leads-kpis {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.crm-leads-kpi {
  position: relative;
  display: flex;
  min-width: 0;
  gap: 0.75rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.75rem;
  background: rgb(var(--slate-1));
  padding: 0.875rem;
  overflow: hidden;
}

.crm-leads-kpi::before {
  position: absolute;
  inset-block: 0;
  left: 0;
  width: 0.24rem;
  background: rgb(var(--blue-8));
  content: '';
}

.crm-leads-kpi__icon-box {
  display: grid;
  width: 2.1rem;
  height: 2.1rem;
  flex-shrink: 0;
  place-items: center;
  border-radius: 0.5rem;
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-leads-kpi__icon {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.crm-leads-kpi--teal {
  border-color: rgb(var(--teal-5));
  background: linear-gradient(135deg, rgb(var(--teal-1)), rgb(var(--slate-1)));
}

.crm-leads-kpi--teal::before {
  background: rgb(var(--teal-8));
}

.crm-leads-kpi--teal .crm-leads-kpi__icon-box {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-leads-kpi--amber {
  border-color: rgb(var(--amber-5));
  background: linear-gradient(135deg, rgb(var(--amber-1)), rgb(var(--slate-1)));
}

.crm-leads-kpi--amber::before {
  background: rgb(var(--amber-8));
}

.crm-leads-kpi--amber .crm-leads-kpi__icon-box {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-2));
}

.crm-leads-kpi--brand {
  border-color: rgb(var(--brand-5));
  background: linear-gradient(135deg, rgb(var(--brand-1)), rgb(var(--slate-1)));
}

.crm-leads-kpi--brand::before {
  background: rgb(var(--brand-8));
}

.crm-leads-kpi--brand .crm-leads-kpi__icon-box {
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-2));
}

.crm-leads-kpi--teal-strong {
  border-color: rgb(var(--teal-6));
  background: linear-gradient(135deg, rgb(var(--teal-2)), rgb(var(--slate-1)));
}

.crm-leads-kpi--teal-strong::before {
  background: rgb(var(--teal-9));
}

.crm-leads-kpi--teal-strong .crm-leads-kpi__icon-box {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-3));
}

.crm-leads-kpi p {
  margin: 0;
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
}

.crm-leads-kpi strong {
  display: block;
  margin-top: 0.25rem;
  color: rgb(var(--slate-12));
  font-size: 1.25rem;
  line-height: 1.1;
}

.crm-leads-kpi span:not(.crm-leads-kpi__icon):not(.crm-leads-kpi__icon-box) {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
}

.crm-leads-stage-strip {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
  gap: 0.625rem;
  margin-bottom: 0.75rem;
}

.crm-leads-stage {
  position: relative;
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 0.625rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.625rem;
  background: rgb(var(--slate-1));
  padding: 0.625rem 0.75rem;
  box-shadow: 0 10px 24px rgb(15 23 42 / 0.04);
  transition:
    border-color 160ms ease,
    transform 160ms ease,
    box-shadow 160ms ease;
}

.crm-leads-stage:hover {
  border-color: color-mix(in srgb, var(--stage-color), transparent 35%);
  transform: translateY(-1px);
  box-shadow: 0 14px 30px rgb(15 23 42 / 0.08);
}

.crm-leads-stage__color {
  width: 0.38rem;
  height: 2.25rem;
  flex-shrink: 0;
  border-radius: 999px;
  box-shadow: 0 0 0 0.25rem
    color-mix(in srgb, var(--stage-color), transparent 84%);
}

.crm-leads-stage strong,
.crm-leads-stage span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-leads-stage strong {
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
}

.crm-leads-stage span {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
}

.crm-leads-stage em {
  margin-left: auto;
  color: rgb(var(--slate-11));
  font-size: 0.75rem;
  font-style: normal;
  font-weight: 700;
  white-space: nowrap;
}

.crm-leads-table-wrap {
  overflow-x: auto;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.75rem;
  background: rgb(var(--slate-1));
  box-shadow: 0 16px 45px rgb(15 23 42 / 0.05);
}

.crm-leads-table {
  width: 100%;
  min-width: 92rem;
  border-collapse: collapse;
}

.crm-leads-table th {
  height: 2.75rem;
  border-bottom: 1px solid rgb(var(--slate-5));
  background: linear-gradient(180deg, rgb(var(--slate-2)), rgb(var(--slate-1)));
  padding: 0 0.75rem;
  color: rgb(var(--slate-11));
  font-size: 0.75rem;
  font-weight: 700;
  text-align: left;
  text-transform: uppercase;
}

.crm-leads-table td {
  border-bottom: 1px solid rgb(var(--slate-4));
  padding: 0.625rem 0.75rem;
  color: rgb(var(--slate-11));
  font-size: 0.875rem;
  vertical-align: top;
}

.crm-leads-table tbody tr:hover {
  background: rgb(var(--blue-1));
}

.crm-leads-table tbody tr:last-child td {
  border-bottom: 0;
}

.crm-leads-table__check {
  width: 2.5rem;
  text-align: center;
}

.crm-leads-table__check input {
  width: 1rem;
  height: 1rem;
}

.crm-leads-table__row--selected {
  background: rgb(var(--brand-2));
}

.crm-leads-table__empty {
  height: 12rem;
  text-align: center;
  vertical-align: middle;
}

.crm-leads-title,
.crm-leads-contact,
.crm-leads-activities {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.25rem;
}

.crm-leads-title a {
  max-width: 18rem;
  overflow: hidden;
  color: rgb(var(--brand-11));
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-leads-title span,
.crm-leads-contact small,
.crm-leads-muted,
.crm-leads-activities span,
.crm-leads-activities small {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
}

.crm-leads-link {
  color: rgb(var(--brand-11));
  text-decoration: none;
}

.crm-leads-link:hover {
  text-decoration: underline;
}

.crm-leads-tags {
  display: flex;
  max-width: 18rem;
  flex-wrap: wrap;
  gap: 0.25rem;
}

.crm-leads-pill {
  display: inline-flex;
  align-items: center;
  border: 1px solid rgb(var(--blue-4));
  border-radius: 999px;
  background: rgb(var(--blue-1));
  padding: 0.16rem 0.52rem;
  color: rgb(var(--blue-11));
  font-size: 0.6875rem;
  font-weight: 750;
}

.crm-leads-activities strong {
  color: rgb(var(--slate-12));
  font-size: 1rem;
}

.crm-leads-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.25rem;
}

.crm-leads-actions button,
.crm-leads-actions a {
  display: grid;
  width: 2rem;
  height: 2rem;
  place-content: center;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-10));
  text-decoration: none;
  transition:
    border-color 150ms ease,
    background 150ms ease,
    color 150ms ease,
    transform 150ms ease;
}

.crm-leads-action--score {
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-1));
}

.crm-leads-action--edit,
.crm-leads-action--link,
.crm-leads-action--conversation {
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-1));
}

.crm-leads-action--won {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-1));
}

.crm-leads-action--base {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-1));
}

.crm-leads-action--discard,
.crm-leads-action--destroy {
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-1));
}

.crm-leads-action--destroy {
  border-color: rgb(var(--ruby-6));
}

.crm-leads-actions-button {
  display: grid;
  width: 2.25rem;
  height: 2.25rem;
  place-content: center;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-10));
}

.crm-leads-actions button:hover:not(:disabled),
.crm-leads-actions a:hover,
.crm-leads-actions-button:hover {
  border-color: rgb(var(--blue-6));
  background: rgb(var(--blue-2));
  color: rgb(var(--blue-11));
  transform: translateY(-1px);
}

.crm-leads-actions .crm-leads-action--destroy:hover:not(:disabled) {
  border-color: rgb(var(--ruby-7));
  background: rgb(var(--ruby-2));
  color: rgb(var(--ruby-11));
}

.crm-leads-actions button:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.crm-leads-pagination {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.875rem 0.25rem 0;
  color: rgb(var(--slate-10));
  font-size: 0.875rem;
}

.crm-leads-modal {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: grid;
  place-content: center;
  background: rgb(15 23 42 / 0.48);
  padding: 1rem;
}

.crm-leads-modal__panel {
  width: min(44rem, calc(100vw - 2rem));
  max-height: calc(100vh - 2rem);
  overflow-y: auto;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.875rem;
  background: rgb(var(--slate-1));
  box-shadow: 0 24px 60px rgb(15 23 42 / 0.25);
}

.crm-leads-modal__header,
.crm-leads-modal__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 1rem;
}

.crm-leads-modal__header {
  border-bottom: 1px solid rgb(var(--slate-5));
}

.crm-leads-modal__header h2 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 1rem;
  font-weight: 700;
}

.crm-leads-modal__header p {
  margin: 0.25rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.875rem;
}

.crm-leads-modal__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.875rem;
  padding: 1rem;
}

.crm-leads-modal__footer {
  border-top: 1px solid rgb(var(--slate-5));
}

.crm-leads-field {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.375rem;
}

.crm-leads-field--wide {
  grid-column: 1 / -1;
}

.crm-leads-field span {
  color: rgb(var(--slate-11));
  font-size: 0.8125rem;
  font-weight: 700;
}

.crm-leads-field input,
.crm-leads-field select {
  height: 2.5rem;
  min-width: 0;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-2));
  color: rgb(var(--slate-12));
  padding: 0 0.75rem;
  outline: none;
}

.crm-leads-field input::placeholder {
  color: rgb(var(--slate-10));
}

.crm-leads-field input:focus,
.crm-leads-field select:focus {
  border-color: rgb(var(--brand-8));
  box-shadow: 0 0 0 2px rgb(var(--brand-4));
}

@media (max-width: 1280px) {
  .crm-leads-kpis {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .crm-leads-filters {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .crm-leads-search,
  .crm-leads-filters__actions {
    grid-column: 1 / -1;
  }

  .crm-leads-bulk {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 768px) {
  .crm-leads-header,
  .crm-leads-filters,
  .crm-leads-bulk,
  .crm-leads-content {
    padding-inline: 0.75rem;
  }

  .crm-leads-kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .crm-leads-control,
  .crm-leads-search,
  .crm-leads-filters__actions,
  .crm-leads-filters__actions .crm-leads-button {
    width: 100%;
    max-width: none;
  }

  .crm-leads-filters,
  .crm-leads-bulk {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 520px) {
  .crm-leads-kpis {
    grid-template-columns: 1fr;
  }

  .crm-leads-modal__grid {
    grid-template-columns: 1fr;
  }
}
</style>

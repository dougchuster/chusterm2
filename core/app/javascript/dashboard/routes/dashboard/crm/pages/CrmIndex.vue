<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-static-inline-styles -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import CrmAPI from 'dashboard/api/crm';
import CRMDealCard from 'dashboard/components/crm/CRMDealCard.vue';
import CRMDealDrawer from 'dashboard/components/crm/CRMDealDrawer.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';

const route = useRoute();
const router = useRouter();
const store = useStore();
const labels = useMapGetter('labels/getLabels');
const agents = useMapGetter('agents/getVerifiedAgents');

const DEFAULT_STAGES = [
  { name: 'Novo lead', probabilityPct: 10, color: '#38bdf8' },
  { name: 'Em qualificação', probabilityPct: 25, color: '#a78bfa' },
  { name: 'Proposta', probabilityPct: 55, color: '#f59e0b' },
  { name: 'Negociação', probabilityPct: 75, color: '#22c55e' },
  { name: 'Ganho', probabilityPct: 100, color: '#14b8a6' },
  { name: 'Perdido', probabilityPct: 0, color: '#f43f5e' },
];

const DEFAULT_LOSS_REASONS = [
  'Sem contato',
  'Sem interesse',
  'Preco',
  'Prazo',
  'Matriculado em concorrente',
];

const normalizePipelineId = value => {
  if (Array.isArray(value)) return normalizePipelineId(value[0]);
  return value === undefined || value === null || value === ''
    ? ''
    : String(value);
};

const pipelines = ref([]);
const selectedPipelineId = ref(normalizePipelineId(route.query.pipeline_id));
const stages = ref([]);
const deals = ref([]);
const activities = ref([]);
const health = ref(null);
const lossReasons = ref([]);
const boardColumns = ref([]);
const loading = ref(true);
const refreshing = ref(false);
const bootstrapping = ref(false);
const scoreRefreshingId = ref('');
const error = ref('');
const purgingOrphans = ref(false);
const selectedDeal = ref(null);
const showDrawer = ref(false);
const selectedDealIds = ref([]);
const kanbanViewportRef = ref(null);
const isPanningBoard = ref(false);
const bulkAction = ref('move');
const bulkStageId = ref('');
const bulkDispositionReason = ref('invalid');
const bulkSource = ref('');
const bulkSourceDetail = ref('');
const bulkOwnerId = ref('');
const bulkLabelTitle = ref('');
const bulkMoving = ref(false);

// Filtros visuais do Kanban — sincronizados com a URL
const filterÁrea = ref(route.query.área || '');
const filterUrgency = ref(route.query.urgency || '');
const filterSearch = ref(route.query.search || '');

const LEAD_SOURCES = [
  { value: '', label: 'Sem origem' },
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

const BULK_ACTIONS = [
  { value: 'move', label: 'Mover etapa' },
  { value: 'discard', label: 'Descartar' },
  { value: 'mark_base_client', label: 'Cliente Base' },
  { value: 'archive', label: 'Arquivar' },
  { value: 'update_source', label: 'Atualizar origem' },
  { value: 'assign_owner', label: 'Atribuir responsável' },
  { value: 'apply_label', label: 'Aplicar etiqueta' },
];

const DISPOSITION_REASONS = [
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
];

const syncFiltersToUrl = () => {
  const query = { ...route.query };
  if (filterÁrea.value) query.área = filterÁrea.value;
  else delete query.área;
  if (filterUrgency.value) query.urgency = filterUrgency.value;
  else delete query.urgency;
  if (filterSearch.value) query.search = filterSearch.value;
  else delete query.search;
  router.replace({ query });
};

const LEGAL_AREAS = [
  { value: '', label: 'Todas as áreas' },
  { value: 'previdenciario', label: 'Previdenciário' },
  { value: 'civil', label: 'Civil' },
  { value: 'trabalhista', label: 'Trabalhista' },
  { value: 'consumidor', label: 'Consumidor' },
  { value: 'familia', label: 'Família' },
  { value: 'penal', label: 'Penal' },
  { value: 'tributario', label: 'Tributário' },
  { value: 'empresarial', label: 'Empresarial' },
  { value: 'imobiliario', label: 'Imobiliário' },
  { value: 'outros', label: 'Outros' },
];

const URGENCY_LEVELS = [
  { value: '', label: 'Qualquer urgência' },
  { value: 'critica', label: '🔴 Crítica' },
  { value: 'alta', label: '🟠 Alta' },
  { value: 'media', label: '🟡 Média' },
  { value: 'baixa', label: '🟢 Baixa' },
];

const accountId = computed(() => Number(route.params.accountId));

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const pendingActivities = computed(
  () => activities.value.filter(activity => !activity.completedAt).length
);

const overdueActivities = computed(() => {
  const now = Date.now();
  return activities.value.filter(activity => {
    return (
      !activity.completedAt &&
      activity.dueAt &&
      new Date(activity.dueAt).getTime() < now
    );
  });
});

const upcomingActivities = computed(() => {
  const now = Date.now();
  return activities.value
    .filter(activity => {
      return (
        !activity.completedAt &&
        activity.dueAt &&
        new Date(activity.dueAt).getTime() >= now
      );
    })
    .slice(0, 5);
});

const averageScore = computed(() => {
  if (!deals.value.length) return 0;
  const total = deals.value.reduce(
    (sum, deal) => sum + Number(deal.score_total || deal.score || 0),
    0
  );
  return Math.round(total / deals.value.length);
});

const wonDeals = computed(
  () => deals.value.filter(deal => deal.status === 'won').length
);

const healthStatus = computed(() => health.value?.status || 'unknown');

const healthStatusLabel = computed(() =>
  healthStatus.value === 'ok' ? 'Saude ok' : 'Atencao'
);

const healthCards = computed(() => {
  const data = health.value;
  if (!data) return [];

  return [
    {
      key: 'contacts_without_owner',
      label: 'Contatos sem responsável',
      value: data.contacts?.without_crm_owner ?? 0,
      tone: (data.contacts?.without_crm_owner ?? 0) > 0 ? 'warn' : 'ok',
    },
    {
      key: 'hot_leads_without_owner',
      label: 'Leads quentes sem responsável',
      value: data.deals?.hot_leads_without_owner ?? 0,
      tone: (data.deals?.hot_leads_without_owner ?? 0) > 0 ? 'danger' : 'ok',
    },
    {
      key: 'stale_media',
      label: 'Mídia parada',
      value: data.media?.stale_processing ?? 0,
      tone: (data.media?.stale_processing ?? 0) > 0 ? 'danger' : 'ok',
    },
    {
      key: 'overdue_activities',
      label: 'Tarefas vencidas',
      value: data.activities?.overdue ?? 0,
      tone: (data.activities?.overdue ?? 0) > 0 ? 'warn' : 'ok',
    },
  ];
});

const overdueCount = computed(() => overdueActivities.value.length);

const summaryToneClasses = {
  brand: {
    card: 'border-n-brand/20 bg-n-brand/5',
    icon: 'bg-n-brand/10 text-n-brand',
    value: 'text-n-brand',
    accent: 'bg-n-brand',
  },
  teal: {
    card: 'border-n-teal-6 bg-n-teal-2',
    icon: 'bg-n-teal-3 text-n-teal-10',
    value: 'text-n-teal-10',
    accent: 'bg-n-teal-9',
  },
  slate: {
    card: 'border-n-weak bg-n-slate-1',
    icon: 'bg-n-slate-3 text-n-slate-11',
    value: 'text-n-slate-12',
    accent: 'bg-n-slate-8',
  },
  warn: {
    card: 'border-n-amber-6 bg-n-amber-2',
    icon: 'bg-n-amber-3 text-n-amber-10',
    value: 'text-n-amber-10',
    accent: 'bg-n-amber-9',
  },
  danger: {
    card: 'border-n-ruby-6 bg-n-ruby-2',
    icon: 'bg-n-ruby-3 text-n-ruby-10',
    value: 'text-n-ruby-9',
    accent: 'bg-n-ruby-9',
  },
  ok: {
    card: 'border-n-teal-6 bg-n-teal-2',
    icon: 'bg-n-teal-3 text-n-teal-10',
    value: 'text-n-slate-12',
    accent: 'bg-n-teal-9',
  },
};

const getHealthSummaryIcon = tone => {
  if (tone === 'danger') return 'i-lucide-circle-alert';
  if (tone === 'warn') return 'i-lucide-triangle-alert';
  return 'i-lucide-circle-check';
};

const summaryMetricCards = computed(() => [
  {
    key: 'deals',
    label: 'Atendimentos',
    value: deals.value.length,
    icon: 'i-lucide-message-circle',
    tone: 'brand',
  },
  {
    key: 'won',
    label: 'Ganhos',
    value: wonDeals.value,
    icon: 'i-lucide-trophy',
    tone: 'teal',
  },
  {
    key: 'tasks',
    label: 'Tarefas pendentes',
    value: pendingActivities.value,
    icon: 'i-lucide-list-checks',
    tone: 'brand',
  },
  {
    key: 'score',
    label: 'Score medio',
    value: averageScore.value,
    icon: 'i-lucide-gauge',
    tone: 'slate',
  },
  {
    key: 'overdue',
    label: 'Vencidas',
    value: overdueCount.value,
    icon: 'i-lucide-clock-alert',
    tone: overdueCount.value > 0 ? 'danger' : 'slate',
  },
  {
    key: 'losses',
    label: 'Perdas',
    value: lossReasons.value.length,
    icon: 'i-lucide-circle-slash',
    tone: lossReasons.value.length > 0 ? 'warn' : 'slate',
  },
  ...healthCards.value.map(item => ({
    key: item.key,
    label: item.label,
    value: item.value,
    icon: getHealthSummaryIcon(item.tone),
    tone: item.tone,
  })),
]);

const selectedPipeline = computed(() =>
  pipelines.value.find(
    pipeline => normalizePipelineId(pipeline.id) === selectedPipelineId.value
  )
);

const selectedDeals = computed(() =>
  deals.value.filter(deal => selectedDealIds.value.includes(deal.id))
);

const filteredDealsCount = computed(() =>
  boardColumns.value.reduce((sum, column) => sum + column.deals.length, 0)
);

const pipelineStagesCount = computed(() => stages.value.length);

const boardPanState = {
  pointerId: null,
  startX: 0,
  scrollLeft: 0,
};

const shouldIgnoreBoardPan = target => {
  if (!target?.closest) return true;
  return !!target.closest(
    'article, button, a, input, select, textarea, label, [role="button"], .crm-no-pan'
  );
};

const onBoardPointerDown = event => {
  if (event.button !== undefined && event.button !== 0) return;
  if (shouldIgnoreBoardPan(event.target)) return;

  const viewport = kanbanViewportRef.value;
  if (!viewport) return;

  isPanningBoard.value = true;
  boardPanState.pointerId = event.pointerId;
  boardPanState.startX = event.clientX;
  boardPanState.scrollLeft = viewport.scrollLeft;
  viewport.setPointerCapture?.(event.pointerId);
};

const onBoardPointerMove = event => {
  if (!isPanningBoard.value || event.pointerId !== boardPanState.pointerId) {
    return;
  }

  const viewport = kanbanViewportRef.value;
  if (!viewport) return;

  event.preventDefault();
  viewport.scrollLeft =
    boardPanState.scrollLeft - (event.clientX - boardPanState.startX);
};

const stopBoardPan = event => {
  if (!isPanningBoard.value) return;

  const viewport = kanbanViewportRef.value;
  viewport?.releasePointerCapture?.(event.pointerId);
  isPanningBoard.value = false;
  boardPanState.pointerId = null;
};

// Filtra deals conforme filtros visuais ativos
const filterDeal = deal => {
  if (filterÁrea.value && deal.legal_area !== filterÁrea.value) return false;
  if (
    filterUrgency.value &&
    (deal.urgency_level || '').toLowerCase() !== filterUrgency.value
  )
    return false;
  if (filterSearch.value) {
    const q = filterSearch.value.toLowerCase();
    const haystack = [
      deal.title,
      deal.contact_name,
      deal.contact_phone_number,
      String(deal.contact_phone_number || '').replace(/\D/g, ''),
      deal.legal_area,
      deal.case_type,
    ]
      .join(' ')
      .toLowerCase();
    if (!haystack.includes(q)) return false;
  }
  return true;
};

const hasActiveFilters = computed(
  () => !!(filterÁrea.value || filterUrgency.value || filterSearch.value)
);

const clearFilters = () => {
  filterÁrea.value = '';
  filterUrgency.value = '';
  filterSearch.value = '';
  syncFiltersToUrl();
};

watch([filterÁrea, filterUrgency, filterSearch], () => {
  syncFiltersToUrl();
  buildBoardColumns();
});

const buildBoardColumns = () => {
  const sourceStages = stages.value.length
    ? stages.value
    : DEFAULT_STAGES.map((stage, index) => ({ ...stage, position: index }));

  const orderedStages = [...sourceStages].sort(
    (a, b) => Number(a.position || 0) - Number(b.position || 0)
  );

  const columns = orderedStages.map(stage => {
    const stageName = stage.name;
    const stageId = stage.id;
    const stageDeals = deals.value.filter(deal => {
      const dealStageId =
        deal.crm_pipeline_stage_id ?? deal.stageId ?? deal.stage?.id;
      const inStage = stageId
        ? dealStageId === stageId
        : deal.stage?.name === stageName || deal.stage === stageName;
      return inStage && filterDeal(deal);
    });
    return {
      id: stage.id || stageName,
      stageId,
      name: stageName,
      probabilityPct: stage.probabilityPct ?? stage.probability_pct ?? 0,
      color: stage.color || '#38bdf8',
      deals: stageDeals,
    };
  });

  const knownStageIds = new Set(
    columns.map(column => column.stageId).filter(Boolean)
  );
  const unmatchedDeals = deals.value.filter(deal => {
    const dealStageId =
      deal.crm_pipeline_stage_id ?? deal.stageId ?? deal.stage?.id;
    return !knownStageIds.has(dealStageId) && filterDeal(deal);
  });

  if (unmatchedDeals.length) {
    columns.unshift({
      id: 'uncategorized',
      name: 'Sem etapa',
      probabilityPct: 0,
      color: '#94a3b8',
      deals: unmatchedDeals,
    });
  }

  boardColumns.value = columns;
};

const loadStages = async () => {
  if (!selectedPipelineId.value) {
    stages.value = [];
    buildBoardColumns();
    return;
  }

  const response = await CrmAPI.getPipelineStages(selectedPipelineId.value);
  stages.value = extractData(response);
  buildBoardColumns();
};

const loadCrm = async ({ silent = false } = {}) => {
  if (silent) refreshing.value = true;
  else loading.value = true;

  error.value = '';

  try {
    const pipelineResponse = await CrmAPI.getPipelines();
    pipelines.value = extractData(pipelineResponse);

    if (!selectedPipelineId.value && pipelines.value.length) {
      selectedPipelineId.value = normalizePipelineId(
        pipelines.value.find(p => p.is_default || p.isDefault)?.id ||
          pipelines.value[0].id
      );
    }

    const dealParams = {
      per_page: 200,
      page: 1,
      ...(selectedPipelineId.value
        ? { pipeline_id: selectedPipelineId.value }
        : {}),
    };

    const [dealsResponse, activitiesResponse, reasonsResponse, healthResponse] =
      await Promise.all([
        CrmAPI.getDeals(dealParams),
        CrmAPI.getActivities({ limit: 100 }),
        CrmAPI.getLossReasons(),
        CrmAPI.getHealth(),
      ]);

    deals.value = extractData(dealsResponse);
    selectedDealIds.value = selectedDealIds.value.filter(id =>
      deals.value.some(deal => deal.id === id)
    );
    activities.value = extractData(activitiesResponse);
    lossReasons.value = extractData(reasonsResponse);
    health.value = healthResponse?.data || null;

    await loadStages();
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      'Não foi possível carregar o CRM integrado.';
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};

const createDefaultPipeline = async () => {
  bootstrapping.value = true;
  error.value = '';

  try {
    const pipelineResponse = await CrmAPI.createPipeline({
      name: 'Comercial',
      slug: 'comercial',
      isDefault: true,
      position: 0,
    });

    const pipeline = pipelineResponse.data;

    await Promise.all(
      DEFAULT_STAGES.map((stage, index) =>
        CrmAPI.createPipelineStage(pipeline.id, {
          name: stage.name,
          position: index,
          probabilityPct: stage.probabilityPct,
          color: stage.color,
        })
      )
    );

    await ensureDefaultLossReasons();
    selectedPipelineId.value = normalizePipelineId(pipeline.id);
    await loadCrm();
    window.dispatchEvent(new CustomEvent('crm:pipelines:changed'));
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      'Não foi possível criar o pipeline padrão.';
  } finally {
    bootstrapping.value = false;
  }
};

const ensureDefaultLossReasons = async () => {
  if (lossReasons.value.length) return;

  await Promise.all(
    DEFAULT_LOSS_REASONS.map((label, index) =>
      CrmAPI.createLossReason({ label, position: index })
    )
  );
};

const onPipelineChange = async () => {
  selectedPipelineId.value = normalizePipelineId(selectedPipelineId.value);

  const query = { ...route.query };
  if (selectedPipelineId.value) query.pipeline_id = selectedPipelineId.value;
  else delete query.pipeline_id;

  await router.replace({ query });
  await loadCrm({ silent: true });
};

watch(
  () => route.query.pipeline_id,
  async pipelineId => {
    const nextPipelineId = normalizePipelineId(pipelineId);
    if (nextPipelineId === selectedPipelineId.value) return;

    selectedPipelineId.value = nextPipelineId;
    await loadCrm({ silent: true });
  }
);

const onDealMoved = async (event, column) => {
  if (!event.added) return;

  const deal = event.added.element;
  const previousStageId = deal.crm_pipeline_stage_id;
  const previousProbability = deal.probabilityPct ?? deal.probability_pct;
  deal.crm_pipeline_stage_id = column.stageId;
  deal.crm_pipeline_id = selectedPipelineId.value;

  try {
    if (column.stageId) {
      await CrmAPI.moveDeal(deal.id, column.stageId);
    } else {
      await CrmAPI.updateDeal(deal.id, {
        crm_pipeline_id: selectedPipelineId.value,
      });
    }
  } catch (err) {
    deal.crm_pipeline_stage_id = previousStageId;
    deal.probabilityPct = previousProbability;
    error.value =
      err?.response?.data?.message ||
      'Não foi possível mover o deal. Atualize e tente novamente.';
    await loadCrm({ silent: true });
  }
};

const recomputeScore = async deal => {
  if (!deal?.id) return;
  scoreRefreshingId.value = deal.id;

  try {
    await CrmAPI.recomputeScore(deal.id);
    window.setTimeout(() => loadCrm({ silent: true }), 1200);
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      'Não foi possível recalcular o score agora.';
  } finally {
    scoreRefreshingId.value = '';
  }
};

const isDealSelected = deal => selectedDealIds.value.includes(deal.id);

const toggleDealSelection = deal => {
  if (isDealSelected(deal)) {
    selectedDealIds.value = selectedDealIds.value.filter(id => id !== deal.id);
  } else {
    selectedDealIds.value = [...selectedDealIds.value, deal.id];
  }
};

const clearBulkSelection = () => {
  selectedDealIds.value = [];
  bulkAction.value = 'move';
  bulkStageId.value = '';
  bulkDispositionReason.value = 'invalid';
  bulkSource.value = '';
  bulkSourceDetail.value = '';
  bulkOwnerId.value = '';
  bulkLabelTitle.value = '';
};

const updateDealTitle = async ({ deal, title }) => {
  const previousTitle = deal.title;
  deal.title = title;
  buildBoardColumns();

  try {
    const response = await CrmAPI.updateDeal(deal.id, { title });
    Object.assign(deal, response?.data || {});
    buildBoardColumns();
  } catch (err) {
    deal.title = previousTitle;
    buildBoardColumns();
    error.value =
      err?.response?.data?.message || 'Não foi possível renomear o lead.';
  }
};

const isBulkActionValid = computed(() => {
  if (!selectedDeals.value.length) return false;
  if (bulkAction.value === 'move') return !!bulkStageId.value;
  if (bulkAction.value === 'discard') return !!bulkDispositionReason.value;
  if (bulkAction.value === 'update_source') return !!bulkSource.value;
  if (bulkAction.value === 'assign_owner') return !!bulkOwnerId.value;
  if (bulkAction.value === 'apply_label') return !!bulkLabelTitle.value;
  return true;
});

const applyBulkAction = async () => {
  if (!isBulkActionValid.value) return;

  bulkMoving.value = true;
  error.value = '';

  try {
    await CrmAPI.bulkActionDeals({
      deal_ids: selectedDealIds.value,
      action: bulkAction.value,
      stage_id: bulkStageId.value || undefined,
      disposition_reason: bulkDispositionReason.value || undefined,
      reason: bulkDispositionReason.value || undefined,
      source: bulkSource.value || undefined,
      source_detail: bulkSourceDetail.value || undefined,
      owner_id: bulkOwnerId.value || undefined,
      label_title: bulkLabelTitle.value || undefined,
    });
    clearBulkSelection();
    await loadCrm({ silent: true });
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      'Não foi possível mover os leads selecionados.';
  } finally {
    bulkMoving.value = false;
  }
};

const discardDeal = async ({ deal, reason = 'spam' }) => {
  if (!deal?.id) return;
  const previousStatus = deal.status;
  const previousOperationalStatus = deal.operational_status;
  deal.status = 'archived';
  deal.operational_status = reason;
  buildBoardColumns();

  try {
    await CrmAPI.discardDeal(deal.id, { reason });
    await loadCrm({ silent: true });
  } catch (err) {
    deal.status = previousStatus;
    deal.operational_status = previousOperationalStatus;
    buildBoardColumns();
    error.value =
      err?.response?.data?.message || 'Não foi possível descartar o lead.';
  }
};

const markBaseClient = async deal => {
  if (!deal?.id) return;
  const previousStatus = deal.status;
  const previousOperationalStatus = deal.operational_status;
  deal.status = 'archived';
  deal.operational_status = 'base_client';
  buildBoardColumns();

  try {
    await CrmAPI.markDealBaseClient(deal.id);
    await loadCrm({ silent: true });
  } catch (err) {
    deal.status = previousStatus;
    deal.operational_status = previousOperationalStatus;
    buildBoardColumns();
    error.value =
      err?.response?.data?.message ||
      'Não foi possível marcar como Cliente Base.';
  }
};

const openDealDrawer = deal => {
  selectedDeal.value = deal;
  showDrawer.value = true;
};

const onDrawerDealUpdated = () => {
  loadCrm({ silent: true });
};

const deleteDeal = async deal => {
  if (!deal?.id) return;
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    `Tem certeza que deseja deletar "${deal.title || 'esta oportunidade'}"?\nEssa ação não pode ser desfeita.`
  );
  if (!confirmed) return;

  try {
    await CrmAPI.deleteDeal(deal.id);
    deals.value = deals.value.filter(d => d.id !== deal.id);
    buildBoardColumns();
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      'Não foi possível deletar a oportunidade.';
  }
};

const onDealDeleted = dealId => {
  deals.value = deals.value.filter(d => d.id !== dealId);
  buildBoardColumns();
};

const purgeOrphans = async () => {
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    'Isso vai remover todos os deals que referenciam conversas que não existem mais. Continuar?'
  );
  if (!confirmed) return;

  purgingOrphans.value = true;
  try {
    const response = await CrmAPI.purgeOrphanDeals();
    const result = response?.data ?? response;
    const purgedCount = result?.purged ?? 0;
    if (purgedCount > 0) {
      await loadCrm({ silent: true });
    }
    // eslint-disable-next-line no-alert
    window.alert(result?.message || `${purgedCount} deal(s) removido(s).`);
  } catch (err) {
    error.value =
      err?.response?.data?.message || 'Não foi possível limpar deals órfãos.';
  } finally {
    purgingOrphans.value = false;
  }
};

const onApplyFilters = () => {
  buildBoardColumns();
};

const completeActivity = async activity => {
  try {
    await CrmAPI.updateActivity(activity.id, {
      completedAt: new Date().toISOString(),
    });
    activity.completedAt = new Date().toISOString();
  } catch (err) {
    error.value =
      err?.response?.data?.message || 'Não foi possível concluir a tarefa.';
  }
};

watch(showDrawer, val => {
  if (!val) selectedDeal.value = null;
});

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('agents/get');
  loadCrm();
});
</script>

<template>
  <div
    class="crm-page flex h-full w-full min-w-0 flex-col overflow-hidden bg-n-slate-2 text-n-slate-12 dark:bg-n-background"
  >
    <header
      class="border-b border-n-weak bg-n-background px-4 py-4 dark:bg-n-slate-1 sm:px-5"
    >
      <div
        class="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between"
      >
        <div class="flex min-w-0 items-start gap-3">
          <span
            class="grid size-11 flex-shrink-0 place-content-center rounded-xl bg-n-brand/10 text-n-brand"
          >
            <span class="i-lucide-kanban-square size-5" />
          </span>
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="m-0 text-xl font-semibold leading-7 text-n-slate-12">
                Pipeline Jurídico
              </h1>
              <span
                v-if="refreshing"
                class="inline-flex items-center gap-1 rounded-full bg-n-brand/10 px-2 py-0.5 text-xs font-semibold text-n-brand"
              >
                <span class="i-lucide-loader-2 size-3 animate-spin" />
                Atualizando
              </span>
            </div>
            <p class="m-0 text-sm text-n-slate-11">
              Gerencie atendimentos, leads, tarefas e priorização em um painel
              operacional.
            </p>
            <div class="mt-3 flex flex-wrap gap-2 text-xs text-n-slate-10">
              <span
                class="inline-flex items-center gap-1 rounded-full border border-n-weak bg-n-slate-1 px-2.5 py-1 dark:bg-n-slate-2"
              >
                <span class="i-lucide-git-branch size-3.5 text-n-brand" />
                {{ selectedPipeline?.name || 'Pipeline' }}
              </span>
              <span
                class="inline-flex items-center gap-1 rounded-full border border-n-weak bg-n-slate-1 px-2.5 py-1 dark:bg-n-slate-2"
              >
                <span class="i-lucide-columns-3 size-3.5 text-n-teal-9" />
                {{ pipelineStagesCount }} etapas
              </span>
              <span
                class="inline-flex items-center gap-1 rounded-full border border-n-weak bg-n-slate-1 px-2.5 py-1 dark:bg-n-slate-2"
              >
                <span class="i-lucide-filter size-3.5 text-n-amber-9" />
                {{ filteredDealsCount }} visíveis
              </span>
            </div>
          </div>
        </div>

        <div class="flex min-w-0 flex-col gap-2 xl:min-w-[42rem]">
          <div v-if="pipelines.length" class="relative min-w-0">
            <select
              v-model="selectedPipelineId"
              class="h-11 w-full appearance-none rounded-xl border border-n-weak bg-n-slate-1 px-3 pr-10 text-sm font-medium text-n-slate-12 outline-none transition-colors duration-150 hover:border-n-slate-7 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 dark:bg-n-slate-2"
              @change="onPipelineChange"
            >
              <option
                v-for="pipeline in pipelines"
                :key="pipeline.id"
                :value="pipeline.id"
              >
                {{ pipeline.name }}
              </option>
            </select>
            <span
              class="i-lucide-chevron-down pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-9"
            />
          </div>
          <div class="flex flex-wrap justify-start gap-2 xl:justify-end">
            <button
              v-if="pipelines.length && !lossReasons.length"
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-amber-6 bg-n-amber-2 px-3 text-sm font-medium text-n-amber-11 transition-colors duration-150 hover:bg-n-amber-3"
              @click="
                ensureDefaultLossReasons().then(() => loadCrm({ silent: true }))
              "
            >
              <span class="i-lucide-circle-alert size-4" />
              Motivos padrão
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm font-medium text-n-slate-12 transition-colors duration-150 hover:bg-n-slate-3 dark:bg-n-slate-2"
              @click="
                $router.push({
                  name: 'crm_pipeline_settings',
                  params: { accountId },
                })
              "
            >
              <span class="i-lucide-settings size-4" />
              Configurações
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm font-medium text-n-slate-12 transition-colors duration-150 hover:bg-n-slate-3 disabled:opacity-60 dark:bg-n-slate-2"
              :disabled="refreshing"
              @click="loadCrm({ silent: true })"
            >
              <span
                class="size-4"
                :class="
                  refreshing
                    ? 'i-lucide-loader-2 animate-spin'
                    : 'i-lucide-refresh-cw'
                "
              />
              Atualizar
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm font-medium text-n-slate-12 transition-colors duration-150 hover:bg-n-slate-3 dark:bg-n-slate-2"
              @click="
                $router.push({ name: 'crm_metrics', params: { accountId } })
              "
            >
              <span class="i-lucide-bar-chart-3 size-4" />
              Métricas
            </button>
            <button
              v-if="pipelines.length"
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-ruby-7 bg-n-ruby-2/0 px-3 text-sm font-medium text-n-ruby-9 transition-colors duration-150 hover:bg-n-ruby-2 disabled:opacity-60 dark:border-n-ruby-8 dark:text-n-ruby-8 dark:hover:bg-n-ruby-3"
              :disabled="purgingOrphans"
              @click="purgeOrphans"
            >
              <span
                class="size-4"
                :class="
                  purgingOrphans
                    ? 'i-lucide-loader-2 animate-spin'
                    : 'i-lucide-trash-2'
                "
              />
              {{ purgingOrphans ? 'Limpando...' : 'Limpar órfãos' }}
            </button>
          </div>
        </div>
      </div>
    </header>

    <div
      class="border-b border-n-weak bg-n-slate-1 px-3 py-2 dark:bg-n-slate-2 sm:px-4"
    >
      <div
        class="grid min-w-0 items-center gap-2 rounded-xl border border-n-weak bg-n-background p-2 shadow-sm dark:bg-n-slate-1 md:grid-cols-[minmax(16rem,1.25fr)_minmax(11rem,0.7fr)_minmax(11rem,0.7fr)_auto_auto]"
      >
        <label class="relative min-w-0">
          <span
            class="pointer-events-none absolute left-3 top-1/2 grid size-5 -translate-y-1/2 place-content-center rounded-md bg-n-brand/10 text-n-brand"
          >
            <span class="i-lucide-search size-3.5" />
          </span>
          <input
            v-model="filterSearch"
            type="search"
            placeholder="Buscar deal ou contato"
            class="h-9 w-full rounded-lg border border-transparent bg-n-slate-1 pl-10 pr-3 text-sm font-medium text-n-slate-12 outline-none transition-colors duration-150 placeholder:text-n-slate-9 hover:border-n-slate-6 focus:border-n-brand focus:bg-n-background focus:ring-2 focus:ring-n-brand/15 dark:bg-n-slate-2 dark:focus:bg-n-slate-1"
            @input="onApplyFilters"
          />
        </label>

        <label class="relative min-w-0">
          <span
            class="pointer-events-none absolute left-3 top-1/2 size-3.5 -translate-y-1/2 text-n-slate-9"
          >
            <span class="i-lucide-scale size-3.5" />
          </span>
          <select
            v-model="filterÁrea"
            class="h-9 w-full appearance-none rounded-lg border border-transparent bg-n-slate-1 pl-8 pr-8 text-sm font-medium text-n-slate-12 outline-none transition-colors duration-150 hover:border-n-slate-6 focus:border-n-brand focus:bg-n-background focus:ring-2 focus:ring-n-brand/15 dark:bg-n-slate-2 dark:focus:bg-n-slate-1"
            @change="onApplyFilters"
          >
            <option
              v-for="opt in LEGAL_AREAS"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
          <span
            class="i-lucide-chevron-down pointer-events-none absolute right-2.5 top-1/2 size-4 -translate-y-1/2 text-n-slate-9"
          />
        </label>

        <label class="relative min-w-0">
          <span
            class="pointer-events-none absolute left-3 top-1/2 size-3.5 -translate-y-1/2 text-n-slate-9"
          >
            <span class="i-lucide-siren size-3.5" />
          </span>
          <select
            v-model="filterUrgency"
            class="h-9 w-full appearance-none rounded-lg border border-transparent bg-n-slate-1 pl-8 pr-8 text-sm font-medium text-n-slate-12 outline-none transition-colors duration-150 hover:border-n-slate-6 focus:border-n-brand focus:bg-n-background focus:ring-2 focus:ring-n-brand/15 dark:bg-n-slate-2 dark:focus:bg-n-slate-1"
            @change="onApplyFilters"
          >
            <option
              v-for="opt in URGENCY_LEVELS"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
          <span
            class="i-lucide-chevron-down pointer-events-none absolute right-2.5 top-1/2 size-4 -translate-y-1/2 text-n-slate-9"
          />
        </label>

        <button
          v-if="hasActiveFilters"
          type="button"
          class="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg border border-n-ruby-6 bg-n-ruby-2 px-3 text-xs font-semibold text-n-ruby-9 transition-colors duration-150 hover:bg-n-ruby-3"
          @click="clearFilters"
        >
          <span class="i-lucide-x size-3.5" />
          Limpar
        </button>

        <span
          class="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg border border-n-weak bg-n-slate-1 px-3 text-xs font-semibold text-n-slate-11 dark:bg-n-slate-2"
        >
          <span class="i-lucide-filter size-3.5 text-n-brand" />
          {{ filteredDealsCount }} resultado(s)
        </span>
      </div>
    </div>

    <div class="hidden">
      <div class="crm-filter-bar__search-wrap relative min-w-0 flex-1 basis-72">
        <span
          class="crm-filter-bar__search-icon i-lucide-search pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-n-brand"
        />
        <input
          v-model="filterSearch"
          type="search"
          placeholder="Buscar deal, contato..."
          class="crm-filter-bar__input crm-filter-bar__input--search h-10 w-full rounded-xl border border-n-weak bg-n-background pl-10 pr-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 placeholder:text-n-slate-9 hover:border-n-slate-7 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 dark:bg-n-slate-1"
          @input="onApplyFilters"
        />
      </div>

      <div class="relative min-w-0 flex-1 basis-56">
        <select
          v-model="filterÁrea"
          class="h-10 w-full appearance-none rounded-xl border border-n-weak bg-n-background px-3 pr-9 text-sm text-n-slate-12 outline-none transition-colors duration-150 hover:border-n-slate-7 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 dark:bg-n-slate-1"
          @change="onApplyFilters"
        >
          <option
            v-for="opt in LEGAL_AREAS"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </option>
        </select>
        <span
          class="i-lucide-chevron-down pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-9"
        />
      </div>

      <div class="relative min-w-0 flex-1 basis-56">
        <select
          v-model="filterUrgency"
          class="h-10 w-full appearance-none rounded-xl border border-n-weak bg-n-background px-3 pr-9 text-sm text-n-slate-12 outline-none transition-colors duration-150 hover:border-n-slate-7 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 dark:bg-n-slate-1"
          @change="onApplyFilters"
        >
          <option
            v-for="opt in URGENCY_LEVELS"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </option>
        </select>
        <span
          class="i-lucide-chevron-down pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-9"
        />
      </div>

      <button
        v-if="hasActiveFilters"
        type="button"
        class="inline-flex h-10 items-center gap-1.5 rounded-xl border border-n-ruby-6 bg-n-ruby-2 px-3 text-sm font-medium text-n-ruby-9 transition-colors duration-150 hover:bg-n-ruby-3"
        @click="clearFilters"
      >
        <span class="i-lucide-x size-3" />
        Limpar
      </button>

      <span
        class="inline-flex h-10 items-center rounded-xl border border-n-weak bg-n-background px-3 text-sm font-semibold text-n-slate-11 dark:bg-n-slate-1"
      >
        {{ filteredDealsCount }} resultado(s)
      </span>
    </div>

    <div
      v-if="selectedDeals.length"
      class="flex flex-wrap items-center gap-2.5 min-w-0 border-b border-n-weak bg-n-brand/5 px-5 py-2.5"
    >
      <div
        class="inline-flex min-w-0 items-center gap-2 text-sm font-medium text-n-brand"
      >
        <span class="i-lucide-check-square size-4" />
        <strong>{{ selectedDeals.length }} lead(s) selecionado(s)</strong>
      </div>
      <select
        v-model="bulkAction"
        class="h-9 flex-1 basis-48 min-w-0 max-w-xs rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
      >
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
        class="h-9 flex-1 basis-48 min-w-0 max-w-xs rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
      >
        <option value="">Escolha a etapa</option>
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>
      <select
        v-if="bulkAction === 'discard'"
        v-model="bulkDispositionReason"
        class="h-9 flex-1 basis-48 min-w-0 max-w-xs rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
      >
        <option
          v-for="reason in DISPOSITION_REASONS"
          :key="reason.value"
          :value="reason.value"
        >
          {{ reason.label }}
        </option>
      </select>
      <template v-if="bulkAction === 'update_source'">
        <select
          v-model="bulkSource"
          class="h-9 flex-1 basis-48 min-w-0 max-w-xs rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
        >
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
          class="h-9 flex-1 basis-56 min-w-0 max-w-sm rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
          type="text"
          placeholder="Campanha, anúncio, planilha..."
        />
      </template>
      <select
        v-if="bulkAction === 'assign_owner'"
        v-model="bulkOwnerId"
        class="h-9 flex-1 basis-48 min-w-0 max-w-xs rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
      >
        <option value="">Escolha o responsável</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name || agent.email }}
        </option>
      </select>
      <select
        v-if="bulkAction === 'apply_label'"
        v-model="bulkLabelTitle"
        class="h-9 flex-1 basis-48 min-w-0 max-w-xs rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm text-n-slate-12 outline-none transition-colors duration-150 focus:border-n-brand"
      >
        <option value="">Escolha a etiqueta</option>
        <option v-for="label in labels" :key="label.id" :value="label.title">
          {{ label.display_title || label.title }}
        </option>
      </select>
      <button
        type="button"
        class="inline-flex min-h-9 items-center justify-center rounded-lg border border-n-brand bg-n-brand px-3.5 text-sm font-bold text-white transition-colors duration-150 hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="!isBulkActionValid || bulkMoving"
        @click="applyBulkAction"
      >
        {{ bulkMoving ? 'Aplicando...' : 'Aplicar' }}
      </button>
      <button
        type="button"
        class="inline-flex min-h-9 items-center justify-center rounded-lg border border-n-weak bg-n-slate-1 px-3.5 text-sm font-bold text-n-slate-11 transition-colors duration-150 hover:bg-n-slate-3 disabled:cursor-not-allowed disabled:opacity-50"
        @click="clearBulkSelection"
      >
        Limpar seleção
      </button>
    </div>

    <section class="hidden">
      <article
        class="crm-metric grid min-w-0 gap-1.5 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
      >
        <span class="text-xs font-medium uppercase text-n-slate-10"
          >Atendimentos</span
        >
        <strong class="text-xl leading-tight text-n-slate-12">{{
          deals.length
        }}</strong>
      </article>
      <article
        class="crm-metric grid min-w-0 gap-1.5 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
      >
        <span class="text-xs font-medium uppercase text-n-slate-10"
          >Ganhos</span
        >
        <strong class="text-xl leading-tight text-n-teal-10">{{
          wonDeals
        }}</strong>
      </article>
      <article
        class="crm-metric grid min-w-0 gap-1.5 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
      >
        <span class="text-xs font-medium uppercase text-n-slate-10">
          Tarefas pendentes
        </span>
        <strong class="text-xl leading-tight text-n-brand">{{
          pendingActivities
        }}</strong>
      </article>
      <article
        class="crm-metric grid min-w-0 gap-1.5 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
      >
        <span class="text-xs font-medium uppercase text-n-slate-10">
          Score médio
        </span>
        <strong class="text-xl leading-tight text-n-slate-12">{{
          averageScore
        }}</strong>
      </article>
      <article
        class="crm-metric grid min-w-0 gap-1.5 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
      >
        <span class="text-xs font-medium uppercase text-n-slate-10">
          Vencidas
        </span>
        <strong
          class="text-xl leading-tight"
          :class="overdueCount ? 'text-n-ruby-9' : 'text-n-slate-12'"
        >
          {{ overdueCount }}
        </strong>
      </article>
      <article
        class="crm-metric grid min-w-0 gap-1.5 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
      >
        <span class="text-xs font-medium uppercase text-n-slate-10">
          Perdas
        </span>
        <strong class="text-xl leading-tight text-n-amber-10">
          {{ lossReasons.length }}
        </strong>
      </article>
    </section>

    <section v-if="health" class="hidden">
      <div class="flex flex-col gap-3 lg:flex-row lg:items-center">
        <div class="flex min-w-[12rem] items-center gap-2">
          <span
            class="grid size-9 place-content-center rounded-lg"
            :class="
              healthStatus === 'ok'
                ? 'bg-n-teal-3 text-n-teal-10'
                : 'bg-n-amber-3 text-n-amber-10'
            "
          >
            <span
              :class="
                healthStatus === 'ok'
                  ? 'i-lucide-shield-check'
                  : 'i-lucide-triangle-alert'
              "
              class="size-5"
            />
          </span>
          <div>
            <p class="m-0 text-sm font-semibold text-n-slate-12">
              {{ healthStatusLabel }}
            </p>
            <p class="m-0 text-xs text-n-slate-10">Check-up CRM/Captain</p>
          </div>
        </div>

        <div class="grid flex-1 gap-2 sm:grid-cols-2 xl:grid-cols-4">
          <article
            v-for="item in healthCards"
            :key="item.key"
            class="rounded-lg border border-n-weak bg-n-background px-3 py-2 shadow-sm dark:bg-n-slate-1"
          >
            <span class="block text-xs font-medium text-n-slate-10">
              {{ item.label }}
            </span>
            <strong
              class="text-lg"
              :class="{
                'text-n-ruby-9': item.tone === 'danger',
                'text-n-amber-10': item.tone === 'warn',
                'text-n-slate-12': item.tone === 'ok',
              }"
            >
              {{ item.value }}
            </strong>
          </article>
        </div>
      </div>
    </section>

    <section class="min-h-0 flex-1 overflow-y-auto p-3">
      <div
        v-if="loading"
        class="grid h-full place-content-center rounded-xl border border-n-weak bg-n-slate-1 text-sm text-n-slate-11"
      >
        Carregando CRM...
      </div>

      <div
        v-else-if="error"
        class="grid h-full place-content-center rounded-xl border border-n-ruby-7 bg-n-ruby-2 p-6 text-center"
      >
        <p class="mb-3 text-sm font-medium text-n-ruby-11">{{ error }}</p>
        <button
          type="button"
          class="mx-auto inline-flex h-10 items-center gap-2 rounded-lg bg-n-ruby-9 px-3 text-sm font-semibold text-white"
          @click="loadCrm()"
        >
          <span class="i-lucide-refresh-cw size-4" />
          Tentar novamente
        </button>
      </div>

      <div
        v-else-if="!pipelines.length"
        class="grid h-full place-content-center rounded-xl border border-dashed border-n-weak bg-n-slate-1 p-6 text-center"
      >
        <div class="mx-auto max-w-md">
          <h2 class="mb-2 text-lg font-semibold text-n-slate-12">
            Nenhum pipeline configurado
          </h2>
          <p class="mb-4 text-sm text-n-slate-11">
            Crie o pipeline comercial padrão para começar a operar o CRM dentro
            da plataforma.
          </p>
          <button
            type="button"
            class="inline-flex h-10 items-center gap-2 rounded-lg bg-n-brand px-4 text-sm font-semibold text-white disabled:opacity-60"
            :disabled="bootstrapping"
            @click="createDefaultPipeline"
          >
            <span class="i-lucide-plus size-4" />
            {{ bootstrapping ? 'Criando...' : 'Criar pipeline padrão' }}
          </button>
        </div>
      </div>

      <div v-else class="flex flex-col gap-2">
        <section
          class="rounded-xl border border-n-weak bg-n-background p-2.5 shadow-sm dark:bg-n-slate-1"
        >
          <div
            class="grid gap-2 [grid-template-columns:repeat(auto-fit,minmax(8.75rem,1fr))]"
          >
            <article
              v-for="card in summaryMetricCards"
              :key="card.key"
              class="relative isolate flex min-h-[4.75rem] flex-col items-center justify-center overflow-hidden rounded-xl border px-3 py-2 text-center shadow-sm transition-all duration-150 hover:-translate-y-0.5 hover:shadow-md dark:bg-n-slate-2"
              :class="summaryToneClasses[card.tone]?.card"
            >
              <span
                class="absolute inset-x-0 top-0 h-0.5"
                :class="summaryToneClasses[card.tone]?.accent"
              />
              <span
                class="mb-1 grid size-7 place-content-center rounded-lg"
                :class="summaryToneClasses[card.tone]?.icon"
              >
                <span class="size-3.5" :class="card.icon" />
              </span>
              <span
                class="max-w-full text-[0.64rem] font-semibold uppercase leading-[0.78rem] tracking-wide text-n-slate-10 line-clamp-2"
              >
                {{ card.label }}
              </span>
              <strong
                class="mt-0.5 text-lg font-bold leading-5 tabular-nums"
                :class="summaryToneClasses[card.tone]?.value"
              >
                {{ card.value }}
              </strong>
            </article>
          </div>

          <div
            class="mt-2 flex min-h-9 flex-wrap items-center gap-2 rounded-lg border border-n-weak bg-n-slate-1 px-2.5 py-1.5 dark:bg-n-slate-2"
          >
            <span
              class="inline-flex items-center gap-1.5 text-xs font-semibold text-n-slate-12"
            >
              <span class="i-lucide-calendar-clock size-3.5 text-n-brand" />
              Proximas tarefas
            </span>
            <span
              v-if="!upcomingActivities.length && !overdueActivities.length"
              class="text-xs text-n-slate-10"
            >
              Nenhuma tarefa pendente.
            </span>
            <template v-else>
              <article
                v-for="activity in [
                  ...overdueActivities,
                  ...upcomingActivities,
                ].slice(0, 3)"
                :key="activity.id"
                class="max-w-64 truncate rounded-md border border-n-weak bg-n-background px-2 py-1 text-xs font-medium text-n-slate-11 dark:bg-n-slate-1"
                :class="{
                  'border-n-ruby-6 bg-n-ruby-2 text-n-ruby-11':
                    overdueActivities.includes(activity),
                }"
                :title="activity.title"
              >
                {{ activity.title }}
              </article>
            </template>
          </div>
        </section>

        <div class="hidden">
          <div
            class="flex min-w-40 items-center gap-2 rounded-lg border border-n-weak bg-n-slate-1 px-2.5 py-1.5 shadow-sm dark:bg-n-slate-2"
          >
            <span
              class="grid size-7 place-content-center rounded-md"
              :class="
                healthStatus === 'ok'
                  ? 'bg-n-teal-3 text-n-teal-10'
                  : 'bg-n-amber-3 text-n-amber-10'
              "
            >
              <span
                :class="
                  healthStatus === 'ok'
                    ? 'i-lucide-shield-check'
                    : 'i-lucide-triangle-alert'
                "
                class="size-4"
              />
            </span>
            <div class="min-w-0">
              <p class="m-0 truncate text-xs font-semibold text-n-slate-12">
                {{ healthStatusLabel }}
              </p>
              <p class="m-0 truncate text-[0.68rem] text-n-slate-10">
                CRM/Captain
              </p>
            </div>
          </div>

          <article
            class="group flex min-w-32 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm transition-colors hover:border-n-brand/30 dark:from-n-slate-1 dark:to-n-slate-2"
          >
            <span
              class="grid size-6 flex-shrink-0 place-content-center rounded-md bg-n-brand/10 text-n-brand"
            >
              <span class="i-lucide-message-circle size-3.5" />
            </span>
            <div class="min-w-0">
              <span
                class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >Atendimentos</span
              >
              <strong class="block text-sm leading-4 text-n-slate-12">{{
                deals.length
              }}</strong>
            </div>
          </article>
          <article
            class="group flex min-w-28 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm transition-colors hover:border-n-teal-8/40 dark:from-n-slate-1 dark:to-n-slate-2"
          >
            <span
              class="grid size-6 flex-shrink-0 place-content-center rounded-md bg-n-teal-3 text-n-teal-10"
            >
              <span class="i-lucide-trophy size-3.5" />
            </span>
            <div class="min-w-0">
              <span
                class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >Ganhos</span
              >
              <strong class="block text-sm leading-4 text-n-teal-10">{{
                wonDeals
              }}</strong>
            </div>
          </article>
          <article
            class="group flex min-w-28 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm transition-colors hover:border-n-brand/30 dark:from-n-slate-1 dark:to-n-slate-2"
          >
            <span
              class="grid size-6 flex-shrink-0 place-content-center rounded-md bg-n-brand/10 text-n-brand"
            >
              <span class="i-lucide-list-checks size-3.5" />
            </span>
            <div class="min-w-0">
              <span
                class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >Tarefas</span
              >
              <strong class="block text-sm leading-4 text-n-brand">{{
                pendingActivities
              }}</strong>
            </div>
          </article>
          <article
            class="group flex min-w-28 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm transition-colors hover:border-n-slate-7 dark:from-n-slate-1 dark:to-n-slate-2"
          >
            <span
              class="grid size-6 flex-shrink-0 place-content-center rounded-md bg-n-slate-3 text-n-slate-11"
            >
              <span class="i-lucide-gauge size-3.5" />
            </span>
            <div class="min-w-0">
              <span
                class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >Score</span
              >
              <strong class="block text-sm leading-4 text-n-slate-12">{{
                averageScore
              }}</strong>
            </div>
          </article>
          <article
            class="group flex min-w-28 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm transition-colors hover:border-n-ruby-8/40 dark:from-n-slate-1 dark:to-n-slate-2"
          >
            <span
              class="grid size-6 flex-shrink-0 place-content-center rounded-md"
              :class="
                overdueCount
                  ? 'bg-n-ruby-3 text-n-ruby-10'
                  : 'bg-n-slate-3 text-n-slate-10'
              "
            >
              <span class="i-lucide-clock-alert size-3.5" />
            </span>
            <div class="min-w-0">
              <span
                class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >Vencidas</span
              >
              <strong
                class="block text-sm leading-4"
                :class="overdueCount ? 'text-n-ruby-9' : 'text-n-slate-12'"
              >
                {{ overdueCount }}
              </strong>
            </div>
          </article>
          <article
            class="group flex min-w-28 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm transition-colors hover:border-n-amber-8/40 dark:from-n-slate-1 dark:to-n-slate-2"
          >
            <span
              class="grid size-6 flex-shrink-0 place-content-center rounded-md bg-n-amber-3 text-n-amber-10"
            >
              <span class="i-lucide-circle-slash size-3.5" />
            </span>
            <div class="min-w-0">
              <span
                class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >Perdas</span
              >
              <strong class="block text-sm leading-4 text-n-amber-10">
                {{ lossReasons.length }}
              </strong>
            </div>
          </article>

          <template v-if="health">
            <article
              v-for="item in healthCards"
              :key="item.key"
              class="flex min-w-44 items-center gap-2 rounded-lg border border-n-weak bg-gradient-to-br from-n-background to-n-slate-1 px-2.5 py-1.5 shadow-sm dark:from-n-slate-1 dark:to-n-slate-2"
            >
              <span
                class="size-2 flex-shrink-0 rounded-full"
                :class="{
                  'bg-n-ruby-9': item.tone === 'danger',
                  'bg-n-amber-9': item.tone === 'warn',
                  'bg-n-teal-9': item.tone === 'ok',
                }"
              />
              <div class="min-w-0">
                <span
                  class="block truncate text-[0.62rem] font-medium uppercase leading-3 text-n-slate-10"
                >
                  {{ item.label }}
                </span>
                <strong
                  class="block text-sm leading-4"
                  :class="{
                    'text-n-ruby-9': item.tone === 'danger',
                    'text-n-amber-10': item.tone === 'warn',
                    'text-n-slate-12': item.tone === 'ok',
                  }"
                >
                  {{ item.value }}
                </strong>
              </div>
            </article>
          </template>

          <div
            class="ml-auto flex min-w-72 items-center gap-2 rounded-lg bg-n-slate-2 px-2.5 py-1.5 dark:bg-n-slate-2"
          >
            <span class="text-xs font-semibold text-n-slate-12">
              Proximas
            </span>
            <span
              v-if="!upcomingActivities.length && !overdueActivities.length"
              class="truncate text-xs text-n-slate-10"
            >
              Nenhuma tarefa pendente.
            </span>
            <div v-else class="flex min-w-0 gap-1.5 overflow-hidden">
              <article
                v-for="activity in [
                  ...overdueActivities,
                  ...upcomingActivities,
                ].slice(0, 2)"
                :key="activity.id"
                class="max-w-36 truncate rounded-md border border-n-weak bg-n-background px-2 py-1 text-xs text-n-slate-11 dark:bg-n-slate-1"
                :class="{
                  'border-n-ruby-6 bg-n-ruby-2 text-n-ruby-11':
                    overdueActivities.includes(activity),
                }"
                :title="activity.title"
              >
                {{ activity.title }}
              </article>
            </div>
          </div>
        </div>
        <!-- Cabeçalho do pipeline + Visão geral + Próximas tarefas -->
        <div class="hidden">
          <!-- Visão geral -->
          <div
            class="flex min-w-0 flex-wrap items-center gap-4 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
          >
            <div>
              <p class="m-0 text-xs font-medium uppercase text-n-slate-10">
                {{ selectedPipeline?.name || 'Pipeline' }}
              </p>
              <p class="m-0 text-xs text-n-slate-10">
                {{ wonDeals }} ganhos · {{ deals.length }} ativos
              </p>
            </div>
            <div class="hidden h-8 w-px bg-n-weak sm:block" />
            <div class="flex flex-col gap-0.5">
              <span
                class="text-[0.7rem] font-medium uppercase tracking-wider text-n-slate-10"
                >Tarefas vencidas</span
              >
              <strong
                class="text-xl font-bold leading-none"
                :class="
                  overdueActivities.length ? 'text-n-ruby-9' : 'text-n-slate-12'
                "
                >{{ overdueActivities.length }}</strong
              >
            </div>
            <div class="flex flex-col gap-0.5">
              <span
                class="text-[0.7rem] font-medium uppercase tracking-wider text-n-slate-10"
                >Motivos de perda</span
              >
              <strong class="text-xl font-bold leading-none text-n-slate-12">{{
                lossReasons.length
              }}</strong>
            </div>
          </div>

          <!-- Próximas tarefas (horizontal) -->
          <div
            class="min-w-0 rounded-xl border border-n-weak bg-n-background p-3.5 shadow-sm dark:bg-n-slate-1"
          >
            <div class="mb-2 flex items-center justify-between">
              <h3 class="m-0 text-sm font-semibold text-n-slate-12">
                Próximas tarefas
              </h3>
            </div>
            <div
              v-if="!upcomingActivities.length && !overdueActivities.length"
              class="text-sm text-n-slate-10"
            >
              Nenhuma tarefa pendente.
            </div>
            <div class="flex gap-2 overflow-x-auto pb-1">
              <article
                v-for="activity in [
                  ...overdueActivities,
                  ...upcomingActivities,
                ].slice(0, 8)"
                :key="activity.id"
                class="w-44 flex-shrink-0 rounded-lg border border-n-weak bg-n-slate-2 p-2 flex flex-col gap-1 dark:bg-n-slate-2"
                :class="{
                  'border-n-ruby-6 bg-n-ruby-2':
                    overdueActivities.includes(activity),
                }"
              >
                <p
                  class="m-0 line-clamp-2 overflow-hidden text-xs font-medium leading-snug text-n-slate-12"
                >
                  {{ activity.title }}
                </p>
                <div class="flex items-center justify-between gap-2">
                  <span class="text-xs text-n-slate-10">
                    {{
                      activity.dueAt
                        ? new Date(activity.dueAt).toLocaleDateString('pt-BR')
                        : 'Sem prazo'
                    }}
                  </span>
                  <button
                    type="button"
                    class="grid size-6 flex-shrink-0 place-content-center rounded border border-n-weak text-n-slate-11 hover:bg-n-slate-3"
                    @click="completeActivity(activity)"
                  >
                    <span class="i-lucide-check size-3" />
                  </button>
                </div>
              </article>
            </div>
          </div>
        </div>

        <section
          class="flex min-h-[calc(100vh-12rem)] flex-col overflow-hidden rounded-xl border border-n-weak bg-n-background shadow-sm dark:bg-n-slate-1"
        >
          <div
            class="flex flex-wrap items-center justify-between gap-2 border-b border-n-weak px-3.5 py-3"
          >
            <div>
              <p class="m-0 text-xs font-medium uppercase text-n-slate-10">
                {{ selectedPipeline?.name || 'Pipeline' }}
              </p>
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                Quadro Kanban
              </h2>
            </div>
            <span
              class="inline-flex items-center gap-1 rounded-full bg-n-slate-2 px-2.5 py-1 text-xs font-medium text-n-slate-10 dark:bg-n-slate-3"
            >
              <span class="i-lucide-move-horizontal size-3.5" />
              Arraste o fundo para navegar
            </span>
          </div>
          <div
            ref="kanbanViewportRef"
            class="max-w-full flex-1 overflow-auto p-3 min-h-[560px]"
            :class="
              isPanningBoard ? 'cursor-grabbing select-none' : 'cursor-grab'
            "
            @pointerdown="onBoardPointerDown"
            @pointermove="onBoardPointerMove"
            @pointerup="stopBoardPan"
            @pointercancel="stopBoardPan"
            @pointerleave="stopBoardPan"
          >
            <div class="flex h-full min-w-max gap-3">
              <section
                v-for="column in boardColumns"
                :key="column.id"
                class="crm-column flex w-80 flex-shrink-0 flex-col overflow-hidden rounded-xl border border-n-weak bg-n-slate-1 h-full dark:bg-n-slate-2"
              >
                <header
                  class="flex items-center gap-2 border-b border-n-weak bg-n-background px-3 py-3 dark:bg-n-slate-1"
                >
                  <span
                    class="h-8 w-1 rounded-full"
                    :style="{ backgroundColor: column.color }"
                  />
                  <div class="min-w-0 flex-1">
                    <h3
                      class="m-0 truncate text-sm font-semibold text-n-slate-12"
                    >
                      {{ column.name }}
                    </h3>
                    <p class="m-0 text-xs text-n-slate-10">
                      {{ column.probabilityPct }}% probabilidade
                    </p>
                  </div>
                  <span
                    class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs font-semibold text-n-slate-11"
                  >
                    {{ column.deals.length }}
                  </span>
                </header>

                <Draggable
                  :list="column.deals"
                  class="min-h-16 flex-1 space-y-2 overflow-y-auto p-2"
                  group="crm-deals"
                  item-key="id"
                  animation="180"
                  ghost-class="opacity-55"
                  @change="event => onDealMoved(event, column)"
                >
                  <template #item="{ element }">
                    <CRMDealCard
                      :deal="element"
                      :account-id="accountId"
                      :score-refreshing="scoreRefreshingId === element.id"
                      :selected="isDealSelected(element)"
                      @recompute-score="recomputeScore"
                      @open-drawer="openDealDrawer"
                      @delete-deal="deleteDeal"
                      @update-title="updateDealTitle"
                      @toggle-select="toggleDealSelection"
                      @discard-deal="discardDeal"
                      @mark-base-client="markBaseClient"
                    />
                  </template>
                  <template #footer>
                    <div
                      v-if="!column.deals.length"
                      class="crm-column__empty grid min-h-24 place-content-center rounded-lg border border-dashed border-n-weak bg-n-background text-xs text-n-slate-10 dark:bg-n-slate-1"
                    >
                      <span class="i-lucide-inbox mx-auto mb-1 size-4" />
                      {{
                        hasActiveFilters
                          ? 'Nenhum deal para os filtros ativos'
                          : 'Sem deals'
                      }}
                    </div>
                  </template>
                </Draggable>
              </section>
            </div>
          </div>
        </section>
      </div>
    </section>

    <!-- Deal Drawer -->
    <CRMDealDrawer
      v-if="showDrawer && selectedDeal"
      v-model:show="showDrawer"
      :deal-id="selectedDeal.id"
      @saved="onDrawerDealUpdated"
      @deal-deleted="onDealDeleted"
    />
  </div>
</template>

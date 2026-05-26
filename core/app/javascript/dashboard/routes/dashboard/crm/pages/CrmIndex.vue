<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-static-inline-styles -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import CrmAPI from 'dashboard/api/crm';
import CRMDealCard from 'dashboard/components/crm/CRMDealCard.vue';
import CRMDealDrawer from 'dashboard/components/crm/CRMDealDrawer.vue';
import CRMKanbanChatDrawer from 'dashboard/components/crm/CRMKanbanChatDrawer.vue';
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
const selectedAttendanceDeal = ref(null);
const showAttendanceDrawer = ref(false);
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

const openAttendanceDrawer = deal => {
  selectedAttendanceDeal.value = deal;
  showAttendanceDrawer.value = true;
};

const openDealDrawer = deal => {
  selectedDeal.value = deal;
  showDrawer.value = true;
  showAttendanceDrawer.value = false;
};

const onAttendanceDealUpdated = updatedDeal => {
  if (!updatedDeal?.id) return;

  const index = deals.value.findIndex(deal => deal.id === updatedDeal.id);
  if (index >= 0) {
    deals.value[index] = { ...deals.value[index], ...updatedDeal };
  } else {
    deals.value = [updatedDeal, ...deals.value];
  }

  selectedAttendanceDeal.value = {
    ...(selectedAttendanceDeal.value || {}),
    ...updatedDeal,
  };
  buildBoardColumns();
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

watch(showDrawer, val => {
  if (!val) selectedDeal.value = null;
});

watch(showAttendanceDrawer, val => {
  if (!val) selectedAttendanceDeal.value = null;
});

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('agents/get');
  loadCrm();
});
</script>

<template>
  <div
    class="crm-page crm-command-center flex h-full w-full min-w-0 flex-col overflow-hidden bg-n-slate-2 text-n-slate-12 dark:bg-n-background"
    :class="{ 'crm-page--attendance-open': showAttendanceDrawer }"
  >
    <header
      class="crm-command-header border-b border-n-weak bg-n-background px-4 py-4 dark:bg-n-slate-1 sm:px-5"
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
      class="crm-command-filters border-b border-n-weak bg-n-slate-1 px-3 py-2 dark:bg-n-slate-2 sm:px-4"
    >
      <div
        class="grid min-w-0 items-center gap-2 rounded-xl border border-n-weak bg-n-background p-2 shadow-sm dark:bg-n-slate-1 md:grid-cols-[minmax(16rem,1.25fr)_minmax(11rem,0.7fr)_minmax(11rem,0.7fr)_auto_auto]"
      >
        <label class="crm-kanban-filter-control">
          <span
            class="crm-kanban-filter-control__icon crm-kanban-filter-control__icon--search"
          >
            <span class="i-lucide-search size-3.5" />
          </span>
          <input
            v-model="filterSearch"
            type="search"
            placeholder="Buscar deal ou contato"
            class="crm-kanban-filter-control__input"
            @input="onApplyFilters"
          />
        </label>

        <label class="crm-kanban-filter-control">
          <span
            class="crm-kanban-filter-control__icon text-n-slate-9"
          >
            <span class="i-lucide-scale size-3.5" />
          </span>
          <select
            v-model="filterÁrea"
            class="crm-kanban-filter-control__select"
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
            class="crm-kanban-filter-control__chevron i-lucide-chevron-down"
          />
        </label>

        <label class="crm-kanban-filter-control">
          <span
            class="crm-kanban-filter-control__icon text-n-slate-9"
          >
            <span class="i-lucide-siren size-3.5" />
          </span>
          <select
            v-model="filterUrgency"
            class="crm-kanban-filter-control__select"
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
            class="crm-kanban-filter-control__chevron i-lucide-chevron-down"
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
          class="crm-command-kpis rounded-xl border border-n-weak bg-n-background p-2.5 shadow-sm dark:bg-n-slate-1"
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
              Próximas tarefas
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

        <section
          class="crm-command-board flex min-h-[calc(100vh-12rem)] flex-col overflow-hidden rounded-xl border border-n-weak bg-n-background shadow-sm dark:bg-n-slate-1"
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
            class="crm-kanban-board max-w-full flex-1 overflow-auto p-3 min-h-[560px]"
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
                class="crm-column crm-command-column flex w-80 flex-shrink-0 flex-col overflow-hidden rounded-xl border border-n-weak bg-n-slate-1 h-full dark:bg-n-slate-2"
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
                      @open-drawer="openAttendanceDrawer"
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

    <CRMKanbanChatDrawer
      v-if="showAttendanceDrawer && selectedAttendanceDeal"
      v-model:show="showAttendanceDrawer"
      :deal="selectedAttendanceDeal"
      :stages="stages"
      :agents="agents"
      :account-id="accountId"
      @deal-updated="onAttendanceDealUpdated"
      @open-deal-drawer="openDealDrawer"
    />
  </div>
</template>

<style scoped>
.crm-command-center {
  background:
    radial-gradient(
      circle at 16% -10%,
      rgb(var(--ds-shell-accent) / 0.12),
      transparent 24rem
    ),
    radial-gradient(
      circle at 88% 2%,
      rgb(var(--ds-shell-secondary) / 0.1),
      transparent 22rem
    ),
    rgb(var(--ds-shell-canvas));
}

.crm-command-header {
  position: sticky;
  top: 0;
  z-index: 12;
  border-color: rgb(var(--ds-shell-divider) / 0.72);
  background:
    linear-gradient(
      135deg,
      rgb(var(--ds-shell-panel-glass)),
      rgb(var(--ds-shell-panel-strong) / 0.86)
    );
  box-shadow: 0 18px 48px rgb(var(--ds-shell-shadow-soft));
  backdrop-filter: blur(18px) saturate(1.08);
}

.crm-command-filters {
  position: sticky;
  top: 6.25rem;
  z-index: 11;
  border-color: rgb(var(--ds-shell-divider) / 0.68);
  background: rgb(var(--ds-shell-panel-glass));
  backdrop-filter: blur(16px) saturate(1.08);
}

.crm-command-filters
  :is(input, select):not(.crm-kanban-filter-control__input):not(
    .crm-kanban-filter-control__select
  ),
.crm-command-header select {
  border-color: rgb(var(--ds-shell-border) / 0.62);
  background: rgb(var(--ds-shell-panel-sunken) / 0.92);
  color: rgb(var(--ds-fg-default));
}

.crm-command-filters
  :is(input, select):not(.crm-kanban-filter-control__input):not(
    .crm-kanban-filter-control__select
  ):focus,
.crm-command-header select:focus {
  border-color: rgb(var(--ds-shell-focus));
  box-shadow: 0 0 0 3px rgb(var(--ds-shell-glow));
}

.crm-kanban-filter-control {
  display: flex;
  min-width: 0;
  height: 2.5rem;
  align-items: center;
  gap: 0.55rem;
  overflow: hidden;
  border: 1px solid rgb(var(--ds-shell-border) / 0.62);
  border-radius: 0.75rem;
  background: rgb(var(--ds-shell-panel-sunken) / 0.92);
  padding: 0 0.75rem;
  color: rgb(var(--ds-fg-default));
  transition:
    border-color 0.16s ease,
    background 0.16s ease,
    box-shadow 0.16s ease;
}

.crm-kanban-filter-control:focus-within {
  border-color: rgb(var(--ds-shell-focus));
  background: rgb(var(--ds-shell-panel));
  box-shadow: 0 0 0 3px rgb(var(--ds-shell-glow));
}

.crm-kanban-filter-control__icon {
  display: grid;
  width: 1.25rem;
  height: 1.25rem;
  flex: 0 0 1.25rem;
  place-content: center;
  border-radius: 0.45rem;
  line-height: 1;
}

.crm-kanban-filter-control__icon--search {
  background: transparent;
  color: rgb(var(--ds-shell-accent));
}

.crm-kanban-filter-control__icon :deep(span),
.crm-kanban-filter-control__icon :deep(svg),
.crm-kanban-filter-control__chevron {
  display: block;
  flex: 0 0 auto;
}

.crm-kanban-filter-control__input,
.crm-kanban-filter-control__select {
  min-width: 0;
  width: 100%;
  height: 100%;
  flex: 1 1 auto;
  margin: 0;
  border: none !important;
  border-radius: 0 !important;
  background: transparent !important;
  background-color: transparent !important;
  color: rgb(var(--ds-fg-default));
  font-size: 0.875rem;
  font-weight: 600;
  outline: none !important;
  box-shadow: none !important;
  appearance: none;
  -webkit-appearance: none;
}

.crm-kanban-filter-control__input {
  padding: 0;
}

.crm-kanban-filter-control__input:focus,
.crm-kanban-filter-control__select:focus {
  border: none !important;
  outline: none !important;
  box-shadow: none !important;
}

.crm-kanban-filter-control__input::-webkit-search-cancel-button,
.crm-kanban-filter-control__input::-webkit-search-decoration,
.crm-kanban-filter-control__input::-webkit-search-results-button,
.crm-kanban-filter-control__input::-webkit-search-results-decoration {
  appearance: none;
  -webkit-appearance: none;
}

.crm-kanban-filter-control__input::placeholder {
  color: rgb(var(--slate-9));
}

.crm-kanban-filter-control__select {
  appearance: none;
  padding: 0;
}

.crm-kanban-filter-control__chevron {
  width: 1rem;
  height: 1rem;
  color: rgb(var(--slate-9));
  pointer-events: none;
}

.crm-command-kpis,
.crm-command-board,
.crm-command-column {
  border-color: rgb(var(--ds-shell-border) / 0.62);
  background: rgb(var(--ds-shell-panel-glass));
  box-shadow: 0 18px 48px rgb(var(--ds-shell-shadow-soft));
  backdrop-filter: blur(14px) saturate(1.06);
}

.crm-command-kpis article {
  border-color: rgb(var(--ds-shell-border) / 0.54);
  background:
    linear-gradient(
      180deg,
      rgb(var(--ds-shell-panel-strong) / 0.86),
      rgb(var(--ds-shell-panel) / 0.74)
    );
}

.crm-command-board > div:first-child,
.crm-command-column > header {
  border-color: rgb(var(--ds-shell-divider) / 0.7);
  background: rgb(var(--ds-shell-panel-strong) / 0.78);
}

.crm-command-column {
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 0.08);
}

.crm-command-column article[role='button'] {
  border-color: rgb(var(--ds-shell-border) / 0.58);
  background:
    linear-gradient(
      180deg,
      rgb(var(--ds-shell-panel) / 0.92),
      rgb(var(--ds-shell-panel-sunken) / 0.78)
    );
}

.crm-command-column article[role='button']:hover {
  border-color: rgb(var(--ds-shell-focus) / 0.72);
  box-shadow:
    0 16px 36px rgb(var(--ds-shell-shadow-soft)),
    0 0 0 3px rgb(var(--ds-shell-glow));
}

.crm-kanban-board {
  transition: padding-right 180ms ease;
}

@media (min-width: 1024px) {
  .crm-page--attendance-open .crm-kanban-board {
    padding-right: min(34rem, 42vw);
  }
}

@media (max-width: 1279px) {
  .crm-command-filters {
    top: 8.5rem;
  }
}

@media (max-width: 767px) {
  .crm-command-header,
  .crm-command-filters {
    position: static;
  }
}
</style>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import CrmAPI from 'dashboard/api/crm';
import CRMBoardColumn from 'dashboard/components/crm/CRMBoardColumn.vue';
import CRMBoardToolbar from 'dashboard/components/crm/CRMBoardToolbar.vue';
import CRMCreateDealDrawer from 'dashboard/components/crm/CRMCreateDealDrawer.vue';
import CRMDealCard from 'dashboard/components/crm/CRMDealCard.vue';
import CRMDealDrawer from 'dashboard/components/crm/CRMDealDrawer.vue';
import CRMKanbanChatDrawer from 'dashboard/components/crm/CRMKanbanChatDrawer.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  describeFilters,
  emptyFilters,
  removeFilter,
  toRequestParams,
} from 'dashboard/helper/crmBoardFilters';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { messageFrom } from 'dashboard/helper/crmErrors';
import { useBoardRealtime } from 'dashboard/composables/useBoardRealtime';
import { useBoardCards } from 'dashboard/composables/useBoardCards';
import { useBoardDealActions } from 'dashboard/composables/useBoardDealActions';
import { useBoardDensity } from 'dashboard/composables/useBoardDensity';
import { useBoardViews } from 'dashboard/composables/useBoardViews';
import {
  DsButton,
  DsModal,
  DsSelect,
} from 'dashboard/design-system/components';
import { BoardPageTemplate } from 'dashboard/design-system/templates';

import CRMDealsTable from '../components/CRMDealsTable.vue';
import { selectInitialCrmPipelineId } from './crmPipelineSelection';

// Precisa casar com o `per_column` que o endpoint da F1.5 usa por padrao.
const BOARD_PER_COLUMN = 25;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const agents = useMapGetter('agents/getVerifiedAgents');
const { accountId } = useAccount();

const pipelines = ref([]);
const stages = ref([]);
const deals = ref([]);
const columns = ref([]);
const lossReasons = ref([]);
const pipelineId = ref(String(route.query.pipeline_id || ''));
const search = ref(String(route.query.search || ''));
const ownerId = ref(String(route.query.owner_id || ''));
const priority = ref(String(route.query.priority || ''));
const loading = ref(true);
const refreshing = ref(false);
const saving = ref(false);
const error = ref('');
const selectedIds = ref([]);
const selectedDealId = ref(null);
const showDealDrawer = ref(false);
// F2.1-a: o chat vive dentro do quadro. O `attendanceDeal` guarda o objeto
// inteiro, e nao so o id, porque o drawer precisa do contato e da conversa
// para abrir sem uma ida extra ao servidor.
const attendanceDeal = ref(null);
const showChatDrawer = ref(false);
// §7 do plano: a densidade e do atendente, nao do produto. Fica no navegador
// dele — trocar de densidade nao e decisao que valha uma coluna no banco.
const { cardDensity, densityOptions, readStoredDensity, setDensity } =
  useBoardDensity(t);

const uiSettingsHolder = ref({});
let updateUISettingsFn = () => {};

try {
  const { uiSettings, updateUISettings } = useUISettings();
  watch(
    () => uiSettings.value,
    val => {
      uiSettingsHolder.value = val || {};
    },
    { immediate: true }
  );
  updateUISettingsFn = updateUISettings;
} catch {
  // Safe fallback para testes que mockam a store sem useStoreGetters
}

const currentView = ref(
  uiSettingsHolder.value?.crm_board_view_type || 'kanban'
);

watch(
  () => uiSettingsHolder.value?.crm_board_view_type,
  storedView => {
    if (storedView === 'kanban' || storedView === 'table') {
      currentView.value = storedView;
    }
  },
  { immediate: true }
);

const setView = mode => {
  if (!['kanban', 'table'].includes(mode)) return;
  currentView.value = mode;
  updateUISettingsFn({ crm_board_view_type: mode });
};

// Reusa o patch do realtime: ele ja sabe tirar o card de uma coluna, coloca-lo
// na outra pela `position` e mesclar por cima do que o board tinha. Duplicar
// essa logica aqui foi o que produziu o bug de o card ficar na coluna antiga
// depois de trocar a etapa pelo chat ou pela ficha.
// Contagem, soma e WIP vem do servidor (F1.5) e valem para a coluna inteira —
// nao so para os 25 cards carregados. Quando um card troca de coluna, esses
// numeros precisam acompanhar; senao o cabecalho mente ate o proximo reload, e
// o limite de WIP pode ser estourado sem o indicador acusar.
const { moveAggregates, removeDealFromBoard, patchDeal } = useBoardCards(
  columns,
  () => {
    deals.value = flattenColumns();
  }
);

const {
  discardTarget,
  dispositionReason,
  dispositionOptions,
  discard,
  markBaseClient,
  recomputeScore,
} = useBoardDealActions({
  t,
  saving,
  error,
  patchDeal,
  removeDealFromBoard,
});

const showCreateDrawer = ref(false);
const createForm = ref({
  title: '',
  contact_name: '',
  contact_phone_number: '',
  crm_pipeline_stage_id: '',
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};
const pipelineOptions = computed(() =>
  pipelines.value.map(item => ({
    value: String(item.id),
    label: item.inbox?.name ? `${item.inbox.name} · ${item.name}` : item.name,
  }))
);
const ownerOptions = computed(() => [
  { value: '', label: 'Todos os responsáveis' },
  ...agents.value.map(agent => ({
    value: String(agent.id),
    label: agent.name || agent.email || 'Responsável',
  })),
]);
// As faixas viram `score_min`/`score_max` no endpoint (F1.4). Antes eram
// comparacoes em JavaScript sobre a lista inteira.
const priorityOptions = [
  { value: '', label: 'Todas as prioridades' },
  { value: 'high', label: 'Alta prioridade (80+)', min: 80 },
  { value: 'qualified', label: 'Qualificados (60–79)', min: 60, max: 79 },
  { value: 'other', label: 'Demais leads', max: 59 },
];
const stageOptions = computed(() =>
  stages.value.map(stage => ({
    value: String(stage.id),
    label: stage.name,
  }))
);
const mobileColumnId = ref('');
const mobileColumnOptions = computed(() =>
  columns.value.map(column => ({
    value: String(column.id),
    label: `${column.name} (${column.count ?? column.deals.length})`,
  }))
);

watch(
  mobileColumnOptions,
  options => {
    if (!options.some(option => option.value === mobileColumnId.value)) {
      mobileColumnId.value = options[0]?.value || '';
    }
  },
  { immediate: true }
);
const selectedPipeline = computed(() =>
  pipelines.value.find(item => String(item.id) === pipelineId.value)
);
const selectedCount = computed(() => selectedIds.value.length);
const hasFilters = computed(() =>
  Boolean(search.value || ownerId.value || priority.value)
);
const totalVisible = computed(() =>
  columns.value.reduce((sum, column) => sum + column.deals.length, 0)
);
const ownerName = id =>
  agents.value.find(agent => String(agent.id) === String(id))?.name ||
  'Sem responsável';
// F2.2: os criterios viram parametros do endpoint de colunas (F1.4/F1.5). O
// board nao peneira mais nada no navegador — era a lacuna K-01.
// F2.6: os 12 criterios da F1.4 num estado so. `search`, `ownerId` e
// `priority` continuam existindo porque a query string antiga usa esses nomes
// — eles alimentam o mesmo objeto.
const filters = ref(emptyFilters());

// F2.7: visoes salvas (lacuna K-05). Aplicar uma visao e trocar o estado de
// filtro inteiro — nao mesclar com o que estava, senao o atendente carrega
// resto de filtro anterior sem perceber.
// F2.8: o board responde outra pergunta conforme o agrupamento. `movable` vem
// do servidor: arrastar entre faixas de score nao salvaria nada, porque score
// e calculado, nao escolhido.
const GROUP_BY_DEFAULT = 'stage';
const groupBy = ref(GROUP_BY_DEFAULT);
const isMovable = ref(true);

const emptyTitle = computed(() =>
  groupBy.value === GROUP_BY_DEFAULT
    ? t('CRM.BOARD.EMPTY_STAGES')
    : t('CRM.BOARD.EMPTY_GROUPED')
);

const groupByOptions = computed(() => [
  { value: 'stage', label: t('CRM.GROUP_BY.STAGE') },
  { value: 'owner', label: t('CRM.GROUP_BY.OWNER') },
  { value: 'score_band', label: t('CRM.GROUP_BY.SCORE_BAND') },
  { value: 'legal_area', label: t('CRM.GROUP_BY.LEGAL_AREA') },
  { value: 'source', label: t('CRM.GROUP_BY.SOURCE') },
  { value: 'operational_status', label: t('CRM.GROUP_BY.OPERATIONAL_STATUS') },
]);

const changeGrouping = async value => {
  groupBy.value = value;
  await loadCrm({ silent: true });
};

const {
  boardViews,
  activeViewId,
  loadBoardViews,
  applyView,
  toggleViewSharing,
  promptForViewName,
  confirmDeleteView,
} = useBoardViews({
  t,
  readFilters: () => toRequestParams(filters.value),
  // Aplicar uma visao e trocar os filtros e repintar: quem sabe fazer isso e a
  // pagina, nao o composable.
  onApply: async saved => {
    filters.value = { ...emptyFilters(), ...saved };
    syncLegacyFilterRefs();
    await loadCrm({ silent: true });
  },
  onError: message => {
    error.value = message;
  },
});

const boardFilters = () => toRequestParams(filters.value);

const filterPills = computed(() =>
  describeFilters(filters.value, {
    stages: stages.value,
    owners: agents.value,
    labels: [],
  })
);

// O contador responde "o filtro me deixou com quantos?" — soma o total de
// cada coluna, que vem do servidor e vale para a coluna inteira.
const filteredTotal = computed(() =>
  columns.value.reduce((total, column) => total + Number(column.count || 0), 0)
);

const dropFilter = async key => {
  filters.value = removeFilter(filters.value, key);
  syncLegacyFilterRefs();
  await loadCrm({ silent: true });
};

const clearAllFilters = async () => {
  filters.value = emptyFilters();
  syncLegacyFilterRefs();
  await loadCrm({ silent: true });
};

// A barra de busca e os dois selects do toolbar escrevem em `search`,
// `ownerId` e `priority`; o estado de verdade e `filters`.
const pullLegacyFilterRefs = () => {
  const band = priorityOptions.find(item => item.value === priority.value);

  filters.value = {
    ...filters.value,
    q: search.value.trim(),
    owner_id: ownerId.value ? [ownerId.value] : [],
    score_min: band?.min ?? null,
    score_max: band?.max ?? null,
  };
};

const syncLegacyFilterRefs = () => {
  search.value = filters.value.q || '';
  ownerId.value = filters.value.owner_id[0] || '';
  priority.value =
    priorityOptions.find(
      item =>
        (item.min ?? null) === filters.value.score_min &&
        (item.max ?? null) === filters.value.score_max
    )?.value || '';
};
// As colunas chegam prontas do servidor, com contagem, soma e tempo medio da
// coluna inteira — nao do punhado que coube na primeira pagina.
const applyBoard = payload => {
  // O servidor e quem diz se o agrupamento aceita arrasto (F2.8).
  isMovable.value = payload?.meta?.movable !== false;
  groupBy.value = payload?.meta?.group_by || GROUP_BY_DEFAULT;

  columns.value = (payload?.columns || []).map(column => ({
    ...column,
    deals: [...(column.deals || [])],
  }));

  // As colunas **sao** as etapas ativas, na ordem do board. Buscar
  // `getPipelineStages` de novo seria uma segunda requisicao para a mesma
  // resposta — e uma chance de as duas discordarem.
  // Etapa so existe no agrupamento por etapa. Nos outros, o seletor de etapa
  // da acao em massa fica vazio de proposito ? melhor vazio que oferecendo
  // nome de responsavel no lugar de etapa.
  stages.value =
    groupBy.value === GROUP_BY_DEFAULT
      ? columns.value.map(({ deals: _deals, ...stage }) => ({
          ...stage,
          id: stage.stage_id,
        }))
      : [];
};

// Varias partes do board (selecao em massa, realtime, arrasto) raciocinam
// sobre a lista plana. Ela passa a ser derivada das colunas.
const flattenColumns = () => columns.value.flatMap(column => column.deals);
// F1.8: o evento de outra sessao vira patch na lista, sem refetch do quadro.
// `draggingDealId` marca o card que o atendente esta arrastando agora: enquanto
// estiver marcado, o evento espera na fila e entra quando ele soltar. Sem isso o
// card salta por baixo do cursor.
const draggingDealId = ref(null);
const nativeDraggingDeal = ref(null);

// Uma rajada (importacao, automacao em massa) viraria uma requisicao por
// card. Enquanto um recarregamento esta em voo, os demais eventos apenas
// marcam que ele precisa acontecer mais uma vez ao final.
const reloadInFlight = ref(false);
const reloadQueued = ref(false);

const reloadBoard = async () => {
  if (reloadInFlight.value) {
    reloadQueued.value = true;
    return;
  }

  reloadInFlight.value = true;
  try {
    do {
      reloadQueued.value = false;
      // eslint-disable-next-line no-await-in-loop
      await loadCrm({ silent: true });
    } while (reloadQueued.value);
  } finally {
    reloadInFlight.value = false;
  }
};

const { flushPendingDealEvents } = useBoardRealtime({
  getColumns: () => columns.value,
  setColumns: next => {
    columns.value = next;
    deals.value = flattenColumns();
  },
  getAccountId: () => accountId.value,
  isBusy: dealId => String(dealId) === String(draggingDealId.value),
  // Fora do agrupamento por etapa o patch nao sabe em que balde um negocio
  // novo cai. Perguntar de novo e a resposta honesta.
  onUnplaceable: () => reloadBoard(),
});

// Descartar nao e o mesmo que perder: o descartado nunca foi um lead de
// verdade e nao pode entrar na taxa de conversao.
// Descartado deixou o funil. Mesclar `operational_status` e manter o card no
// quadro mostrava um lead ativo que nao existe mais.
// B-12: o board recebe 25 cards por coluna (F1.5). Quem tem 1.200 negocios na
// coluna precisa alcancar o resto — e a F1.6 ja tinha construido o endpoint
// para isso, sem consumidor.
const loadingColumnIds = ref([]);

const loadMoreInColumn = async column => {
  if (loadingColumnIds.value.includes(column.id)) return;
  // Rolar para pedir mais so funciona por etapa: o endpoint da F1.6 filtra por
  // `stage_id`, e nao ha equivalente para "faixa de score".
  if (!column.stage_id) return;
  if (column.deals.length >= Number(column.count || 0)) return;

  loadingColumnIds.value = [...loadingColumnIds.value, column.id];
  try {
    const nextPage = Math.floor(column.deals.length / BOARD_PER_COLUMN) + 1;
    const response = await CrmAPI.getColumnPage(column.stage_id, {
      ...boardFilters(),
      page: nextPage,
      perPage: BOARD_PER_COLUMN,
    });

    // Uma pagina pode chegar depois de o realtime ja ter mexido na coluna, e
    // o offset da F1.6 nao sobrevive a reordenacao (divida B-08). Descartar
    // repetidos e mais barato do que mostrar o mesmo card duas vezes.
    const known = new Set(column.deals.map(deal => deal.id));
    const arriving = (response?.data?.data || []).filter(
      deal => !known.has(deal.id)
    );

    columns.value = columns.value.map(item =>
      item.id === column.id
        ? { ...item, deals: [...item.deals, ...arriving] }
        : item
    );
    deals.value = flattenColumns();
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível carregar mais negócios desta coluna.';
  } finally {
    loadingColumnIds.value = loadingColumnIds.value.filter(
      id => id !== column.id
    );
  }
};

// A coluna nao sabe mover nada: ela avisa o que aconteceu e o board decide.
const onColumnChanged = (column, payload) => {
  if (payload?.deals) {
    columns.value = columns.value.map(item =>
      item.id === column.id ? { ...item, deals: payload.deals } : item
    );
    deals.value = flattenColumns();
    return;
  }

  if (payload?.event) onDealMoved(payload.event, column);
};

const openAttendance = deal => {
  attendanceDeal.value = deal;
  showChatDrawer.value = true;
};

// O drawer troca etapa, alterna o modo da IA e marca ganho/perdido. Recarregar
// o quadro a cada uma dessas jogaria fora o ganho da F1.5; o retorno e
// mesclado no card, como o realtime da F1.8 faz.
const onAttendanceDealUpdated = updated => {
  if (!updated?.id) return;

  patchDeal(updated, updated);
  attendanceDeal.value = { ...(attendanceDeal.value || {}), ...updated };
};

// Editar e atender sao coisas diferentes: o chat cede a vez para a ficha.
const openDealFromAttendance = deal => {
  showChatDrawer.value = false;
  openDeal(deal);
};

watch(showChatDrawer, isOpen => {
  if (!isOpen) attendanceDeal.value = null;
});

const onDragStart = deal => {
  draggingDealId.value = deal?.id ?? null;
};

const onDragEnd = () => {
  draggingDealId.value = null;
  flushPendingDealEvents();
};

const onNativeDragStart = (deal, event) => {
  nativeDraggingDeal.value = deal;
  onDragStart(deal);

  if (event?.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', String(deal.id));
  }
};

const onNativeDragEnd = () => {
  nativeDraggingDeal.value = null;
  onDragEnd();
};

const syncQuery = () =>
  router.replace({
    query: {
      ...route.query,
      pipeline_id: pipelineId.value || undefined,
      search: search.value.trim() || undefined,
      owner_id: ownerId.value || undefined,
      priority: priority.value || undefined,
    },
  });
const loadCrm = async ({ silent = false } = {}) => {
  if (silent) refreshing.value = true;
  else loading.value = true;
  error.value = '';
  try {
    pipelines.value = extractData(await CrmAPI.getPipelines());
    pipelineId.value = selectInitialCrmPipelineId(
      pipelines.value,
      pipelineId.value
    );

    // Uma requisicao pinta o quadro inteiro (F1.5). Antes eram 25 para um
    // pipeline de 5.000 negocios, e todos os cards vinham para o DOM.
    const [boardResponse, reasonsResponse] = await Promise.all([
      CrmAPI.getBoard(pipelineId.value, {
        ...boardFilters(),
        group_by: groupBy.value,
      }),
      CrmAPI.getLossReasons(),
    ]);

    applyBoard(boardResponse?.data);
    deals.value = flattenColumns();
    lossReasons.value = extractData(reasonsResponse);
    selectedIds.value = selectedIds.value.filter(id =>
      deals.value.some(deal => deal.id === id)
    );
    await syncQuery();
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível carregar o pipeline.';
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};
const changePipeline = async () => {
  selectedIds.value = [];
  await loadCrm({ silent: true });
};
// Filtrar agora significa perguntar de novo ao servidor. E mais barato do que
// parece: o board devolve 25 cards por coluna, nao o pipeline.
const applyFilters = async () => {
  pullLegacyFilterRefs();
  // Mexeu no filtro a mao: o que esta na tela nao e mais a visao salva.
  activeViewId.value = null;
  await loadCrm({ silent: true });
};
const clearFilters = clearAllFilters;
// Otimismo com rollback (principio 2 do plano). Tudo imutavel: durante o
// `await`, um evento de realtime pode substituir o objeto do card em
// `columns`, e mutar a referencia capturada aqui mexeria num orfao.
const onDealMoved = async (event, column) => {
  const moved = event?.added?.element;
  if (!moved?.id || !column?.id) return;

  // Sem etapa nao ha o que persistir: o board nem oferece o arrasto, mas a
  // guarda fica porque o evento pode vir de um estado antigo da tela.
  if (!column.stage_id) return;

  const fromStageId = moved.crm_pipeline_stage_id;
  if (fromStageId === column.stage_id) return;

  patchDeal(moved, { crm_pipeline_stage_id: column.stage_id });
  moveAggregates(moved, fromStageId, column.stage_id);
  error.value = '';

  try {
    const response = await CrmAPI.moveDeal(moved.id, column.stage_id);
    if (response?.data) patchDeal(moved, response.data);
  } catch (exception) {
    patchDeal(moved, { crm_pipeline_stage_id: fromStageId });
    moveAggregates(moved, column.stage_id, fromStageId);
    error.value = messageFrom(exception, 'Não foi possível mover o negócio.');
  }
};
const moveDealToStage = async (deal, stageId) => {
  const targetStage = stages.value.find(
    stage => String(stage.id) === String(stageId)
  );
  if (!targetStage) return;

  await onDealMoved(
    { added: { element: deal } },
    { id: targetStage.id, stage_id: targetStage.id }
  );
};
const onNativeDrop = async column => {
  const deal = nativeDraggingDeal.value;
  if (!deal || !column?.stage_id) return;

  nativeDraggingDeal.value = null;
  await moveDealToStage(deal, column.stage_id);
};
const toggleSelection = (deal, checked) => {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, deal.id])]
    : selectedIds.value.filter(id => id !== deal.id);
};
const bulkMove = async stageId => {
  if (!stageId || !selectedIds.value.length) return;
  saving.value = true;
  try {
    await CrmAPI.bulkActionDeals({
      deal_ids: selectedIds.value,
      bulk_action: 'move',
      stage_id: stageId,
    });
    selectedIds.value = [];
    await loadCrm({ silent: true });
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível mover os negócios selecionados.';
  } finally {
    saving.value = false;
  }
};
const openDeal = deal => {
  selectedDealId.value = deal.id;
  showDealDrawer.value = true;
};
const onDealSaved = updatedDeal => {
  if (updatedDeal?.id) patchDeal(updatedDeal, updatedDeal);
};
const onDealDeleted = dealId => {
  columns.value = columns.value.map(column => ({
    ...column,
    deals: column.deals.filter(item => item.id !== dealId),
    count: Math.max(
      0,
      Number(column.count || 0) -
        (column.deals.some(item => item.id === dealId) ? 1 : 0)
    ),
  }));
  deals.value = flattenColumns();
  showDealDrawer.value = false;
};
const openCreate = stage => {
  createForm.value = {
    title: '',
    contact_name: '',
    contact_phone_number: '',
    // `stage_id` e nao `id`: fora do agrupamento por etapa, `column.id` e a
    // chave do balde (id de responsavel, 'hot', nome de area). Mandar isso
    // como etapa cria o negocio na etapa errada quando os numeros coincidem.
    crm_pipeline_stage_id: String(stage?.stage_id || stages.value[0]?.id || ''),
  };
  showCreateDrawer.value = true;
};
const createDeal = async () => {
  if (!createForm.value.title.trim() || !pipelineId.value) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.createDeal({
      title: createForm.value.title.trim(),
      contact_name: createForm.value.contact_name.trim() || undefined,
      contact_phone_number:
        createForm.value.contact_phone_number.trim() || undefined,
      crm_pipeline_id: pipelineId.value,
      inbox_id: selectedPipeline.value?.inbox_id || undefined,
      crm_pipeline_stage_id:
        createForm.value.crm_pipeline_stage_id || stages.value[0]?.id,
      operational_status: 'active',
    });
    showCreateDrawer.value = false;
    await loadCrm({ silent: true });
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message || 'Não foi possível criar o negócio.';
  } finally {
    saving.value = false;
  }
};
const dealUrl = deal =>
  `/app/accounts/${route.params.accountId}/crm/deals/${deal.id}`;

onMounted(async () => {
  readStoredDensity();
  loadBoardViews();
  store.dispatch('agents/get');
  // Query string e a fonte de verdade dos filtros legados: sem o pull, um
  // link como `/crm?search=X` pintava a caixa mas nao filtrava o quadro.
  pullLegacyFilterRefs();
  await loadCrm();

  // Deep-link vindo do atendimento (`/crm?deal_id=`): abre a ficha do
  // negocio por cima do quadro, sem exigir que o card esteja carregado.
  const deepLinkedDeal = Number(route.query.deal_id);
  if (deepLinkedDeal > 0) {
    selectedDealId.value = deepLinkedDeal;
    showDealDrawer.value = true;
  }
});
</script>

<template>
  <BoardPageTemplate
    title="Pipeline"
    :breadcrumbs="[{ label: 'CRM' }, { label: 'Pipeline' }]"
    :loading="loading"
    :empty="!columns.length"
    :empty-title="emptyTitle"
    empty-action-label="Atualizar"
    @empty-action="loadCrm"
  >
    <template #actions>
      <div
        class="inline-flex rounded-ui-control border border-ui-border-subtle bg-ui-sunken p-0.5"
        role="group"
        :aria-label="$t('CRM.VIEW_SWITCHER.LABEL')"
      >
        <DsButton
          :variant="currentView === 'kanban' ? 'secondary' : 'ghost'"
          size="sm"
          icon="i-lucide-kanban"
          :aria-label="$t('CRM.VIEW_SWITCHER.KANBAN')"
          :title="$t('CRM.VIEW_SWITCHER.KANBAN')"
          data-testid="crm-view-kanban"
          @click="setView('kanban')"
        />
        <DsButton
          :variant="currentView === 'table' ? 'secondary' : 'ghost'"
          size="sm"
          icon="i-lucide-table-2"
          :aria-label="$t('CRM.VIEW_SWITCHER.TABLE')"
          :title="$t('CRM.VIEW_SWITCHER.TABLE')"
          data-testid="crm-view-table"
          @click="setView('table')"
        />
      </div>
      <DsButton
        icon="i-lucide-refresh-cw"
        variant="secondary"
        :loading="refreshing"
        aria-label="Atualizar pipeline"
        @click="loadCrm({ silent: true })"
      />
      <DsButton
        label="Novo negócio"
        icon="i-lucide-plus"
        variant="primary"
        @click="openCreate()"
      />
    </template>

    <template #toolbar>
      <CRMBoardToolbar
        v-model:search="search"
        v-model:pipeline-id="pipelineId"
        v-model:owner-id="ownerId"
        v-model:priority="priority"
        :views="boardViews"
        :active-view-id="activeViewId"
        :filter-pills="filterPills"
        :filtered-total="filteredTotal"
        :group-by="groupBy"
        :group-by-options="groupByOptions"
        :density="cardDensity"
        :density-options="densityOptions"
        :pipeline-options="pipelineOptions"
        :owner-options="ownerOptions"
        :priority-options="priorityOptions"
        :has-filters="hasFilters"
        :total-visible="totalVisible"
        @update:group-by="changeGrouping"
        @update:density="setDensity"
        @apply-filters="applyFilters"
        @change-pipeline="changePipeline"
        @clear-filters="clearFilters"
        @remove-filter="dropFilter"
        @clear-all-filters="clearAllFilters"
        @select-view="applyView"
        @save-view="promptForViewName"
        @share-view="toggleViewSharing"
        @delete-view="confirmDeleteView"
      />
    </template>

    <template v-if="currentView === 'kanban'" #mobileNavigation>
      <DsSelect
        v-model="mobileColumnId"
        :label="$t('CRM.GROUP_BY.LABEL')"
        :options="mobileColumnOptions"
        data-testid="crm-mobile-column-selector"
      />
    </template>

    <div
      v-if="error"
      role="alert"
      class="fixed bottom-4 left-1/2 z-ui-overlay flex max-w-lg -translate-x-1/2 items-start gap-2 rounded-ui-control border border-ui-danger/30 bg-ui-elevated p-3 text-ui-body-sm text-ui-danger-foreground shadow-ui-overlay"
    >
      <Icon icon="i-lucide-circle-alert" class="mt-0.5 size-4 shrink-0" />
      <span class="flex-1">{{ error }}</span>
      <DsButton
        icon="i-lucide-x"
        variant="ghost"
        size="sm"
        aria-label="Fechar aviso"
        @click="error = ''"
      />
    </div>

    <section
      v-if="selectedCount"
      class="fixed bottom-4 left-1/2 z-ui-overlay flex max-w-[calc(100vw-2rem)] -translate-x-1/2 flex-wrap items-center gap-2 rounded-ui-surface border border-ui-border bg-ui-elevated p-2 shadow-ui-overlay"
      aria-label="Ações para negócios selecionados"
    >
      <span class="px-2 text-ui-body-sm font-medium">
        {{ selectedCount }} selecionado(s)
      </span>
      <DsSelect
        label="Mover para"
        hide-label
        placeholder="Mover para etapa"
        :options="stageOptions"
        :disabled="saving"
        @change="bulkMove($event.target.value)"
      />
      <DsButton
        label="Cancelar"
        variant="ghost"
        :disabled="saving"
        @click="selectedIds = []"
      />
    </section>

    <template v-if="currentView === 'kanban'">
      <CRMBoardColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :loading="loadingColumnIds.includes(column.id)"
        :movable="isMovable"
        :class="{
          'max-md:hidden': String(column.id) !== mobileColumnId,
        }"
        @create="openCreate(column)"
        @load-more="loadMoreInColumn(column)"
        @drag-start="onDragStart($event.item?.__draggable_context?.element)"
        @drag-end="onDragEnd"
        @native-drop="onNativeDrop(column)"
        @change="onColumnChanged(column, $event)"
      >
        <template #card="{ deal }">
          <CRMDealCard
            :deal="deal"
            :stage="column"
            :selected="selectedIds.includes(deal.id)"
            :owner-name="ownerName(deal.owner_id)"
            :density="cardDensity"
            :href="dealUrl(deal)"
            :stage-options="stageOptions"
            :can-drag="isMovable"
            @native-drag-start="onNativeDragStart(deal, $event)"
            @native-drag-end="onNativeDragEnd"
            @open="openDeal(deal)"
            @attend="openAttendance(deal)"
            @select="toggleSelection(deal, $event)"
            @recompute="recomputeScore(deal)"
            @mark-base-client="markBaseClient(deal)"
            @discard="discardTarget = deal"
            @schedule-next-action="openDeal(deal)"
            @move-to-stage="moveDealToStage(deal, $event)"
          />
        </template>
      </CRMBoardColumn>
    </template>

    <div v-else class="w-full min-w-full flex-1 overflow-y-auto">
      <CRMDealsTable
        :deals="deals"
        :stages="stages"
        :agents="agents"
        :loading="loading"
        :selected-ids="selectedIds"
        @open="openDeal"
        @attend="openAttendance"
        @select="toggleSelection"
        @recompute="recomputeScore"
        @mark-base-client="markBaseClient"
        @discard="discardTarget = $event"
      />
    </div>
  </BoardPageTemplate>

  <CRMCreateDealDrawer
    v-model="createForm"
    :open="showCreateDrawer"
    :saving="saving"
    :stage-options="stageOptions"
    @close="showCreateDrawer = false"
    @submit="createDeal"
  />

  <DsModal
    id="discard-board-deal-modal"
    :open="!!discardTarget"
    title="Descartar negócio"
    description="Descartar tira o negócio do funil sem contá-lo como perda comercial. Use quando nunca houve um lead de verdade."
    confirm-label="Descartar"
    dangerous
    :loading="saving"
    @close="discardTarget = null"
    @confirm="discard"
  >
    <DsSelect
      v-model="dispositionReason"
      label="Motivo do descarte"
      :options="dispositionOptions"
    />
  </DsModal>

  <CRMKanbanChatDrawer
    v-model:show="showChatDrawer"
    :deal="attendanceDeal"
    :stages="stages"
    :agents="agents"
    :loss-reasons="lossReasons"
    :account-id="Number(accountId)"
    @deal-updated="onAttendanceDealUpdated"
    @open-deal-drawer="openDealFromAttendance"
  />

  <CRMDealDrawer
    v-if="selectedDealId"
    v-model:show="showDealDrawer"
    :deal-id="selectedDealId"
    :loss-reasons="lossReasons"
    @saved="onDealSaved"
    @deal-deleted="onDealDeleted"
  />
</template>

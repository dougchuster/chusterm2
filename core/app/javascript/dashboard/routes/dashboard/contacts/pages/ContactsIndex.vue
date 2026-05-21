<script setup>
import { onMounted, computed, ref, reactive, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { debounce } from '@ChusteRM/utils';
import { useUISettings } from 'dashboard/composables/useUISettings';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';

import ContactsListLayout from 'dashboard/components-next/Contacts/ContactsListLayout.vue';
import ContactEmptyState from 'dashboard/components-next/Contacts/EmptyState/ContactEmptyState.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactsList from 'dashboard/components-next/Contacts/Pages/ContactsList.vue';
import ContactsTableList from 'dashboard/components-next/Contacts/Pages/ContactsTableList.vue';
import ContactsBulkActionBar from '../components/ContactsBulkActionBar.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import BulkActionsAPI from 'dashboard/api/bulkActions';
import ContactAPI from 'dashboard/api/contacts';
import ContactCategoriesAPI from 'dashboard/api/contactCategories';

const DEFAULT_SORT_FIELD = 'last_activity_at';
const DEBOUNCE_DELAY = 300;
const LIST_OWNER_WITHOUT = 'without_owner';
const CRM_FILTER_TEXT = {
  title: 'Central de segmentação',
  subtitle: 'Organize contatos por categorias, setor jurídico e responsável.',
  listTitle: 'Filtros da lista',
  listSubtitle:
    'Refine a tabela por relacionamento, etapa, categoria e responsável.',
  relationship: 'Relacionamento',
  lifecycle: 'Qualificação',
  owner: 'Responsável',
  label: 'Categoria',
  sourceList: 'Lista',
  legalArea: 'Setor jurídico',
  legalAreaPlaceholder: 'Selecione um setor jurídico',
  all: 'Todos',
  allContacts: 'Todos os contatos',
  lead: 'Lead',
  customer: 'Cliente',
  qualifiedLead: 'Lead qualificado',
  triage: 'Triagem',
  scheduled: 'Consulta agendada',
  mine: 'Meus contatos',
  withoutOwner: 'Sem responsável',
  clear: 'Limpar filtros',
  importedLists: 'Listas importadas recentes',
  noList: 'Sem listas recentes',
  categories: 'Categorias',
  newCategory: 'Nova categoria',
  createCategory: 'Criar categoria',
  categoryName: 'Nome da categoria',
  categoryNamePlaceholder: 'Ex: DF, Previdenciário...',
  categoryKind: 'Tipo',
  legalSector: 'Setor jurídico',
  legalSectorDescription:
    'Use para separar contatos por área do caso, como INSS, Trabalhista e Família.',
  noCategoriesInType: 'Nenhuma categoria criada neste tipo.',
  responsiblePeople: 'Responsáveis',
  responsiblePeopleDescription:
    'Acompanhe rapidamente quem cuida da carteira de contatos.',
  activeAudience: 'Audiência ativa',
  campaignCta: 'Criar campanha',
  saveSegment: 'Salvar segmento',
};
const CATEGORY_KIND_OPTIONS = [
  { value: 'area', label: 'Setor jurídico' },
  { value: 'location', label: 'Localidade' },
  { value: 'campaign', label: 'Campanha' },
  { value: 'origin', label: 'Origem' },
  { value: 'restriction', label: 'Restrição' },
  { value: 'custom', label: 'Livre' },
];
const CATEGORY_COLORS = [
  '#2563eb',
  '#059669',
  '#7c3aed',
  '#ea580c',
  '#0891b2',
  '#dc2626',
  '#475569',
];
const IMPORT_TEXT = {
  title: 'Importações recentes',
  loading: 'Atualizando...',
  processed: 'processados',
  failures: 'falhas',
  downloadErrors: 'Baixar erros',
};
const CATEGORIES_PAGE_TEXT = {
  title: 'Gestão de categorias',
  subtitle:
    'Categorias por tipo, responsáveis e audiência pronta para campanhas.',
  totalCategories: 'Categorias',
  legalSectors: 'Setores jurídicos',
  campaignLists: 'Campanhas/listas',
  restrictedCategories: 'Restrições',
  directory: 'Diretório de categorias',
  responsiblePortfolio: 'Carteira por responsável',
  viewContacts: 'Ver contatos',
  selectedAudience: 'Contatos da categoria',
  chooseCategory:
    'Selecione uma categoria para abrir os contatos vinculados a ela.',
  contactsSuffix: 'contatos',
  editCategory: 'Editar',
  deleteCategory: 'Excluir',
  editCategoryTitle: 'Editar categoria',
  deleteCategoryTitle: 'Excluir categoria',
  deleteCategoryConfirm: 'Excluir categoria',
  deleteCategoryDescription:
    'Esta categoria será removida dos contatos e conversas vinculados antes de ser excluída.',
  categoryColor: 'Cor',
  categoryDescription: 'Descrição',
  categoryDescriptionPlaceholder:
    'Ex: Contatos de campanha, setor jurídico ou localidade.',
};

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const { updateUISettings, uiSettings } = useUISettings();

const contacts = useMapGetter('contacts/getContactsList');
const uiFlags = useMapGetter('contacts/getUIFlags');
const customViewsUiFlags = useMapGetter('customViews/getUIFlags');
const segments = useMapGetter('customViews/getContactCustomViews');
const appliedFilters = useMapGetter('contacts/getAppliedContactFilters');
const meta = useMapGetter('contacts/getMeta');
const agentList = useMapGetter('agents/getVerifiedAgents');
const currentUserId = useMapGetter('getCurrentUserID');
const labels = useMapGetter('labels/getLabels');
const contactCategories = ref([]);

const searchQuery = computed(() => route.query?.search);
const searchValue = ref(searchQuery.value || '');
const pageNumber = computed(() => Number(route.query?.page) || 1);
// For infinite scroll in search, track page internally
const searchPageNumber = ref(1);
const isLoadingMore = ref(false);
const crmFilters = reactive({
  relationshipStatus: route.query?.relationship_status || '',
  lifecycleStage: route.query?.lifecycle_stage || '',
  crmOwnerId: route.query?.crm_owner_id || '',
  withoutCrmOwner: route.query?.without_crm_owner === 'true',
  label: route.query?.label || '',
  sourceList: route.query?.source_list || '',
  legalArea: route.query?.legal_area || '',
});
const listOwnerFilter = computed({
  get: () =>
    crmFilters.withoutCrmOwner ? LIST_OWNER_WITHOUT : crmFilters.crmOwnerId,
  set: value => {
    if (value === LIST_OWNER_WITHOUT) {
      crmFilters.crmOwnerId = '';
      crmFilters.withoutCrmOwner = true;
      return;
    }

    crmFilters.crmOwnerId = value;
    crmFilters.withoutCrmOwner = false;
  },
});

const parseSortSettings = (sortString = '') => {
  const hasDescending = sortString.startsWith('-');
  const sortField = hasDescending ? sortString.slice(1) : sortString;
  return {
    sort: sortField || DEFAULT_SORT_FIELD,
    order: hasDescending ? '-' : '',
  };
};

const { contacts_sort_by: contactSortBy = '' } = uiSettings.value ?? {};
const { sort: initialSort, order: initialOrder } =
  parseSortSettings(contactSortBy);

const sortState = reactive({
  activeSort: initialSort,
  activeOrdering: initialOrder,
});

const activeLabel = computed(() => route.params.label);
const activeSegmentId = computed(() => route.params.segmentId);
const isCategoriesView = computed(
  () => route.name === 'contacts_dashboard_categories'
);
const isListView = computed(() => route.name === 'contacts_dashboard_list');
const isFetchingList = computed(
  () => uiFlags.value.isFetching || customViewsUiFlags.value.isFetching
);
const currentPage = computed(() => Number(meta.value?.currentPage));
const totalItems = computed(() => meta.value?.count);
const hasMore = computed(() => meta.value?.hasMore ?? false);
const isSearchView = computed(() => !!searchQuery.value);

const selectedContactIds = ref([]);
const recentImports = ref([]);
const isLoadingImports = ref(false);
const isBulkActionLoading = ref(false);
const isCreatingCategory = ref(false);
const isUpdatingCategory = ref(false);
const isDeletingCategory = ref(false);
const isFetchingCategories = ref(false);
const showCategoryForm = ref(false);
const newCategoryName = ref('');
const newCategoryKind = ref('custom');
const bulkDeleteDialogRef = ref(null);
const categoryEditDialogRef = ref(null);
const categoryDeleteDialogRef = ref(null);
const selectedCategoryForEdit = ref(null);
const selectedCategoryForDelete = ref(null);
const categoryEditForm = reactive({
  name: '',
  kind: 'custom',
  color: CATEGORY_COLORS[0],
  description: '',
});
const selectedCount = computed(() => selectedContactIds.value.length);
const bulkDeleteDialogTitle = computed(() =>
  selectedCount.value > 1
    ? t('CONTACTS_BULK_ACTIONS.DELETE_DIALOG.TITLE')
    : t('CONTACTS_BULK_ACTIONS.DELETE_DIALOG.SINGULAR_TITLE')
);
const bulkDeleteDialogDescription = computed(() =>
  selectedCount.value > 1
    ? t('CONTACTS_BULK_ACTIONS.DELETE_DIALOG.DESCRIPTION', {
        count: selectedCount.value,
      })
    : t('CONTACTS_BULK_ACTIONS.DELETE_DIALOG.SINGULAR_DESCRIPTION')
);
const bulkDeleteDialogConfirmLabel = computed(() =>
  selectedCount.value > 1
    ? t('CONTACTS_BULK_ACTIONS.DELETE_DIALOG.CONFIRM_MULTIPLE')
    : t('CONTACTS_BULK_ACTIONS.DELETE_DIALOG.CONFIRM_SINGLE')
);
const hasSelection = computed(() => selectedCount.value > 0);
const activeSegment = computed(() => {
  if (!activeSegmentId.value) return undefined;
  return segments.value.find(view => view.id === Number(activeSegmentId.value));
});

const hasContacts = computed(() => contacts.value.length > 0);
const isContactIndexView = computed(
  () =>
    (['contacts_dashboard_index', 'contacts_dashboard_categories'].includes(
      route.name
    ) ||
      route.name === 'contacts_dashboard_list') &&
    pageNumber.value === 1
);
const isActiveView = computed(() => route.name === 'contacts_dashboard_active');
const hasAppliedFilters = computed(() => {
  return appliedFilters.value.length > 0;
});
const hasCrmFilters = computed(
  () =>
    !!crmFilters.relationshipStatus ||
    !!crmFilters.lifecycleStage ||
    !!crmFilters.crmOwnerId ||
    crmFilters.withoutCrmOwner ||
    !!crmFilters.label ||
    !!crmFilters.sourceList ||
    !!crmFilters.legalArea
);
const shouldShowContactsList = computed(
  () =>
    !isCategoriesView.value ||
    !!crmFilters.label ||
    !!searchQuery.value ||
    hasAppliedFilters.value
);
const showPaginationFooter = computed(
  () =>
    shouldShowContactsList.value &&
    !isFetchingList.value &&
    hasContacts.value &&
    !isSearchView.value
);

const showEmptyStateLayout = computed(() => {
  return (
    !searchQuery.value &&
    !hasContacts.value &&
    isContactIndexView.value &&
    !hasAppliedFilters.value
  );
});
const showEmptyText = computed(() => {
  return (
    (searchQuery.value ||
      hasAppliedFilters.value ||
      !isContactIndexView.value) &&
    !hasContacts.value
  );
});

const headerTitle = computed(() => {
  if (searchQuery.value) return t('CONTACTS_LAYOUT.HEADER.SEARCH_TITLE');
  if (isActiveView.value) return t('CONTACTS_LAYOUT.HEADER.ACTIVE_TITLE');
  if (isCategoriesView.value) return 'Categorias';
  if (isListView.value) return 'Lista';
  if (activeSegmentId.value) return activeSegment.value?.name;
  if (activeLabel.value) return `#${activeLabel.value}`;
  return t('CONTACTS_LAYOUT.HEADER.TITLE');
});

const emptyStateMessage = computed(() => {
  if (isActiveView.value)
    return t('CONTACTS_LAYOUT.EMPTY_STATE.ACTIVE_EMPTY_STATE_TITLE');
  if (!searchQuery.value || hasAppliedFilters.value)
    return t('CONTACTS_LAYOUT.EMPTY_STATE.LIST_EMPTY_STATE_TITLE');
  return t('CONTACTS_LAYOUT.EMPTY_STATE.SEARCH_EMPTY_STATE_TITLE');
});

const visibleContactIds = computed(() =>
  contacts.value.map(contact => contact.id)
);

const hasRecentImports = computed(() => recentImports.value.length > 0);
const sourceListOptions = computed(() => {
  const importNames = recentImports.value
    .map(item => item.metadata?.source_list)
    .filter(Boolean);
  const contactNames = contacts.value
    .map(
      contact =>
        contact.additionalAttributes?.sourceList ||
        contact.additionalAttributes?.source_list
    )
    .filter(Boolean);

  return [...new Set([...importNames, ...contactNames])];
});
const sanitizeCategoryTitle = value =>
  value
    .toString()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');

const humanizeCategoryTitle = value =>
  value
    ?.toString()
    .replace(
      /^(area|origin|location|campaign|custom|status|restriction|rel|temp|risk|doc)[._]/,
      ''
    )
    .replace(/_/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase()) || value;

const categoryStyle = label => ({
  borderColor: label.color || '#cbd5e1',
  backgroundColor: `${label.color || '#2563eb'}14`,
  color: label.color || '#2563eb',
});

const categorySource = computed(() =>
  contactCategories.value.length ? contactCategories.value : labels.value
);
const categoryKind = label => label.kind || label.category || 'custom';
const categoryLabels = computed(() =>
  categorySource.value.filter(
    label =>
      !label.is_system &&
      ['contact', 'both', undefined, null, ''].includes(label.scope) &&
      !['relationship', 'status', 'temperature'].includes(categoryKind(label))
  )
);
const visibleLabels = computed(() =>
  categoryLabels.value.filter(label => !label.is_system).slice(0, 80)
);
const legalAreaCategoryLabels = computed(() =>
  categoryLabels.value.filter(label => categoryKind(label) === 'area')
);
const activeCategoryLabel = computed(() =>
  categoryLabels.value.find(label => label.title === crmFilters.label)
);
const activeCategoryName = computed(() =>
  crmFilters.label
    ? humanizeCategoryTitle(
        activeCategoryLabel.value?.title || crmFilters.label
      )
    : ''
);
const categoryCountByTitle = computed(() => {
  return contacts.value.reduce((counts, contact) => {
    (contact.labels || []).forEach(label => {
      counts[label] = (counts[label] || 0) + 1;
    });
    return counts;
  }, {});
});
const categoryDisplayName = label =>
  label?.display_title || humanizeCategoryTitle(label?.title);
const categoryContactCount = label =>
  label
    ? categoryCountByTitle.value[label.title] || label.contacts_count || 0
    : 0;
const categoryDeleteDescription = computed(() => {
  const count = categoryContactCount(selectedCategoryForDelete.value);
  if (!count) {
    return 'Esta categoria será excluída permanentemente.';
  }

  return `${CATEGORIES_PAGE_TEXT.deleteCategoryDescription} Total vinculado: ${count} contato(s).`;
});
const categoryGroups = computed(() => {
  const groups = [
    {
      key: 'area',
      title: CRM_FILTER_TEXT.legalSector,
      description: CRM_FILTER_TEXT.legalSectorDescription,
      icon: 'i-lucide-scale',
    },
    {
      key: 'location',
      title: 'Localidade',
      description: 'Estados, cidades ou regiões para campanhas locais.',
      icon: 'i-lucide-map-pin',
    },
    {
      key: 'campaign',
      title: 'Campanhas e listas',
      description: 'Audiências de remarketing, importações e ações comerciais.',
      icon: 'i-lucide-megaphone',
    },
    {
      key: 'origin',
      title: 'Origem',
      description: 'Canais e fontes de entrada do contato.',
      icon: 'i-lucide-route',
    },
    {
      key: 'restriction',
      title: 'Restrições',
      description: 'Opt-out, não chamar e outras regras de cuidado.',
      icon: 'i-lucide-shield-alert',
    },
    {
      key: 'custom',
      title: 'Outras categorias',
      description: 'Grupos livres criados pela operação.',
      icon: 'i-lucide-tags',
    },
  ];

  return groups.map(group => ({
    ...group,
    categories: categoryLabels.value.filter(
      label => categoryKind(label) === group.key
    ),
  }));
});
const categoriesPageStats = computed(() => {
  const total = categoryLabels.value.length;
  const countByKind = categoryLabels.value.reduce((counts, label) => {
    const kind = categoryKind(label);
    counts[kind] = (counts[kind] || 0) + 1;
    return counts;
  }, {});

  return [
    {
      key: 'total',
      label: CATEGORIES_PAGE_TEXT.totalCategories,
      value: total,
      icon: 'i-lucide-tags',
    },
    {
      key: 'area',
      label: CATEGORIES_PAGE_TEXT.legalSectors,
      value: countByKind.area || 0,
      icon: 'i-lucide-scale',
    },
    {
      key: 'campaign',
      label: CATEGORIES_PAGE_TEXT.campaignLists,
      value: countByKind.campaign || 0,
      icon: 'i-lucide-megaphone',
    },
    {
      key: 'restriction',
      label: CATEGORIES_PAGE_TEXT.restrictedCategories,
      value: countByKind.restriction || 0,
      icon: 'i-lucide-shield-alert',
    },
  ];
});
const ownerSummaries = computed(() => {
  const counts = contacts.value.reduce((result, contact) => {
    const ownerId = contact.crmOwnerId || contact.crm_owner_id || 'unassigned';
    result[ownerId] = (result[ownerId] || 0) + 1;
    return result;
  }, {});

  const owners = agentList.value.map(agent => ({
    id: String(agent.id),
    name: agent.name || agent.email,
    count: counts[agent.id] || counts[String(agent.id)] || 0,
  }));

  return [
    {
      id: 'unassigned',
      name: CRM_FILTER_TEXT.withoutOwner,
      count: counts.unassigned || 0,
      unassigned: true,
    },
    ...owners,
  ].filter(owner => owner.count > 0 || owner.unassigned);
});
const activeAudienceSummary = computed(() => {
  const parts = [];
  if (crmFilters.label) {
    parts.push(
      activeCategoryLabel.value?.display_title ||
        humanizeCategoryTitle(crmFilters.label)
    );
  }
  if (crmFilters.relationshipStatus) {
    parts.push(
      crmFilters.relationshipStatus === 'customer' ? 'Cliente' : 'Lead'
    );
  }
  if (crmFilters.lifecycleStage) parts.push(crmFilters.lifecycleStage);
  if (crmFilters.crmOwnerId) parts.push('Responsável selecionado');
  if (crmFilters.withoutCrmOwner) parts.push('Sem responsável');
  if (crmFilters.legalArea) parts.push(crmFilters.legalArea);
  return parts.length ? parts.join(' + ') : 'Todos os contatos';
});

const currentCrmFilters = () => ({
  relationshipStatus: crmFilters.relationshipStatus,
  lifecycleStage: crmFilters.lifecycleStage,
  crmOwnerId: crmFilters.withoutCrmOwner ? '' : crmFilters.crmOwnerId,
  withoutCrmOwner: crmFilters.withoutCrmOwner,
  label: crmFilters.label,
  sourceList: crmFilters.sourceList,
  legalArea: crmFilters.legalArea,
});

const clearSelection = () => {
  selectedContactIds.value = [];
};

const loadRecentImports = async () => {
  isLoadingImports.value = true;
  try {
    const response = await ContactAPI.getImports();
    recentImports.value = response.data || [];
  } finally {
    isLoadingImports.value = false;
  }
};

const fetchContactCategories = async () => {
  if (isFetchingCategories.value) return;

  isFetchingCategories.value = true;
  try {
    const response = await ContactCategoriesAPI.get();
    contactCategories.value = response.data?.payload || [];
  } catch (error) {
    contactCategories.value = [];
  } finally {
    isFetchingCategories.value = false;
  }
};

const refreshContactImportsAndCategories = () => {
  loadRecentImports();
  fetchContactCategories();
};

const importStatusLabel = status =>
  ({
    pending: 'Pendente',
    processing: 'Processando',
    completed: 'Concluída',
    failed: 'Falhou',
  })[status] || status;

const importTitle = item =>
  item.metadata?.source_list || item.filename || `Importação #${item.id}`;
const importProgress = item =>
  `${item.processed_records || 0}/${item.total_records || 0} ${IMPORT_TEXT.processed}`;
const importFailures = item =>
  item.rejected_records
    ? ` - ${item.rejected_records} ${IMPORT_TEXT.failures}`
    : '';

const openBulkDeleteDialog = () => {
  if (!selectedContactIds.value.length || isBulkActionLoading.value) return;
  bulkDeleteDialogRef.value?.open?.();
};

const toggleSelectAll = shouldSelect => {
  selectedContactIds.value = shouldSelect ? [...visibleContactIds.value] : [];
};

const showContactDetails = async id => {
  await router.push({
    name: 'contacts_edit',
    params: { ...route.params, contactId: id },
    query: route.query,
  });
};

const toggleContactSelection = ({ id, value }) => {
  const isAlreadySelected = selectedContactIds.value.includes(id);
  const shouldSelect = value ?? !isAlreadySelected;

  if (shouldSelect && !isAlreadySelected) {
    selectedContactIds.value = [...selectedContactIds.value, id];
  } else if (!shouldSelect && isAlreadySelected) {
    selectedContactIds.value = selectedContactIds.value.filter(
      contactId => contactId !== id
    );
  }
};

const updatePageParam = (page, search = '') => {
  const query = {
    ...route.query,
    page: page.toString(),
    ...(search ? { search } : {}),
  };

  if (!search) {
    delete query.search;
  }

  if (crmFilters.relationshipStatus) {
    query.relationship_status = crmFilters.relationshipStatus;
  } else {
    delete query.relationship_status;
  }

  if (crmFilters.lifecycleStage) {
    query.lifecycle_stage = crmFilters.lifecycleStage;
  } else {
    delete query.lifecycle_stage;
  }

  if (crmFilters.crmOwnerId && !crmFilters.withoutCrmOwner) {
    query.crm_owner_id = crmFilters.crmOwnerId;
  } else {
    delete query.crm_owner_id;
  }

  if (crmFilters.withoutCrmOwner) {
    query.without_crm_owner = 'true';
  } else {
    delete query.without_crm_owner;
  }

  if (crmFilters.label) {
    query.label = crmFilters.label;
  } else {
    delete query.label;
  }

  if (crmFilters.sourceList) {
    query.source_list = crmFilters.sourceList;
  } else {
    delete query.source_list;
  }

  if (crmFilters.legalArea) {
    query.legal_area = crmFilters.legalArea;
  } else {
    delete query.legal_area;
  }

  router.replace({ query });
};

const buildSortAttr = () =>
  `${sortState.activeOrdering}${sortState.activeSort}`;

const getCommonFetchParams = (page = 1) => ({
  page,
  sortAttr: buildSortAttr(),
  label: activeLabel.value,
  crmFilters: currentCrmFilters(),
});

const fetchContacts = async (page = 1) => {
  clearSelection();
  await store.dispatch('contacts/clearContactFilters');
  await store.dispatch('contacts/get', getCommonFetchParams(page));
  updatePageParam(page);
};

const fetchSavedOrAppliedFilteredContact = async (payload, page = 1) => {
  if (!activeSegmentId.value && !hasAppliedFilters.value) return;
  clearSelection();
  await store.dispatch('contacts/filter', {
    ...getCommonFetchParams(page),
    queryPayload: payload,
  });
  updatePageParam(page);
};

const fetchActiveContacts = async (page = 1) => {
  clearSelection();
  await store.dispatch('contacts/clearContactFilters');
  await store.dispatch('contacts/active', {
    page,
    sortAttr: buildSortAttr(),
    crmFilters: currentCrmFilters(),
  });
  updatePageParam(page);
};

const searchContacts = debounce(async (value, page = 1, append = false) => {
  if (!append) {
    clearSelection();
    searchPageNumber.value = 1;
  }
  await store.dispatch('contacts/clearContactFilters');
  searchValue.value = value;

  if (!value) {
    updatePageParam(page);
    await fetchContacts(page);
    return;
  }

  updatePageParam(page, value);
  await store.dispatch('contacts/search', {
    ...getCommonFetchParams(page),
    search: encodeURIComponent(value),
    append,
  });
  searchPageNumber.value = page;
}, DEBOUNCE_DELAY);

const loadMoreSearchResults = async () => {
  if (!hasMore.value || isLoadingMore.value) return;

  isLoadingMore.value = true;
  const nextPage = searchPageNumber.value + 1;

  await store.dispatch('contacts/search', {
    ...getCommonFetchParams(nextPage),
    search: encodeURIComponent(searchValue.value),
    append: true,
  });

  searchPageNumber.value = nextPage;
  isLoadingMore.value = false;
};

const fetchContactsBasedOnContext = async page => {
  clearSelection();
  updatePageParam(page, searchValue.value);
  if (isFetchingList.value) return;
  if (searchQuery.value) {
    await searchContacts(searchQuery.value, page);
    return;
  }
  // Reset the search value when we change the view
  searchValue.value = '';
  // If we're on the active route, fetch active contacts
  if (isActiveView.value) {
    await fetchActiveContacts(page);
    return;
  }
  // If there are applied filters or active segment with query
  if (
    (hasAppliedFilters.value || activeSegment.value?.query) &&
    !activeLabel.value
  ) {
    const queryPayload =
      activeSegment.value?.query || filterQueryGenerator(appliedFilters.value);
    await fetchSavedOrAppliedFilteredContact(queryPayload, page);
    return;
  }
  // Default case: fetch regular contacts + label
  await fetchContacts(page);
};

const assignLabels = async assignedLabels => {
  if (!assignedLabels.length || !selectedContactIds.value.length) {
    return;
  }

  isBulkActionLoading.value = true;
  try {
    await ContactCategoriesAPI.bulkAssign({
      contact_ids: selectedContactIds.value,
      categories: assignedLabels,
    });
    useAlert(t('CONTACTS_BULK_ACTIONS.ASSIGN_LABELS_SUCCESS'));
    clearSelection();
    await fetchContactCategories();
    await store.dispatch('labels/get');
    await fetchContactsBasedOnContext(pageNumber.value);
  } catch (error) {
    useAlert(t('CONTACTS_BULK_ACTIONS.ASSIGN_LABELS_FAILED'));
  } finally {
    isBulkActionLoading.value = false;
  }
};

const removeActiveCategoryFromSelection = async () => {
  if (
    !selectedContactIds.value.length ||
    !crmFilters.label ||
    isBulkActionLoading.value
  ) {
    return;
  }

  isBulkActionLoading.value = true;
  try {
    await ContactCategoriesAPI.bulkRemove({
      contact_ids: selectedContactIds.value,
      categories: [crmFilters.label],
    });
    useAlert('Categoria removida dos contatos selecionados.');
    clearSelection();
    await fetchContactCategories();
    await fetchContactsBasedOnContext(pageNumber.value);
  } catch (error) {
    useAlert('Não foi possível remover a categoria dos contatos selecionados.');
  } finally {
    isBulkActionLoading.value = false;
  }
};

const deleteContacts = async () => {
  if (!selectedContactIds.value.length) {
    return;
  }

  isBulkActionLoading.value = true;
  try {
    await BulkActionsAPI.create({
      type: 'Contact',
      ids: selectedContactIds.value,
      action_name: 'delete',
    });
    useAlert(t('CONTACTS_BULK_ACTIONS.DELETE_SUCCESS'));
    clearSelection();
    await fetchContactsBasedOnContext(pageNumber.value);
    bulkDeleteDialogRef.value?.close?.();
  } catch (error) {
    useAlert(t('CONTACTS_BULK_ACTIONS.DELETE_FAILED'));
  } finally {
    isBulkActionLoading.value = false;
  }
};

const handleSort = async ({ sort, order }) => {
  Object.assign(sortState, { activeSort: sort, activeOrdering: order });

  await updateUISettings({
    contacts_sort_by: buildSortAttr(),
  });

  if (searchQuery.value) {
    await searchContacts(searchValue.value);
    return;
  }

  if (isActiveView.value) {
    await fetchActiveContacts();
    return;
  }

  await (activeSegmentId.value || hasAppliedFilters.value
    ? fetchSavedOrAppliedFilteredContact(
        activeSegmentId.value
          ? activeSegment.value?.query
          : filterQueryGenerator(appliedFilters.value)
      )
    : fetchContacts());
};

const createContact = async contact => {
  await store.dispatch('contacts/create', contact);
};

const applyCrmFilters = async () => {
  if (crmFilters.withoutCrmOwner) {
    crmFilters.crmOwnerId = '';
  }
  await fetchContactsBasedOnContext(1);
};

const clearCrmFilters = async () => {
  crmFilters.relationshipStatus = '';
  crmFilters.lifecycleStage = '';
  crmFilters.crmOwnerId = '';
  crmFilters.withoutCrmOwner = false;
  crmFilters.label = '';
  crmFilters.sourceList = '';
  crmFilters.legalArea = '';
  await fetchContactsBasedOnContext(1);
};

const applyCategory = async labelTitle => {
  crmFilters.label = labelTitle || '';
  crmFilters.legalArea = '';
  await fetchContactsBasedOnContext(1);
};

const applyLegalAreaCategory = async labelTitle => {
  crmFilters.label = labelTitle || '';
  crmFilters.legalArea = '';
  await fetchContactsBasedOnContext(1);
};

const createCategory = async () => {
  const title = sanitizeCategoryTitle(newCategoryName.value);
  if (!title || isCreatingCategory.value) return;

  isCreatingCategory.value = true;
  try {
    const color =
      CATEGORY_COLORS[categoryLabels.value.length % CATEGORY_COLORS.length];
    const response = await ContactCategoriesAPI.create({
      category: {
        title,
        color,
        kind: newCategoryKind.value,
        description: 'Categoria de contato para segmentação e campanhas',
      },
    });
    await fetchContactCategories();
    await store.dispatch('labels/get');
    newCategoryName.value = '';
    showCategoryForm.value = false;
    crmFilters.label = response.data?.title || title;
    useAlert(
      'Categoria criada. Ela já pode ser usada em filtros, importações e campanhas.'
    );
    await fetchContactsBasedOnContext(1);
  } catch (error) {
    useAlert('Não foi possível criar a categoria.');
  } finally {
    isCreatingCategory.value = false;
  }
};

const openEditCategoryDialog = label => {
  selectedCategoryForEdit.value = label;
  categoryEditForm.name = humanizeCategoryTitle(label.title);
  categoryEditForm.kind = categoryKind(label);
  categoryEditForm.color = label.color || CATEGORY_COLORS[0];
  categoryEditForm.description = label.description || '';
  categoryEditDialogRef.value?.open?.();
};

const updateCategory = async () => {
  const category = selectedCategoryForEdit.value;
  const title = sanitizeCategoryTitle(categoryEditForm.name);
  if (!category || !title || isUpdatingCategory.value) return;

  const previousTitle = category.title;
  isUpdatingCategory.value = true;
  try {
    const response = await ContactCategoriesAPI.update(category.id, {
      category: {
        title,
        kind: categoryEditForm.kind,
        color: categoryEditForm.color,
        description: categoryEditForm.description,
      },
    });
    await fetchContactCategories();
    await store.dispatch('labels/get');

    if (crmFilters.label === previousTitle) {
      crmFilters.label = response.data?.title || title;
      await fetchContactsBasedOnContext(1);
    }

    useAlert('Categoria atualizada com sucesso.');
    categoryEditDialogRef.value?.close?.();
  } catch (error) {
    useAlert('Não foi possível atualizar a categoria.');
  } finally {
    isUpdatingCategory.value = false;
  }
};

const openDeleteCategoryDialog = label => {
  selectedCategoryForDelete.value = label;
  categoryDeleteDialogRef.value?.open?.();
};

const deleteCategory = async () => {
  const category = selectedCategoryForDelete.value;
  if (!category || isDeletingCategory.value) return;

  isDeletingCategory.value = true;
  try {
    await ContactCategoriesAPI.delete(category.id);

    if (crmFilters.label === category.title) {
      crmFilters.label = '';
      crmFilters.legalArea = '';
    }

    await fetchContactCategories();
    await store.dispatch('labels/get');
    await fetchContactsBasedOnContext(1);

    useAlert('Categoria excluída e removida dos contatos vinculados.');
    categoryDeleteDialogRef.value?.close?.();
  } catch (error) {
    useAlert('Não foi possível excluir a categoria.');
  } finally {
    isDeletingCategory.value = false;
  }
};

const applyRelationshipShortcut = async status => {
  crmFilters.relationshipStatus = status;
  crmFilters.lifecycleStage = '';
  crmFilters.withoutCrmOwner = false;
  await fetchContactsBasedOnContext(1);
};

const applySourceList = async sourceList => {
  crmFilters.sourceList = sourceList;
  await fetchContactsBasedOnContext(1);
};

const applyWithoutOwnerShortcut = async () => {
  crmFilters.crmOwnerId = '';
  crmFilters.withoutCrmOwner = true;
  await fetchContactsBasedOnContext(1);
};

const applyOwnerSummary = async owner => {
  if (owner.unassigned) {
    await applyWithoutOwnerShortcut();
    return;
  }

  crmFilters.crmOwnerId = owner.id;
  crmFilters.withoutCrmOwner = false;
  await fetchContactsBasedOnContext(1);
};

const applyMyCrmContacts = async () => {
  if (!currentUserId.value) return;
  crmFilters.crmOwnerId = String(currentUserId.value);
  crmFilters.withoutCrmOwner = false;
  await fetchContactsBasedOnContext(1);
};

const openCampaigns = () => {
  router.push({
    name: 'campaigns_whatsapp_index',
    params: route.params,
    query: {
      labels: crmFilters.label,
      relationship_status: crmFilters.relationshipStatus,
      source_list: crmFilters.sourceList,
    },
  });
};

watch(
  contacts,
  newContacts => {
    const idsOnPage = newContacts.map(contact => contact.id);
    selectedContactIds.value = selectedContactIds.value.filter(id =>
      idsOnPage.includes(id)
    );
  },
  { deep: true }
);

watch(hasSelection, value => {
  if (!value) {
    bulkDeleteDialogRef.value?.close?.();
  }
});

watch(
  () => uiSettings.value?.contacts_sort_by,
  newSortBy => {
    if (newSortBy) {
      const { sort, order } = parseSortSettings(newSortBy);
      sortState.activeSort = sort;
      sortState.activeOrdering = order;
    }
  },
  { immediate: true }
);

watch(
  [activeLabel, activeSegment, isActiveView, isCategoriesView, isListView],
  () => {
    fetchContactsBasedOnContext(pageNumber.value);
  },
  { deep: true }
);

watch(searchQuery, value => {
  if (isFetchingList.value) return;
  searchValue.value = value || '';
  // Reset the view if there is search query when we click on the sidebar group
  if (value === undefined) {
    if (
      isActiveView.value ||
      activeLabel.value ||
      activeSegment.value ||
      hasAppliedFilters.value
    )
      return;
    fetchContacts();
  }
});

onMounted(async () => {
  loadRecentImports();
  fetchContactCategories();
  if (!agentList.value?.length) {
    store.dispatch('agents/get');
  }
  if (!labels.value?.length) {
    store.dispatch('labels/get');
  }
  if (!activeSegmentId.value) {
    if (searchQuery.value) {
      await searchContacts(searchQuery.value, pageNumber.value);
      return;
    }
    if (isActiveView.value) {
      await fetchActiveContacts(pageNumber.value);
      return;
    }
    await fetchContacts(pageNumber.value);
  } else if (activeSegment.value && activeSegmentId.value) {
    await fetchSavedOrAppliedFilteredContact(
      activeSegment.value.query,
      pageNumber.value
    );
  }
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <ContactsListLayout
      :search-value="searchValue"
      :header-title="headerTitle"
      :current-page="currentPage"
      :total-items="totalItems"
      :show-pagination-footer="showPaginationFooter"
      :active-sort="sortState.activeSort"
      :active-ordering="sortState.activeOrdering"
      :active-segment="activeSegment"
      :segments-id="activeSegmentId"
      :is-fetching-list="isFetchingList"
      :has-applied-filters="hasAppliedFilters"
      :use-infinite-scroll="isSearchView"
      :has-more="hasMore"
      :is-loading-more="isLoadingMore"
      @update:current-page="fetchContactsBasedOnContext"
      @search="searchContacts"
      @update:sort="handleSort"
      @apply-filter="fetchSavedOrAppliedFilteredContact"
      @clear-filters="fetchContacts"
      @load-more="loadMoreSearchResults"
      @import-complete="refreshContactImportsAndCategories"
    >
      <section v-if="isCategoriesView" class="mt-4 flex flex-col gap-4 text-xs">
        <div class="rounded-lg border border-n-weak bg-n-solid-2 p-4 sm:p-5">
          <div
            class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
          >
            <div class="min-w-0">
              <p
                class="mb-1 text-[11px] font-semibold uppercase tracking-normal text-n-slate-10"
              >
                {{ CRM_FILTER_TEXT.categories }}
              </p>
              <h3 class="m-0 text-lg font-semibold text-n-slate-12">
                {{ CATEGORIES_PAGE_TEXT.title }}
              </h3>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ CATEGORIES_PAGE_TEXT.subtitle }}
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                v-if="hasCrmFilters"
                type="button"
                class="inline-flex h-9 items-center justify-center rounded border border-n-weak px-3 font-medium text-n-slate-11 hover:bg-n-slate-2"
                @click="clearCrmFilters"
              >
                {{ CRM_FILTER_TEXT.clear }}
              </button>
              <button
                type="button"
                class="inline-flex h-9 items-center gap-1 rounded border border-n-weak px-3 font-medium text-n-slate-11 transition hover:bg-n-slate-2"
                @click="showCategoryForm = !showCategoryForm"
              >
                <span class="i-lucide-plus size-3.5" />
                {{ CRM_FILTER_TEXT.newCategory }}
              </button>
            </div>
          </div>

          <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <article
              v-for="stat in categoriesPageStats"
              :key="stat.key"
              class="rounded border border-n-weak bg-n-surface-1 p-3"
            >
              <span :class="stat.icon" class="size-4 text-n-slate-10" />
              <p class="mb-1 mt-3 text-n-slate-11">{{ stat.label }}</p>
              <strong class="text-2xl font-semibold text-n-slate-12">
                {{ stat.value }}
              </strong>
            </article>
          </div>

          <form
            v-if="showCategoryForm"
            class="mt-4 grid gap-2 rounded border border-n-weak bg-n-surface-1 p-3 sm:grid-cols-[minmax(0,1fr)_190px_auto]"
            @submit.prevent="createCategory"
          >
            <label class="flex min-w-0 flex-col gap-1">
              <span class="font-medium text-n-slate-11">
                {{ CRM_FILTER_TEXT.categoryName }}
              </span>
              <input
                v-model="newCategoryName"
                type="text"
                :placeholder="CRM_FILTER_TEXT.categoryNamePlaceholder"
                class="h-9 rounded border border-n-weak bg-n-solid-2 px-2 outline-none"
              />
            </label>
            <label class="flex min-w-0 flex-col gap-1">
              <span class="font-medium text-n-slate-11">
                {{ CRM_FILTER_TEXT.categoryKind }}
              </span>
              <select
                v-model="newCategoryKind"
                class="h-9 rounded border border-n-weak bg-n-solid-2 px-2 outline-none"
              >
                <option
                  v-for="option in CATEGORY_KIND_OPTIONS"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
            <button
              type="submit"
              class="mt-auto inline-flex h-9 items-center justify-center rounded bg-n-blue-9 px-3 font-semibold text-white disabled:opacity-50"
              :disabled="isCreatingCategory || !newCategoryName"
            >
              {{ CRM_FILTER_TEXT.createCategory }}
            </button>
          </form>
        </div>

        <div class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
          <section class="rounded-lg border border-n-weak bg-n-solid-2 p-4">
            <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
              <div>
                <h3 class="m-0 text-sm font-semibold text-n-slate-12">
                  {{ CATEGORIES_PAGE_TEXT.directory }}
                </h3>
                <p class="mt-0.5 text-n-slate-11">
                  {{ activeAudienceSummary }}
                </p>
              </div>
              <button
                type="button"
                class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
                :class="
                  !crmFilters.label
                    ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                    : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
                "
                @click="applyCategory('')"
              >
                {{ CRM_FILTER_TEXT.allContacts }}
              </button>
            </div>

            <div class="grid gap-3 lg:grid-cols-2">
              <article
                v-for="group in categoryGroups"
                :key="group.key"
                class="rounded border border-n-weak bg-n-surface-1 p-3"
              >
                <div class="mb-3 flex items-start gap-2">
                  <span
                    :class="group.icon"
                    class="mt-0.5 size-4 shrink-0 text-n-slate-10"
                  />
                  <div class="min-w-0">
                    <h4 class="m-0 text-sm font-semibold text-n-slate-12">
                      {{ group.title }}
                    </h4>
                    <p class="mt-0.5 text-[11px] leading-4 text-n-slate-11">
                      {{ group.description }}
                    </p>
                  </div>
                </div>

                <div v-if="group.categories.length" class="grid gap-2">
                  <div
                    v-for="label in group.categories"
                    :key="label.id"
                    class="flex min-w-0 flex-col gap-3 rounded border border-n-weak bg-n-solid-2 p-3 sm:flex-row sm:items-start sm:justify-between"
                    :class="{
                      'ring-2 ring-n-blue-7': crmFilters.label === label.title,
                    }"
                  >
                    <button
                      type="button"
                      class="flex min-w-0 items-center gap-2 text-left"
                      @click="applyCategory(label.title)"
                    >
                      <span
                        class="size-3 shrink-0 rounded"
                        :style="{
                          backgroundColor: label.color || '#2563eb',
                        }"
                      />
                      <span class="min-w-0">
                        <span
                          class="block truncate font-semibold text-n-slate-12"
                        >
                          {{ categoryDisplayName(label) }}
                        </span>
                        <span class="text-[11px] text-n-slate-10">
                          {{ categoryContactCount(label) }}
                          {{ CATEGORIES_PAGE_TEXT.contactsSuffix }}
                        </span>
                      </span>
                    </button>
                    <div
                      class="flex shrink-0 flex-wrap items-center gap-2 sm:justify-end"
                    >
                      <button
                        type="button"
                        class="inline-flex h-8 items-center gap-1 rounded border border-n-weak px-2 font-medium text-n-slate-11 hover:bg-n-slate-2"
                        @click="applyCategory(label.title)"
                      >
                        <span class="i-lucide-eye size-3.5" />
                        {{ CATEGORIES_PAGE_TEXT.viewContacts }}
                      </button>
                      <button
                        type="button"
                        class="inline-flex h-8 items-center gap-1 rounded border border-n-weak px-2 font-medium text-n-slate-11 hover:bg-n-slate-2"
                        @click="openEditCategoryDialog(label)"
                      >
                        <span class="i-lucide-pencil size-3.5" />
                        {{ CATEGORIES_PAGE_TEXT.editCategory }}
                      </button>
                      <button
                        type="button"
                        class="inline-flex h-8 items-center gap-1 rounded border border-ruby-200 px-2 font-medium text-ruby-700 hover:bg-ruby-50 dark:border-ruby-900 dark:text-ruby-300 dark:hover:bg-ruby-950/40"
                        @click="openDeleteCategoryDialog(label)"
                      >
                        <span class="i-lucide-trash-2 size-3.5" />
                        {{ CATEGORIES_PAGE_TEXT.deleteCategory }}
                      </button>
                    </div>
                  </div>
                </div>
                <p v-else class="text-[11px] text-n-slate-10">
                  {{ CRM_FILTER_TEXT.noCategoriesInType }}
                </p>
              </article>
            </div>
          </section>

          <aside class="rounded-lg border border-n-weak bg-n-solid-2 p-4">
            <h3 class="m-0 text-sm font-semibold text-n-slate-12">
              {{ CATEGORIES_PAGE_TEXT.responsiblePortfolio }}
            </h3>
            <div class="mt-3 grid gap-2">
              <button
                v-for="owner in ownerSummaries"
                :key="owner.id"
                type="button"
                class="flex h-10 min-w-0 items-center justify-between gap-2 rounded border px-3 font-medium transition hover:bg-n-slate-2"
                :class="
                  (owner.unassigned && crmFilters.withoutCrmOwner) ||
                  crmFilters.crmOwnerId === owner.id
                    ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                    : owner.unassigned
                      ? 'border-ruby-200 bg-ruby-50 text-ruby-700 dark:border-ruby-900 dark:bg-ruby-950/40 dark:text-ruby-300'
                      : 'border-n-weak text-n-slate-11'
                "
                @click="applyOwnerSummary(owner)"
              >
                <span class="flex min-w-0 items-center gap-2">
                  <span
                    :class="
                      owner.unassigned
                        ? 'i-lucide-user-x'
                        : 'i-lucide-user-check'
                    "
                    class="size-3.5 shrink-0"
                  />
                  <span class="truncate">{{ owner.name }}</span>
                </span>
                <span class="text-[11px] opacity-70">{{ owner.count }}</span>
              </button>
            </div>
          </aside>
        </div>

        <div
          v-if="!crmFilters.label && !searchQuery && !hasAppliedFilters"
          class="rounded-lg border border-dashed border-n-weak bg-n-solid-2 p-5 text-center text-sm text-n-slate-11"
        >
          {{ CATEGORIES_PAGE_TEXT.chooseCategory }}
        </div>

        <div
          v-if="crmFilters.label"
          class="rounded-lg border border-n-weak bg-n-solid-2 p-3"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div>
              <p
                class="m-0 text-[11px] font-semibold uppercase tracking-normal text-n-slate-10"
              >
                {{ CATEGORIES_PAGE_TEXT.selectedAudience }}
              </p>
              <h3 class="m-0 mt-1 text-sm font-semibold text-n-slate-12">
                {{ activeCategoryName }}
              </h3>
            </div>
            <button
              type="button"
              class="inline-flex h-8 items-center justify-center rounded border border-n-weak px-3 font-medium text-n-slate-11 hover:bg-n-slate-2"
              @click="clearCrmFilters"
            >
              {{ CRM_FILTER_TEXT.clear }}
            </button>
          </div>
        </div>
      </section>
      <section
        v-else-if="isListView"
        class="mt-4 rounded-lg border border-n-weak bg-n-solid-2 p-3 text-xs sm:p-4"
      >
        <div
          class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between"
        >
          <div class="min-w-0">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ CRM_FILTER_TEXT.listTitle }}
            </h3>
            <p class="mt-0.5 text-xs text-n-slate-11">
              {{ CRM_FILTER_TEXT.listSubtitle }}
            </p>
          </div>
          <button
            v-if="hasCrmFilters"
            type="button"
            class="inline-flex h-8 items-center justify-center rounded border border-n-weak px-3 font-medium text-n-slate-11 hover:bg-n-slate-2"
            @click="clearCrmFilters"
          >
            {{ CRM_FILTER_TEXT.clear }}
          </button>
        </div>

        <div class="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.relationship }}
            </span>
            <select
              v-model="crmFilters.relationshipStatus"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option value="lead">{{ CRM_FILTER_TEXT.lead }}</option>
              <option value="customer">{{ CRM_FILTER_TEXT.customer }}</option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.lifecycle }}
            </span>
            <select
              v-model="crmFilters.lifecycleStage"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option value="lead">{{ CRM_FILTER_TEXT.lead }}</option>
              <option value="qualified_lead">
                {{ CRM_FILTER_TEXT.qualifiedLead }}
              </option>
              <option value="triage">{{ CRM_FILTER_TEXT.triage }}</option>
              <option value="consultation_scheduled">
                {{ CRM_FILTER_TEXT.scheduled }}
              </option>
              <option value="customer">{{ CRM_FILTER_TEXT.customer }}</option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.label }}
            </span>
            <select
              v-model="crmFilters.label"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option
                v-for="label in visibleLabels"
                :key="label.id"
                :value="label.title"
              >
                {{ categoryDisplayName(label) }}
              </option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.owner }}
            </span>
            <select
              v-model="listOwnerFilter"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option :value="LIST_OWNER_WITHOUT">
                {{ CRM_FILTER_TEXT.withoutOwner }}
              </option>
              <option
                v-for="agent in agentList"
                :key="agent.id"
                :value="String(agent.id)"
              >
                {{ agent.name || agent.email }}
              </option>
            </select>
          </label>
        </div>
      </section>
      <section
        v-else-if="!isListView"
        class="mt-4 rounded-lg border border-n-weak bg-n-solid-2 p-3 text-xs sm:p-4"
      >
        <div
          class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
        >
          <div class="min-w-0">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ CRM_FILTER_TEXT.title }}
            </h3>
            <p class="mt-0.5 text-xs text-n-slate-11">
              {{ CRM_FILTER_TEXT.subtitle }}
            </p>
          </div>
          <button
            v-if="hasCrmFilters"
            type="button"
            class="inline-flex h-8 items-center justify-center rounded border border-n-weak px-3 font-medium text-n-slate-11 hover:bg-n-slate-2"
            @click="clearCrmFilters"
          >
            {{ CRM_FILTER_TEXT.clear }}
          </button>
        </div>

        <div class="mt-4 rounded border border-n-weak bg-n-surface-1 p-3">
          <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
            <div>
              <span class="font-semibold text-n-slate-12">
                {{ CRM_FILTER_TEXT.categories }}
              </span>
              <p class="mt-0.5 text-n-slate-11">
                {{ `${CRM_FILTER_TEXT.activeAudience}:` }}
                <span class="font-medium text-n-slate-12">
                  {{ activeAudienceSummary }}
                </span>
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                type="button"
                class="inline-flex h-8 items-center gap-1 rounded border border-n-weak px-3 font-medium text-n-slate-11 transition hover:bg-n-slate-2"
                @click="showCategoryForm = !showCategoryForm"
              >
                <span class="i-lucide-plus size-3.5" />
                {{ CRM_FILTER_TEXT.newCategory }}
              </button>
              <button
                type="button"
                class="inline-flex h-8 items-center gap-1 rounded border border-n-blue-7 bg-n-blue-3 px-3 font-medium text-n-blue-11"
                @click="openCampaigns"
              >
                <span class="i-lucide-megaphone size-3.5" />
                {{ CRM_FILTER_TEXT.campaignCta }}
              </button>
            </div>
          </div>

          <form
            v-if="showCategoryForm"
            class="mb-3 grid gap-2 rounded border border-n-weak bg-n-solid-2 p-3 sm:grid-cols-[minmax(0,1fr)_180px_auto]"
            @submit.prevent="createCategory"
          >
            <label class="flex min-w-0 flex-col gap-1">
              <span class="font-medium text-n-slate-11">
                {{ CRM_FILTER_TEXT.categoryName }}
              </span>
              <input
                v-model="newCategoryName"
                type="text"
                :placeholder="CRM_FILTER_TEXT.categoryNamePlaceholder"
                class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              />
            </label>
            <label class="flex min-w-0 flex-col gap-1">
              <span class="font-medium text-n-slate-11">
                {{ CRM_FILTER_TEXT.categoryKind }}
              </span>
              <select
                v-model="newCategoryKind"
                class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              >
                <option
                  v-for="option in CATEGORY_KIND_OPTIONS"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
            <button
              type="submit"
              class="mt-auto inline-flex h-9 items-center justify-center rounded bg-n-blue-9 px-3 font-semibold text-white disabled:opacity-50"
              :disabled="isCreatingCategory || !newCategoryName"
            >
              {{ CRM_FILTER_TEXT.createCategory }}
            </button>
          </form>

          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
              :class="
                !crmFilters.label
                  ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                  : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
              "
              @click="applyCategory('')"
            >
              {{ CRM_FILTER_TEXT.allContacts }}
            </button>
          </div>

          <div class="mt-3 grid gap-3 lg:grid-cols-2">
            <article
              v-for="group in categoryGroups"
              :key="group.key"
              class="rounded border border-n-weak bg-n-solid-2 p-3"
            >
              <div class="mb-3 flex items-start gap-2">
                <span
                  :class="group.icon"
                  class="mt-0.5 size-4 shrink-0 text-n-slate-10"
                />
                <div class="min-w-0">
                  <h4 class="text-sm font-semibold text-n-slate-12">
                    {{ group.title }}
                  </h4>
                  <p class="mt-0.5 text-[11px] leading-4 text-n-slate-11">
                    {{ group.description }}
                  </p>
                </div>
              </div>

              <div v-if="group.categories.length" class="flex flex-wrap gap-2">
                <button
                  v-for="label in group.categories"
                  :key="label.id"
                  type="button"
                  class="inline-flex h-8 max-w-full items-center gap-2 rounded border px-3 font-medium transition hover:bg-n-slate-2"
                  :class="{
                    'ring-2 ring-n-blue-7': crmFilters.label === label.title,
                  }"
                  :style="categoryStyle(label)"
                  @click="applyCategory(label.title)"
                >
                  <span class="i-lucide-tags size-3.5 shrink-0" />
                  <span class="truncate">
                    {{
                      label.display_title || humanizeCategoryTitle(label.title)
                    }}
                  </span>
                  <span class="text-[11px] opacity-70">
                    {{
                      categoryCountByTitle[label.title] ||
                      label.contacts_count ||
                      0
                    }}
                  </span>
                </button>
              </div>
              <p v-else class="text-[11px] text-n-slate-10">
                {{ CRM_FILTER_TEXT.noCategoriesInType }}
              </p>
            </article>
          </div>
        </div>

        <div class="mt-3 rounded border border-n-weak bg-n-surface-1 p-3">
          <div class="mb-3 flex items-start gap-2">
            <span class="i-lucide-user-check mt-0.5 size-4 text-n-slate-10" />
            <div>
              <span class="font-semibold text-n-slate-12">
                {{ CRM_FILTER_TEXT.responsiblePeople }}
              </span>
              <p class="mt-0.5 text-n-slate-11">
                {{ CRM_FILTER_TEXT.responsiblePeopleDescription }}
              </p>
            </div>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="owner in ownerSummaries"
              :key="owner.id"
              type="button"
              class="inline-flex h-8 max-w-full items-center gap-2 rounded border px-3 font-medium transition hover:bg-n-slate-2"
              :class="
                (owner.unassigned && crmFilters.withoutCrmOwner) ||
                crmFilters.crmOwnerId === owner.id
                  ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                  : owner.unassigned
                    ? 'border-ruby-200 bg-ruby-50 text-ruby-700 dark:border-ruby-900 dark:bg-ruby-950/40 dark:text-ruby-300'
                    : 'border-n-weak text-n-slate-11'
              "
              @click="applyOwnerSummary(owner)"
            >
              <span
                :class="
                  owner.unassigned ? 'i-lucide-user-x' : 'i-lucide-user-check'
                "
                class="size-3.5 shrink-0"
              />
              <span class="truncate">{{ owner.name }}</span>
              <span class="text-[11px] opacity-70">{{ owner.count }}</span>
            </button>
          </div>
        </div>

        <div class="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
            :class="
              !hasCrmFilters
                ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
            "
            @click="clearCrmFilters"
          >
            {{ CRM_FILTER_TEXT.allContacts }}
          </button>
          <button
            type="button"
            class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
            :class="
              crmFilters.relationshipStatus === 'lead'
                ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
            "
            @click="applyRelationshipShortcut('lead')"
          >
            {{ CRM_FILTER_TEXT.lead }}
          </button>
          <button
            type="button"
            class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
            :class="
              crmFilters.relationshipStatus === 'customer'
                ? 'border-emerald-300 bg-emerald-50 text-emerald-700 dark:border-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-300'
                : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
            "
            @click="applyRelationshipShortcut('customer')"
          >
            {{ CRM_FILTER_TEXT.customer }}
          </button>
          <button
            type="button"
            class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
            :class="
              crmFilters.withoutCrmOwner
                ? 'border-ruby-300 bg-ruby-50 text-ruby-700 dark:border-ruby-900 dark:bg-ruby-950/40 dark:text-ruby-300'
                : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
            "
            @click="applyWithoutOwnerShortcut"
          >
            {{ CRM_FILTER_TEXT.withoutOwner }}
          </button>
          <button
            v-if="currentUserId"
            type="button"
            class="inline-flex h-8 items-center rounded border px-3 font-medium transition"
            :class="
              crmFilters.crmOwnerId === String(currentUserId)
                ? 'border-n-blue-8 bg-n-blue-3 text-n-blue-11'
                : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'
            "
            @click="applyMyCrmContacts"
          >
            {{ CRM_FILTER_TEXT.mine }}
          </button>
        </div>

        <div class="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.relationship }}
            </span>
            <select
              v-model="crmFilters.relationshipStatus"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option value="lead">{{ CRM_FILTER_TEXT.lead }}</option>
              <option value="customer">{{ CRM_FILTER_TEXT.customer }}</option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.lifecycle }}
            </span>
            <select
              v-model="crmFilters.lifecycleStage"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option value="lead">{{ CRM_FILTER_TEXT.lead }}</option>
              <option value="qualified_lead">
                {{ CRM_FILTER_TEXT.qualifiedLead }}
              </option>
              <option value="triage">{{ CRM_FILTER_TEXT.triage }}</option>
              <option value="consultation_scheduled">
                {{ CRM_FILTER_TEXT.scheduled }}
              </option>
              <option value="customer">{{ CRM_FILTER_TEXT.customer }}</option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.owner }}
            </span>
            <select
              v-model="crmFilters.crmOwnerId"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              :disabled="crmFilters.withoutCrmOwner"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option
                v-for="agent in agentList"
                :key="agent.id"
                :value="String(agent.id)"
              >
                {{ agent.name || agent.email }}
              </option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.label }}
            </span>
            <select
              v-model="crmFilters.label"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option
                v-for="label in visibleLabels"
                :key="label.id"
                :value="label.title"
              >
                {{ label.display_title || label.title }}
              </option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.sourceList }}
            </span>
            <select
              v-model="crmFilters.sourceList"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyCrmFilters"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option
                v-for="sourceList in sourceListOptions"
                :key="sourceList"
                :value="sourceList"
              >
                {{ sourceList }}
              </option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.legalArea }}
            </span>
            <select
              :model-value="crmFilters.label"
              class="h-9 rounded border border-n-weak bg-n-surface-1 px-2 outline-none"
              @change="applyLegalAreaCategory($event.target.value)"
            >
              <option value="">{{ CRM_FILTER_TEXT.all }}</option>
              <option
                v-for="label in legalAreaCategoryLabels"
                :key="label.id"
                :value="label.title"
              >
                {{ label.display_title || humanizeCategoryTitle(label.title) }}
              </option>
            </select>
          </label>
        </div>

        <div
          v-if="hasRecentImports || isLoadingImports"
          class="mt-4 border-t border-n-weak pt-3"
        >
          <div class="mb-2 flex items-center justify-between gap-2">
            <span class="font-medium text-n-slate-12">
              {{ CRM_FILTER_TEXT.importedLists }}
            </span>
            <span v-if="isLoadingImports" class="text-n-slate-10">
              {{ IMPORT_TEXT.loading }}
            </span>
          </div>
          <div class="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
            <button
              v-for="item in recentImports.slice(0, 4)"
              :key="item.id"
              type="button"
              class="rounded border border-n-weak bg-n-surface-1 p-2 text-left transition hover:border-n-blue-8 hover:bg-n-blue-2"
              @click="applySourceList(item.metadata?.source_list)"
            >
              <div class="flex items-center justify-between gap-2">
                <span class="truncate font-medium text-n-slate-12">
                  {{ importTitle(item) }}
                </span>
                <span class="shrink-0 text-n-slate-10">
                  {{ importStatusLabel(item.status) }}
                </span>
              </div>
              <div class="mt-1 text-n-slate-11">
                {{ importProgress(item) }}
                <span v-if="item.rejected_records">
                  {{ importFailures(item) }}
                </span>
              </div>
              <a
                v-if="item.failed_records_url"
                :href="item.failed_records_url"
                class="mt-1 inline-flex text-n-blue-11 hover:underline"
                @click.stop
              >
                {{ IMPORT_TEXT.downloadErrors }}
              </a>
            </button>
          </div>
        </div>
      </section>
      <div
        v-if="
          shouldShowContactsList &&
          isFetchingList &&
          !(isSearchView && hasContacts)
        "
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <template v-else-if="shouldShowContactsList">
        <ContactsBulkActionBar
          v-if="hasSelection"
          :visible-contact-ids="visibleContactIds"
          :selected-contact-ids="selectedContactIds"
          :is-loading="isBulkActionLoading"
          :active-category-name="activeCategoryName"
          @toggle-all="toggleSelectAll"
          @clear-selection="clearSelection"
          @assign-labels="assignLabels"
          @remove-category="removeActiveCategoryFromSelection"
          @delete-selected="openBulkDeleteDialog"
        />
        <ContactEmptyState
          v-if="showEmptyStateLayout"
          class="pt-14"
          :title="t('CONTACTS_LAYOUT.EMPTY_STATE.TITLE')"
          :subtitle="t('CONTACTS_LAYOUT.EMPTY_STATE.SUBTITLE')"
          :button-label="t('CONTACTS_LAYOUT.EMPTY_STATE.BUTTON_LABEL')"
          @create="createContact"
        />
        <div
          v-else-if="showEmptyText"
          class="flex items-center justify-center py-10"
        >
          <span class="text-base text-n-slate-11">
            {{ emptyStateMessage }}
          </span>
        </div>
        <div v-else class="flex flex-col gap-4 pt-4 pb-6">
          <ContactsTableList
            v-if="isListView"
            :contacts="contacts"
            :selected-contact-ids="selectedContactIds"
            :category-labels="categoryLabels"
            :agents="agentList"
            @toggle-contact="toggleContactSelection"
            @toggle-all="toggleSelectAll"
            @show-contact="showContactDetails"
          />
          <ContactsList
            v-else
            :contacts="contacts"
            :selected-contact-ids="selectedContactIds"
            @toggle-contact="toggleContactSelection"
          />
          <Dialog
            v-if="selectedCount"
            ref="bulkDeleteDialogRef"
            type="alert"
            :title="bulkDeleteDialogTitle"
            :description="bulkDeleteDialogDescription"
            :confirm-button-label="bulkDeleteDialogConfirmLabel"
            :is-loading="isBulkActionLoading"
            @confirm="deleteContacts"
          />
        </div>
      </template>
      <Dialog
        ref="categoryEditDialogRef"
        width="md"
        :title="CATEGORIES_PAGE_TEXT.editCategoryTitle"
        :confirm-button-label="CATEGORIES_PAGE_TEXT.editCategory"
        :is-loading="isUpdatingCategory"
        :disable-confirm-button="!categoryEditForm.name || isUpdatingCategory"
        @confirm="updateCategory"
      >
        <div class="grid gap-3 text-sm">
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.categoryName }}
            </span>
            <input
              v-model="categoryEditForm.name"
              type="text"
              class="h-10 rounded border border-n-weak bg-n-surface-1 px-3 outline-none"
            />
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CRM_FILTER_TEXT.categoryKind }}
            </span>
            <select
              v-model="categoryEditForm.kind"
              class="h-10 rounded border border-n-weak bg-n-surface-1 px-3 outline-none"
            >
              <option
                v-for="option in CATEGORY_KIND_OPTIONS"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CATEGORIES_PAGE_TEXT.categoryColor }}
            </span>
            <span
              class="flex h-10 items-center gap-2 rounded border border-n-weak bg-n-surface-1 px-3"
            >
              <input
                v-model="categoryEditForm.color"
                type="color"
                class="size-6 border-0 bg-transparent p-0"
              />
              <input
                v-model="categoryEditForm.color"
                type="text"
                class="min-w-0 flex-1 bg-transparent outline-none"
              />
            </span>
          </label>
          <label class="flex min-w-0 flex-col gap-1">
            <span class="font-medium text-n-slate-11">
              {{ CATEGORIES_PAGE_TEXT.categoryDescription }}
            </span>
            <textarea
              v-model="categoryEditForm.description"
              rows="3"
              :placeholder="CATEGORIES_PAGE_TEXT.categoryDescriptionPlaceholder"
              class="resize-none rounded border border-n-weak bg-n-surface-1 px-3 py-2 outline-none"
            />
          </label>
        </div>
      </Dialog>
      <Dialog
        ref="categoryDeleteDialogRef"
        type="alert"
        :title="CATEGORIES_PAGE_TEXT.deleteCategoryTitle"
        :description="categoryDeleteDescription"
        :confirm-button-label="CATEGORIES_PAGE_TEXT.deleteCategoryConfirm"
        :is-loading="isDeletingCategory"
        @confirm="deleteCategory"
      />
    </ContactsListLayout>
  </div>
</template>

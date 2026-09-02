<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import {
  computed,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
} from 'vue';
import { useRoute } from 'vue-router';

import AgentsAPI from '../../../../api/agents';
import ContactAPI from '../../../../api/contacts';
import CrmAPI from '../../../../api/crm';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsCheckbox,
  DsDrawer,
  DsDropdown,
  DsEmptyState,
  DsInput,
  DsModal,
  DsPagination,
  DsSelect,
  DsTable,
  DsTabs,
  DsToast,
  DsTooltip,
} from 'dashboard/design-system/components';

const route = useRoute();

const activities = ref([]);
const deals = ref([]);
const contacts = ref([]);
const agents = ref([]);
const loading = ref(false);
const saving = ref(false);
const deleting = ref(false);
const syncingActivityId = ref(null);
const importingCalendar = ref(false);
const suggestingSchedule = ref(false);
const schedulingSuggestion = ref(false);
const error = ref('');
const calendarSyncSummary = ref('');
const scheduleSuggestionSummary = ref('');
const scheduleSuggestions = ref([]);
const scheduleDraft = ref(null);
const syncSuggestedSchedule = ref(true);
const drawerOpen = ref(false);
const drawerMode = ref('create');
const activityToDelete = ref(null);
const currentPage = ref(1);
let searchTimer = null;

const PAGE_SIZE = 50;

const filters = reactive({
  status: 'pending',
  kind: '',
  priority: '',
  from: '',
  to: '',
  search: '',
});

const form = reactive({
  id: null,
  title: '',
  description: '',
  kind: 'follow_up',
  priority: 'normal',
  due_at: '',
  reminder_at: '',
  crm_deal_id: '',
  contact_id: '',
  conversation_id: '',
  assignee_id: '',
});

const STATUS_TABS = [
  { value: 'pending', label: 'Pendentes', icon: 'i-lucide-list-todo' },
  { value: 'today', label: 'Hoje', icon: 'i-lucide-calendar-days' },
  { value: 'overdue', label: 'Vencidas', icon: 'i-lucide-alarm-clock' },
  { value: 'completed', label: 'Concluídas', icon: 'i-lucide-check-circle-2' },
  { value: 'all', label: 'Todas', icon: 'i-lucide-inbox' },
];

const KINDS = [
  { value: '', label: 'Todos os tipos' },
  { value: 'follow_up', label: 'Follow-up', icon: 'i-lucide-message-circle' },
  { value: 'ligacao', label: 'Ligação', icon: 'i-lucide-phone' },
  { value: 'reuniao', label: 'Reunião', icon: 'i-lucide-calendar-clock' },
  {
    value: 'solicitacao_documentos',
    label: 'Solicitação de documentos',
    icon: 'i-lucide-file-question',
  },
  {
    value: 'analise_documental',
    label: 'Análise documental',
    icon: 'i-lucide-file-search',
  },
  {
    value: 'revisao_juridica',
    label: 'Revisão jurídica',
    icon: 'i-lucide-scale',
  },
  {
    value: 'retorno_cliente',
    label: 'Retorno ao cliente',
    icon: 'i-lucide-reply',
  },
  {
    value: 'envio_proposta',
    label: 'Envio de proposta',
    icon: 'i-lucide-send',
  },
  {
    value: 'envio_contrato',
    label: 'Envio de contrato',
    icon: 'i-lucide-file-signature',
  },
  { value: 'arquivamento', label: 'Arquivamento', icon: 'i-lucide-archive' },
];

const PRIORITIES = [
  { value: '', label: 'Toda prioridade' },
  { value: 'baixa', label: 'Baixa', shortLabel: 'Baixa' },
  { value: 'normal', label: 'Normal', shortLabel: 'Normal' },
  { value: 'alta', label: 'Alta', shortLabel: 'Alta' },
  { value: 'critica', label: 'Crítica', shortLabel: 'Crítica' },
];

const isSearchMode = computed(() => filters.search.trim().length > 0);
const hasScheduleSuggestions = computed(
  () => scheduleSuggestions.value.length > 0
);
const isDrawerEditing = computed(() => drawerMode.value === 'edit');
const drawerTitle = computed(() =>
  isDrawerEditing.value ? 'Editar atividade' : 'Nova atividade'
);
const isFormValid = computed(() => form.title.trim().length > 2);
const visibleActivities = computed(() => {
  const start = (currentPage.value - 1) * PAGE_SIZE;
  return activities.value.slice(start, start + PAGE_SIZE);
});
const hasActiveFilters = computed(
  () =>
    filters.status !== 'pending' ||
    Boolean(filters.kind) ||
    Boolean(filters.priority) ||
    Boolean(filters.from) ||
    Boolean(filters.to) ||
    Boolean(filters.search)
);
const headerActionBusy = computed(
  () =>
    importingCalendar.value ||
    suggestingSchedule.value ||
    schedulingSuggestion.value
);

const ACTIVITY_HEADERS = [
  { key: 'activity', label: 'Atividade', class: 'w-[34%]' },
  { key: 'contact', label: 'Contato', class: 'w-[20%]' },
  { key: 'due', label: 'Prazo', class: 'w-[18%]' },
  { key: 'owner', label: 'Responsável', class: 'w-[18%]' },
  { key: 'actions', label: 'Ações', class: 'w-[10%] text-right' },
];
const MENU_ITEM_CLASSES =
  'flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text transition-colors duration-ui-fast hover:bg-ui-hover active:bg-ui-active focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus disabled:cursor-not-allowed disabled:text-ui-text-disabled max-sm:min-h-11';
const MENU_DANGER_ITEM_CLASSES =
  'flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-danger transition-colors duration-ui-fast hover:bg-ui-danger-soft active:bg-ui-danger-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-danger disabled:cursor-not-allowed disabled:opacity-60 max-sm:min-h-11';

const contactOptions = computed(() => {
  const contactsById = new Map();

  activities.value.forEach(activity => {
    addContactOption(contactsById, activity.contact);
    addContactOption(contactsById, activity.deal?.contact);
  });
  deals.value.forEach(deal => addContactOption(contactsById, deal.contact));
  contacts.value.forEach(contact => addContactOption(contactsById, contact));

  return Array.from(contactsById.values()).sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const dealOptions = computed(() =>
  deals.value
    .filter(deal => deal.id)
    .map(deal => ({
      id: deal.id,
      title: deal.title || `Lead #${deal.id}`,
      contact_id: deal.contact?.id || deal.contact_id || '',
      contactName: deal.contact?.name || '',
      stageName: deal.stage?.name || deal.crm_pipeline_stage?.name || '',
    }))
);

function addContactOption(map, contact) {
  if (!contact?.id) return;
  map.set(String(contact.id), {
    id: contact.id,
    name:
      contact.name ||
      contact.email ||
      contact.phone_number ||
      `Contato #${contact.id}`,
  });
}

function labelFor(list, value) {
  return list.find(item => item.value === value)?.label || value || 'Sem valor';
}

function dealOptionLabel(deal) {
  return [deal.title, deal.contactName].filter(Boolean).join(' — ');
}

function iconForKind(kind) {
  return KINDS.find(item => item.value === kind)?.icon || 'i-lucide-check';
}

function priorityLabel(priority) {
  return (
    PRIORITIES.find(item => item.value === (priority || 'normal'))
      ?.shortLabel || 'Normal'
  );
}

function priorityVariant(priority) {
  return {
    baixa: 'neutral',
    normal: 'neutral',
    alta: 'warning',
    critica: 'danger',
  }[priority || 'normal'];
}

function statusVariant(activity) {
  if (activity.completed_at) return 'success';
  if (activity.is_overdue) return 'danger';
  if (activity.is_due_today) return 'warning';
  return 'neutral';
}

function statusLabel(activity) {
  if (activity.completed_at) return 'Concluída';
  if (activity.is_overdue) return 'Vencida';
  if (activity.is_due_today) return 'Hoje';
  return 'Pendente';
}

function formatDateTime(value) {
  if (!value) return 'Sem prazo';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatTime(value) {
  return new Intl.DateTimeFormat('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function dueText(activity) {
  if (!activity.due_at) return 'Sem prazo definido';
  if (activity.is_overdue)
    return `Venceu em ${formatDateTime(activity.due_at)}`;
  if (activity.is_due_today) return `Hoje às ${formatTime(activity.due_at)}`;
  return formatDateTime(activity.due_at);
}

function dateTimeInputValue(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const offsetDate = new Date(
    date.getTime() - date.getTimezoneOffset() * 60000
  );
  return offsetDate.toISOString().slice(0, 16);
}

function nullableId(value) {
  return value ? Number(value) : null;
}

function dealPath(activity) {
  if (!activity.crm_deal_id) return '';
  return `/app/accounts/${route.params.accountId}/crm/deals/${activity.crm_deal_id}`;
}

function googleCalendarUrl(activity) {
  return (
    activity.calendar_links?.google || activity.calendarLinks?.google || ''
  );
}

function openExternalUrl(url) {
  if (!url) return;
  window.open(url, '_blank', 'noopener,noreferrer');
}

function cleanParams() {
  const params = {};
  const search = filters.search.trim();

  if (search) {
    params.q = search;
  } else if (filters.status && filters.status !== 'all') {
    params.status = filters.status;
  }

  if (filters.kind) params.kind = filters.kind;
  if (filters.priority) params.priority = filters.priority;
  if (filters.from) params.from = filters.from;
  if (filters.to) params.to = filters.to;
  return params;
}

function clearTransientMessages() {
  error.value = '';
  calendarSyncSummary.value = '';
  scheduleSuggestionSummary.value = '';
}

async function loadActivities() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.getActivities(cleanParams());
    activities.value = Array.isArray(data) ? data : [];
    const lastPage = Math.max(
      1,
      Math.ceil(activities.value.length / PAGE_SIZE)
    );
    if (currentPage.value > lastPage) currentPage.value = lastPage;
  } catch {
    error.value = 'Não foi possível carregar as atividades do CRM.';
  } finally {
    loading.value = false;
  }
}

function extractCollection(response) {
  const payload = response?.data;
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.payload)) return payload.payload;
  return [];
}

async function loadSupportData() {
  try {
    const [dealsResponse, agentsResponse, contactsResponse] = await Promise.all(
      [
        CrmAPI.getDeals({ per_page: 200 }),
        AgentsAPI.get(),
        ContactAPI.get(1, 'name'),
      ]
    );
    deals.value = extractCollection(dealsResponse);
    agents.value = extractCollection(agentsResponse);
    contacts.value = extractCollection(contactsResponse);
  } catch {
    // Support data is optional; activities still work without these selects.
  }
}

function exportCalendar() {
  window.open(CrmAPI.activitiesCalendarUrl(cleanParams()), '_blank');
}

async function importGoogleCalendar() {
  importingCalendar.value = true;
  clearTransientMessages();
  try {
    const { data } = await CrmAPI.importActivitiesGoogleCalendar({
      from: filters.from || undefined,
      to: filters.to || undefined,
    });
    calendarSyncSummary.value = `Google Calendar: ${data.imported || 0} importadas, ${data.updated || 0} atualizadas, ${data.skipped || 0} ignoradas.`;
    await loadActivities();
  } catch (err) {
    if (err?.response?.data?.authorization_required) {
      const response = await CrmAPI.authorizeGoogleWorkspace();
      if (response.data?.url) window.location.href = response.data.url;
      return;
    }
    error.value =
      err?.response?.data?.error ||
      'Não foi possível importar o Google Calendar.';
  } finally {
    importingCalendar.value = false;
  }
}

async function suggestSchedule() {
  suggestingSchedule.value = true;
  clearTransientMessages();
  scheduleSuggestions.value = [];
  scheduleDraft.value = null;

  try {
    const { data } = await CrmAPI.suggestActivitySchedule({
      title: form.title || undefined,
      description: form.description || undefined,
      kind: form.kind || 'reuniao',
      priority: form.priority || 'normal',
      from: filters.from || undefined,
      to: filters.to || undefined,
      duration_minutes: form.kind === 'reuniao' ? 60 : 30,
    });
    scheduleDraft.value = data.draft || null;
    scheduleSuggestions.value = Array.isArray(data.suggestions)
      ? data.suggestions
      : [];
    scheduleSuggestionSummary.value = scheduleSuggestions.value.length
      ? 'Escolha uma janela sugerida para criar a atividade.'
      : 'Nenhuma janela livre foi encontrada no período selecionado.';
  } catch (err) {
    error.value =
      err?.response?.data?.error ||
      'Não foi possível gerar sugestões de agenda.';
  } finally {
    suggestingSchedule.value = false;
  }
}

async function scheduleSuggestedSlot(slot) {
  schedulingSuggestion.value = true;
  error.value = '';
  try {
    const draft = scheduleDraft.value || {};
    const { data } = await CrmAPI.scheduleActivitySuggestion({
      title: draft.title || form.title || 'Consulta jurídica',
      description:
        draft.description ||
        form.description ||
        'Criada pelo agendamento inteligente do CRM.',
      kind: draft.kind || form.kind || 'reuniao',
      priority: draft.priority || form.priority || 'normal',
      due_at: slot.starts_at,
      reminder_at: slot.starts_at,
      crm_deal_id: draft.crm_deal_id || undefined,
      contact_id: draft.contact_id || undefined,
      assignee_id: draft.assignee_id || undefined,
      sync_google_calendar: syncSuggestedSchedule.value,
    });

    if (data.authorization_required) {
      const response = await CrmAPI.authorizeGoogleWorkspace();
      if (response.data?.url) window.location.href = response.data.url;
      return;
    }

    scheduleSuggestionSummary.value = data.calendar?.meet_link
      ? `Atividade criada e Meet gerado: ${data.calendar.meet_link}`
      : 'Atividade criada a partir da sugestão.';
    scheduleSuggestions.value = [];
    scheduleDraft.value = null;
    await loadActivities();
  } catch (err) {
    error.value =
      err?.response?.data?.error ||
      'Não foi possível criar a atividade sugerida.';
  } finally {
    schedulingSuggestion.value = false;
  }
}

function setStatus(status) {
  filters.status = status;
  currentPage.value = 1;
  if (!isSearchMode.value) loadActivities();
}

function reloadFromFirstPage() {
  currentPage.value = 1;
  loadActivities();
}

function resetFilters() {
  filters.status = 'pending';
  filters.kind = '';
  filters.priority = '';
  filters.from = '';
  filters.to = '';
  filters.search = '';
  currentPage.value = 1;
  loadActivities();
}

function resetForm() {
  form.id = null;
  form.title = '';
  form.description = '';
  form.kind = 'follow_up';
  form.priority = 'normal';
  form.due_at = '';
  form.reminder_at = '';
  form.crm_deal_id = '';
  form.contact_id = '';
  form.conversation_id = '';
  form.assignee_id = '';
}

function openCreateDrawer() {
  drawerMode.value = 'create';
  resetForm();
  drawerOpen.value = true;
}

function openEditDrawer(activity) {
  drawerMode.value = 'edit';
  form.id = activity.id;
  form.title = activity.title || '';
  form.description = activity.description || '';
  form.kind = activity.kind || 'follow_up';
  form.priority = activity.priority || 'normal';
  form.due_at = dateTimeInputValue(activity.due_at);
  form.reminder_at = dateTimeInputValue(activity.reminder_at);
  form.crm_deal_id = activity.crm_deal_id || '';
  form.contact_id = activity.contact?.id || activity.contact_id || '';
  form.conversation_id = activity.conversation_id || '';
  form.assignee_id = activity.assignee_id || '';
  drawerOpen.value = true;
}

function closeDrawer() {
  drawerOpen.value = false;
  resetForm();
}

function applyDealContext() {
  const selectedDeal = dealOptions.value.find(
    deal => String(deal.id) === String(form.crm_deal_id)
  );
  if (selectedDeal?.contact_id) form.contact_id = selectedDeal.contact_id;
}

function activityPayload() {
  return {
    title: form.title.trim(),
    description: form.description.trim() || null,
    kind: form.kind,
    priority: form.priority,
    due_at: form.due_at || null,
    reminder_at: form.reminder_at || null,
    crm_deal_id: nullableId(form.crm_deal_id),
    contact_id: nullableId(form.contact_id),
    conversation_id: nullableId(form.conversation_id),
    assignee_id: nullableId(form.assignee_id),
  };
}

async function saveActivity() {
  if (!isFormValid.value) return;

  saving.value = true;
  error.value = '';
  try {
    if (isDrawerEditing.value) {
      await CrmAPI.updateActivity(form.id, activityPayload());
    } else {
      await CrmAPI.createActivity(activityPayload());
    }
    closeDrawer();
    await loadActivities();
  } catch (err) {
    error.value =
      err?.response?.data?.error || 'Não foi possível salvar a atividade.';
  } finally {
    saving.value = false;
  }
}

async function completeActivity(activity) {
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.completeActivity(activity.id, 'Concluída no CRM');
    await loadActivities();
  } catch {
    error.value = 'Não foi possível concluir a atividade.';
  } finally {
    saving.value = false;
  }
}

async function snoozeActivity(activity, hours) {
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.snoozeActivity(activity.id, hours);
    await loadActivities();
  } catch {
    error.value = 'Não foi possível reagendar a atividade.';
  } finally {
    saving.value = false;
  }
}

function askDeleteActivity(activity) {
  activityToDelete.value = activity;
}

function cancelDelete() {
  activityToDelete.value = null;
}

async function deleteActivity() {
  if (!activityToDelete.value) return;

  deleting.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteActivity(activityToDelete.value.id);
    activityToDelete.value = null;
    await loadActivities();
  } catch {
    error.value = 'Não foi possível excluir a atividade.';
  } finally {
    deleting.value = false;
  }
}

async function syncGoogleCalendar(activity) {
  if (!activity.due_at) return;

  syncingActivityId.value = activity.id;
  error.value = '';
  try {
    const { data } = await CrmAPI.syncActivityGoogleCalendar(activity.id);
    openExternalUrl(data.html_link || data.htmlLink || data.meet_link);
  } catch (err) {
    if (err?.response?.data?.authorization_required) {
      const response = await CrmAPI.authorizeGoogleWorkspace();
      if (response.data?.url) window.location.href = response.data.url;
      return;
    }
    error.value =
      err?.response?.data?.error ||
      'Não foi possível sincronizar com o Google Calendar.';
  } finally {
    syncingActivityId.value = null;
  }
}

watch(
  () => filters.search,
  () => {
    window.clearTimeout(searchTimer);
    currentPage.value = 1;
    searchTimer = window.setTimeout(loadActivities, 350);
  }
);

onMounted(async () => {
  await Promise.all([loadActivities(), loadSupportData()]);
});

onBeforeUnmount(() => {
  window.clearTimeout(searchTimer);
});
</script>

<template>
  <main
    class="flex h-full min-h-0 flex-col overflow-hidden bg-ui-canvas font-sans text-ui-text"
  >
    <header
      class="flex shrink-0 flex-wrap items-center justify-between gap-4 border-b border-ui-border-subtle bg-ui-surface px-4 py-3"
    >
      <div class="min-w-0">
        <nav aria-label="Navegação estrutural">
          <ol
            class="mb-1 flex items-center gap-2 text-ui-caption text-ui-text-muted"
          >
            <li>CRM</li>
            <li aria-hidden="true">/</li>
            <li aria-current="page">Atividades</li>
          </ol>
        </nav>
        <h1 class="m-0 text-ui-title font-semibold text-ui-text">Atividades</h1>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <DsButton
          label="Nova atividade"
          icon="i-lucide-plus"
          variant="primary"
          @click="openCreateDrawer"
        />
        <DsDropdown
          label="Mais ações"
          icon="i-lucide-ellipsis"
          :loading="headerActionBusy"
        >
          <button
            type="button"
            role="menuitem"
            :class="MENU_ITEM_CLASSES"
            @click="exportCalendar"
          >
            <span class="i-lucide-download size-4" aria-hidden="true" />
            Exportar calendário
          </button>
          <button
            type="button"
            role="menuitem"
            :class="MENU_ITEM_CLASSES"
            :disabled="importingCalendar"
            @click="importGoogleCalendar"
          >
            <span class="i-lucide-upload size-4" aria-hidden="true" />
            Importar do Google
          </button>
          <button
            type="button"
            role="menuitem"
            :class="MENU_ITEM_CLASSES"
            :disabled="suggestingSchedule"
            @click="suggestSchedule"
          >
            <span class="i-lucide-calendar-search size-4" aria-hidden="true" />
            Sugerir horário
          </button>
        </DsDropdown>
      </div>
    </header>

    <section
      aria-label="Filtros de atividades"
      class="shrink-0 border-b border-ui-border-subtle bg-ui-surface p-3"
    >
      <div class="flex flex-col gap-3">
        <div class="flex min-w-0 flex-wrap items-center justify-between gap-3">
          <DsTabs
            :model-value="filters.status"
            :tabs="STATUS_TABS"
            label="Situação das atividades"
            :loading="loading && !isSearchMode"
            @change="setStatus"
          />
          <p
            class="m-0 shrink-0 text-ui-body-sm tabular-nums text-ui-text-muted"
            aria-live="polite"
          >
            {{ activities.length }}
            {{ activities.length === 1 ? 'atividade' : 'atividades' }}
          </p>
        </div>

        <div
          class="grid min-w-0 grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-[minmax(16rem,1fr)_12rem_12rem_10rem_10rem_auto]"
        >
          <DsInput
            v-model="filters.search"
            type="search"
            label="Buscar atividades"
            hide-label
            placeholder="Buscar atividade, contato, caso ou responsável"
            :loading="loading && isSearchMode"
          >
            <template #prefix>
              <span class="i-lucide-search size-4" aria-hidden="true" />
            </template>
          </DsInput>
          <DsSelect
            v-model="filters.kind"
            label="Tipo de atividade"
            hide-label
            :options="KINDS"
            @change="reloadFromFirstPage"
          />
          <DsSelect
            v-model="filters.priority"
            label="Prioridade"
            hide-label
            :options="PRIORITIES"
            @change="reloadFromFirstPage"
          />
          <DsInput
            v-model="filters.from"
            type="date"
            label="Data inicial"
            hide-label
            @change="reloadFromFirstPage"
          />
          <DsInput
            v-model="filters.to"
            type="date"
            label="Data final"
            hide-label
            @change="reloadFromFirstPage"
          />
          <DsButton
            label="Limpar"
            icon="i-lucide-filter-x"
            variant="ghost"
            :disabled="!hasActiveFilters"
            @click="resetFilters"
          />
        </div>
      </div>
    </section>

    <div
      class="pointer-events-none fixed right-4 top-4 z-ui-toast flex w-[calc(100%-2rem)] max-w-sm flex-col gap-2"
      role="region"
      aria-label="Avisos"
    >
      <DsToast
        v-if="error"
        class="pointer-events-auto"
        variant="danger"
        title="Não foi possível concluir a ação"
        :message="error"
        @dismiss="error = ''"
      />
      <DsToast
        v-if="calendarSyncSummary"
        class="pointer-events-auto"
        variant="success"
        :message="calendarSyncSummary"
        @dismiss="calendarSyncSummary = ''"
      />
      <DsToast
        v-if="scheduleSuggestionSummary"
        class="pointer-events-auto"
        variant="success"
        :message="scheduleSuggestionSummary"
        @dismiss="scheduleSuggestionSummary = ''"
      />
    </div>

    <section class="min-h-0 flex-1 overflow-y-auto p-3">
      <DsCard
        v-if="hasScheduleSuggestions"
        as="section"
        padding="md"
        class="mb-3"
        aria-labelledby="schedule-suggestions-title"
      >
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="min-w-0">
            <h2
              id="schedule-suggestions-title"
              class="m-0 text-ui-heading font-semibold text-ui-text"
            >
              {{ scheduleDraft?.title || 'Sugestões de horário' }}
            </h2>
            <p class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted">
              Janelas livres em horário comercial, sem conflito com atividades
              já marcadas.
            </p>
          </div>
          <DsCheckbox
            v-model="syncSuggestedSchedule"
            label="Sincronizar Google e Meet"
          />
        </div>

        <div class="mt-4 divide-y divide-ui-border-subtle">
          <div
            v-for="slot in scheduleSuggestions"
            :key="slot.starts_at"
            class="flex flex-wrap items-center justify-between gap-4 py-3"
          >
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <strong class="text-ui-body font-semibold text-ui-text">
                  {{ slot.label }}
                </strong>
                <DsBadge :label="`${slot.duration_minutes} min`" />
              </div>
              <p class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted">
                {{ slot.reason }}
              </p>
            </div>
            <DsButton
              label="Criar atividade"
              icon="i-lucide-calendar-check"
              variant="primary"
              :loading="schedulingSuggestion"
              @click="scheduleSuggestedSlot(slot)"
            />
          </div>
        </div>
      </DsCard>

      <DsTable
        id="ds-tab-panel-activities"
        caption="Lista de atividades do CRM"
        :headers="ACTIVITY_HEADERS"
        :items="visibleActivities"
        :loading="loading && !isSearchMode"
        empty-title="Nenhuma atividade corresponde aos filtros atuais."
        min-width-class="min-w-[58rem]"
      >
        <template #row="{ item: activity }">
          <tr
            class="group transition-colors duration-ui-fast hover:bg-ui-hover"
          >
            <td class="p-3 align-middle">
              <div class="flex min-w-0 items-start gap-3">
                <span
                  class="mt-1 flex size-8 shrink-0 items-center justify-center rounded-ui-control bg-ui-sunken text-ui-text-muted"
                  aria-hidden="true"
                >
                  <span :class="[iconForKind(activity.kind), 'size-4']" />
                </span>
                <div class="min-w-0">
                  <div class="flex min-w-0 flex-wrap items-center gap-2">
                    <strong
                      class="min-w-0 truncate text-ui-body font-semibold text-ui-text"
                    >
                      {{ activity.title }}
                    </strong>
                    <DsBadge
                      :label="statusLabel(activity)"
                      :variant="statusVariant(activity)"
                    />
                    <DsBadge
                      :label="priorityLabel(activity.priority)"
                      :variant="priorityVariant(activity.priority)"
                    />
                  </div>
                  <p
                    v-if="activity.description"
                    class="mb-0 mt-1 line-clamp-1 text-ui-body-sm text-ui-text-muted"
                  >
                    {{ activity.description }}
                  </p>
                  <div
                    class="mt-1 flex min-w-0 flex-wrap items-center gap-2 text-ui-caption text-ui-text-muted"
                  >
                    <span>{{ labelFor(KINDS, activity.kind) }}</span>
                    <span v-if="activity.deal?.stage?.name" aria-hidden="true">
                      ·
                    </span>
                    <span v-if="activity.deal?.stage?.name">
                      {{ activity.deal.stage.name }}
                    </span>
                    <router-link
                      v-if="activity.crm_deal_id"
                      :to="dealPath(activity)"
                      class="font-medium text-ui-brand-foreground hover:underline focus-visible:rounded-ui-control focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
                    >
                      Abrir caso
                    </router-link>
                  </div>
                </div>
              </div>
            </td>

            <td class="p-3 align-middle">
              <p class="m-0 truncate text-ui-body font-medium text-ui-text">
                {{ activity.contact?.name || 'Sem contato' }}
              </p>
              <p
                v-if="activity.deal?.title"
                class="m-0 truncate text-ui-caption text-ui-text-muted"
              >
                {{ activity.deal.title }}
              </p>
            </td>

            <td class="p-3 align-middle">
              <p
                class="m-0 text-ui-body-sm font-medium"
                :class="
                  activity.is_overdue
                    ? 'text-ui-danger-foreground'
                    : 'text-ui-text'
                "
              >
                {{ dueText(activity) }}
              </p>
            </td>

            <td class="p-3 align-middle">
              <p class="m-0 truncate text-ui-body-sm font-medium text-ui-text">
                {{
                  activity.assignee?.name ||
                  activity.owner?.name ||
                  'Sem responsável'
                }}
              </p>
              <p class="m-0 text-ui-caption text-ui-text-muted">
                {{
                  activity.external_calendar_synced_at
                    ? 'Sincronizada'
                    : 'Somente no CRM'
                }}
              </p>
            </td>

            <td class="p-3 align-middle">
              <div class="flex items-center justify-end gap-1">
                <DsTooltip
                  v-if="!activity.completed_at"
                  text="Concluir atividade"
                >
                  <template #default="{ tooltipId }">
                    <DsButton
                      icon="i-lucide-check"
                      size="sm"
                      variant="secondary"
                      aria-label="Concluir atividade"
                      :aria-describedby="tooltipId"
                      :disabled="saving"
                      @click="completeActivity(activity)"
                    />
                  </template>
                </DsTooltip>
                <DsTooltip text="Editar atividade">
                  <template #default="{ tooltipId }">
                    <DsButton
                      icon="i-lucide-pencil"
                      size="sm"
                      variant="ghost"
                      aria-label="Editar atividade"
                      :aria-describedby="tooltipId"
                      @click="openEditDrawer(activity)"
                    />
                  </template>
                </DsTooltip>
                <DsDropdown
                  icon="i-lucide-ellipsis"
                  aria-label="Mais ações da atividade"
                >
                  <button
                    v-if="!activity.completed_at"
                    type="button"
                    role="menuitem"
                    :class="MENU_ITEM_CLASSES"
                    :disabled="saving"
                    @click="snoozeActivity(activity, 24)"
                  >
                    <span class="i-lucide-clock-3 size-4" aria-hidden="true" />
                    Adiar 24 horas
                  </button>
                  <button
                    v-if="!activity.completed_at"
                    type="button"
                    role="menuitem"
                    :class="MENU_ITEM_CLASSES"
                    :disabled="saving"
                    @click="snoozeActivity(activity, 72)"
                  >
                    <span class="i-lucide-clock-9 size-4" aria-hidden="true" />
                    Adiar 72 horas
                  </button>
                  <button
                    v-if="googleCalendarUrl(activity)"
                    type="button"
                    role="menuitem"
                    :class="MENU_ITEM_CLASSES"
                    @click="openExternalUrl(googleCalendarUrl(activity))"
                  >
                    <span
                      class="i-lucide-external-link size-4"
                      aria-hidden="true"
                    />
                    Abrir no Google
                  </button>
                  <button
                    v-if="activity.due_at"
                    type="button"
                    role="menuitem"
                    :class="MENU_ITEM_CLASSES"
                    :disabled="saving || syncingActivityId === activity.id"
                    @click="syncGoogleCalendar(activity)"
                  >
                    <span
                      :class="[
                        syncingActivityId === activity.id
                          ? 'i-lucide-loader-circle animate-spin'
                          : 'i-lucide-cloud-upload',
                        'size-4',
                      ]"
                      aria-hidden="true"
                    />
                    Sincronizar calendário
                  </button>
                  <button
                    type="button"
                    role="menuitem"
                    :class="MENU_DANGER_ITEM_CLASSES"
                    @click="askDeleteActivity(activity)"
                  >
                    <span class="i-lucide-trash-2 size-4" aria-hidden="true" />
                    Excluir atividade
                  </button>
                </DsDropdown>
              </div>
            </td>
          </tr>
        </template>

        <template #empty>
          <DsEmptyState
            title="Nenhuma atividade corresponde aos filtros atuais."
            action-label="Nova atividade"
            @action="openCreateDrawer"
          />
        </template>
      </DsTable>

      <DsPagination
        v-if="activities.length > PAGE_SIZE"
        v-model:current-page="currentPage"
        :total-items="activities.length"
        :items-per-page="PAGE_SIZE"
      />
    </section>

    <DsDrawer
      id="activity-drawer"
      :open="drawerOpen"
      :title="drawerTitle"
      description="Defina a próxima ação, o prazo e a pessoa responsável."
      :loading="saving"
      @close="closeDrawer"
    >
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <DsInput
          v-model="form.title"
          label="Título"
          placeholder="Ex.: Retornar sobre aposentadoria"
          class="sm:col-span-2"
          :state="form.title && !isFormValid ? 'error' : 'default'"
          :message="
            form.title && !isFormValid
              ? 'Informe pelo menos três caracteres.'
              : ''
          "
          required
        />

        <DsSelect
          v-model="form.kind"
          label="Tipo"
          :options="KINDS.filter(item => item.value)"
        />
        <DsSelect
          v-model="form.priority"
          label="Prioridade"
          :options="PRIORITIES.filter(item => item.value)"
        />
        <DsInput v-model="form.due_at" type="datetime-local" label="Prazo" />
        <DsInput
          v-model="form.reminder_at"
          type="datetime-local"
          label="Lembrete"
        />

        <DsSelect
          v-model="form.crm_deal_id"
          label="Caso ou lead"
          class="sm:col-span-2"
          :options="[
            { value: '', label: 'Sem caso vinculado' },
            ...dealOptions.map(deal => ({
              value: deal.id,
              label: dealOptionLabel(deal),
            })),
          ]"
          @change="applyDealContext"
        />

        <DsSelect
          v-model="form.contact_id"
          label="Contato"
          :options="[
            { value: '', label: 'Sem contato' },
            ...contactOptions.map(contact => ({
              value: contact.id,
              label: contact.name,
            })),
          ]"
        />
        <DsSelect
          v-model="form.assignee_id"
          label="Responsável"
          :options="[
            { value: '', label: 'Sem responsável' },
            ...agents.map(agent => ({
              value: agent.id,
              label: agent.name || agent.email,
            })),
          ]"
        />

        <label class="flex flex-col gap-1 sm:col-span-2">
          <span class="text-ui-label font-medium text-ui-text">Descrição</span>
          <textarea
            v-model="form.description"
            rows="5"
            placeholder="Contexto, combinados ou próxima ação esperada"
            class="m-0 w-full resize-y rounded-ui-control border border-ui-border bg-ui-surface p-3 text-ui-body text-ui-text outline-none transition-colors duration-ui-fast placeholder:text-ui-text-subtle hover:border-ui-border-strong focus:border-ui-border-focus focus:ring-2 focus:ring-ui-border-focus/20 disabled:bg-ui-sunken disabled:text-ui-text-disabled"
          />
        </label>
      </div>

      <template #footer>
        <div class="flex flex-wrap justify-end gap-2">
          <DsButton
            label="Cancelar"
            variant="secondary"
            :disabled="saving"
            @click="closeDrawer"
          />
          <DsButton
            label="Salvar atividade"
            variant="primary"
            :loading="saving"
            :disabled="!isFormValid"
            @click="saveActivity"
          />
        </div>
      </template>
    </DsDrawer>

    <DsModal
      id="delete-activity-modal"
      :open="Boolean(activityToDelete)"
      title="Excluir atividade?"
      description="A atividade será removida da agenda e a exclusão ficará registrada no histórico do CRM."
      confirm-label="Excluir atividade"
      dangerous
      :loading="deleting"
      @close="cancelDelete"
      @confirm="deleteActivity"
    >
      <p class="m-0 text-ui-body font-medium text-ui-text">
        {{ activityToDelete?.title }}
      </p>
    </DsModal>
  </main>
</template>

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
let searchTimer = null;

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
    label: 'Analise documental',
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

const activeStatus = computed(() =>
  STATUS_TABS.find(tab => tab.value === filters.status)
);
const isSearchMode = computed(() => filters.search.trim().length > 0);
const hasScheduleSuggestions = computed(
  () => scheduleSuggestions.value.length > 0
);
const isDrawerEditing = computed(() => drawerMode.value === 'edit');
const drawerTitle = computed(() =>
  isDrawerEditing.value ? 'Editar atividade' : 'Nova atividade'
);
const isFormValid = computed(() => form.title.trim().length > 2);

const stats = computed(() => {
  const source = activities.value;
  return {
    total: source.length,
    overdue: source.filter(item => item.is_overdue).length,
    today: source.filter(item => item.is_due_today).length,
    highPriority: source.filter(item =>
      ['alta', 'critica'].includes(item.priority)
    ).length,
    withoutAssignee: source.filter(item => !item.assignee && !item.owner)
      .length,
  };
});

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

function iconForKind(kind) {
  return KINDS.find(item => item.value === kind)?.icon || 'i-lucide-check';
}

function priorityLabel(priority) {
  return (
    PRIORITIES.find(item => item.value === (priority || 'normal'))
      ?.shortLabel || 'Normal'
  );
}

function prioritySignalClass(priority) {
  return {
    baixa: 'crm-priority-signal crm-priority-signal--low',
    normal: 'crm-priority-signal crm-priority-signal--normal',
    alta: 'crm-priority-signal crm-priority-signal--high',
    critica: 'crm-priority-signal crm-priority-signal--critical',
  }[priority || 'normal'];
}

function activityRowClass(priority) {
  return {
    baixa: 'crm-activity-row--low',
    normal: 'crm-activity-row--normal',
    alta: 'crm-activity-row--high',
    critica: 'crm-activity-row--critical',
  }[priority || 'normal'];
}

function statusClass(activity) {
  if (activity.completed_at) return 'crm-status crm-status--done';
  if (activity.is_overdue) return 'crm-status crm-status--overdue';
  if (activity.is_due_today) return 'crm-status crm-status--today';
  return 'crm-status crm-status--pending';
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
  if (activity.is_due_today) return `Hoje as ${formatTime(activity.due_at)}`;
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
  if (!isSearchMode.value) loadActivities();
}

function resetFilters() {
  filters.status = 'pending';
  filters.kind = '';
  filters.priority = '';
  filters.from = '';
  filters.to = '';
  filters.search = '';
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
    await CrmAPI.completeActivity(activity.id, 'Concluída pela agenda CRM');
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
  <main class="crm-activities-page">
    <header class="crm-page-header">
      <div>
        <p class="crm-eyebrow">Agenda CRM</p>
        <h1>Atividades</h1>
        <p>
          Organize próximas ações, prazos, retornos e reuniões com contexto do
          contato e do caso.
        </p>
      </div>
      <div class="crm-page-header__actions">
        <button class="crm-primary-button" @click="openCreateDrawer">
          <span class="i-lucide-plus size-4" />
          Nova atividade
        </button>
        <button class="crm-secondary-button" @click="exportCalendar">
          <span class="i-lucide-calendar-plus size-4" />
          Exportar ICS
        </button>
        <button
          class="crm-secondary-button"
          :disabled="importingCalendar"
          @click="importGoogleCalendar"
        >
          <span
            :class="[
              importingCalendar
                ? 'i-lucide-loader-circle animate-spin'
                : 'i-lucide-calendar-sync',
              'size-4',
            ]"
          />
          {{ importingCalendar ? 'Importando...' : 'Importar Google' }}
        </button>
        <button
          class="crm-secondary-button"
          :disabled="suggestingSchedule"
          @click="suggestSchedule"
        >
          <span
            :class="[
              suggestingSchedule
                ? 'i-lucide-loader-circle animate-spin'
                : 'i-lucide-sparkles',
              'size-4',
            ]"
          />
          {{ suggestingSchedule ? 'Analisando...' : 'Sugerir horário' }}
        </button>
      </div>
    </header>

    <section class="crm-kpi-grid" aria-label="Resumo das atividades">
      <article class="crm-kpi-card crm-kpi-card--pending">
        <span class="crm-kpi-card__icon i-lucide-list-todo size-4" />
        <strong>{{ stats.total }}</strong>
        <small>{{ isSearchMode ? 'Resultados' : activeStatus?.label }}</small>
      </article>
      <article class="crm-kpi-card crm-kpi-card--today">
        <span class="crm-kpi-card__icon i-lucide-calendar-days size-4" />
        <strong>{{ stats.today }}</strong>
        <small>Para hoje</small>
      </article>
      <article
        class="crm-kpi-card crm-kpi-card--overdue"
        :class="{ 'crm-kpi-card--danger': stats.overdue }"
      >
        <span class="crm-kpi-card__icon i-lucide-alarm-clock size-4" />
        <strong>{{ stats.overdue }}</strong>
        <small>Vencidas</small>
      </article>
      <article class="crm-kpi-card crm-kpi-card--priority">
        <span class="crm-kpi-card__icon i-lucide-alert-triangle size-4" />
        <strong>{{ stats.highPriority }}</strong>
        <small>Alta prioridade</small>
      </article>
      <article class="crm-kpi-card crm-kpi-card--unassigned">
        <span class="crm-kpi-card__icon i-lucide-user-x size-4" />
        <strong>{{ stats.withoutAssignee }}</strong>
        <small>Sem responsável</small>
      </article>
    </section>

    <section class="crm-toolbar">
      <div class="crm-tabs">
        <button
          v-for="tab in STATUS_TABS"
          :key="tab.value"
          type="button"
          :class="{ active: filters.status === tab.value && !isSearchMode }"
          @click="setStatus(tab.value)"
        >
          <span :class="[tab.icon, 'size-4']" />
          {{ tab.label }}
        </button>
      </div>

      <div class="crm-filters">
        <label class="crm-search-field">
          <span class="crm-search-field__icon" aria-hidden="true">
            <span class="i-lucide-search size-4" />
          </span>
          <input
            v-model="filters.search"
            type="search"
            placeholder="Buscar por atividade, contato, caso ou responsável"
          />
          <span
            v-if="loading && isSearchMode"
            class="crm-search-field__loader i-lucide-loader-circle size-4 animate-spin"
          />
        </label>
        <select
          v-model="filters.kind"
          class="crm-select"
          @change="loadActivities"
        >
          <option v-for="kind in KINDS" :key="kind.value" :value="kind.value">
            {{ kind.label }}
          </option>
        </select>
        <select
          v-model="filters.priority"
          class="crm-select"
          @change="loadActivities"
        >
          <option
            v-for="priority in PRIORITIES"
            :key="priority.value"
            :value="priority.value"
          >
            {{ priority.label }}
          </option>
        </select>
        <input
          v-model="filters.from"
          type="date"
          class="crm-input"
          title="Data inicial"
          @change="loadActivities"
        />
        <input
          v-model="filters.to"
          type="date"
          class="crm-input"
          title="Data final"
          @change="loadActivities"
        />
        <button type="button" class="crm-ghost-button" @click="resetFilters">
          Limpar
        </button>
      </div>
    </section>

    <div v-if="error" class="crm-alert">
      <span class="i-lucide-circle-alert size-4" />
      {{ error }}
    </div>
    <div v-if="calendarSyncSummary" class="crm-alert crm-alert--success">
      <span class="i-lucide-circle-check size-4" />
      {{ calendarSyncSummary }}
    </div>
    <div v-if="scheduleSuggestionSummary" class="crm-alert crm-alert--success">
      <span class="i-lucide-sparkles size-4" />
      {{ scheduleSuggestionSummary }}
    </div>

    <section v-if="hasScheduleSuggestions" class="crm-ai-scheduler-panel">
      <div class="crm-ai-scheduler-panel__header">
        <div>
          <p class="crm-eyebrow">Agendamento inteligente</p>
          <h2>{{ scheduleDraft?.title || 'Sugestões de horário' }}</h2>
          <p>
            O CRM avaliou janelas livres em horário comercial e evitou conflitos
            com atividades já marcadas.
          </p>
        </div>
        <label class="crm-ai-scheduler-panel__toggle">
          <input v-model="syncSuggestedSchedule" type="checkbox" />
          <span>Sincronizar Google/Meet</span>
        </label>
      </div>
      <div class="crm-ai-scheduler-slots">
        <article
          v-for="slot in scheduleSuggestions"
          :key="slot.starts_at"
          class="crm-ai-scheduler-slot"
        >
          <div>
            <strong>{{ slot.label }}</strong>
            <span>{{ slot.duration_minutes }} min</span>
            <p>{{ slot.reason }}</p>
          </div>
          <button
            class="crm-primary-button"
            :disabled="schedulingSuggestion"
            @click="scheduleSuggestedSlot(slot)"
          >
            <span
              :class="[
                schedulingSuggestion
                  ? 'i-lucide-loader-circle animate-spin'
                  : 'i-lucide-calendar-check',
                'size-4',
              ]"
            />
            Criar
          </button>
        </article>
      </div>
    </section>

    <section class="crm-activity-list">
      <div v-if="loading && !isSearchMode" class="crm-state">
        <span class="i-lucide-loader-circle size-5 animate-spin" />
        Carregando atividades...
      </div>

      <div v-else-if="activities.length === 0" class="crm-empty-state">
        <span class="i-lucide-calendar-check size-10" />
        <h2>Nenhuma atividade encontrada</h2>
        <p>
          Ajuste os filtros ou crie uma atividade para manter cada atendimento
          com próxima ação definida.
        </p>
        <button class="crm-primary-button" @click="openCreateDrawer">
          <span class="i-lucide-plus size-4" />
          Nova atividade
        </button>
      </div>

      <template v-else>
        <article
          v-for="activity in activities"
          :key="activity.id"
          class="crm-activity-row"
          :class="activityRowClass(activity.priority)"
        >
          <div class="crm-activity-main">
            <div :class="prioritySignalClass(activity.priority)">
              <span
                class="crm-priority-signal__icon"
                :class="[iconForKind(activity.kind)]"
              />
              <span class="crm-priority-signal__label">
                {{ priorityLabel(activity.priority) }}
              </span>
            </div>
            <div class="crm-activity-copy">
              <div class="crm-activity-title-line">
                <h2>{{ activity.title }}</h2>
                <span :class="statusClass(activity)">
                  {{ statusLabel(activity) }}
                </span>
              </div>
              <p v-if="activity.description">{{ activity.description }}</p>
              <div class="crm-activity-meta">
                <span>{{ labelFor(KINDS, activity.kind) }}</span>
                <span v-if="activity.deal?.stage?.name">
                  {{ activity.deal.stage.name }}
                </span>
                <router-link
                  v-if="activity.crm_deal_id"
                  :to="dealPath(activity)"
                >
                  Abrir caso
                </router-link>
              </div>
            </div>
          </div>

          <div class="crm-activity-context">
            <span>Contato</span>
            <strong>
              {{ activity.contact?.name || 'Sem contato vinculado' }}
            </strong>
            <small v-if="activity.deal?.title">{{ activity.deal.title }}</small>
          </div>

          <div class="crm-activity-due">
            <span>Prazo</span>
            <strong>{{ dueText(activity) }}</strong>
          </div>

          <div class="crm-activity-owner">
            <span>Responsável</span>
            <strong>
              {{
                activity.assignee?.name ||
                activity.owner?.name ||
                'Sem responsável'
              }}
            </strong>
            <small>
              {{
                activity.external_calendar_synced_at ? 'Sincronizada' : 'Local'
              }}
            </small>
          </div>

          <div class="crm-row-actions">
            <button
              v-if="!activity.completed_at"
              class="crm-action-button crm-action-button--done"
              :disabled="saving"
              title="Concluir"
              @click="completeActivity(activity)"
            >
              <span class="i-lucide-check size-4" />
            </button>
            <button
              v-if="!activity.completed_at"
              class="crm-action-button"
              :disabled="saving"
              title="Adiar 24h"
              @click="snoozeActivity(activity, 24)"
            >
              +24h
            </button>
            <button
              v-if="!activity.completed_at"
              class="crm-action-button"
              :disabled="saving"
              title="Adiar 72h"
              @click="snoozeActivity(activity, 72)"
            >
              +72h
            </button>
            <button
              class="crm-action-button"
              title="Editar"
              @click="openEditDrawer(activity)"
            >
              <span class="i-lucide-pencil size-4" />
            </button>
            <button
              v-if="googleCalendarUrl(activity)"
              class="crm-action-button"
              title="Abrir no Google Calendar"
              @click="openExternalUrl(googleCalendarUrl(activity))"
            >
              <span class="i-lucide-calendar-clock size-4" />
            </button>
            <button
              v-if="activity.due_at"
              class="crm-action-button"
              :disabled="saving || syncingActivityId === activity.id"
              title="Sincronizar Google Calendar"
              @click="syncGoogleCalendar(activity)"
            >
              <span
                :class="[
                  syncingActivityId === activity.id
                    ? 'i-lucide-loader-circle animate-spin'
                    : 'i-lucide-cloud-upload',
                  'size-4',
                ]"
              />
            </button>
            <button
              class="crm-action-button crm-action-button--danger"
              title="Excluir"
              @click="askDeleteActivity(activity)"
            >
              <span class="i-lucide-trash-2 size-4" />
            </button>
          </div>
        </article>
      </template>
    </section>

    <div
      v-if="drawerOpen"
      class="crm-drawer-backdrop"
      @click.self="closeDrawer"
    >
      <aside class="crm-drawer" aria-modal="true" role="dialog">
        <header class="crm-drawer__header">
          <div>
            <p class="crm-eyebrow">Agenda CRM</p>
            <h2>{{ drawerTitle }}</h2>
          </div>
          <button class="crm-icon-button" @click="closeDrawer">
            <span class="i-lucide-x size-4" />
          </button>
        </header>

        <div class="crm-drawer__body">
          <label class="crm-field crm-field--full">
            <span>Título</span>
            <input
              v-model="form.title"
              class="crm-input"
              type="text"
              placeholder="Ex: Ligar para lead INSS"
            />
          </label>

          <label class="crm-field">
            <span>Tipo</span>
            <select v-model="form.kind" class="crm-select">
              <option
                v-for="kind in KINDS.filter(item => item.value)"
                :key="kind.value"
                :value="kind.value"
              >
                {{ kind.label }}
              </option>
            </select>
          </label>

          <label class="crm-field">
            <span>Prioridade</span>
            <select v-model="form.priority" class="crm-select">
              <option
                v-for="priority in PRIORITIES.filter(item => item.value)"
                :key="priority.value"
                :value="priority.value"
              >
                {{ priority.label }}
              </option>
            </select>
          </label>

          <label class="crm-field">
            <span>Prazo</span>
            <input
              v-model="form.due_at"
              type="datetime-local"
              class="crm-input"
            />
          </label>

          <label class="crm-field">
            <span>Lembrete</span>
            <input
              v-model="form.reminder_at"
              type="datetime-local"
              class="crm-input"
            />
          </label>

          <label class="crm-field crm-field--full">
            <span>Caso / lead</span>
            <select
              v-model="form.crm_deal_id"
              class="crm-select"
              @change="applyDealContext"
            >
              <option value="">Sem caso vinculado</option>
              <option
                v-for="deal in dealOptions"
                :key="deal.id"
                :value="deal.id"
              >
                {{ deal.title
                }}{{ deal.contactName ? ` - ${deal.contactName}` : '' }}
              </option>
            </select>
          </label>

          <label class="crm-field">
            <span>Contato</span>
            <select v-model="form.contact_id" class="crm-select">
              <option value="">Sem contato</option>
              <option
                v-for="contact in contactOptions"
                :key="contact.id"
                :value="contact.id"
              >
                {{ contact.name }}
              </option>
            </select>
          </label>

          <label class="crm-field">
            <span>Responsável</span>
            <select v-model="form.assignee_id" class="crm-select">
              <option value="">Sem responsável</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name || agent.email }}
              </option>
            </select>
          </label>

          <label class="crm-field crm-field--full">
            <span>Descrição</span>
            <textarea
              v-model="form.description"
              class="crm-textarea"
              rows="5"
              placeholder="Contexto, combinados ou próxima ação esperada."
            />
          </label>
        </div>

        <footer class="crm-drawer__footer">
          <button class="crm-ghost-button" @click="closeDrawer">
            Cancelar
          </button>
          <button
            class="crm-primary-button"
            :disabled="saving || !isFormValid"
            @click="saveActivity"
          >
            {{ saving ? 'Salvando...' : 'Salvar atividade' }}
          </button>
        </footer>
      </aside>
    </div>

    <div
      v-if="activityToDelete"
      class="crm-confirm-backdrop"
      @click.self="cancelDelete"
    >
      <section class="crm-confirm" role="dialog" aria-modal="true">
        <span class="i-lucide-trash-2 size-5" />
        <h2>Excluir atividade?</h2>
        <p>
          Esta ação remove a atividade da agenda e registra a exclusão no
          histórico do CRM.
        </p>
        <strong>{{ activityToDelete.title }}</strong>
        <div class="crm-confirm__actions">
          <button class="crm-ghost-button" @click="cancelDelete">
            Cancelar
          </button>
          <button
            class="crm-danger-button"
            :disabled="deleting"
            @click="deleteActivity"
          >
            {{ deleting ? 'Excluindo...' : 'Excluir' }}
          </button>
        </div>
      </section>
    </div>
  </main>
</template>

<style scoped>
.crm-activities-page {
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

.crm-page-header > div:first-child {
  min-width: 0;
  flex: 1 1 auto;
}

.crm-page-header__actions {
  display: flex;
  flex: 0 0 auto;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.5rem;
}

.crm-eyebrow {
  margin: 0 0 0.25rem;
  color: rgb(var(--brand-9));
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.crm-page-header h1,
.crm-drawer h2,
.crm-empty-state h2,
.crm-activity-row h2,
.crm-confirm h2 {
  margin: 0;
}

.crm-page-header h1 {
  font-size: 1.5rem;
  font-weight: 800;
}

.crm-page-header p:last-child,
.crm-empty-state p,
.crm-ai-scheduler-panel__header p:last-child,
.crm-confirm p {
  max-width: 48rem;
  margin: 0.25rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.875rem;
  line-height: 1.5;
}

.crm-kpi-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-kpi-card {
  position: relative;
  display: grid;
  gap: 0.35rem;
  overflow: hidden;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 1rem;
  background: rgb(var(--slate-1));
}

.crm-kpi-card::before {
  position: absolute;
  inset-block: 0;
  left: 0;
  width: 0.22rem;
  content: '';
}

.crm-kpi-card__icon {
  display: grid;
  width: 1.75rem;
  height: 1.75rem;
  place-items: center;
  border-radius: 8px;
}

.crm-kpi-card strong {
  font-size: 1.65rem;
  line-height: 1;
}

.crm-kpi-card small {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.crm-kpi-card--danger {
  border-color: rgb(var(--ruby-7));
  background: rgb(var(--ruby-1));
}

.crm-kpi-card--pending {
  border-color: rgb(var(--blue-6));
  background: linear-gradient(135deg, rgb(var(--blue-1)), rgb(var(--slate-1)));
}

.crm-kpi-card--pending::before {
  background: rgb(var(--blue-9));
}

.crm-kpi-card--pending .crm-kpi-card__icon {
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-3));
}

.crm-kpi-card--today {
  border-color: rgb(var(--teal-6));
  background: linear-gradient(135deg, rgb(var(--teal-1)), rgb(var(--slate-1)));
}

.crm-kpi-card--today::before {
  background: rgb(var(--teal-9));
}

.crm-kpi-card--today .crm-kpi-card__icon {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-3));
}

.crm-kpi-card--overdue {
  border-color: rgb(var(--ruby-6));
  background: linear-gradient(135deg, rgb(var(--ruby-1)), rgb(var(--slate-1)));
}

.crm-kpi-card--overdue::before {
  background: rgb(var(--ruby-9));
}

.crm-kpi-card--overdue .crm-kpi-card__icon {
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-3));
}

.crm-kpi-card--priority {
  border-color: rgb(var(--amber-6));
  background: linear-gradient(135deg, rgb(var(--amber-1)), rgb(var(--slate-1)));
}

.crm-kpi-card--priority::before {
  background: rgb(var(--amber-9));
}

.crm-kpi-card--priority .crm-kpi-card__icon {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-3));
}

.crm-kpi-card--unassigned {
  border-color: rgb(var(--brand-6));
  background: linear-gradient(135deg, rgb(var(--brand-1)), rgb(var(--slate-1)));
}

.crm-kpi-card--unassigned::before {
  background: rgb(var(--brand-9));
}

.crm-kpi-card--unassigned .crm-kpi-card__icon {
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-3));
}

.crm-toolbar,
.crm-ai-scheduler-panel,
.crm-activity-row,
.crm-empty-state,
.crm-state,
.crm-alert {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  background: rgb(var(--slate-1));
}

.crm-toolbar {
  display: grid;
  gap: 1rem;
  min-width: 0;
  overflow: hidden;
  padding: 1rem;
}

.crm-tabs {
  display: flex;
  min-width: 0;
  gap: 0.35rem;
  overflow-x: auto;
  padding-bottom: 0.1rem;
  scrollbar-width: thin;
}

.crm-tabs button {
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  border-radius: 8px;
  padding: 0.55rem 0.75rem;
  color: rgb(var(--slate-11));
  font-size: 0.8125rem;
  font-weight: 700;
}

.crm-tabs button:hover,
.crm-tabs button.active {
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-2));
}

.crm-filters {
  display: grid;
  min-width: 0;
  grid-template-columns:
    minmax(18rem, 1.4fr) repeat(2, minmax(10rem, 0.75fr))
    repeat(2, minmax(9rem, 0.7fr)) auto;
  align-items: center;
  gap: 0.55rem;
}

.crm-filters > * {
  min-width: 0;
}

.crm-search-field,
.crm-input,
.crm-select,
.crm-textarea {
  width: 100%;
  min-width: 0;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  color: rgb(var(--slate-12));
  background: rgb(var(--slate-2));
  outline: none;
}

.crm-search-field {
  position: relative;
  display: block;
  height: 2.5rem;
  overflow: hidden;
  padding: 0;
  border-color: rgb(var(--blue-6));
  background: rgb(var(--slate-1));
}

.crm-search-field__icon,
.crm-search-field__loader {
  position: absolute;
  z-index: 1;
  color: rgb(var(--slate-9));
  pointer-events: none;
}

.crm-search-field__icon {
  top: 0;
  left: 0;
  display: grid;
  width: 2.75rem;
  height: 100%;
  place-items: center;
  border-right: 1px solid rgb(var(--slate-4));
  color: rgb(var(--blue-10));
  background: rgb(var(--blue-2));
}

.crm-search-field__icon > span {
  width: 1rem;
  height: 1rem;
}

.crm-search-field__loader {
  top: 50%;
  right: 0.85rem;
  transform: translateY(-50%);
}

.crm-search-field input {
  display: block;
  width: 100%;
  height: 100%;
  min-width: 0;
  border: 0 !important;
  border-radius: 0;
  appearance: none;
  box-shadow: none !important;
  color: rgb(var(--slate-12));
  background: transparent;
  outline: none;
  padding: 0 2.75rem 0 3.35rem !important;
  font-size: 0.875rem;
  line-height: 2.5rem;
}

.crm-search-field input::-webkit-search-decoration,
.crm-search-field input::-webkit-search-cancel-button,
.crm-search-field input::-webkit-search-results-button,
.crm-search-field input::-webkit-search-results-decoration {
  appearance: none;
}

.crm-input,
.crm-select {
  height: 2.5rem;
  padding: 0 0.75rem;
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

.crm-textarea {
  resize: vertical;
  padding: 0.75rem;
}

.crm-input:focus,
.crm-select:focus,
.crm-textarea:focus,
.crm-search-field:focus-within {
  border-color: rgb(var(--brand-8));
  box-shadow: 0 0 0 3px rgb(var(--brand-4) / 0.25);
}

.crm-primary-button,
.crm-secondary-button,
.crm-ghost-button,
.crm-danger-button,
.crm-action-button,
.crm-icon-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  font-weight: 800;
}

.crm-primary-button {
  gap: 0.45rem;
  min-height: 2.5rem;
  padding: 0 0.9rem;
  color: white;
  background: rgb(var(--brand-9));
}

.crm-primary-button:hover:not(:disabled) {
  background: rgb(var(--brand-10));
}

.crm-secondary-button {
  gap: 0.45rem;
  min-height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  padding: 0 0.9rem;
  color: rgb(var(--slate-12));
  background: rgb(var(--slate-2));
}

.crm-secondary-button:hover {
  border-color: rgb(var(--brand-7));
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-2));
}

.crm-primary-button:disabled,
.crm-secondary-button:disabled,
.crm-action-button:disabled,
.crm-danger-button:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.crm-ghost-button {
  height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  padding: 0 0.85rem;
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-2));
}

.crm-ghost-button:hover {
  background: rgb(var(--slate-3));
}

.crm-danger-button {
  height: 2.5rem;
  border: 1px solid rgb(var(--ruby-7));
  padding: 0 0.85rem;
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
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

.crm-alert--success {
  border-color: rgb(var(--green-7));
  color: rgb(var(--green-11));
  background: rgb(var(--green-2));
}

.crm-ai-scheduler-panel {
  display: grid;
  gap: 1rem;
  padding: 1rem;
}

.crm-ai-scheduler-panel__header {
  display: flex;
  min-width: 0;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.crm-ai-scheduler-panel__header h2 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 800;
}

.crm-ai-scheduler-panel__toggle {
  display: inline-flex;
  flex-shrink: 0;
  align-items: center;
  gap: 0.5rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  padding: 0.55rem 0.75rem;
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-2));
  font-size: 0.8rem;
  font-weight: 800;
}

.crm-ai-scheduler-slots {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
  gap: 0.75rem;
}

.crm-ai-scheduler-slot {
  display: flex;
  min-width: 0;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 0.85rem;
  background: rgb(var(--slate-2));
}

.crm-ai-scheduler-slot strong,
.crm-ai-scheduler-slot span,
.crm-ai-scheduler-slot p {
  display: block;
}

.crm-ai-scheduler-slot strong {
  color: rgb(var(--slate-12));
  font-size: 0.95rem;
}

.crm-ai-scheduler-slot span {
  margin-top: 0.15rem;
  color: rgb(var(--brand-11));
  font-size: 0.78rem;
  font-weight: 800;
}

.crm-ai-scheduler-slot p {
  margin: 0.35rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.8rem;
  line-height: 1.4;
}

.crm-activity-list {
  display: grid;
  gap: 0.65rem;
}

.crm-state,
.crm-empty-state {
  display: grid;
  min-height: 14rem;
  place-items: center;
  padding: 2rem;
  text-align: center;
}

.crm-empty-state {
  gap: 0.75rem;
}

.crm-state {
  gap: 0.65rem;
  color: rgb(var(--slate-10));
}

.crm-empty-state > span {
  color: rgb(var(--brand-8));
}

.crm-empty-state h2 {
  font-size: 1rem;
}

.crm-activity-row {
  position: relative;
  display: grid;
  grid-template-columns:
    minmax(24rem, 1.65fr) minmax(12rem, 0.75fr) minmax(11rem, 0.7fr)
    minmax(10rem, 0.7fr) auto;
  gap: 1rem;
  align-items: center;
  overflow: hidden;
  padding: 0.9rem;
}

.crm-activity-row::before {
  position: absolute;
  inset-block: 0;
  left: 0;
  width: 0.24rem;
  background: linear-gradient(180deg, rgb(var(--brand-8)), rgb(var(--teal-8)));
  content: '';
}

.crm-activity-row--low::before {
  background: linear-gradient(180deg, rgb(var(--teal-6)), rgb(var(--teal-9)));
}

.crm-activity-row--normal::before {
  background: linear-gradient(180deg, rgb(var(--blue-6)), rgb(var(--blue-9)));
}

.crm-activity-row--high::before {
  background: linear-gradient(180deg, rgb(var(--amber-5)), rgb(var(--amber-9)));
}

.crm-activity-row--critical::before {
  background: linear-gradient(180deg, rgb(var(--ruby-5)), rgb(var(--ruby-9)));
}

.crm-activity-row > * {
  min-width: 0;
}

.crm-activity-main {
  display: grid;
  min-width: 0;
  grid-template-columns: 4.6rem minmax(0, 1fr);
  align-items: start;
  gap: 0.9rem;
}

.crm-priority-signal {
  display: grid;
  width: 4.25rem;
  min-height: 4.45rem;
  flex-shrink: 0;
  place-items: center;
  align-content: center;
  gap: 0.32rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  background: rgb(var(--slate-2));
}

.crm-priority-signal__icon {
  width: 1.65rem;
  height: 1.65rem;
}

.crm-priority-signal__label {
  max-width: 100%;
  overflow: hidden;
  border-radius: 999px;
  padding: 0.12rem 0.45rem;
  font-size: 0.68rem;
  font-weight: 900;
  line-height: 1.2;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-priority-signal--low {
  border-color: rgb(var(--teal-5));
  color: rgb(var(--teal-11));
  background: linear-gradient(135deg, rgb(var(--teal-1)), rgb(var(--teal-2)));
}

.crm-priority-signal--low .crm-priority-signal__label {
  background: rgb(var(--teal-3));
}

.crm-priority-signal--normal {
  border-color: rgb(var(--blue-5));
  color: rgb(var(--blue-11));
  background: linear-gradient(135deg, rgb(var(--blue-1)), rgb(var(--blue-2)));
}

.crm-priority-signal--normal .crm-priority-signal__label {
  background: rgb(var(--blue-3));
}

.crm-priority-signal--high {
  border-color: rgb(var(--amber-5));
  color: rgb(var(--amber-11));
  background: linear-gradient(135deg, rgb(var(--amber-1)), rgb(var(--amber-2)));
}

.crm-priority-signal--high .crm-priority-signal__label {
  background: rgb(var(--amber-3));
}

.crm-priority-signal--critical {
  border-color: rgb(var(--ruby-5));
  color: rgb(var(--ruby-11));
  background: linear-gradient(135deg, rgb(var(--ruby-1)), rgb(var(--ruby-2)));
}

.crm-priority-signal--critical .crm-priority-signal__label {
  background: rgb(var(--ruby-3));
}

.crm-activity-copy {
  min-width: 0;
}

.crm-activity-title-line {
  display: flex;
  min-width: 0;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.45rem;
}

.crm-activity-title-line h2 {
  overflow: hidden;
  color: rgb(var(--slate-12));
  font-size: 0.95rem;
  font-weight: 800;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-activity-main p {
  display: -webkit-box;
  overflow: hidden;
  margin: 0.25rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.8125rem;
  line-height: 1.45;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.crm-activity-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  margin-top: 0.45rem;
  color: rgb(var(--slate-9));
  font-size: 0.75rem;
}

.crm-activity-meta span,
.crm-activity-meta a {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 999px;
  padding: 0.18rem 0.5rem;
  background: rgb(var(--slate-3));
}

.crm-activity-meta a {
  border-color: rgb(var(--blue-5));
  color: rgb(var(--brand-11));
  background: rgb(var(--blue-2));
}

.crm-activity-context,
.crm-activity-due,
.crm-activity-owner {
  display: grid;
  min-width: 0;
  gap: 0.18rem;
}

.crm-activity-context span,
.crm-activity-due span,
.crm-activity-owner span {
  color: rgb(var(--slate-9));
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
}

.crm-activity-context strong,
.crm-activity-due strong,
.crm-activity-owner strong {
  overflow: hidden;
  color: rgb(var(--slate-12));
  font-size: 0.84rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-activity-context small,
.crm-activity-owner small {
  overflow: hidden;
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-status,
.crm-priority {
  display: inline-flex;
  width: fit-content;
  border-radius: 999px;
  padding: 0.18rem 0.5rem;
  font-size: 0.72rem;
  font-weight: 800;
  white-space: nowrap;
}

.crm-status--pending,
.crm-priority--normal {
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-status--today,
.crm-priority--high {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-2));
}

.crm-status--overdue,
.crm-priority--critical {
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-status--done,
.crm-priority--low {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-row-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.4rem;
}

.crm-action-button {
  min-width: 2.35rem;
  height: 2.1rem;
  border: 1px solid rgb(var(--slate-5));
  padding: 0 0.55rem;
  color: rgb(var(--slate-11));
  font-size: 0.75rem;
  background: rgb(var(--slate-2));
}

.crm-action-button:hover:not(:disabled) {
  border-color: rgb(var(--blue-6));
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-action-button--done {
  border-color: rgb(var(--teal-6));
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-action-button--danger {
  border-color: rgb(var(--ruby-6));
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-drawer-backdrop,
.crm-confirm-backdrop {
  position: fixed;
  inset: 0;
  z-index: 80;
  background: rgb(15 23 42 / 0.38);
}

.crm-drawer {
  position: absolute;
  top: 0;
  right: 0;
  display: flex;
  width: min(34rem, 100vw);
  height: 100%;
  flex-direction: column;
  border-left: 1px solid rgb(var(--slate-4));
  background: rgb(var(--slate-1));
  box-shadow: -24px 0 60px rgb(15 23 42 / 0.18);
}

.crm-drawer__header,
.crm-drawer__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.crm-drawer__header {
  border-bottom: 1px solid rgb(var(--slate-4));
}

.crm-drawer__footer {
  border-top: 1px solid rgb(var(--slate-4));
}

.crm-drawer__body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.85rem;
  overflow-y: auto;
  padding: 1rem;
}

.crm-field {
  display: grid;
  gap: 0.35rem;
}

.crm-field--full {
  grid-column: 1 / -1;
}

.crm-field span {
  color: rgb(var(--slate-10));
  font-size: 0.78rem;
  font-weight: 800;
}

.crm-icon-button {
  width: 2.2rem;
  height: 2.2rem;
  color: rgb(var(--slate-10));
}

.crm-icon-button:hover {
  background: rgb(var(--slate-3));
}

.crm-confirm-backdrop {
  display: grid;
  place-items: center;
  padding: 1rem;
}

.crm-confirm {
  display: grid;
  width: min(28rem, 100%);
  gap: 0.75rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 1rem;
  background: rgb(var(--slate-1));
  box-shadow: 0 24px 70px rgb(15 23 42 / 0.24);
}

.crm-confirm > span {
  color: rgb(var(--ruby-10));
}

.crm-confirm > strong {
  color: rgb(var(--slate-12));
}

.crm-confirm__actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

@media (max-width: 1380px) {
  .crm-kpi-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .crm-filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .crm-search-field {
    grid-column: 1 / -1;
  }

  .crm-activity-row {
    grid-template-columns: minmax(18rem, 1fr) minmax(12rem, 0.75fr);
  }

  .crm-row-actions {
    justify-content: flex-start;
  }
}

@media (max-width: 1024px) {
  .crm-page-header {
    flex-direction: column;
  }

  .crm-page-header__actions {
    justify-content: flex-start;
  }

  .crm-activity-row {
    grid-template-columns: 1fr;
    align-items: stretch;
  }

  .crm-row-actions {
    border-top: 1px solid rgb(var(--slate-4));
    padding-top: 0.7rem;
  }
}

@media (max-width: 760px) {
  .crm-kpi-grid,
  .crm-filters,
  .crm-drawer__body {
    grid-template-columns: 1fr;
  }

  .crm-primary-button,
  .crm-secondary-button,
  .crm-ghost-button {
    width: 100%;
  }

  .crm-tabs {
    margin-inline: -0.35rem;
    padding-inline: 0.35rem;
  }

  .crm-drawer__footer,
  .crm-confirm__actions {
    flex-direction: column-reverse;
  }
}
</style>

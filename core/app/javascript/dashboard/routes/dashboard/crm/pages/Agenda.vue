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
import { useRoute, useRouter } from 'vue-router';

import AgentsAPI from '../../../../api/agents';
import ContactAPI from '../../../../api/contacts';
import CrmAPI from '../../../../api/crm';

const route = useRoute();
const router = useRouter();

const events = ref([]);
const deals = ref([]);
const contacts = ref([]);
const agents = ref([]);
const loading = ref(false);
const supportLoading = ref(false);
const saving = ref(false);
const syncing = ref(false);
const connectingGoogle = ref(false);
const deleting = ref(false);
const suggesting = ref(false);
const error = ref('');
const successMessage = ref('');
const drawerOpen = ref(false);
const drawerMode = ref('create');
const selectedEvent = ref(null);
const selectedActivity = ref(null);
const scheduleSuggestions = ref([]);
const googleStatus = ref({
  connected: false,
  status: 'disconnected',
  email: '',
  name: '',
  last_error: '',
  oauth_configured: false,
});

let searchTimer = null;

const HOUR_HEIGHT = 64;
const HOURS = Array.from({ length: 24 }, (_, index) => index);
const MAX_MONTH_EVENTS = 3;

const filters = reactive({
  view: 'week',
  cursor: dateInputValue(new Date()),
  query: '',
  source: '',
  priority: '',
  assignee_id: '',
  sync_status: '',
});

const form = reactive({
  id: null,
  title: '',
  description: '',
  kind: 'reuniao',
  priority: 'normal',
  due_at: '',
  reminder_at: '',
  crm_deal_id: '',
  contact_id: '',
  conversation_id: '',
  assignee_id: '',
  sync_google_calendar: true,
});

const VIEW_OPTIONS = [
  { value: 'day', label: 'Dia' },
  { value: 'week', label: 'Semana' },
  { value: 'month', label: 'Mes' },
];

const SOURCE_OPTIONS = [
  { value: '', label: 'Todos os eventos' },
  { value: 'crm_activity', label: 'Reunioes e atividades' },
  { value: 'lead_contact', label: 'Entrada de lead' },
];

const PRIORITIES = [
  { value: '', label: 'Todas as prioridades' },
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
];

const SYNC_OPTIONS = [
  { value: '', label: 'Todos Google' },
  { value: 'synced', label: 'Sincronizados' },
  { value: 'unsynced', label: 'Sem Google' },
];

const KINDS = [
  { value: 'reuniao', label: 'Reunião' },
  { value: 'follow_up', label: 'Follow-up' },
  { value: 'ligacao', label: 'Ligação' },
  { value: 'retorno_cliente', label: 'Retorno ao cliente' },
  { value: 'analise_documental', label: 'Analise documental' },
  { value: 'solicitacao_documentos', label: 'Solicitação de documentos' },
  { value: 'revisao_juridica', label: 'Revisão jurídica' },
];

const monthNames = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

const fullMonthNames = [
  'Janeiro',
  'Fevereiro',
  'Marco',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const weekDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];

const cursorDate = computed(() => parseDate(filters.cursor) || new Date());
const visibleRange = computed(() =>
  rangeForView(filters.view, cursorDate.value)
);
const fetchRange = computed(() => {
  if (filters.view !== 'month') return visibleRange.value;

  return {
    from: startOfWeek(startOfMonth(cursorDate.value)),
    to: endOfWeek(endOfMonth(cursorDate.value)),
  };
});
const visibleDays = computed(() =>
  filters.view === 'month'
    ? daysBetween(fetchRange.value.from, fetchRange.value.to)
    : daysBetween(visibleRange.value.from, visibleRange.value.to)
);
const isDrawerEditing = computed(() => drawerMode.value === 'edit');
const isDrawerDetail = computed(() => drawerMode.value === 'detail');
const isLeadContactDetail = computed(
  () => isDrawerDetail.value && selectedEvent.value?.source === 'lead_contact'
);
const drawerTitle = computed(() => {
  if (isDrawerDetail.value) return selectedEvent.value?.title || 'Evento';
  return isDrawerEditing.value ? 'Editar reunião' : 'Nova reunião';
});
const hasGoogleConnection = computed(() => googleStatus.value.connected);
const currentReturnPath = computed(
  () => `/app/accounts/${route.params.accountId}/crm/agenda`
);
const timelineHeight = computed(() => `${HOURS.length * HOUR_HEIGHT}px`);
const nowLineStyle = computed(() => ({
  top: `${((new Date().getHours() * 60 + new Date().getMinutes()) / 60) * HOUR_HEIGHT}px`,
}));

const sortedEvents = computed(() =>
  [...events.value].sort((a, b) => new Date(a.start_at) - new Date(b.start_at))
);

const eventsByDay = computed(() => {
  const map = new Map();
  visibleDays.value.forEach(day => map.set(dayKey(day), []));
  sortedEvents.value.forEach(event => {
    const key = dayKey(new Date(event.start_at));
    if (map.has(key)) map.get(key).push(event);
  });
  return map;
});

const upcomingEvents = computed(() => {
  const now = Date.now();
  return sortedEvents.value
    .filter(
      event =>
        event.source === 'crm_activity' &&
        event.status !== 'completed' &&
        new Date(event.start_at).getTime() >= now
    )
    .slice(0, 8);
});

const stats = computed(() => {
  const source = sortedEvents.value;
  return {
    meetings: source.filter(
      event => event.source === 'crm_activity' && event.kind === 'reuniao'
    ).length,
    leadContacts: source.filter(event => event.source === 'lead_contact')
      .length,
    today: source.filter(event =>
      isSameDay(new Date(event.start_at), new Date())
    ).length,
    overdue: source.filter(event => event.status === 'overdue').length,
    unsynced: source.filter(
      event =>
        event.source === 'crm_activity' &&
        event.kind === 'reuniao' &&
        !event.activity?.external_calendar_event_id
    ).length,
  };
});

const agentOptions = computed(() =>
  agents.value
    .filter(agent => agent.id)
    .map(agent => ({
      id: agent.id,
      name: agent.name || agent.email || `Agente #${agent.id}`,
    }))
);

const contactOptions = computed(() => {
  const map = new Map();
  contacts.value.forEach(contact => addContactOption(map, contact));
  events.value.forEach(event => {
    addContactOption(map, event.contact);
    addContactOption(map, event.deal?.contact);
  });
  deals.value.forEach(deal => addContactOption(map, deal.contact));
  return Array.from(map.values()).sort((a, b) => a.name.localeCompare(b.name));
});

const dealOptions = computed(() =>
  deals.value
    .filter(deal => deal.id)
    .map(deal => ({
      id: deal.id,
      title: deal.title || `Atendimento #${deal.id}`,
      contact_id: deal.contact?.id || deal.contact_id || '',
      contactName: deal.contact?.name || '',
      conversation_id: deal.conversation_id || deal.conversation?.id || '',
      conversation_display_id:
        deal.conversation?.display_id || deal.conversation_display_id || '',
      stageName: deal.stage?.name || deal.crm_pipeline_stage?.name || '',
      legalArea: deal.legal_area || '',
      status: deal.status || '',
    }))
);

const selectedDeal = computed(() =>
  dealOptions.value.find(deal => String(deal.id) === String(form.crm_deal_id))
);

const selectedContact = computed(() =>
  contactOptions.value.find(
    contact => String(contact.id) === String(form.contact_id)
  )
);

const conflictWarning = computed(() => {
  if (!form.due_at) return '';
  const startsAt = new Date(form.due_at);
  const endsAt = new Date(startsAt.getTime() + 60 * 60 * 1000);
  const conflict = events.value.find(event => {
    if (event.source !== 'crm_activity' || !event.start_at) return false;
    if (event.activity_id === form.id) return false;
    const eventAssignee =
      event.activity?.assignee_id ||
      event.assignee?.id ||
      event.owner?.id ||
      '';
    if (form.assignee_id && String(eventAssignee) !== String(form.assignee_id))
      return false;
    const eventStart = new Date(event.start_at);
    const eventEnd = new Date(event.end_at || eventStart.getTime() + 3600000);
    return startsAt < eventEnd && endsAt > eventStart;
  });

  if (!conflict) return '';
  return `Conflito com "${conflict.title}" em ${formatDateTime(conflict.start_at)}.`;
});

const canSave = computed(() => form.title.trim().length > 2 && form.due_at);

watch(
  () => [
    filters.view,
    filters.cursor,
    filters.source,
    filters.priority,
    filters.assignee_id,
    filters.sync_status,
  ],
  () => loadAgenda()
);

watch(
  () => filters.query,
  () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => loadAgenda(), 350);
  }
);

onMounted(async () => {
  handleGoogleCallbackStatus();
  await Promise.all([loadGoogleStatus(), loadSupportData()]);
  await loadAgenda();
});

onBeforeUnmount(() => {
  window.clearTimeout(searchTimer);
});

function extractCollection(response) {
  const payload = response?.data;
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.payload)) return payload.payload;
  return [];
}

function addContactOption(map, contact) {
  if (!contact?.id) return;
  map.set(String(contact.id), {
    id: contact.id,
    name:
      contact.name ||
      contact.email ||
      contact.phone_number ||
      `Contato #${contact.id}`,
    email: contact.email || '',
    phone_number: contact.phone_number || '',
    relationship_status: contact.relationship_status || '',
  });
}

async function loadGoogleStatus() {
  try {
    const { data } = await CrmAPI.getGoogleWorkspaceAuthorization();
    googleStatus.value = {
      connected: Boolean(data.connected),
      status: data.status || 'disconnected',
      email: data.email || '',
      name: data.name || '',
      last_error: data.last_error || '',
      oauth_configured: Boolean(data.oauth_configured),
    };
  } catch {
    googleStatus.value = {
      connected: false,
      status: 'disconnected',
      email: '',
      name: '',
      last_error: '',
      oauth_configured: false,
    };
  }
}

async function loadSupportData() {
  supportLoading.value = true;
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
    // Agenda still works without optional selectors.
  } finally {
    supportLoading.value = false;
  }
}

async function loadAgenda() {
  loading.value = true;
  error.value = '';
  const params = {
    from: fetchRange.value.from.toISOString(),
    to: fetchRange.value.to.toISOString(),
    q: filters.query.trim() || undefined,
    source: filters.source || undefined,
    priority: filters.priority || undefined,
    assignee_id: filters.assignee_id || undefined,
    sync_status: filters.sync_status || undefined,
  };
  try {
    const { data } = await CrmAPI.getAgendaEvents(params);
    events.value = Array.isArray(data) ? data : [];
  } catch (err) {
    if (err?.response?.status === 404) {
      await loadAgendaFallback(params);
      return;
    }
    error.value =
      err?.response?.data?.error ||
      err?.response?.data?.message ||
      'Não foi possível carregar a agenda do CRM.';
  } finally {
    loading.value = false;
  }
}

async function loadAgendaFallback(params) {
  try {
    const { data } = await CrmAPI.getActivities({
      from: params.from,
      to: params.to,
      q: params.q,
      priority: params.priority,
      assignee_id: params.assignee_id,
      status: 'all',
    });
    const activities = Array.isArray(data) ? data : [];
    const fallbackEvents = activities
      .filter(activity => activity.due_at)
      .map(activityToAgendaEvent)
      .filter(event => eventMatchesFallbackFilters(event));
    events.value = fallbackEvents;
  } catch (fallbackErr) {
    error.value =
      fallbackErr?.response?.data?.error ||
      fallbackErr?.response?.data?.message ||
      'Não foi possível carregar a agenda do CRM.';
  }
}

function eventMatchesFallbackFilters(event) {
  if (filters.source === 'lead_contact') return false;
  if (filters.source && event.source !== filters.source) return false;
  if (filters.sync_status === 'synced') {
    return Boolean(event.activity?.external_calendar_event_id);
  }
  if (filters.sync_status === 'unsynced') {
    return !event.activity?.external_calendar_event_id;
  }
  return true;
}

function activityToAgendaEvent(activity) {
  const startAt = activity.due_at;
  const endAt = new Date(
    new Date(startAt).getTime() +
      (activity.kind === 'reuniao' ? 60 : 30) * 60000
  ).toISOString();
  const conversationId =
    activity.conversation_id || activity.conversation?.id || '';
  const conversationDisplayId =
    activity.conversation_display_id ||
    activity.conversation?.display_id ||
    conversationId;

  return {
    id: activity.id,
    event_key: `crm_activity-${activity.id}`,
    source: 'crm_activity',
    title: activity.title,
    description: activity.description,
    kind: activity.kind,
    start_at: startAt,
    end_at: endAt,
    status: normalizedActivityStatus(activity),
    priority: activity.priority || 'normal',
    editable: true,
    activity,
    activity_id: activity.id,
    contact: activity.contact || null,
    deal: activity.deal || null,
    conversation: conversationId
      ? {
          id: conversationId,
          display_id: conversationDisplayId,
        }
      : null,
    assignee: activity.assignee || activity.owner || null,
    owner: activity.owner || null,
    inbox: null,
    links: {
      google:
        activity.external_calendar_link ||
        activity.calendar_links?.google ||
        '',
      meet: activity.meeting_url || '',
      deal: activity.crm_deal_id
        ? `/app/accounts/${route.params.accountId}/crm/deals/${activity.crm_deal_id}`
        : '',
      conversation: conversationId
        ? `/app/accounts/${route.params.accountId}/conversations/${conversationId}`
        : '',
    },
  };
}

function normalizedActivityStatus(activity) {
  if (activity.completed_at) return 'completed';
  if (activity.is_overdue) return 'overdue';
  if (activity.is_due_today) return 'today';
  return 'scheduled';
}

async function connectGoogle() {
  error.value = '';
  successMessage.value = '';
  connectingGoogle.value = true;
  try {
    const { data } = await CrmAPI.authorizeGoogleWorkspace(
      currentReturnPath.value
    );
    if (data?.url) {
      window.location.href = data.url;
      return;
    }
    error.value =
      'Não foi possível iniciar a conexão com Google. Verifique a configuração OAuth.';
  } catch (err) {
    error.value =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      'Configure GOOGLE_OAUTH_CLIENT_ID e GOOGLE_OAUTH_CLIENT_SECRET para conectar o Google Calendar.';
  } finally {
    connectingGoogle.value = false;
  }
}

async function importGoogleEvents() {
  syncing.value = true;
  error.value = '';
  successMessage.value = '';
  try {
    const { data } = await CrmAPI.importActivitiesGoogleCalendar({
      from: fetchRange.value.from.toISOString(),
      to: fetchRange.value.to.toISOString(),
    });
    successMessage.value = `Google sincronizado: ${data.imported || 0} importadas, ${data.updated || 0} atualizadas, ${data.skipped || 0} ignoradas.`;
    await Promise.all([loadGoogleStatus(), loadAgenda()]);
  } catch (err) {
    if (err?.response?.data?.authorization_required) {
      await connectGoogle();
      return;
    }
    error.value =
      err?.response?.data?.error ||
      'Não foi possível sincronizar o Google Calendar.';
  } finally {
    syncing.value = false;
  }
}

function openCreateDrawer(day = null, contextEvent = null) {
  drawerMode.value = 'create';
  selectedEvent.value = contextEvent;
  selectedActivity.value = null;
  resetForm();
  const start = contextEvent
    ? meetingTimeFromEvent(contextEvent)
    : nextBusinessHour(day || cursorDate.value);
  form.due_at = dateTimeInputValue(start);
  form.reminder_at = dateTimeInputValue(new Date(start.getTime() - 30 * 60000));

  if (contextEvent) {
    form.title = contextEvent.contact?.name
      ? `Reunião - ${contextEvent.contact.name}`
      : 'Reunião de acompanhamento';
    form.description = `Criada a partir da ${sourceLabel(contextEvent)} em ${formatDateTime(contextEvent.start_at)}.`;
    form.contact_id = contextEvent.contact?.id || '';
    form.crm_deal_id = contextEvent.deal?.id || '';
    form.conversation_id = contextEvent.conversation?.id || '';
    form.assignee_id = contextEvent.assignee?.id || '';
  }

  drawerOpen.value = true;
}

function openDetailDrawer(event) {
  drawerMode.value = 'detail';
  selectedEvent.value = event;
  selectedActivity.value = event.activity || null;
  scheduleSuggestions.value = [];
  drawerOpen.value = true;
}

function openEditDrawer(event = selectedEvent.value) {
  const activity = event?.activity || event;
  if (!activity?.id) return;
  drawerMode.value = 'edit';
  selectedEvent.value = event;
  selectedActivity.value = activity;
  form.id = activity.id;
  form.title = activity.title || '';
  form.description = activity.description || '';
  form.kind = activity.kind || 'reuniao';
  form.priority = activity.priority || 'normal';
  form.due_at = dateTimeInputValue(activity.due_at || event?.start_at);
  form.reminder_at = dateTimeInputValue(activity.reminder_at);
  form.crm_deal_id = activity.crm_deal_id || event?.deal?.id || '';
  form.contact_id = activity.contact_id || event?.contact?.id || '';
  form.conversation_id =
    activity.conversation_id || event?.conversation?.id || '';
  form.assignee_id = activity.assignee_id || event?.assignee?.id || '';
  form.sync_google_calendar = activity.kind === 'reuniao';
  scheduleSuggestions.value = [];
  drawerOpen.value = true;
}

function closeDrawer() {
  drawerOpen.value = false;
  selectedEvent.value = null;
  selectedActivity.value = null;
  scheduleSuggestions.value = [];
  resetForm();
}

function resetForm() {
  form.id = null;
  form.title = '';
  form.description = '';
  form.kind = 'reuniao';
  form.priority = 'normal';
  form.due_at = '';
  form.reminder_at = '';
  form.crm_deal_id = '';
  form.contact_id = '';
  form.conversation_id = '';
  form.assignee_id = '';
  form.sync_google_calendar = true;
}

function applyDealContext() {
  if (!selectedDeal.value) return;
  if (selectedDeal.value.contact_id)
    form.contact_id = selectedDeal.value.contact_id;
  if (selectedDeal.value.conversation_id)
    form.conversation_id = selectedDeal.value.conversation_id;
  if (!form.title.trim()) {
    form.title = selectedDeal.value.contactName
      ? `Reunião - ${selectedDeal.value.contactName}`
      : selectedDeal.value.title;
  }
}

function applyContactContext() {
  if (!selectedContact.value || form.title.trim()) return;
  form.title = `Reunião - ${selectedContact.value.name}`;
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

async function saveMeeting() {
  if (!canSave.value) return;
  saving.value = true;
  error.value = '';
  successMessage.value = '';
  let syncFailed = false;
  let syncedWithGoogle = false;

  try {
    let activity;
    if (isDrawerEditing.value) {
      const { data } = await CrmAPI.updateActivity(form.id, activityPayload());
      activity = data;
    } else {
      const { data } = await CrmAPI.createActivity(activityPayload());
      activity = data;
    }

    if (
      form.sync_google_calendar &&
      activity?.id &&
      activity.kind === 'reuniao'
    ) {
      try {
        await CrmAPI.syncActivityGoogleCalendar(activity.id);
        syncedWithGoogle = true;
      } catch (err) {
        syncFailed = true;
        if (err?.response?.data?.authorization_required) {
          error.value =
            'Reunião salva no CRM. Conecte o Google para gerar Meet.';
        } else {
          error.value =
            err?.response?.data?.error ||
            'Reunião salva no CRM, mas a sincronização com Google falhou.';
        }
      }
    }

    if (syncFailed) {
      successMessage.value =
        'Reunião salva no CRM. Sincronize com Google quando a conexão estiver pronta.';
    } else if (syncedWithGoogle) {
      successMessage.value = 'Reunião salva e sincronizada.';
    } else {
      successMessage.value =
        'Reunião salva no CRM. Conecte o Google para gerar Meet.';
    }
    closeDrawer();
    await Promise.all([loadGoogleStatus(), loadAgenda()]);
  } catch (err) {
    error.value =
      err?.response?.data?.error || 'Não foi possível salvar a reunião.';
  } finally {
    saving.value = false;
  }
}

async function syncEvent(event = selectedEvent.value) {
  if (!event?.activity_id) return;
  syncing.value = true;
  error.value = '';
  try {
    await CrmAPI.syncActivityGoogleCalendar(event.activity_id);
    successMessage.value = 'Reunião sincronizada com Google Calendar.';
    await Promise.all([loadGoogleStatus(), loadAgenda()]);
  } catch (err) {
    if (err?.response?.data?.authorization_required) {
      error.value = 'Conecte o Google para sincronizar esta reunião.';
      return;
    }
    error.value =
      err?.response?.data?.error ||
      'Não foi possível sincronizar com o Google.';
  } finally {
    syncing.value = false;
  }
}

async function suggestSchedule() {
  suggesting.value = true;
  error.value = '';
  scheduleSuggestions.value = [];
  try {
    const { data } = await CrmAPI.suggestActivitySchedule({
      title: form.title || undefined,
      description: form.description || undefined,
      kind: form.kind || 'reuniao',
      priority: form.priority || 'normal',
      from: fetchRange.value.from.toISOString(),
      to: fetchRange.value.to.toISOString(),
      duration_minutes: 60,
      crm_deal_id: form.crm_deal_id || undefined,
      contact_id: form.contact_id || undefined,
      assignee_id: form.assignee_id || undefined,
    });
    scheduleSuggestions.value = Array.isArray(data.suggestions)
      ? data.suggestions
      : [];
    if (!scheduleSuggestions.value.length) {
      successMessage.value =
        'Nenhum horário livre encontrado no período visível.';
    }
  } catch (err) {
    error.value =
      err?.response?.data?.error || 'Não foi possível sugerir horários.';
  } finally {
    suggesting.value = false;
  }
}

function applySuggestion(slot) {
  form.due_at = dateTimeInputValue(slot.starts_at);
  form.reminder_at = dateTimeInputValue(
    new Date(new Date(slot.starts_at).getTime() - 30 * 60000)
  );
  scheduleSuggestions.value = [];
}

async function completeActivity(event = selectedEvent.value) {
  if (!event?.activity_id) return;
  saving.value = true;
  try {
    await CrmAPI.completeActivity(
      event.activity_id,
      'Concluída pela Agenda CRM'
    );
    closeDrawer();
    await loadAgenda();
  } catch {
    error.value = 'Não foi possível concluir a atividade.';
  } finally {
    saving.value = false;
  }
}

async function deleteActivity(event = selectedEvent.value) {
  if (!event?.activity_id) return;
  const confirmed = window.confirm('Excluir esta reunião da agenda do CRM?');
  if (!confirmed) return;
  deleting.value = true;
  try {
    await CrmAPI.deleteActivity(event.activity_id);
    closeDrawer();
    await loadAgenda();
  } catch {
    error.value = 'Não foi possível excluir a reunião.';
  } finally {
    deleting.value = false;
  }
}

function openEventLink(event, kind) {
  const url = event?.links?.[kind];
  if (!url) return;
  if (kind === 'deal' || kind === 'conversation') {
    router.push(url);
    return;
  }
  window.open(url, '_blank', 'noopener,noreferrer');
}

function clearFilters() {
  filters.query = '';
  filters.source = '';
  filters.priority = '';
  filters.assignee_id = '';
  filters.sync_status = '';
  loadAgenda();
}

function handleGoogleCallbackStatus() {
  const status = route.query.google_workspace;
  if (!status) return;

  if (status === 'connected') {
    successMessage.value = 'Google Calendar conectado com sucesso.';
    return;
  }

  if (status === 'not_configured') {
    error.value =
      'Google OAuth ainda não está configurado. Defina GOOGLE_OAUTH_CLIENT_ID e GOOGLE_OAUTH_CLIENT_SECRET.';
    return;
  }

  error.value =
    'Não foi possível concluir a conexão com Google. Revise o OAuth e tente novamente.';
}

function goToday() {
  filters.cursor = dateInputValue(new Date());
}

function moveCursor(amount) {
  const date = new Date(cursorDate.value);
  if (filters.view === 'day') date.setDate(date.getDate() + amount);
  if (filters.view === 'week') date.setDate(date.getDate() + amount * 7);
  if (filters.view === 'month') date.setMonth(date.getMonth() + amount);
  filters.cursor = dateInputValue(date);
}

function selectDay(day) {
  filters.cursor = dateInputValue(day);
  filters.view = 'day';
}

function rangeForView(view, date) {
  if (view === 'day') {
    return {
      from: startOfDay(date),
      to: endOfDay(date),
    };
  }
  if (view === 'month') {
    return {
      from: startOfMonth(date),
      to: endOfMonth(date),
    };
  }
  return {
    from: startOfWeek(date),
    to: endOfWeek(date),
  };
}

function daysBetween(from, to) {
  const days = [];
  const current = startOfDay(from);
  const last = startOfDay(to);
  while (current <= last) {
    days.push(new Date(current));
    current.setDate(current.getDate() + 1);
  }
  return days;
}

function parseDate(value) {
  if (!value) return null;
  const date = new Date(`${value}T00:00:00`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function startOfDay(date) {
  const value = new Date(date);
  value.setHours(0, 0, 0, 0);
  return value;
}

function endOfDay(date) {
  const value = new Date(date);
  value.setHours(23, 59, 59, 999);
  return value;
}

function startOfWeek(date) {
  const value = startOfDay(date);
  const day = value.getDay() || 7;
  value.setDate(value.getDate() - day + 1);
  return value;
}

function endOfWeek(date) {
  const value = startOfWeek(date);
  value.setDate(value.getDate() + 6);
  return endOfDay(value);
}

function startOfMonth(date) {
  const value = startOfDay(date);
  value.setDate(1);
  return value;
}

function endOfMonth(date) {
  const value = startOfMonth(date);
  value.setMonth(value.getMonth() + 1);
  value.setDate(0);
  return endOfDay(value);
}

function nextBusinessHour(day) {
  const value = new Date(day);
  const now = new Date();
  if (isSameDay(value, now)) {
    value.setHours(Math.max(now.getHours() + 1, 9), 0, 0, 0);
  } else {
    value.setHours(9, 0, 0, 0);
  }
  if (value.getHours() >= 18) value.setHours(9, 0, 0, 0);
  return value;
}

function meetingTimeFromEvent(event) {
  const value = new Date(event.start_at || new Date());
  value.setHours(Math.min(Math.max(value.getHours() + 1, 9), 17), 0, 0, 0);
  return value;
}

function dayKey(date) {
  return dateInputValue(date);
}

function dateInputValue(value) {
  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
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

function formatDayLabel(date) {
  return `${weekDays[(date.getDay() + 6) % 7]}, ${String(date.getDate()).padStart(2, '0')} ${monthNames[date.getMonth()]}`;
}

function formatRangeLabel() {
  const from = visibleRange.value.from;
  const to = visibleRange.value.to;
  if (filters.view === 'day') return formatDayLabel(from);
  if (filters.view === 'month') {
    return `${fullMonthNames[cursorDate.value.getMonth()]} ${cursorDate.value.getFullYear()}`;
  }
  return `${formatDayLabel(from)} - ${formatDayLabel(to)}`;
}

function formatDateTime(value) {
  if (!value) return 'Sem data';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatTime(value) {
  if (!value) return '--:--';
  return new Intl.DateTimeFormat('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatHour(hour) {
  return `${String(hour).padStart(2, '0')}:00`;
}

function isSameDay(first, second) {
  return dayKey(first) === dayKey(second);
}

function isCurrentMonth(day) {
  return (
    day.getMonth() === cursorDate.value.getMonth() &&
    day.getFullYear() === cursorDate.value.getFullYear()
  );
}

function nullableId(value) {
  return value ? Number(value) : null;
}

function eventDurationMinutes(event) {
  const start = new Date(event.start_at);
  const end = new Date(event.end_at || start.getTime() + 30 * 60000);
  const minutes = Math.round((end - start) / 60000);
  return Math.max(minutes || 30, event.source === 'lead_contact' ? 15 : 30);
}

function eventStyle(event) {
  const start = new Date(event.start_at);
  const minutes = start.getHours() * 60 + start.getMinutes();
  return {
    top: `${(minutes / 60) * HOUR_HEIGHT}px`,
    minHeight: `${Math.max((eventDurationMinutes(event) / 60) * HOUR_HEIGHT, 34)}px`,
  };
}

function eventsForDay(day) {
  return eventsByDay.value.get(dayKey(day)) || [];
}

function monthEvents(day) {
  return eventsForDay(day).slice(0, MAX_MONTH_EVENTS);
}

function remainingMonthEvents(day) {
  return Math.max(eventsForDay(day).length - MAX_MONTH_EVENTS, 0);
}

function sourceLabel(event) {
  if (event?.source === 'lead_contact') return 'entrada de lead';
  if (event?.kind === 'reuniao') return 'reunião';
  return kindLabel(event?.kind);
}

function kindLabel(kind) {
  return KINDS.find(item => item.value === kind)?.label || kind || 'Atividade';
}

function statusLabel(event) {
  if (event?.source === 'lead_contact') return 'Lead entrou em contato';
  if (event?.status === 'completed') return 'Concluída';
  if (event?.status === 'overdue') return 'Vencida';
  if (event?.status === 'today') return 'Hoje';
  return 'Agendada';
}

function priorityLabel(priority) {
  return PRIORITIES.find(item => item.value === priority)?.label || 'Normal';
}

function eventClass(event) {
  return [
    'agenda-event',
    `agenda-event--${event.source}`,
    event.status === 'completed' ? 'agenda-event--done' : '',
    event.status === 'overdue' ? 'agenda-event--overdue' : '',
    event.priority === 'critica' ? 'agenda-event--critical' : '',
    event.priority === 'alta' ? 'agenda-event--high' : '',
    event.activity?.external_calendar_event_id ? 'agenda-event--synced' : '',
  ]
    .filter(Boolean)
    .join(' ');
}

function priorityClass(priority) {
  return {
    baixa: 'agenda-priority agenda-priority--low',
    normal: 'agenda-priority agenda-priority--normal',
    alta: 'agenda-priority agenda-priority--high',
    critica: 'agenda-priority agenda-priority--critical',
  }[priority || 'normal'];
}
</script>

<template>
  <main class="crm-agenda">
    <div class="crm-agenda__scroll">
      <section class="agenda-hero">
        <div class="agenda-hero__title">
          <span class="agenda-hero__icon">
            <span class="i-lucide-calendar-days" />
          </span>
          <div>
            <span class="agenda-hero__eyebrow">AGENDA CRM</span>
            <h1>Agenda</h1>
            <p>
              Veja reuniões, atividades e o horário real em que cada lead entrou
              em contato.
            </p>
          </div>
        </div>
        <div class="agenda-hero__actions">
          <button
            class="agenda-btn agenda-btn--ghost"
            type="button"
            @click="goToday"
          >
            <span class="i-lucide-calendar-clock" />
            Hoje
          </button>
          <button
            class="agenda-btn agenda-btn--ghost"
            type="button"
            :disabled="syncing"
            @click="importGoogleEvents"
          >
            <span
              :class="
                syncing
                  ? 'i-lucide-loader-2 is-spinning'
                  : 'i-lucide-refresh-cw'
              "
            />
            {{ syncing ? 'Sincronizando...' : 'Sincronizar' }}
          </button>
          <button
            v-if="!hasGoogleConnection"
            class="agenda-btn agenda-btn--google"
            type="button"
            :disabled="connectingGoogle"
            @click="connectGoogle"
          >
            <span
              :class="
                connectingGoogle
                  ? 'i-lucide-loader-2 is-spinning'
                  : 'i-lucide-link'
              "
            />
            {{ connectingGoogle ? 'Conectando...' : 'Conectar Google' }}
          </button>
          <button
            class="agenda-btn agenda-btn--primary"
            type="button"
            @click="openCreateDrawer()"
          >
            <span class="i-lucide-plus" />
            Nova reunião
          </button>
        </div>
      </section>

      <section class="agenda-status-grid">
        <article class="agenda-status agenda-status--google">
          <span class="agenda-status__icon">
            <span class="i-lucide-badge-check" />
          </span>
          <div>
            <strong>{{
              hasGoogleConnection ? 'Google conectado' : 'Google desconectado'
            }}</strong>
            <p>
              {{
                hasGoogleConnection
                  ? googleStatus.email || 'Conta pronta para sincronizar'
                  : googleStatus.oauth_configured
                    ? 'Conecte para gerar Meet automaticamente'
                    : 'OAuth pendente de configuração'
              }}
            </p>
          </div>
        </article>
        <article class="agenda-status agenda-status--blue">
          <span class="agenda-status__icon">
            <span class="i-lucide-video" />
          </span>
          <div>
            <strong>{{ stats.meetings }}</strong>
            <p>reuniões no período</p>
          </div>
        </article>
        <article class="agenda-status agenda-status--teal">
          <span class="agenda-status__icon">
            <span class="i-lucide-message-circle" />
          </span>
          <div>
            <strong>{{ stats.leadContacts }}</strong>
            <p>entradas de lead</p>
          </div>
        </article>
        <article class="agenda-status agenda-status--amber">
          <span class="agenda-status__icon">
            <span class="i-lucide-calendar-check-2" />
          </span>
          <div>
            <strong>{{ stats.today }}</strong>
            <p>eventos hoje</p>
          </div>
        </article>
        <article class="agenda-status agenda-status--red">
          <span class="agenda-status__icon">
            <span class="i-lucide-alarm-clock" />
          </span>
          <div>
            <strong>{{ stats.overdue }}</strong>
            <p>vencidas</p>
          </div>
        </article>
        <article class="agenda-status agenda-status--violet">
          <span class="agenda-status__icon">
            <span class="i-lucide-cloud-off" />
          </span>
          <div>
            <strong>{{ stats.unsynced }}</strong>
            <p>sem Google</p>
          </div>
        </article>
      </section>

      <div v-if="error" class="agenda-alert agenda-alert--error">
        <span class="i-lucide-alert-triangle" />
        {{ error }}
      </div>
      <div v-if="successMessage" class="agenda-alert agenda-alert--success">
        <span class="i-lucide-check-circle" />
        {{ successMessage }}
      </div>

      <section class="agenda-toolbar">
        <div class="agenda-toolbar__top">
          <div class="agenda-view-switch">
            <button
              v-for="view in VIEW_OPTIONS"
              :key="view.value"
              type="button"
              :class="{ active: filters.view === view.value }"
              @click="filters.view = view.value"
            >
              {{ view.label }}
            </button>
          </div>

          <div class="agenda-date-nav">
            <button
              type="button"
              class="agenda-icon-btn"
              @click="moveCursor(-1)"
            >
              <span class="i-lucide-chevron-left" />
            </button>
            <strong>{{ formatRangeLabel() }}</strong>
            <button
              type="button"
              class="agenda-icon-btn"
              @click="moveCursor(1)"
            >
              <span class="i-lucide-chevron-right" />
            </button>
          </div>
        </div>

        <div class="agenda-filter-grid">
          <label class="agenda-search">
            <span class="i-lucide-search" />
            <input
              v-model="filters.query"
              type="search"
              placeholder="Buscar reunião ou lead"
            />
          </label>
          <select v-model="filters.source" class="agenda-select">
            <option
              v-for="option in SOURCE_OPTIONS"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
          <select v-model="filters.priority" class="agenda-select">
            <option
              v-for="priority in PRIORITIES"
              :key="priority.value"
              :value="priority.value"
            >
              {{ priority.label }}
            </option>
          </select>
          <select v-model="filters.assignee_id" class="agenda-select">
            <option value="">Todos os responsaveis</option>
            <option value="none">Sem responsável</option>
            <option
              v-for="agent in agentOptions"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agent.name }}
            </option>
          </select>
          <select v-model="filters.sync_status" class="agenda-select">
            <option
              v-for="option in SYNC_OPTIONS"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
          <input v-model="filters.cursor" class="agenda-select" type="date" />
          <button
            class="agenda-btn agenda-btn--ghost agenda-clear-btn"
            type="button"
            @click="clearFilters"
          >
            <span class="i-lucide-eraser" />
            Limpar
          </button>
        </div>
      </section>

      <section class="agenda-layout">
        <div class="agenda-calendar-card">
          <div v-if="loading" class="agenda-loading">
            <span class="i-lucide-loader-2 is-spinning" />
            Carregando agenda...
          </div>

          <template v-else>
            <div v-if="sortedEvents.length === 0" class="agenda-empty-inline">
              <span class="i-lucide-calendar-plus" />
              Nenhum evento no período. A grade continua disponível para criar
              reuniões.
            </div>

            <div v-if="filters.view === 'month'" class="agenda-month">
              <div
                v-for="dayName in weekDays"
                :key="dayName"
                class="agenda-month__weekday"
              >
                {{ dayName }}
              </div>
              <button
                v-for="day in visibleDays"
                :key="dayKey(day)"
                type="button"
                class="agenda-month__day"
                :class="{
                  'agenda-month__day--muted': !isCurrentMonth(day),
                  'agenda-month__day--today': isSameDay(day, new Date()),
                }"
                @click="selectDay(day)"
              >
                <span class="agenda-month__number">{{ day.getDate() }}</span>
                <span
                  v-for="event in monthEvents(day)"
                  :key="event.event_key"
                  :class="eventClass(event)"
                  class="agenda-month-event"
                  @click.stop="openDetailDrawer(event)"
                >
                  {{ formatTime(event.start_at) }} {{ event.title }}
                </span>
                <span
                  v-if="remainingMonthEvents(day)"
                  class="agenda-month__more"
                >
                  +{{ remainingMonthEvents(day) }} eventos
                </span>
              </button>
            </div>

            <div v-else class="agenda-timeboard">
              <div class="agenda-timeboard__header">
                <div class="agenda-timeboard__corner" />
                <button
                  v-for="day in visibleDays"
                  :key="dayKey(day)"
                  type="button"
                  class="agenda-timeboard__day-head"
                  :class="{ 'is-today': isSameDay(day, new Date()) }"
                  @click="selectDay(day)"
                >
                  <span>{{ formatDayLabel(day) }}</span>
                  <strong>{{ day.getDate() }}</strong>
                </button>
              </div>
              <div class="agenda-timeboard__body">
                <div class="agenda-hours" :style="{ height: timelineHeight }">
                  <div
                    v-for="hour in HOURS"
                    :key="hour"
                    class="agenda-hour"
                    :style="{ height: `${HOUR_HEIGHT}px` }"
                  >
                    {{ formatHour(hour) }}
                  </div>
                </div>
                <div
                  v-for="day in visibleDays"
                  :key="dayKey(day)"
                  class="agenda-time-column"
                  :class="{ 'is-today': isSameDay(day, new Date()) }"
                  :style="{ height: timelineHeight }"
                >
                  <button
                    class="agenda-time-column__create"
                    type="button"
                    @click="openCreateDrawer(day)"
                  >
                    <span class="i-lucide-plus" />
                  </button>
                  <div
                    v-if="isSameDay(day, new Date())"
                    class="agenda-now-line"
                    :style="nowLineStyle"
                  />
                  <button
                    v-for="event in eventsForDay(day)"
                    :key="event.event_key"
                    type="button"
                    :class="eventClass(event)"
                    :style="eventStyle(event)"
                    @click="openDetailDrawer(event)"
                  >
                    <span class="agenda-event__time">{{
                      formatTime(event.start_at)
                    }}</span>
                    <strong>{{ event.title }}</strong>
                    <small>
                      {{ sourceLabel(event) }} -
                      {{ event.contact?.name || 'Sem contato' }}
                    </small>
                  </button>
                </div>
              </div>
            </div>

            <div class="agenda-mobile-list">
              <section
                v-for="day in visibleDays"
                :key="`mobile-${dayKey(day)}`"
                class="agenda-mobile-day"
              >
                <header>{{ formatDayLabel(day) }}</header>
                <button
                  v-if="eventsForDay(day).length === 0"
                  class="agenda-mobile-empty"
                  type="button"
                  @click="openCreateDrawer(day)"
                >
                  Criar reunião neste dia
                </button>
                <button
                  v-for="event in eventsForDay(day)"
                  :key="`mobile-${event.event_key}`"
                  type="button"
                  :class="eventClass(event)"
                  @click="openDetailDrawer(event)"
                >
                  <span class="agenda-event__time">{{
                    formatTime(event.start_at)
                  }}</span>
                  <strong>{{ event.title }}</strong>
                  <small
                    >{{ sourceLabel(event) }} - {{ statusLabel(event) }}</small
                  >
                </button>
              </section>
            </div>
          </template>
        </div>

        <aside class="agenda-side-panel">
          <section class="agenda-panel-card">
            <div class="agenda-panel-card__header">
              <span class="agenda-panel-card__icon">
                <span class="i-lucide-list-checks" />
              </span>
              <div>
                <strong>Próximas reuniões</strong>
                <p>Atendimentos com agenda ativa</p>
              </div>
            </div>
            <div v-if="upcomingEvents.length === 0" class="agenda-mini-empty">
              Nenhuma reunião futura.
            </div>
            <button
              v-for="event in upcomingEvents"
              :key="`upcoming-${event.event_key}`"
              class="agenda-mini-event"
              type="button"
              @click="openDetailDrawer(event)"
            >
              <strong>{{ event.title }}</strong>
              <small>{{ formatDateTime(event.start_at) }}</small>
              <span :class="priorityClass(event.priority)">
                {{ priorityLabel(event.priority) }}
              </span>
            </button>
          </section>

          <section class="agenda-panel-card agenda-panel-card--tips">
            <div class="agenda-panel-card__header">
              <span
                class="agenda-panel-card__icon agenda-panel-card__icon--teal"
              >
                <span class="i-lucide-sparkles" />
              </span>
              <div>
                <strong>Fluxo recomendado</strong>
                <p>Use a agenda como ponte entre lead e reunião.</p>
              </div>
            </div>
            <ul>
              <li>Use entrada de lead para entender o primeiro contato.</li>
              <li>Crie reuniões direto do evento do lead.</li>
              <li>Sincronize o Google para gerar Meet.</li>
            </ul>
          </section>
        </aside>
      </section>
    </div>

    <div
      v-if="drawerOpen"
      class="agenda-drawer-backdrop"
      @click.self="closeDrawer"
    >
      <aside class="agenda-drawer">
        <header class="agenda-drawer__header">
          <div>
            <span class="agenda-hero__eyebrow">
              {{ isDrawerDetail ? 'DETALHE DA AGENDA' : 'REUNIAO CRM' }}
            </span>
            <h2>{{ drawerTitle }}</h2>
          </div>
          <button class="agenda-icon-btn" type="button" @click="closeDrawer">
            <span class="i-lucide-x" />
          </button>
        </header>

        <div v-if="isDrawerDetail" class="agenda-drawer__body">
          <section class="agenda-form-section">
            <div class="agenda-detail-head">
              <span
                :class="eventClass(selectedEvent)"
                class="agenda-detail-source"
              >
                {{ sourceLabel(selectedEvent) }}
              </span>
              <span :class="priorityClass(selectedEvent?.priority)">
                {{ priorityLabel(selectedEvent?.priority) }}
              </span>
            </div>
            <h3>{{ selectedEvent?.title }}</h3>
            <p>{{ selectedEvent?.description || 'Sem descrição.' }}</p>
            <div class="agenda-detail-grid">
              <div>
                <span>Horario</span>
                <strong>{{ formatDateTime(selectedEvent?.start_at) }}</strong>
              </div>
              <div>
                <span>Status</span>
                <strong>{{ statusLabel(selectedEvent) }}</strong>
              </div>
              <div>
                <span>Contato</span>
                <strong>{{
                  selectedEvent?.contact?.name || 'Sem contato'
                }}</strong>
              </div>
              <div>
                <span>Responsável</span>
                <strong>{{
                  selectedEvent?.assignee?.name || 'Sem responsável'
                }}</strong>
              </div>
              <div>
                <span>Telefone</span>
                <strong>{{
                  selectedEvent?.contact?.phone_number || '-'
                }}</strong>
              </div>
              <div>
                <span>E-mail</span>
                <strong>{{ selectedEvent?.contact?.email || '-' }}</strong>
              </div>
              <div>
                <span>Atendimento</span>
                <strong>
                  {{
                    selectedEvent?.deal?.title ||
                    (selectedEvent?.conversation?.display_id
                      ? `Conversa #${selectedEvent.conversation.display_id}`
                      : '-')
                  }}
                </strong>
              </div>
              <div>
                <span>Etapa</span>
                <strong>{{ selectedEvent?.deal?.stage?.name || '-' }}</strong>
              </div>
            </div>
          </section>

          <section
            v-if="selectedEvent?.links?.meet || selectedEvent?.links?.google"
            class="agenda-form-section"
          >
            <h3>Google Calendar</h3>
            <div class="agenda-google-links">
              <button
                v-if="selectedEvent?.links?.google"
                type="button"
                @click="openEventLink(selectedEvent, 'google')"
              >
                <span class="i-lucide-calendar-check" />
                Abrir Google
              </button>
              <button
                v-if="selectedEvent?.links?.meet"
                type="button"
                @click="openEventLink(selectedEvent, 'meet')"
              >
                <span class="i-lucide-video" />
                Abrir Meet
              </button>
            </div>
          </section>
        </div>

        <div v-else class="agenda-drawer__body">
          <section class="agenda-form-section">
            <h3>Dados da reunião</h3>
            <label>
              Título
              <input
                v-model="form.title"
                type="text"
                placeholder="Ex: Reunião - Douglas Chuster"
              />
            </label>
            <label>
              Descrição
              <textarea
                v-model="form.description"
                rows="4"
                placeholder="Contexto, pauta e próximos passos"
              />
            </label>
            <div class="agenda-form-grid">
              <label>
                Tipo
                <select v-model="form.kind">
                  <option
                    v-for="kind in KINDS"
                    :key="kind.value"
                    :value="kind.value"
                  >
                    {{ kind.label }}
                  </option>
                </select>
              </label>
              <label>
                Prioridade
                <select v-model="form.priority">
                  <option
                    v-for="priority in PRIORITIES.filter(item => item.value)"
                    :key="priority.value"
                    :value="priority.value"
                  >
                    {{ priority.label }}
                  </option>
                </select>
              </label>
              <label>
                Inicio
                <input v-model="form.due_at" type="datetime-local" />
              </label>
              <label>
                Lembrete
                <input v-model="form.reminder_at" type="datetime-local" />
              </label>
            </div>
            <div v-if="conflictWarning" class="agenda-warning">
              <span class="i-lucide-alert-triangle" />
              {{ conflictWarning }}
            </div>
          </section>

          <section class="agenda-form-section">
            <h3>Vinculos do atendimento</h3>
            <div class="agenda-form-grid">
              <label>
                Atendimento / lead
                <select v-model="form.crm_deal_id" @change="applyDealContext">
                  <option value="">Sem atendimento</option>
                  <option
                    v-for="deal in dealOptions"
                    :key="deal.id"
                    :value="deal.id"
                  >
                    {{ deal.title }}
                    {{ deal.contactName ? `- ${deal.contactName}` : '' }}
                  </option>
                </select>
              </label>
              <label>
                Contato
                <select v-model="form.contact_id" @change="applyContactContext">
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
              <label>
                Responsável
                <select v-model="form.assignee_id">
                  <option value="">Sem responsável</option>
                  <option
                    v-for="agent in agentOptions"
                    :key="agent.id"
                    :value="agent.id"
                  >
                    {{ agent.name }}
                  </option>
                </select>
              </label>
            </div>
            <div
              v-if="selectedDeal || selectedContact"
              class="agenda-context-card"
            >
              <span class="i-lucide-briefcase" />
              <div>
                <strong>{{
                  selectedDeal?.title || selectedContact?.name
                }}</strong>
                <p>
                  {{ selectedDeal?.stageName || 'Etapa não informada' }}
                  <span v-if="selectedDeal?.legalArea"
                    >- {{ selectedDeal.legalArea }}</span
                  >
                </p>
                <p v-if="selectedContact">
                  {{ selectedContact.email || 'Sem e-mail' }}
                  <span v-if="selectedContact.phone_number"
                    >- {{ selectedContact.phone_number }}</span
                  >
                </p>
              </div>
            </div>
          </section>

          <section class="agenda-form-section">
            <div class="agenda-sync-row">
              <div>
                <h3>Google Calendar</h3>
                <p>
                  {{
                    hasGoogleConnection
                      ? 'Gerar ou atualizar evento e Meet automaticamente.'
                      : 'A reunião será salva localmente até conectar o Google.'
                  }}
                </p>
              </div>
              <label class="agenda-toggle">
                <input v-model="form.sync_google_calendar" type="checkbox" />
                Sincronizar
              </label>
            </div>
            <div class="agenda-suggestions">
              <button
                class="agenda-btn agenda-btn--ghost"
                type="button"
                :disabled="suggesting"
                @click="suggestSchedule"
              >
                <span
                  :class="
                    suggesting
                      ? 'i-lucide-loader-2 is-spinning'
                      : 'i-lucide-wand-sparkles'
                  "
                />
                Sugerir horário
              </button>
              <button
                v-for="slot in scheduleSuggestions"
                :key="slot.starts_at"
                class="agenda-suggestion"
                type="button"
                @click="applySuggestion(slot)"
              >
                <strong>{{ formatDateTime(slot.starts_at) }}</strong>
                <span>{{ slot.reason }}</span>
              </button>
            </div>
          </section>
        </div>

        <footer class="agenda-drawer__footer">
          <template v-if="isDrawerDetail">
            <button
              v-if="selectedEvent?.links?.conversation"
              class="agenda-btn agenda-btn--ghost"
              type="button"
              @click="openEventLink(selectedEvent, 'conversation')"
            >
              <span class="i-lucide-message-square" />
              Abrir conversa
            </button>
            <button
              v-if="selectedEvent?.links?.deal"
              class="agenda-btn agenda-btn--ghost"
              type="button"
              @click="openEventLink(selectedEvent, 'deal')"
            >
              <span class="i-lucide-external-link" />
              Abrir atendimento
            </button>
            <button
              v-if="isLeadContactDetail"
              class="agenda-btn agenda-btn--primary"
              type="button"
              @click="openCreateDrawer(null, selectedEvent)"
            >
              <span class="i-lucide-calendar-plus" />
              Criar reunião
            </button>
            <button
              v-if="selectedEvent?.source === 'crm_activity'"
              class="agenda-btn agenda-btn--ghost"
              type="button"
              @click="openEditDrawer(selectedEvent)"
            >
              <span class="i-lucide-pencil" />
              Editar
            </button>
            <button
              v-if="selectedEvent?.source === 'crm_activity'"
              class="agenda-btn agenda-btn--success"
              type="button"
              :disabled="saving"
              @click="completeActivity(selectedEvent)"
            >
              <span class="i-lucide-check" />
              Concluir
            </button>
            <button
              v-if="selectedEvent?.source === 'crm_activity'"
              class="agenda-btn agenda-btn--google"
              type="button"
              :disabled="syncing"
              @click="syncEvent(selectedEvent)"
            >
              <span class="i-lucide-refresh-cw" />
              Google
            </button>
            <button
              v-if="selectedEvent?.source === 'crm_activity'"
              class="agenda-btn agenda-btn--danger"
              type="button"
              :disabled="deleting"
              @click="deleteActivity(selectedEvent)"
            >
              <span class="i-lucide-trash-2" />
              Excluir
            </button>
          </template>
          <template v-else>
            <button
              class="agenda-btn agenda-btn--ghost"
              type="button"
              @click="closeDrawer"
            >
              Cancelar
            </button>
            <button
              class="agenda-btn agenda-btn--primary"
              type="button"
              :disabled="!canSave || saving || supportLoading"
              @click="saveMeeting"
            >
              <span
                :class="
                  saving ? 'i-lucide-loader-2 is-spinning' : 'i-lucide-save'
                "
              />
              {{ saving ? 'Salvando...' : 'Salvar reunião' }}
            </button>
          </template>
        </footer>
      </aside>
    </div>
  </main>
</template>

<style scoped>
.crm-agenda {
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  color: #071327;
  --agenda-border: #c8d7ea;
  --agenda-soft-border: #dbe5f2;
  --agenda-card: rgba(255, 255, 255, 0.94);
  --agenda-field: #ffffff;
  --agenda-heading: #071327;
  --agenda-muted: #425571;
}

.crm-agenda__scroll {
  height: 100%;
  min-height: 0;
  overflow-x: hidden;
  overflow-y: auto;
  padding: 24px 32px 32px;
  background: radial-gradient(
      circle at top left,
      rgba(20, 184, 166, 0.18),
      transparent 28%
    ),
    radial-gradient(
      circle at top right,
      rgba(37, 99, 235, 0.12),
      transparent 26%
    ),
    linear-gradient(180deg, #f8fbff 0%, #edf4fa 100%);
}

.agenda-hero,
.agenda-toolbar,
.agenda-calendar-card,
.agenda-panel-card {
  border: 1px solid var(--agenda-border);
  background: var(--agenda-card);
  box-shadow: 0 18px 50px rgba(30, 64, 175, 0.08);
}

.agenda-hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 20px;
  padding: 24px;
  border-radius: 18px;
}

.agenda-hero__title {
  display: flex;
  align-items: center;
  gap: 16px;
  min-width: 0;
}

.agenda-hero__icon,
.agenda-status__icon,
.agenda-panel-card__icon,
.agenda-empty-inline > span {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
}

.agenda-hero__icon {
  width: 52px;
  height: 52px;
  border-radius: 16px;
  background: linear-gradient(135deg, #dbeafe, #ccfbf1);
  color: #1d4ed8;
  box-shadow:
    inset 0 0 0 1px rgba(37, 99, 235, 0.18),
    0 14px 30px rgba(37, 99, 235, 0.16);
}

.agenda-hero__icon > span {
  width: 28px;
  height: 28px;
}

.agenda-hero__eyebrow {
  display: inline-flex;
  margin-bottom: 6px;
  color: #2563eb;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0;
}

.agenda-hero h1,
.agenda-drawer h2 {
  margin: 0;
  color: var(--agenda-heading);
  font-size: 28px;
  font-weight: 800;
  letter-spacing: 0;
}

.agenda-hero p,
.agenda-panel-card p,
.agenda-status p,
.agenda-form-section p {
  margin: 4px 0 0;
  color: var(--agenda-muted);
  font-size: 14px;
}

.agenda-hero__actions,
.agenda-drawer__footer,
.agenda-google-links,
.agenda-suggestions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.agenda-hero__actions {
  justify-content: flex-end;
}

.agenda-btn,
.agenda-icon-btn,
.agenda-google-links button,
.agenda-suggestion {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 40px;
  border: 1px solid #9fb5d1;
  border-radius: 10px;
  background: linear-gradient(180deg, #ffffff, #f8fbff);
  color: #0f2442;
  font-size: 14px;
  font-weight: 750;
  transition:
    transform 160ms ease,
    border-color 160ms ease,
    background 160ms ease,
    box-shadow 160ms ease;
}

.agenda-btn > span,
.agenda-icon-btn > span,
.agenda-google-links button > span {
  flex: 0 0 auto;
  width: 18px;
  height: 18px;
}

.agenda-btn {
  padding: 0 14px;
}

.agenda-btn:hover:not(:disabled),
.agenda-icon-btn:hover,
.agenda-google-links button:hover,
.agenda-suggestion:hover {
  transform: translateY(-1px);
  border-color: #2563eb;
  box-shadow: 0 10px 24px rgba(37, 99, 235, 0.14);
}

.agenda-btn:focus-visible,
.agenda-icon-btn:focus-visible,
.agenda-google-links button:focus-visible,
.agenda-suggestion:focus-visible,
.agenda-view-switch button:focus-visible,
.agenda-timeboard__day-head:focus-visible,
.agenda-month__day:focus-visible {
  outline: 3px solid rgba(37, 99, 235, 0.22);
  outline-offset: 2px;
}

.agenda-btn:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.agenda-btn--primary {
  border-color: #2563eb;
  background: linear-gradient(135deg, #2563eb, #4f46e5);
  color: #ffffff;
}

.agenda-btn--google {
  border-color: #0f766e;
  background: linear-gradient(135deg, #99f6e4, #ccfbf1);
  color: #083f3a;
}

.agenda-btn--success {
  border-color: #0f766e;
  background: #ccfbf1;
  color: #0f4f4a;
}

.agenda-btn--danger {
  border-color: #fb7185;
  background: #ffe4e6;
  color: #be123c;
}

.agenda-icon-btn {
  width: 40px;
  padding: 0;
}

.agenda-status-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 12px;
  margin: 16px 0;
}

.agenda-status {
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 94px;
  padding: 16px;
  border: 1px solid var(--agenda-border);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.86);
}

.agenda-status::before {
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  content: '';
}

.agenda-status strong {
  display: block;
  color: var(--agenda-heading);
  font-size: 20px;
  font-weight: 800;
}

.agenda-status__icon {
  width: 42px;
  height: 42px;
  border-radius: 14px;
  filter: drop-shadow(0 8px 16px rgba(15, 23, 42, 0.12));
}

.agenda-status__icon > span {
  width: 23px;
  height: 23px;
}

.agenda-status--google .agenda-status__icon {
  background: #dcfce7;
  color: #15803d;
}

.agenda-status--google::before {
  background: #16a34a;
}

.agenda-status--blue .agenda-status__icon {
  background: #dbeafe;
  color: #2563eb;
}

.agenda-status--blue::before {
  background: #2563eb;
}

.agenda-status--teal .agenda-status__icon {
  background: #ccfbf1;
  color: #0f766e;
}

.agenda-status--teal::before {
  background: #0f766e;
}

.agenda-status--amber .agenda-status__icon {
  background: #fef3c7;
  color: #b45309;
}

.agenda-status--amber::before {
  background: #f59e0b;
}

.agenda-status--red .agenda-status__icon {
  background: #ffe4e6;
  color: #e11d48;
}

.agenda-status--red::before {
  background: #e11d48;
}

.agenda-status--violet .agenda-status__icon {
  background: #ede9fe;
  color: #7c3aed;
}

.agenda-status--violet::before {
  background: #7c3aed;
}

.agenda-alert {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  padding: 12px 14px;
  border-radius: 12px;
  font-weight: 700;
}

.agenda-alert--error {
  border: 1px solid #fb7185;
  background: #fff1f2;
  color: #be123c;
}

.agenda-alert--success {
  border: 1px solid #5eead4;
  background: #f0fdfa;
  color: #0f766e;
}

.agenda-toolbar {
  display: grid;
  gap: 12px;
  align-items: stretch;
  padding: 14px;
  border-radius: 16px;
  overflow: hidden;
}

.agenda-toolbar__top {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 12px;
  align-items: center;
}

.agenda-view-switch {
  display: inline-flex;
  gap: 4px;
  padding: 4px;
  border: 1px solid #c9d8ea;
  border-radius: 12px;
  background: #f1f5f9;
}

.agenda-view-switch button {
  min-width: 72px;
  min-height: 34px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: #43536c;
  font-weight: 800;
}

.agenda-view-switch button.active {
  background: #ffffff;
  color: #1d4ed8;
  box-shadow: 0 8px 20px rgba(37, 99, 235, 0.12);
}

.agenda-date-nav {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  white-space: nowrap;
}

.agenda-date-nav strong {
  overflow: hidden;
  color: var(--agenda-heading);
  font-size: 16px;
  font-weight: 850;
  text-overflow: ellipsis;
}

.agenda-filter-grid {
  display: grid;
  grid-template-columns:
    minmax(280px, 1.35fr) repeat(5, minmax(132px, 0.85fr))
    minmax(108px, auto);
  gap: 12px;
  align-items: stretch;
  min-width: 0;
}

.agenda-search {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  min-width: 0;
  height: 44px;
  min-height: 44px;
  border: 1px solid #c7d4e5;
  border-radius: 12px;
  background: var(--agenda-field);
  box-shadow: none;
  overflow: hidden;
  padding: 0 14px;
  transition:
    border-color 160ms ease,
    box-shadow 160ms ease,
    background 160ms ease;
}

.agenda-search > span {
  position: static;
  flex: 0 0 auto;
  width: 18px;
  height: 18px;
  color: #2563eb;
  pointer-events: none;
}

.agenda-search input,
.agenda-select,
.agenda-form-section input,
.agenda-form-section select,
.agenda-form-section textarea {
  width: 100%;
  min-width: 0;
  height: 44px;
  min-height: 44px;
  border: 1px solid #c7d4e5;
  border-radius: 12px;
  background: var(--agenda-field);
  box-sizing: border-box;
  color: var(--agenda-heading);
  font-size: 14px;
  outline: none;
  transition:
    border-color 160ms ease,
    box-shadow 160ms ease,
    background 160ms ease;
}

.agenda-search input {
  flex: 1 1 auto;
  display: block;
  width: auto;
  height: 100%;
  min-height: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
  padding: 0;
  appearance: none;
  box-shadow: none;
  line-height: normal;
}

.agenda-search input::-webkit-search-cancel-button,
.agenda-search input::-webkit-search-decoration {
  appearance: none;
}

.agenda-search input::placeholder {
  color: #6b7b90;
}

.agenda-select,
.agenda-form-section input,
.agenda-form-section select,
.agenda-form-section textarea {
  padding: 0 12px;
}

.agenda-form-section textarea {
  padding-top: 10px;
  resize: vertical;
}

.agenda-clear-btn {
  width: 100%;
  min-width: 108px;
  height: 44px;
  min-height: 44px;
  align-self: stretch;
  border-color: #a8bad2;
  border-radius: 12px;
  white-space: nowrap;
}

.agenda-select:focus,
.agenda-form-section input:focus,
.agenda-form-section select:focus,
.agenda-form-section textarea:focus {
  border-color: #2563eb;
  box-shadow: inset 0 0 0 1px #2563eb;
  outline: none;
}

.agenda-search:focus-within {
  outline: none;
  border-color: #2563eb;
  box-shadow: inset 0 0 0 1px #2563eb;
}

.agenda-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(300px, 340px);
  gap: 16px;
  margin-top: 16px;
  min-width: 0;
}

.agenda-calendar-card {
  min-width: 0;
  min-height: 620px;
  overflow: hidden;
  border-radius: 18px;
}

.agenda-loading {
  display: grid;
  min-height: 620px;
  place-items: center;
  padding: 30px;
  text-align: center;
}

.agenda-empty-inline {
  display: flex;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid var(--agenda-soft-border);
  padding: 12px 16px;
  color: var(--agenda-muted);
  font-weight: 700;
}

.agenda-empty-inline > span {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  background: #dbeafe;
  color: #2563eb;
}

.agenda-timeboard {
  overflow: auto;
  width: 100%;
  max-height: calc(100vh - 360px);
  min-height: 620px;
  scrollbar-gutter: stable;
}

.agenda-timeboard__header,
.agenda-timeboard__body {
  display: grid;
  grid-template-columns: 68px repeat(var(--agenda-days, 7), minmax(132px, 1fr));
  min-width: max(100%, 860px);
}

.agenda-timeboard__header {
  position: sticky;
  top: 0;
  z-index: 4;
  background: rgba(248, 251, 255, 0.96);
  border-bottom: 1px solid var(--agenda-soft-border);
  backdrop-filter: blur(12px);
}

.agenda-timeboard__corner {
  border-right: 1px solid var(--agenda-soft-border);
}

.agenda-timeboard__day-head {
  display: flex;
  min-height: 62px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 0;
  border-right: 1px solid var(--agenda-soft-border);
  background: transparent;
  color: var(--agenda-heading);
  gap: 4px;
}

.agenda-timeboard__day-head span {
  color: #64748b;
  font-size: 12px;
  font-weight: 800;
}

.agenda-timeboard__day-head strong {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border-radius: 999px;
  font-size: 16px;
}

.agenda-timeboard__day-head.is-today strong {
  background: #2563eb;
  color: #ffffff;
}

.agenda-hours {
  border-right: 1px solid var(--agenda-soft-border);
  background: #f8fbff;
}

.agenda-hour {
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  border-bottom: 1px solid #e2eaf5;
  padding: 6px 8px;
  color: #64748b;
  font-size: 12px;
  font-weight: 700;
}

.agenda-time-column {
  position: relative;
  border-right: 1px solid var(--agenda-soft-border);
  background: repeating-linear-gradient(
      to bottom,
      transparent 0,
      transparent 63px,
      rgba(148, 163, 184, 0.22) 64px
    ),
    linear-gradient(
      to bottom,
      transparent 0,
      transparent 512px,
      rgba(20, 184, 166, 0.06) 512px,
      rgba(20, 184, 166, 0.06) 1152px,
      transparent 1152px
    ),
    #ffffff;
}

.agenda-time-column.is-today {
  background: repeating-linear-gradient(
      to bottom,
      transparent 0,
      transparent 63px,
      rgba(37, 99, 235, 0.22) 64px
    ),
    #f8fbff;
}

.agenda-time-column__create {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 2;
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  border: 1px solid #bfdbfe;
  border-radius: 999px;
  background: #ffffff;
  color: #2563eb;
  opacity: 0;
  transition: opacity 160ms ease;
}

.agenda-time-column:hover .agenda-time-column__create {
  opacity: 1;
}

.agenda-now-line {
  position: absolute;
  right: 0;
  left: 0;
  z-index: 3;
  height: 2px;
  background: #ef4444;
}

.agenda-now-line::before {
  position: absolute;
  top: -4px;
  left: -5px;
  width: 10px;
  height: 10px;
  border-radius: 999px;
  content: '';
  background: #ef4444;
}

.agenda-event {
  display: grid;
  gap: 3px;
  width: calc(100% - 16px);
  border: 1px solid transparent;
  border-left-width: 5px;
  border-radius: 10px;
  padding: 7px 9px;
  text-align: left;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.08);
}

.agenda-time-column > .agenda-event {
  position: absolute;
  left: 8px;
  z-index: 2;
}

.agenda-event strong {
  color: var(--agenda-heading);
  font-size: 13px;
  font-weight: 800;
  line-height: 1.2;
}

.agenda-event small,
.agenda-event__time {
  color: var(--agenda-muted);
  font-size: 11px;
  font-weight: 700;
}

.agenda-event--crm_activity {
  border-color: #93c5fd;
  background: #eff6ff;
}

.agenda-event--lead_contact {
  border-color: #14b8a6;
  background: #ecfdf5;
}

.agenda-event--synced {
  border-color: #5eead4;
  background: #f0fdfa;
}

.agenda-event--high {
  border-color: #f59e0b;
  background: #fffbeb;
}

.agenda-event--critical,
.agenda-event--overdue {
  border-color: #fb7185;
  background: #fff1f2;
}

.agenda-event--done {
  border-color: #94a3b8;
  background: #f1f5f9;
  opacity: 0.8;
}

.agenda-month {
  display: grid;
  grid-template-columns: repeat(7, minmax(120px, 1fr));
  overflow: auto;
  width: 100%;
}

.agenda-month__weekday {
  position: sticky;
  top: 0;
  z-index: 2;
  border-bottom: 1px solid var(--agenda-soft-border);
  border-right: 1px solid var(--agenda-soft-border);
  background: rgba(248, 251, 255, 0.96);
  padding: 12px;
  color: #43536c;
  font-size: 12px;
  font-weight: 800;
  text-align: center;
}

.agenda-month__day {
  display: flex;
  min-height: 138px;
  flex-direction: column;
  gap: 5px;
  border: 0;
  border-right: 1px solid var(--agenda-soft-border);
  border-bottom: 1px solid var(--agenda-soft-border);
  background: #ffffff;
  padding: 9px;
  text-align: left;
}

.agenda-month__day--muted {
  background: #f8fafc;
  color: #94a3b8;
}

.agenda-month__day--today .agenda-month__number {
  background: #2563eb;
  color: #ffffff;
}

.agenda-month__number {
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  border-radius: 999px;
  color: #0f2442;
  font-weight: 800;
}

.agenda-month-event {
  display: block;
  overflow: hidden;
  width: 100%;
  min-height: 24px;
  border-left-width: 4px;
  padding: 4px 6px;
  text-overflow: ellipsis;
  white-space: nowrap;
  box-shadow: none;
}

.agenda-month__more {
  color: #2563eb;
  font-size: 12px;
  font-weight: 800;
}

.agenda-mobile-list {
  display: none;
}

.agenda-side-panel {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 14px;
}

.agenda-panel-card {
  border-radius: 18px;
  padding: 16px;
}

.agenda-panel-card__header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.agenda-panel-card__icon {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  background: #dbeafe;
  color: #2563eb;
}

.agenda-panel-card__icon > span {
  width: 20px;
  height: 20px;
}

.agenda-panel-card__icon--teal {
  background: #ccfbf1;
  color: #0f766e;
}

.agenda-panel-card__header strong {
  font-size: 16px;
  font-weight: 800;
}

.agenda-mini-event {
  display: grid;
  gap: 5px;
  width: 100%;
  margin-top: 8px;
  border: 1px solid #d1def0;
  border-radius: 14px;
  background: #f8fbff;
  padding: 12px;
  text-align: left;
}

.agenda-mini-event strong {
  color: #071327;
  font-weight: 800;
}

.agenda-mini-event small {
  color: #43536c;
}

.agenda-mini-empty {
  border: 1px dashed #c9d8ea;
  border-radius: 14px;
  padding: 14px;
  color: #64748b;
}

.agenda-panel-card--tips ul {
  margin: 0;
  padding-left: 18px;
  color: #43536c;
}

.agenda-priority {
  display: inline-flex;
  width: fit-content;
  border-radius: 999px;
  padding: 3px 8px;
  font-size: 12px;
  font-weight: 800;
}

.agenda-priority--low {
  background: #e0f2fe;
  color: #0369a1;
}

.agenda-priority--normal {
  background: #e2e8f0;
  color: #334155;
}

.agenda-priority--high {
  background: #fef3c7;
  color: #b45309;
}

.agenda-priority--critical {
  background: #ffe4e6;
  color: #be123c;
}

.agenda-drawer-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: flex;
  justify-content: flex-end;
  background: rgba(15, 23, 42, 0.44);
}

.agenda-drawer {
  display: flex;
  width: min(760px, 100vw);
  height: 100vh;
  flex-direction: column;
  background: #f8fbff;
  box-shadow: -24px 0 60px rgba(15, 23, 42, 0.22);
}

.agenda-drawer__header,
.agenda-drawer__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 18px 22px;
  border-bottom: 1px solid #d1def0;
  background: #ffffff;
}

.agenda-drawer__footer {
  justify-content: flex-end;
  border-top: 1px solid #d1def0;
  border-bottom: 0;
}

.agenda-drawer__body {
  display: grid;
  gap: 14px;
  overflow-y: auto;
  padding: 18px 22px;
}

.agenda-form-section {
  display: grid;
  gap: 12px;
  border: 1px solid #d1def0;
  border-radius: 16px;
  background: #ffffff;
  padding: 16px;
}

.agenda-form-section h3 {
  margin: 0;
  color: #071327;
  font-size: 16px;
  font-weight: 800;
}

.agenda-form-section label {
  display: grid;
  gap: 6px;
  color: #0f2442;
  font-size: 13px;
  font-weight: 800;
}

.agenda-form-grid,
.agenda-detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.agenda-detail-grid > div {
  display: grid;
  gap: 4px;
  border: 1px solid #dbe5f2;
  border-radius: 12px;
  background: #f8fbff;
  padding: 10px;
}

.agenda-detail-grid span {
  color: #64748b;
  font-size: 12px;
  font-weight: 800;
}

.agenda-detail-grid strong {
  color: #071327;
}

.agenda-detail-head {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.agenda-detail-source {
  position: static;
  width: fit-content;
  min-height: auto;
}

.agenda-context-card,
.agenda-warning,
.agenda-sync-row {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  border-radius: 14px;
  padding: 12px;
}

.agenda-context-card {
  border: 1px solid #bfdbfe;
  background: #eff6ff;
}

.agenda-context-card > span {
  color: #2563eb;
  font-size: 22px;
}

.agenda-context-card strong {
  color: #071327;
}

.agenda-warning {
  border: 1px solid #f59e0b;
  background: #fffbeb;
  color: #92400e;
  font-weight: 700;
}

.agenda-sync-row {
  align-items: center;
  justify-content: space-between;
  border: 1px solid #ccfbf1;
  background: #f0fdfa;
}

.agenda-toggle {
  display: inline-flex !important;
  grid-auto-flow: column;
  align-items: center;
  gap: 8px !important;
  white-space: nowrap;
}

.agenda-toggle input {
  width: 18px;
  min-height: 18px;
}

.agenda-google-links button {
  min-height: 36px;
  padding: 0 12px;
}

.agenda-suggestion {
  display: grid;
  justify-items: flex-start;
  min-height: auto;
  padding: 10px 12px;
  text-align: left;
}

.agenda-suggestion span {
  color: #43536c;
  font-size: 12px;
}

.is-spinning {
  animation: agenda-spin 900ms linear infinite;
}

@keyframes agenda-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>

<style>
/* Global dark-mode overrides for Agenda. The dashboard theme applies .dark on <body>, so these cannot live inside scoped CSS. */
.dark .crm-agenda__scroll {
  background: radial-gradient(
      circle at top left,
      rgba(45, 212, 191, 0.12),
      transparent 32%
    ),
    linear-gradient(180deg, #07111f 0%, #0b1320 100%);
  color: #e5edf7;
}

.dark .crm-agenda {
  --agenda-border: #24364f;
  --agenda-soft-border: #24364f;
  --agenda-card: rgba(15, 23, 42, 0.92);
  --agenda-field: #111c2d;
  --agenda-heading: #f8fbff;
  --agenda-muted: #a9b8cc;
}

.dark .agenda-hero,
.dark .agenda-toolbar,
.dark .agenda-calendar-card,
.dark .agenda-panel-card,
.dark .agenda-status,
.dark .agenda-form-section,
.dark .agenda-drawer__header,
.dark .agenda-drawer__footer {
  border-color: #24364f;
  background: rgba(15, 23, 42, 0.92);
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.24);
}

.dark .crm-agenda .agenda-hero,
.dark .crm-agenda .agenda-toolbar,
.dark .crm-agenda .agenda-calendar-card,
.dark .crm-agenda .agenda-panel-card,
.dark .crm-agenda .agenda-status {
  border-color: #2a3b52 !important;
  background: linear-gradient(
    180deg,
    rgba(15, 23, 42, 0.98),
    rgba(11, 19, 32, 0.96)
  ) !important;
  color: #e5edf7;
}

.dark .crm-agenda .agenda-status {
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.03),
    0 18px 44px rgba(0, 0, 0, 0.2);
}

.dark .agenda-drawer {
  background: #0b1320;
}

.dark .agenda-hero h1,
.dark .agenda-drawer h2,
.dark .agenda-form-section h3,
.dark .agenda-status strong,
.dark .agenda-mini-event strong,
.dark .agenda-event strong,
.dark .agenda-timeboard__day-head,
.dark .agenda-detail-grid strong,
.dark .agenda-context-card strong {
  color: #f8fbff;
}

.dark .agenda-hero p,
.dark .agenda-panel-card p,
.dark .agenda-status p,
.dark .agenda-form-section p,
.dark .agenda-mini-event small,
.dark .agenda-event small,
.dark .agenda-event__time,
.dark .agenda-suggestion span,
.dark .agenda-panel-card--tips ul,
.dark .agenda-detail-grid span {
  color: #a9b8cc;
}

.dark .agenda-btn,
.dark .agenda-icon-btn,
.dark .agenda-google-links button,
.dark .agenda-suggestion,
.dark .agenda-search,
.dark .agenda-select,
.dark .agenda-form-section input,
.dark .agenda-form-section select,
.dark .agenda-form-section textarea {
  border-color: #334964;
  background: #111c2d;
  color: #e5edf7;
}

.dark .agenda-search input::placeholder {
  color: #8495ab;
}

.dark .agenda-search > span {
  color: #60a5fa;
}

.dark .agenda-select:focus,
.dark .agenda-form-section input:focus,
.dark .agenda-form-section select:focus,
.dark .agenda-form-section textarea:focus {
  border-color: #60a5fa;
  box-shadow: inset 0 0 0 1px #60a5fa;
}

.dark .agenda-search input {
  background: transparent;
  color: #e5edf7;
}

.dark .agenda-search:focus-within {
  border-color: #60a5fa;
  box-shadow: inset 0 0 0 1px #60a5fa;
}

.dark .agenda-clear-btn {
  border-color: #49617f;
  background: #132238;
  color: #edf5ff;
}

.dark .agenda-alert--error {
  border-color: rgba(251, 113, 133, 0.72);
  background: rgba(127, 29, 29, 0.28);
  color: #fecdd3;
}

.dark .agenda-alert--success {
  border-color: rgba(45, 212, 191, 0.58);
  background: rgba(15, 118, 110, 0.18);
  color: #99f6e4;
}

.dark .agenda-btn--primary {
  border-color: #60a5fa;
  background: linear-gradient(135deg, #2563eb, #4f46e5);
  color: #ffffff;
}

.dark .agenda-btn--google {
  border-color: #2dd4bf;
  background: linear-gradient(135deg, rgba(20, 184, 166, 0.92), #0f766e);
  color: #ecfeff;
}

.dark .agenda-btn--success {
  border-color: #2dd4bf;
  background: rgba(20, 184, 166, 0.18);
  color: #99f6e4;
}

.dark .agenda-btn--danger {
  border-color: #fb7185;
  background: rgba(225, 29, 72, 0.2);
  color: #fecdd3;
}

.dark .agenda-hero__icon {
  background: linear-gradient(
    135deg,
    rgba(37, 99, 235, 0.35),
    rgba(20, 184, 166, 0.3)
  );
  color: #93c5fd;
}

.dark .agenda-status--google .agenda-status__icon,
.dark .agenda-panel-card__icon--teal {
  background: rgba(20, 184, 166, 0.18);
  color: #5eead4;
}

.dark .agenda-status--blue .agenda-status__icon,
.dark .agenda-panel-card__icon {
  background: rgba(37, 99, 235, 0.22);
  color: #93c5fd;
}

.dark .agenda-status--teal .agenda-status__icon {
  background: rgba(20, 184, 166, 0.18);
  color: #5eead4;
}

.dark .agenda-status--amber .agenda-status__icon {
  background: rgba(245, 158, 11, 0.2);
  color: #fbbf24;
}

.dark .agenda-status--red .agenda-status__icon {
  background: rgba(225, 29, 72, 0.2);
  color: #fb7185;
}

.dark .agenda-status--violet .agenda-status__icon {
  background: rgba(124, 58, 237, 0.22);
  color: #c4b5fd;
}

.dark .agenda-view-switch,
.dark .agenda-hours,
.dark .agenda-empty-inline,
.dark .agenda-timeboard__header,
.dark .agenda-month__weekday,
.dark .agenda-detail-grid > div {
  border-color: #24364f;
  background: #101827;
}

.dark .agenda-date-nav strong,
.dark .agenda-month__number,
.dark .agenda-panel-card__header strong {
  color: #f8fbff;
}

.dark .agenda-view-switch button {
  color: #a9b8cc;
}

.dark .agenda-view-switch button.active {
  background: #1e293b;
  color: #93c5fd;
}

.dark .agenda-time-column,
.dark .agenda-month__day {
  border-color: #24364f;
  background: #0f172a;
}

.dark .agenda-timeboard__body,
.dark .agenda-month {
  background: #0f172a;
}

.dark .agenda-hour {
  border-color: #24364f;
  color: #8393a9;
}

.dark .agenda-time-column.is-today,
.dark .agenda-month__day--today {
  background: #102039;
}

.dark .agenda-time-column__create {
  border-color: #334964;
  background: #111c2d;
  color: #93c5fd;
}

.dark .agenda-event--crm_activity {
  background: rgba(37, 99, 235, 0.16);
}

.dark .agenda-event--lead_contact,
.dark .agenda-event--synced {
  background: rgba(20, 184, 166, 0.16);
}

.dark .agenda-event--high {
  background: rgba(245, 158, 11, 0.16);
}

.dark .agenda-event--critical,
.dark .agenda-event--overdue {
  background: rgba(225, 29, 72, 0.16);
}

.dark .agenda-event--done,
.dark .agenda-mini-event,
.dark .agenda-month__day--muted {
  background: #111c2d;
}

.dark .agenda-mini-empty {
  border-color: #334964;
  color: #a9b8cc;
}

.dark .agenda-context-card {
  border-color: #1d4ed8;
  background: rgba(37, 99, 235, 0.12);
}

.dark .agenda-sync-row {
  border-color: #0f766e;
  background: rgba(15, 118, 110, 0.14);
}
</style>

<style scoped>
@media (max-width: 1500px) {
  .agenda-status-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .agenda-layout {
    grid-template-columns: 1fr;
  }

  .agenda-filter-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .crm-agenda__scroll {
    padding: 14px;
  }

  .agenda-hero,
  .agenda-hero__title,
  .agenda-hero__actions,
  .agenda-toolbar__top,
  .agenda-date-nav,
  .agenda-drawer__footer {
    align-items: stretch;
  }

  .agenda-hero {
    grid-template-columns: 1fr;
  }

  .agenda-hero__title,
  .agenda-hero__actions,
  .agenda-date-nav,
  .agenda-drawer__footer {
    flex-direction: column;
  }

  .agenda-toolbar__top {
    grid-template-columns: 1fr;
  }

  .agenda-view-switch {
    width: 100%;
  }

  .agenda-view-switch button {
    flex: 1 1 0;
    min-width: 0;
  }

  .agenda-status-grid,
  .agenda-filter-grid,
  .agenda-form-grid,
  .agenda-detail-grid {
    grid-template-columns: 1fr;
  }

  .agenda-timeboard,
  .agenda-month {
    display: none;
  }

  .agenda-mobile-list {
    display: grid;
    gap: 12px;
    padding: 12px;
  }

  .agenda-mobile-day {
    display: grid;
    gap: 8px;
  }

  .agenda-mobile-day header {
    color: #43536c;
    font-weight: 800;
  }

  .agenda-mobile-day .agenda-event {
    position: static;
    width: 100%;
  }

  .agenda-mobile-empty {
    min-height: 42px;
    border: 1px dashed #c9d8ea;
    border-radius: 12px;
    background: transparent;
    color: #2563eb;
    font-weight: 800;
  }

  .agenda-drawer {
    width: 100vw;
  }
}
</style>

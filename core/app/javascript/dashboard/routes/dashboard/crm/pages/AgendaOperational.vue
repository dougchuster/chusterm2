<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import AgentsAPI from '../../../../api/agents';
import ContactAPI from '../../../../api/contacts';
import CrmAPI from '../../../../api/crm';
import CRMConfirmDialog from 'dashboard/components/crm/CRMConfirmDialog.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsDrawer,
  DsInput,
  DsSelect,
} from 'dashboard/design-system/components';
import { CalendarPageTemplate } from 'dashboard/design-system/templates';
import { crmConversationUrl } from 'dashboard/helper/conversationIdentifier';

const route = useRoute();
const router = useRouter();
const events = ref([]);
const deals = ref([]);
const contacts = ref([]);
const agents = ref([]);
const loading = ref(true);
const saving = ref(false);
const syncing = ref(false);
const suggesting = ref(false);
const error = ref('');
const success = ref('');
const drawerOpen = ref(false);
const drawerMode = ref('create');
const selectedEvent = ref(null);
const suggestions = ref([]);
const confirmDialog = ref(null);
let searchTimer;

const filters = reactive({
  view: 'week',
  cursor: toDateInput(new Date()),
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

const google = ref({ connected: false, email: '', oauth_configured: false });
const viewOptions = [
  { value: 'day', label: 'Dia' },
  { value: 'week', label: 'Semana' },
  { value: 'month', label: 'Mês' },
];
const sourceOptions = [
  { value: '', label: 'Todos os eventos' },
  { value: 'crm_activity', label: 'Atividades do CRM' },
  { value: 'lead_contact', label: 'Entrada de lead' },
];
const priorityOptions = [
  { value: '', label: 'Todas as prioridades' },
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
];
const syncOptions = [
  { value: '', label: 'Qualquer sincronização' },
  { value: 'synced', label: 'Sincronizados' },
  { value: 'unsynced', label: 'Sem Google' },
];
const kindOptions = [
  { value: 'reuniao', label: 'Reunião' },
  { value: 'follow_up', label: 'Follow-up' },
  { value: 'ligacao', label: 'Ligação' },
  { value: 'retorno_cliente', label: 'Retorno ao cliente' },
  { value: 'analise_documental', label: 'Análise documental' },
  { value: 'solicitacao_documentos', label: 'Solicitação de documentos' },
  { value: 'revisao_juridica', label: 'Revisão jurídica' },
];

const cursorDate = computed(() => parseDate(filters.cursor));
const range = computed(() => rangeFor(filters.view, cursorDate.value));
const visibleDays = computed(() => daysBetween(range.value.from, range.value.to));
const sortedEvents = computed(() =>
  [...events.value].sort((a, b) => new Date(a.start_at) - new Date(b.start_at))
);
const eventsByDay = computed(() => {
  const grouped = new Map(visibleDays.value.map(day => [dayKey(day), []]));
  sortedEvents.value.forEach(event => {
    grouped.get(dayKey(new Date(event.start_at)))?.push(event);
  });
  return grouped;
});
const upcoming = computed(() =>
  sortedEvents.value
    .filter(event => event.status !== 'completed' && new Date(event.start_at) >= new Date())
    .slice(0, 8)
);
const stats = computed(() => ({
  total: sortedEvents.value.length,
  today: sortedEvents.value.filter(event => sameDay(new Date(event.start_at), new Date())).length,
  overdue: sortedEvents.value.filter(event => event.status === 'overdue').length,
  unsynced: sortedEvents.value.filter(
    event => event.source === 'crm_activity' && !event.activity?.external_calendar_event_id
  ).length,
}));
const titleRange = computed(() => {
  const start = range.value.from.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' });
  const end = range.value.to.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
  return filters.view === 'day' ? end : `${start} – ${end}`;
});
const drawerTitle = computed(() => {
  if (drawerMode.value === 'detail') return selectedEvent.value?.title || 'Compromisso';
  return drawerMode.value === 'edit' ? 'Editar compromisso' : 'Novo compromisso';
});
const canSave = computed(() => form.title.trim().length > 2 && form.due_at);
const agentOptions = computed(() => [
  { value: '', label: 'Qualquer responsável' },
  ...agents.value.map(agent => ({
    value: String(agent.id),
    label: agent.name || agent.email || `Agente ${agent.id}`,
  })),
]);
const formAgentOptions = computed(() => [
  { value: '', label: 'Sem responsável' },
  ...agentOptions.value.slice(1),
]);
const dealOptions = computed(() => [
  { value: '', label: 'Sem negócio vinculado' },
  ...deals.value.map(deal => ({
    value: String(deal.id),
    label: deal.title || deal.contact?.name || `Negócio ${deal.id}`,
  })),
]);
const contactOptions = computed(() => [
  { value: '', label: 'Sem contato vinculado' },
  ...contacts.value.map(contact => ({
    value: String(contact.id),
    label: contact.name || contact.email || contact.phone_number || `Contato ${contact.id}`,
  })),
]);

function extract(response) {
  const responsePayload = response?.data ?? response;
  if (Array.isArray(responsePayload)) return responsePayload;
  if (Array.isArray(responsePayload?.data)) return responsePayload.data;
  if (Array.isArray(responsePayload?.payload)) return responsePayload.payload;
  return [];
}

function activityStatus(activity) {
  if (activity.completed_at) return 'completed';
  if (activity.is_overdue) return 'overdue';
  return 'scheduled';
}

function toEvent(activity) {
  const start = activity.due_at;
  return {
    id: activity.id,
    activity_id: activity.id,
    source: 'crm_activity',
    title: activity.title,
    description: activity.description,
    kind: activity.kind,
    priority: activity.priority || 'normal',
    status: activityStatus(activity),
    start_at: start,
    end_at: new Date(new Date(start).getTime() + 3600000).toISOString(),
    activity,
    contact: activity.contact,
    deal: activity.deal,
    assignee: activity.assignee || activity.owner,
    links: {
      google: activity.external_calendar_link || activity.calendar_links?.google || '',
      meet: activity.meeting_url || '',
      deal: activity.crm_deal_id
        ? `/app/accounts/${route.params.accountId}/crm/deals/${activity.crm_deal_id}`
        : '',
      conversation: crmConversationUrl({
        accountId: route.params.accountId,
        record: activity,
      }),
    },
  };
}

async function loadAgenda() {
  loading.value = true;
  error.value = '';
  const params = {
    from: range.value.from.toISOString(),
    to: range.value.to.toISOString(),
    q: filters.query.trim() || undefined,
    source: filters.source || undefined,
    priority: filters.priority || undefined,
    assignee_id: filters.assignee_id || undefined,
    sync_status: filters.sync_status || undefined,
  };
  try {
    const { data } = await CrmAPI.getAgendaEvents(params);
    events.value = Array.isArray(data) ? data : [];
  } catch (requestError) {
    if (requestError?.response?.status !== 404) {
      error.value =
        requestError?.response?.data?.error || 'Não foi possível carregar a agenda.';
    } else {
      try {
        const response = await CrmAPI.getActivities({ ...params, status: 'all' });
        events.value = extract(response)
          .filter(activity => activity.due_at)
          .map(toEvent)
          .filter(event => {
            if (filters.source === 'lead_contact') return false;
            if (filters.sync_status === 'synced')
              return Boolean(event.activity?.external_calendar_event_id);
            if (filters.sync_status === 'unsynced')
              return !event.activity?.external_calendar_event_id;
            return true;
          });
      } catch {
        error.value = 'Não foi possível carregar a agenda.';
      }
    }
  } finally {
    loading.value = false;
  }
}

async function loadSupport() {
  const results = await Promise.allSettled([
    CrmAPI.getDeals({ per_page: 200 }),
    AgentsAPI.get(),
    ContactAPI.get(1, 'name'),
    CrmAPI.getGoogleWorkspaceAuthorization(),
  ]);
  deals.value = results[0].status === 'fulfilled' ? extract(results[0].value) : [];
  agents.value = results[1].status === 'fulfilled' ? extract(results[1].value) : [];
  contacts.value = results[2].status === 'fulfilled' ? extract(results[2].value) : [];
  if (results[3].status === 'fulfilled') {
    const data = results[3].value.data || {};
    google.value = {
      connected: Boolean(data.connected),
      email: data.email || '',
      oauth_configured: Boolean(data.oauth_configured),
    };
  }
}

function resetForm() {
  Object.assign(form, {
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
  suggestions.value = [];
}

function createEvent(day = new Date()) {
  resetForm();
  drawerMode.value = 'create';
  const due = new Date(day);
  due.setHours(Math.max(9, new Date().getHours() + 1), 0, 0, 0);
  form.due_at = toDateTimeInput(due);
  form.reminder_at = toDateTimeInput(new Date(due.getTime() - 1800000));
  drawerOpen.value = true;
}

function showEvent(event) {
  selectedEvent.value = event;
  drawerMode.value = 'detail';
  drawerOpen.value = true;
}

function editEvent(event = selectedEvent.value) {
  const activity = event?.activity || event;
  if (!activity?.id) return;
  drawerMode.value = 'edit';
  selectedEvent.value = event;
  Object.assign(form, {
    id: activity.id,
    title: activity.title || '',
    description: activity.description || '',
    kind: activity.kind || 'reuniao',
    priority: activity.priority || 'normal',
    due_at: toDateTimeInput(activity.due_at || event.start_at),
    reminder_at: toDateTimeInput(activity.reminder_at),
    crm_deal_id: String(activity.crm_deal_id || event.deal?.id || ''),
    contact_id: String(activity.contact_id || event.contact?.id || ''),
    conversation_id: activity.conversation_id || event.conversation?.id || '',
    assignee_id: String(activity.assignee_id || event.assignee?.id || ''),
    sync_google_calendar: activity.kind === 'reuniao',
  });
}

function closeDrawer() {
  drawerOpen.value = false;
  selectedEvent.value = null;
  resetForm();
}

function payload() {
  return {
    title: form.title.trim(),
    description: form.description.trim() || null,
    kind: form.kind,
    priority: form.priority,
    due_at: form.due_at || null,
    reminder_at: form.reminder_at || null,
    crm_deal_id: Number(form.crm_deal_id) || null,
    contact_id: Number(form.contact_id) || null,
    conversation_id: Number(form.conversation_id) || null,
    assignee_id: Number(form.assignee_id) || null,
  };
}

async function saveEvent() {
  if (!canSave.value) return;
  saving.value = true;
  error.value = '';
  try {
    const response =
      drawerMode.value === 'edit'
        ? await CrmAPI.updateActivity(form.id, payload())
        : await CrmAPI.createActivity(payload());
    const activity = response.data;
    if (form.sync_google_calendar && activity?.id && activity.kind === 'reuniao') {
      try {
        await CrmAPI.syncActivityGoogleCalendar(activity.id);
        success.value = 'Compromisso salvo e sincronizado.';
      } catch {
        success.value = 'Compromisso salvo. A sincronização com Google ficou pendente.';
      }
    } else {
      success.value = 'Compromisso salvo.';
    }
    closeDrawer();
    await loadAgenda();
  } catch (requestError) {
    error.value =
      requestError?.response?.data?.error || 'Não foi possível salvar o compromisso.';
  } finally {
    saving.value = false;
  }
}

async function completeEvent() {
  if (!selectedEvent.value?.activity_id) return;
  saving.value = true;
  try {
    await CrmAPI.completeActivity(
      selectedEvent.value.activity_id,
      'Concluída pela Agenda CRM'
    );
    closeDrawer();
    await loadAgenda();
  } finally {
    saving.value = false;
  }
}

async function deleteEvent() {
  if (!selectedEvent.value?.activity_id) return;
  const confirmed = await confirmDialog.value?.confirm({
    title: 'Excluir compromisso',
    description: 'Esta ação remove o compromisso da agenda do CRM.',
    confirmLabel: 'Excluir',
  });
  if (!confirmed) return;
  saving.value = true;
  try {
    await CrmAPI.deleteActivity(selectedEvent.value.activity_id);
    closeDrawer();
    await loadAgenda();
  } finally {
    saving.value = false;
  }
}

async function suggestSchedule() {
  suggesting.value = true;
  suggestions.value = [];
  try {
    const { data } = await CrmAPI.suggestActivitySchedule({
      ...payload(),
      from: range.value.from.toISOString(),
      to: range.value.to.toISOString(),
      duration_minutes: 60,
    });
    suggestions.value = Array.isArray(data.suggestions) ? data.suggestions : [];
  } catch {
    error.value = 'Não foi possível sugerir horários.';
  } finally {
    suggesting.value = false;
  }
}

function useSuggestion(slot) {
  form.due_at = toDateTimeInput(slot.starts_at);
  form.reminder_at = toDateTimeInput(new Date(new Date(slot.starts_at) - 1800000));
  suggestions.value = [];
}

async function connectGoogle() {
  syncing.value = true;
  try {
    const { data } = await CrmAPI.authorizeGoogleWorkspace(
      `/app/accounts/${route.params.accountId}/crm/agenda`
    );
    if (data?.url) window.location.href = data.url;
  } catch {
    error.value = 'Não foi possível iniciar a conexão com o Google.';
  } finally {
    syncing.value = false;
  }
}

async function syncGoogle() {
  syncing.value = true;
  try {
    const { data } = await CrmAPI.importActivitiesGoogleCalendar({
      from: range.value.from.toISOString(),
      to: range.value.to.toISOString(),
    });
    success.value = `${data.imported || 0} importados e ${data.updated || 0} atualizados.`;
    await loadAgenda();
  } catch (requestError) {
    if (requestError?.response?.data?.authorization_required) {
      await connectGoogle();
      return;
    }
    error.value = 'Não foi possível sincronizar o Google Calendar.';
  } finally {
    syncing.value = false;
  }
}

function moveCursor(amount) {
  const next = new Date(cursorDate.value);
  if (filters.view === 'day') next.setDate(next.getDate() + amount);
  if (filters.view === 'week') next.setDate(next.getDate() + amount * 7);
  if (filters.view === 'month') next.setMonth(next.getMonth() + amount);
  filters.cursor = toDateInput(next);
}

function clearFilters() {
  Object.assign(filters, {
    ...filters,
    query: '',
    source: '',
    priority: '',
    assignee_id: '',
    sync_status: '',
  });
}

function openLink(kind) {
  const url = selectedEvent.value?.links?.[kind];
  if (!url) return;
  if (kind === 'deal' || kind === 'conversation') router.push(url);
  else window.open(url, '_blank', 'noopener,noreferrer');
}

function parseDate(value) {
  const [year, month, day] = String(value).split('-').map(Number);
  return new Date(year, month - 1, day);
}
function startOfDay(date) {
  const result = new Date(date);
  result.setHours(0, 0, 0, 0);
  return result;
}
function endOfDay(date) {
  const result = new Date(date);
  result.setHours(23, 59, 59, 999);
  return result;
}
function startOfWeek(date) {
  const result = startOfDay(date);
  result.setDate(result.getDate() - ((result.getDay() + 6) % 7));
  return result;
}
function endOfWeek(date) {
  const result = startOfWeek(date);
  result.setDate(result.getDate() + 6);
  return endOfDay(result);
}
function rangeFor(view, date) {
  if (view === 'day') return { from: startOfDay(date), to: endOfDay(date) };
  if (view === 'month') {
    const first = new Date(date.getFullYear(), date.getMonth(), 1);
    const last = new Date(date.getFullYear(), date.getMonth() + 1, 0);
    return { from: startOfWeek(first), to: endOfWeek(last) };
  }
  return { from: startOfWeek(date), to: endOfWeek(date) };
}
function daysBetween(from, to) {
  const days = [];
  const current = startOfDay(from);
  while (current <= to) {
    days.push(new Date(current));
    current.setDate(current.getDate() + 1);
  }
  return days;
}
function dayKey(date) {
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}
function sameDay(first, second) {
  return dayKey(first) === dayKey(second);
}
function toDateInput(value) {
  const date = new Date(value);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}
function toDateTimeInput(value) {
  if (!value) return '';
  const date = new Date(value);
  return `${toDateInput(date)}T${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}
function formatDay(date) {
  return date.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit' });
}
function formatDateTime(value) {
  return new Date(value).toLocaleString('pt-BR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}
function badgeVariant(event) {
  if (event.status === 'overdue') return 'danger';
  if (event.status === 'completed') return 'success';
  if (event.priority === 'critica' || event.priority === 'alta') return 'warning';
  return event.source === 'lead_contact' ? 'info' : 'neutral';
}

watch(
  () => [
    filters.view,
    filters.cursor,
    filters.source,
    filters.priority,
    filters.assignee_id,
    filters.sync_status,
  ],
  loadAgenda
);
watch(
  () => filters.query,
  () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(loadAgenda, 350);
  }
);
onMounted(async () => {
  await Promise.all([loadSupport(), loadAgenda()]);
});
onBeforeUnmount(() => window.clearTimeout(searchTimer));
</script>

<template>
  <CalendarPageTemplate
    title="Agenda"
    :breadcrumbs="[{ label: 'CRM' }, { label: 'Agenda' }]"
    :loading="loading"
    :empty="!loading && !events.length"
    empty-title="Nenhum compromisso neste período."
    empty-action-label="Criar compromisso"
    @empty-action="createEvent()"
  >
    <template #actions>
      <DsButton
        v-if="google.connected"
        variant="secondary"
        icon="i-lucide-refresh-cw"
        label="Sincronizar"
        :loading="syncing"
        @click="syncGoogle"
      />
      <DsButton
        v-else
        variant="secondary"
        icon="i-lucide-calendar-sync"
        label="Conectar Google"
        :loading="syncing"
        @click="connectGoogle"
      />
      <DsButton
        variant="primary"
        icon="i-lucide-plus"
        label="Novo compromisso"
        @click="createEvent()"
      />
    </template>

    <template #toolbar>
      <DsInput
        v-model="filters.query"
        label="Buscar na agenda"
        hide-label
        placeholder="Buscar compromisso"
        class="min-w-60 flex-1"
      >
        <template #prefix><span class="i-lucide-search size-4" aria-hidden="true" /></template>
      </DsInput>
      <DsSelect v-model="filters.source" label="Origem" hide-label :options="sourceOptions" class="w-48" />
      <DsSelect v-model="filters.priority" label="Prioridade" hide-label :options="priorityOptions" class="w-44" />
      <DsSelect v-model="filters.assignee_id" label="Responsável" hide-label :options="agentOptions" class="w-48" />
      <DsSelect v-model="filters.sync_status" label="Sincronização" hide-label :options="syncOptions" class="w-48" />
      <DsButton variant="ghost" icon="i-lucide-filter-x" aria-label="Limpar filtros" @click="clearFilters" />
    </template>

    <div class="flex min-w-0 flex-col gap-4">
      <div class="grid grid-cols-2 gap-2 xl:grid-cols-4">
        <DsCard
          v-for="metric in [
            ['No período', stats.total],
            ['Hoje', stats.today],
            ['Atrasados', stats.overdue],
            ['Sem Google', stats.unsynced],
          ]"
          :key="metric[0]"
          padding="sm"
        >
          <p class="m-0 text-ui-caption text-ui-text-muted">{{ metric[0] }}</p>
          <strong class="mt-1 block text-ui-heading tabular-nums">{{ metric[1] }}</strong>
        </DsCard>
      </div>

      <DsCard padding="none" class="overflow-hidden">
        <div class="flex flex-wrap items-center justify-between gap-2 border-b border-ui-border-subtle p-3">
          <div class="flex items-center gap-1">
            <DsButton variant="ghost" icon="i-lucide-chevron-left" aria-label="Período anterior" @click="moveCursor(-1)" />
            <DsButton variant="secondary" size="sm" label="Hoje" @click="filters.cursor = toDateInput(new Date())" />
            <DsButton variant="ghost" icon="i-lucide-chevron-right" aria-label="Próximo período" @click="moveCursor(1)" />
          </div>
          <h2 class="m-0 text-ui-body font-semibold">{{ titleRange }}</h2>
          <DsSelect v-model="filters.view" label="Visualização" hide-label :options="viewOptions" class="w-36" />
        </div>
        <div
          class="grid min-w-[44rem] divide-x divide-ui-border-subtle"
          :class="filters.view === 'month' ? 'grid-cols-7' : filters.view === 'week' ? 'grid-cols-7' : 'grid-cols-1'"
        >
          <div
            v-for="day in visibleDays"
            :key="dayKey(day)"
            class="min-h-32 min-w-0 bg-ui-surface p-2 text-left text-ui-text"
            :class="{ 'bg-ui-brand-soft': sameDay(day, new Date()) }"
            @dblclick="createEvent(day)"
          >
            <span class="mb-2 block text-ui-caption font-semibold text-ui-text-muted">{{ formatDay(day) }}</span>
            <span class="flex flex-col gap-1">
              <button
                v-for="event in (eventsByDay.get(dayKey(day)) || []).slice(0, filters.view === 'month' ? 3 : 8)"
                :key="`${event.source}-${event.id}`"
                type="button"
                class="w-full rounded-ui-control border border-ui-border-subtle bg-ui-sunken px-2 py-1.5 text-left hover:border-ui-border-focus"
                @click.stop="showEvent(event)"
              >
                <span class="block truncate text-ui-caption font-medium">{{ formatDateTime(event.start_at) }} · {{ event.title }}</span>
              </button>
              <span v-if="(eventsByDay.get(dayKey(day)) || []).length > (filters.view === 'month' ? 3 : 8)" class="text-ui-caption text-ui-text-muted">
                +{{ (eventsByDay.get(dayKey(day)) || []).length - (filters.view === 'month' ? 3 : 8) }} outros
              </span>
            </span>
          </div>
        </div>
      </DsCard>
    </div>

    <template #mobile>
      <div class="flex flex-col gap-3">
        <div class="flex items-center justify-between gap-2">
          <DsButton variant="ghost" icon="i-lucide-chevron-left" aria-label="Período anterior" @click="moveCursor(-1)" />
          <strong class="text-ui-body">{{ titleRange }}</strong>
          <DsButton variant="ghost" icon="i-lucide-chevron-right" aria-label="Próximo período" @click="moveCursor(1)" />
        </div>
        <DsCard v-for="event in sortedEvents" :key="`${event.source}-${event.id}`" interactive padding="sm" @click="showEvent(event)">
          <div class="flex items-start justify-between gap-2">
            <div class="min-w-0">
              <p class="m-0 truncate text-ui-body font-medium">{{ event.title }}</p>
              <p class="mb-0 mt-1 text-ui-caption text-ui-text-muted">{{ formatDateTime(event.start_at) }}</p>
            </div>
            <DsBadge :label="event.kind || 'Lead'" :variant="badgeVariant(event)" />
          </div>
        </DsCard>
      </div>
    </template>

    <template #agenda>
      <DsCard>
        <div class="mb-3 flex items-center justify-between">
          <h2 class="m-0 text-ui-body font-semibold">Próximos compromissos</h2>
          <DsBadge :label="upcoming.length" variant="neutral" />
        </div>
        <div class="flex flex-col divide-y divide-ui-border-subtle">
          <button
            v-for="event in upcoming"
            :key="`${event.source}-${event.id}`"
            type="button"
            class="border-0 bg-transparent py-3 text-left text-ui-text hover:text-ui-brand"
            @click="showEvent(event)"
          >
            <span class="block text-ui-body-sm font-medium">{{ event.title }}</span>
            <span class="mt-1 block text-ui-caption text-ui-text-muted">{{ formatDateTime(event.start_at) }}</span>
          </button>
          <p v-if="!upcoming.length" class="my-3 text-ui-body-sm text-ui-text-muted">Nenhum compromisso futuro.</p>
        </div>
      </DsCard>
    </template>
  </CalendarPageTemplate>

  <DsDrawer :open="drawerOpen" :title="drawerTitle" :loading="saving" @close="closeDrawer">
    <div v-if="drawerMode === 'detail' && selectedEvent" class="flex flex-col gap-4">
      <div class="flex flex-wrap gap-2">
        <DsBadge :label="selectedEvent.kind || 'Entrada de lead'" :variant="badgeVariant(selectedEvent)" />
        <DsBadge :label="selectedEvent.priority || 'normal'" variant="neutral" />
      </div>
      <dl class="grid gap-3 text-ui-body-sm">
        <div><dt class="text-ui-caption text-ui-text-muted">Data e hora</dt><dd class="m-0 font-medium">{{ formatDateTime(selectedEvent.start_at) }}</dd></div>
        <div v-if="selectedEvent.description"><dt class="text-ui-caption text-ui-text-muted">Descrição</dt><dd class="m-0 whitespace-pre-wrap">{{ selectedEvent.description }}</dd></div>
        <div v-if="selectedEvent.contact"><dt class="text-ui-caption text-ui-text-muted">Contato</dt><dd class="m-0">{{ selectedEvent.contact.name }}</dd></div>
      </dl>
      <div class="flex flex-wrap gap-2">
        <DsButton v-if="selectedEvent.links?.deal" variant="secondary" label="Abrir negócio" icon="i-lucide-briefcase" @click="openLink('deal')" />
        <DsButton v-if="selectedEvent.links?.conversation" variant="secondary" label="Abrir conversa" icon="i-lucide-message-circle" @click="openLink('conversation')" />
        <DsButton v-if="selectedEvent.links?.meet" variant="secondary" label="Abrir Meet" icon="i-lucide-video" @click="openLink('meet')" />
      </div>
    </div>

    <form v-else id="agenda-event-form" class="flex flex-col gap-4" @submit.prevent="saveEvent">
      <DsInput v-model="form.title" label="Título" placeholder="Ex.: Retorno sobre documentos" required />
      <label class="flex flex-col gap-1 text-ui-label font-medium">
        Descrição
        <textarea v-model="form.description" rows="4" class="rounded-ui-control border border-ui-border bg-ui-surface px-3 py-2 text-ui-body text-ui-text focus:border-ui-border-focus focus:outline-none" />
      </label>
      <div class="grid gap-3 sm:grid-cols-2">
        <DsSelect v-model="form.kind" label="Tipo" :options="kindOptions" />
        <DsSelect v-model="form.priority" label="Prioridade" :options="priorityOptions.slice(1)" />
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 text-ui-label font-medium">Data e hora<input v-model="form.due_at" type="datetime-local" required class="h-10 rounded-ui-control border border-ui-border bg-ui-surface px-3 text-ui-body text-ui-text focus:border-ui-border-focus focus:outline-none" /></label>
        <label class="flex flex-col gap-1 text-ui-label font-medium">Lembrete<input v-model="form.reminder_at" type="datetime-local" class="h-10 rounded-ui-control border border-ui-border bg-ui-surface px-3 text-ui-body text-ui-text focus:border-ui-border-focus focus:outline-none" /></label>
      </div>
      <DsSelect v-model="form.assignee_id" label="Responsável" :options="formAgentOptions" />
      <DsSelect v-model="form.contact_id" label="Contato" :options="contactOptions" />
      <DsSelect v-model="form.crm_deal_id" label="Negócio" :options="dealOptions" />
      <label class="flex items-center gap-2 text-ui-body-sm"><input v-model="form.sync_google_calendar" type="checkbox" class="size-4 accent-ui-brand" /> Sincronizar reunião com Google Calendar</label>
      <DsButton variant="secondary" icon="i-lucide-sparkles" label="Sugerir horário" :loading="suggesting" @click="suggestSchedule" />
      <div v-if="suggestions.length" class="flex flex-wrap gap-2">
        <DsButton v-for="slot in suggestions" :key="slot.starts_at" variant="ghost" size="sm" :label="formatDateTime(slot.starts_at)" @click="useSuggestion(slot)" />
      </div>
    </form>

    <template #footer>
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div class="flex gap-2">
          <DsButton v-if="drawerMode === 'detail' && selectedEvent?.activity_id" variant="danger" icon="i-lucide-trash-2" aria-label="Excluir compromisso" @click="deleteEvent" />
          <DsButton v-if="drawerMode === 'detail' && selectedEvent?.activity_id" variant="secondary" label="Concluir" icon="i-lucide-check" @click="completeEvent" />
        </div>
        <div class="ml-auto flex gap-2">
          <DsButton variant="secondary" label="Cancelar" @click="closeDrawer" />
          <DsButton v-if="drawerMode === 'detail' && selectedEvent?.activity_id" variant="primary" label="Editar" icon="i-lucide-pencil" @click="editEvent()" />
          <DsButton v-else type="submit" form="agenda-event-form" variant="primary" label="Salvar" :loading="saving" :disabled="!canSave" />
        </div>
      </div>
    </template>
  </DsDrawer>

  <CRMConfirmDialog ref="confirmDialog" />

  <div class="pointer-events-none fixed bottom-4 left-1/2 z-ui-toast flex w-[min(92vw,32rem)] -translate-x-1/2 flex-col gap-2">
    <div v-if="error" role="alert" class="pointer-events-auto rounded-ui-surface border border-ui-danger bg-ui-danger-soft px-4 py-3 text-ui-body-sm text-ui-danger-foreground">{{ error }}</div>
    <div v-if="success" role="status" class="pointer-events-auto rounded-ui-surface border border-ui-success bg-ui-success-soft px-4 py-3 text-ui-body-sm text-ui-success">{{ success }}</div>
  </div>
</template>

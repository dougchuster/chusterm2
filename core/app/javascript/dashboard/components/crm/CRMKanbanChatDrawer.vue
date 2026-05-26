<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class -->
<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import CrmAPI from 'dashboard/api/crm';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import ConversationApi from 'dashboard/api/inbox/conversation';
import MessageApi from 'dashboard/api/inbox/message';

const props = defineProps({
  deal: {
    type: Object,
    default: null,
  },
  stages: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
  accountId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['dealUpdated', 'openDealDrawer']);
const show = defineModel('show', { type: Boolean, default: false });

const OPERATIONAL_OPTIONS = [
  { value: 'active', label: 'Lead ativo' },
  { value: 'returning_client', label: 'Retorno' },
  { value: 'converted_client', label: 'Cliente convertido' },
  { value: 'base_client', label: 'Cliente base' },
  { value: 'invalid', label: 'Invalido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Nao e lead' },
  { value: 'archived', label: 'Arquivado' },
];

const AI_MODE_LABELS = {
  auto: 'IA ativa',
  supervised: 'IA supervisionada',
  paused: 'IA pausada',
  human_only: 'Humano assumiu',
};

const localDeal = ref(null);
const messages = ref([]);
const activities = ref([]);
const aiState = ref(null);
const draft = ref('');
const handoffReason = ref('');
const loading = ref(false);
const messagesLoading = ref(false);
const aiLoading = ref(false);
const updatingStage = ref(false);
const updatingStatus = ref(false);
const updatingAi = ref(false);
const sending = ref(false);
const error = ref('');
const localEvents = ref([]);
const timelineRef = ref(null);
const searchOpen = ref(false);
const searchQuery = ref('');
const activeSearchIndex = ref(0);
const searchInputRef = ref(null);
const timelineItemRefs = new Map();
let loadToken = 0;
let localEventSequence = 0;

const displayTitle = computed(
  () =>
    localDeal.value?.title ||
    localDeal.value?.contact_name ||
    props.deal?.title ||
    'Atendimento'
);

const contactName = computed(
  () => localDeal.value?.contact?.name || localDeal.value?.contact_name || ''
);

const contactPhone = computed(
  () =>
    localDeal.value?.contact?.phone_number ||
    localDeal.value?.contact_phone_number ||
    ''
);

const contactId = computed(
  () =>
    localDeal.value?.contact?.id ||
    localDeal.value?.contact_id ||
    localDeal.value?.contactId ||
    localDeal.value?.chatwootContactId ||
    localDeal.value?.chatwoot_contact_id ||
    props.deal?.contact?.id ||
    props.deal?.contact_id ||
    props.deal?.contactId ||
    props.deal?.chatwootContactId ||
    props.deal?.chatwoot_contact_id ||
    ''
);

const contactUrl = computed(() => {
  if (!contactId.value) return '';
  return `/app/accounts/${props.accountId}/contacts/${contactId.value}`;
});

const attendanceNumber = computed(() => {
  const titleNumber = String(localDeal.value?.title || '').match(/#\s*(\d+)/);
  return (
    conversationLookupId.value ||
    localDeal.value?.conversation_id ||
    titleNumber?.[1] ||
    localDeal.value?.id ||
    props.deal?.id ||
    ''
  );
});

const attendanceLabel = computed(() =>
  attendanceNumber.value
    ? `Atendimento #${attendanceNumber.value}`
    : 'Atendimento'
);

const headerContactName = computed(
  () => contactName.value || displayTitle.value || 'Contato sem nome'
);

const ownerName = computed(() => {
  const ownerId = localDeal.value?.owner_id || props.deal?.owner_id;
  if (!ownerId) return 'Sem responsavel';
  const owner = props.agents.find(agent => String(agent.id) === String(ownerId));
  return owner?.name || owner?.email || 'Sem responsavel';
});

const conversationDisplayId = computed(
  () =>
    localDeal.value?.conversation?.display_id ||
    localDeal.value?.conversation_display_id ||
    props.deal?.conversation?.display_id ||
    props.deal?.conversation_display_id ||
    ''
);

const conversationRecordId = computed(
  () =>
    localDeal.value?.conversation?.id ||
    localDeal.value?.conversation_id ||
    props.deal?.conversation?.id ||
    props.deal?.conversation_id ||
    ''
);

const conversationLookupId = computed(
  () => conversationDisplayId.value || conversationRecordId.value
);

const hasConversation = computed(() => !!conversationLookupId.value);
const canLoadMessages = computed(() => !!conversationDisplayId.value);

const conversationUrl = computed(() => {
  if (!conversationDisplayId.value) return '';
  return `/app/accounts/${props.accountId}/conversations/${conversationDisplayId.value}`;
});

const currentStageId = computed(
  () => localDeal.value?.crm_pipeline_stage_id || props.deal?.crm_pipeline_stage_id || ''
);

const currentOperationalStatus = computed(
  () => localDeal.value?.operational_status || props.deal?.operational_status || 'active'
);

const aiMode = computed(() => aiState.value?.ai_mode || 'auto');
const aiModeLabel = computed(() => AI_MODE_LABELS[aiMode.value] || 'IA ativa');
const humanControlled = computed(() =>
  ['paused', 'human_only'].includes(aiMode.value)
);

const summaryText = computed(
  () =>
    aiState.value?.context_summary ||
    localDeal.value?.summary ||
    localDeal.value?.next_best_action ||
    ''
);

const shouldShowSummary = computed(
  () => humanControlled.value || Boolean(summaryText.value)
);

const normalizedSearchQuery = computed(() =>
  searchQuery.value.trim().toLocaleLowerCase('pt-BR')
);

const timelineItems = computed(() => {
  const messageItems = messages.value.map(message => ({
    id: `message-${message.id}`,
    type: 'message',
    createdAt: message.createdAt,
    message,
  }));

  const activityItems = activities.value.slice(0, 10).map(activity => ({
    id: `activity-${activity.id}`,
    type: 'event',
    icon: 'i-lucide-list-checks',
    label: `Tarefa: ${activity.title}`,
    meta: activity.due_at ? `Prazo ${formatDateTime(activity.due_at)}` : '',
    createdAt:
      activity.completed_at ||
      activity.due_at ||
      localDeal.value?.updated_at ||
      new Date().toISOString(),
  }));

  const handoffItem = aiState.value?.handoff_at
    ? [
        {
          id: `handoff-${aiState.value.id}`,
          type: 'event',
          icon: 'i-lucide-user-check',
          label: 'Controle assumido por humano',
          meta: aiState.value.handoff_by_name || '',
          createdAt: aiState.value.handoff_at,
        },
      ]
    : [];

  return [
    ...messageItems,
    ...activityItems,
    ...handoffItem,
    ...localEvents.value,
  ].sort((a, b) => timeToMs(a.createdAt) - timeToMs(b.createdAt));
});

const searchResults = computed(() => {
  const query = normalizedSearchQuery.value;
  if (!query) return [];

  return timelineItems.value
    .map((item, index) => ({ item, index, haystack: searchableText(item) }))
    .filter(result => result.haystack.includes(query));
});

const activeSearchItemId = computed(
  () => searchResults.value[activeSearchIndex.value]?.item.id || ''
);

const searchStatusLabel = computed(() => {
  if (!normalizedSearchQuery.value) return 'Digite para buscar';
  if (!searchResults.value.length) return 'Nenhum resultado';
  return `${activeSearchIndex.value + 1} de ${searchResults.value.length}`;
});

function timeToMs(value) {
  if (!value) return 0;
  if (typeof value === 'number') {
    return value < 10000000000 ? value * 1000 : value;
  }
  const parsed = new Date(value).getTime();
  return Number.isNaN(parsed) ? 0 : parsed;
}

function formatDateTime(value) {
  if (!value) return '';
  const date = typeof value === 'number' ? new Date(value * 1000) : new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

function searchableText(item) {
  if (item.type === 'event') {
    return `${item.label || ''} ${item.meta || ''}`.toLocaleLowerCase('pt-BR');
  }

  const message = item.message || {};
  return [
    message.content,
    message.senderName,
    messageSender(message),
    formatDateTime(message.createdAt),
  ]
    .filter(Boolean)
    .join(' ')
    .toLocaleLowerCase('pt-BR');
}

function setTimelineItemRef(id, el) {
  if (el) {
    timelineItemRefs.set(id, el);
  } else {
    timelineItemRefs.delete(id);
  }
}

function scrollToSearchResult() {
  const id = activeSearchItemId.value;
  if (!id) return;

  nextTick(() => {
    const el = timelineItemRefs.get(id);
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  });
}

function openSearch() {
  searchOpen.value = true;
  nextTick(() => searchInputRef.value?.focus());
}

function closeSearch() {
  searchOpen.value = false;
  searchQuery.value = '';
  activeSearchIndex.value = 0;
}

function moveSearchResult(direction) {
  const total = searchResults.value.length;
  if (!total) return;
  activeSearchIndex.value =
    (activeSearchIndex.value + direction + total) % total;
  scrollToSearchResult();
}

function onSearchKeydown(event) {
  if (event.key === 'Enter') {
    event.preventDefault();
    moveSearchResult(event.shiftKey ? -1 : 1);
  }
}

function normalizeMessage(message) {
  const sender = message.sender || {};
  return {
    id: message.id || message.echo_id || `pending-${Date.now()}`,
    content: message.content || message.content_for_llm || '',
    contentType: message.content_type,
    messageType: message.message_type,
    status: message.status,
    private: Boolean(message.private),
    senderName:
      message.sender_name || sender.name || sender.email || sender.available_name || '',
    createdAt: message.created_at || new Date().toISOString(),
    attachments: message.attachments || [],
  };
}

function messageDirection(message) {
  const type = message.messageType;
  if (message.private) return 'private';
  if (type === 'outgoing' || Number(type) === 1) return 'outgoing';
  if (type === 'activity' || Number(type) === 2) return 'event';
  return 'incoming';
}

function messageClass(message) {
  return {
    'crm-attendance-message--outgoing': messageDirection(message) === 'outgoing',
    'crm-attendance-message--incoming': messageDirection(message) === 'incoming',
    'crm-attendance-message--private': messageDirection(message) === 'private',
  };
}

function messageSender(message) {
  if (message.private) return 'Nota interna';
  if (messageDirection(message) === 'outgoing') {
    return message.senderName || 'Equipe';
  }
  return message.senderName || contactName.value || 'Contato';
}

function attachmentLabel(attachment) {
  return (
    attachment.fallback_title ||
    attachment.file_name ||
    attachment.filename ||
    attachment.file_type ||
    'Anexo'
  );
}

function stageName(stageId) {
  return (
    props.stages.find(stage => String(stage.id) === String(stageId))?.name ||
    'etapa'
  );
}

function statusLabel(status) {
  return (
    OPERATIONAL_OPTIONS.find(option => option.value === status)?.label || status
  );
}

function mergeDeal(payload) {
  localDeal.value = {
    ...(localDeal.value || {}),
    ...(payload || {}),
  };
  emit('dealUpdated', localDeal.value);
}

function pushSystemEvent(label, meta = '', icon = 'i-lucide-activity') {
  localEventSequence += 1;
  localEvents.value = [
    ...localEvents.value,
    {
      id: `local-${Date.now()}-${localEventSequence}`,
      type: 'event',
      icon,
      label,
      meta,
      createdAt: new Date().toISOString(),
    },
  ];
}

function scrollTimelineToBottom() {
  const el = timelineRef.value;
  if (!el) return;
  el.scrollTop = el.scrollHeight;
}

async function refreshMessages(expectedToken = loadToken) {
  if (!canLoadMessages.value) return false;

  messagesLoading.value = true;
  try {
    const { data } = await MessageApi.getPreviousMessages({
      conversationId: conversationDisplayId.value,
    });
    if (expectedToken !== loadToken) return false;

    const payload = data?.payload || [];
    messages.value = payload.map(normalizeMessage);
    ConversationApi.markMessageRead({ id: conversationDisplayId.value }).catch(
      () => {}
    );
    await nextTick();
    scrollTimelineToBottom();
    return true;
  } catch {
    // The CRM detail payload already contains the last messages.
    return false;
  } finally {
    if (expectedToken === loadToken) {
      messagesLoading.value = false;
    }
  }
}

async function loadAiState(expectedToken = loadToken) {
  if (!hasConversation.value) {
    aiState.value = null;
    return;
  }

  aiLoading.value = true;
  try {
    const { data } = await CaptainConversationStateAPI.show(
      conversationLookupId.value
    );
    if (expectedToken !== loadToken) return;

    aiState.value = data;
    handoffReason.value = data.handoff_reason || '';
  } catch {
    aiState.value = null;
  } finally {
    aiLoading.value = false;
  }
}

async function loadContext() {
  if (!props.deal?.id || !show.value) return;

  loadToken += 1;
  const token = loadToken;
  loading.value = true;
  error.value = '';
  localEvents.value = [];
  localDeal.value = { ...props.deal };
  messages.value = (props.deal.messages || []).map(normalizeMessage);
  activities.value = props.deal.activities || [];

  const hadInitialMessageRoute = canLoadMessages.value;
  refreshMessages(token);
  loadAiState(token);

  try {
    const { data } = await CrmAPI.getDeal(props.deal.id);
    if (token !== loadToken) return;

    localDeal.value = { ...props.deal, ...data };
    const detailMessages = (data.messages || []).map(normalizeMessage);
    if (detailMessages.length && !messages.value.length) {
      messages.value = detailMessages;
    }
    activities.value = data.activities || [];
    emit('dealUpdated', localDeal.value);

    if (!hadInitialMessageRoute && canLoadMessages.value) {
      refreshMessages(token);
      loadAiState(token);
    }
    await nextTick();
    scrollTimelineToBottom();
  } catch (e) {
    error.value =
      e?.response?.data?.message ||
      e?.response?.data?.error ||
      'Nao foi possivel carregar o atendimento.';
  } finally {
    if (token === loadToken) {
      loading.value = false;
    }
  }
}

async function updateStage(stageId) {
  if (!localDeal.value?.id || !stageId) return;

  const previousStageId = localDeal.value.crm_pipeline_stage_id;
  updatingStage.value = true;
  mergeDeal({
    crm_pipeline_stage_id: stageId,
    stage: props.stages.find(stage => String(stage.id) === String(stageId)),
  });

  try {
    const { data } = await CrmAPI.moveDeal(localDeal.value.id, stageId);
    mergeDeal(data);
    pushSystemEvent(
      `Lead movido para ${stageName(stageId)}`,
      '',
      'i-lucide-git-branch'
    );
  } catch (e) {
    mergeDeal({ crm_pipeline_stage_id: previousStageId });
    error.value =
      e?.response?.data?.message ||
      e?.response?.data?.error ||
      'Nao foi possivel mover o lead.';
  } finally {
    updatingStage.value = false;
  }
}

async function updateOperationalStatus(status) {
  if (!localDeal.value?.id || !status) return;

  const previousStatus = localDeal.value.operational_status;
  updatingStatus.value = true;
  mergeDeal({ operational_status: status });

  try {
    const { data } = await CrmAPI.updateDeal(localDeal.value.id, {
      operational_status: status,
    });
    mergeDeal(data);
    pushSystemEvent(
      `Situacao alterada para ${statusLabel(status)}`,
      '',
      'i-lucide-badge-check'
    );
  } catch (e) {
    mergeDeal({ operational_status: previousStatus });
    error.value =
      e?.response?.data?.message ||
      e?.response?.data?.error ||
      'Nao foi possivel atualizar a situacao.';
  } finally {
    updatingStatus.value = false;
  }
}

async function setAiMode(mode) {
  if (!hasConversation.value) return;

  updatingAi.value = true;
  error.value = '';

  try {
    const reason =
      handoffReason.value ||
      (mode === 'human_only'
        ? 'Atendimento assumido pelo Kanban'
        : 'Atualizado pelo Kanban');
    const { data } = await CaptainConversationStateAPI.update(
      conversationLookupId.value,
      {
        ai_mode: mode,
        handoff_reason: reason,
        crm_deal_id: localDeal.value?.id,
        context_summary: summaryText.value || undefined,
      }
    );
    aiState.value = data;
    handoffReason.value = data.handoff_reason || '';
    pushSystemEvent(aiModeLabel.value, reason, 'i-lucide-bot');
  } catch (e) {
    error.value =
      e?.response?.data?.message ||
      e?.response?.data?.error ||
      'Nao foi possivel alterar o controle da IA.';
  } finally {
    updatingAi.value = false;
  }
}

async function sendDraft() {
  const content = draft.value.trim();
  if (!content || sending.value) return;

  if (!canLoadMessages.value) {
    error.value = hasConversation.value
      ? 'Carregando rota da conversa. Tente novamente em instantes.'
      : 'Este lead ainda nao tem conversa vinculada.';
    return;
  }

  sending.value = true;
  error.value = '';
  draft.value = '';

  try {
    const { data } = await MessageApi.create({
      conversationId: conversationDisplayId.value,
      message: content,
      private: false,
    });
    messages.value = [...messages.value, normalizeMessage(data)];
    await nextTick();
    scrollTimelineToBottom();
  } catch (e) {
    draft.value = content;
    error.value =
      e?.response?.data?.message ||
      e?.response?.data?.error ||
      'Nao foi possivel enviar a mensagem.';
  } finally {
    sending.value = false;
  }
}

function onComposerKeydown(event) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault();
    sendDraft();
  }
}

function closeDrawer() {
  show.value = false;
}

function onWindowKeydown(event) {
  if (!show.value) return;

  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'f') {
    event.preventDefault();
    openSearch();
    return;
  }

  if (event.key === 'Escape' && searchOpen.value) {
    event.preventDefault();
    closeSearch();
    return;
  }

  if (event.key === 'Escape') {
    event.preventDefault();
    closeDrawer();
  }
}

watch(
  () => [props.deal?.id, show.value],
  () => loadContext(),
  { immediate: true }
);

watch(timelineItems, () => {
  nextTick(scrollTimelineToBottom);
});

watch(searchResults, results => {
  if (activeSearchIndex.value >= results.length) {
    activeSearchIndex.value = Math.max(results.length - 1, 0);
  }
  if (normalizedSearchQuery.value && results.length) {
    scrollToSearchResult();
  }
});

onMounted(() => {
  window.addEventListener('keydown', onWindowKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onWindowKeydown);
});
</script>

<template>
  <div v-show="show" class="crm-attendance-layer">
    <section class="crm-attendance-panel" aria-label="Atendimento no Kanban">
      <header class="crm-attendance-header">
        <div class="crm-attendance-contact-head">
          <div class="crm-attendance-avatar" aria-hidden="true">
            {{ headerContactName.slice(0, 1).toUpperCase() }}
          </div>
          <div class="min-w-0">
            <h2 class="m-0 truncate text-lg font-semibold text-n-slate-12">
              {{ headerContactName }}
            </h2>
            <div class="crm-attendance-header-meta">
              <span class="crm-attendance-chip crm-attendance-chip--strong">
                {{ attendanceLabel }}
              </span>
              <span v-if="contactPhone" class="crm-attendance-chip">
                <span class="i-lucide-phone size-3" />
                {{ contactPhone }}
              </span>
            </div>
            <p class="m-0 truncate text-xs text-n-slate-10">
              Responsavel: {{ ownerName }}
            </p>
          </div>
        </div>

        <div class="crm-attendance-header-actions">
          <button
            type="button"
            class="crm-attendance-action-button"
            title="Buscar mensagens"
            @click="openSearch"
          >
            <span class="i-lucide-search size-4" />
            Buscar
          </button>
          <a
            v-if="contactUrl"
            :href="contactUrl"
            class="crm-attendance-action-button"
            title="Editar contato"
          >
            <span class="i-lucide-user-pen size-4" />
            Editar
          </a>
          <button
            v-else
            type="button"
            class="crm-attendance-action-button crm-attendance-action-button--disabled"
            title="Contato ainda nao vinculado"
            disabled
          >
            <span class="i-lucide-user-pen size-4" />
            Editar
          </button>
          <a
            v-if="conversationUrl"
            :href="conversationUrl"
            class="crm-attendance-icon-button"
            title="Abrir conversa completa"
          >
            <span class="i-lucide-message-square-more size-4" />
          </a>
          <button
            type="button"
            class="crm-attendance-icon-button"
            title="Abrir ficha 360"
            @click="emit('openDealDrawer', localDeal || deal)"
          >
            <span class="i-lucide-panel-right-open size-4" />
          </button>
          <button
            type="button"
            class="crm-attendance-icon-button"
            title="Fechar"
            @click="closeDrawer"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>
      </header>

      <div class="crm-attendance-searchbar">
        <span class="i-lucide-search size-4 text-n-slate-10" />
        <input
          ref="searchInputRef"
          v-model="searchQuery"
          type="search"
          placeholder="Buscar mensagens"
          @focus="searchOpen = true"
          @keydown="onSearchKeydown"
        />
        <span class="crm-attendance-searchbar__count">
          {{ searchStatusLabel }}
        </span>
        <button
          type="button"
          class="crm-attendance-searchbar__button"
          :disabled="!searchResults.length"
          title="Resultado anterior"
          @click="moveSearchResult(-1)"
        >
          <span class="i-lucide-chevron-up size-4" />
        </button>
        <button
          type="button"
          class="crm-attendance-searchbar__button"
          :disabled="!searchResults.length"
          title="Proximo resultado"
          @click="moveSearchResult(1)"
        >
          <span class="i-lucide-chevron-down size-4" />
        </button>
        <button
          type="button"
          class="crm-attendance-searchbar__button"
          title="Fechar busca"
          @click="closeSearch"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>

      <div class="crm-attendance-controls">
        <label class="crm-attendance-field">
          <span>Etapa</span>
          <select
            :value="currentStageId"
            :disabled="updatingStage || !localDeal"
            @change="updateStage($event.target.value)"
          >
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </label>

        <label class="crm-attendance-field">
          <span>Situacao</span>
          <select
            :value="currentOperationalStatus"
            :disabled="updatingStatus || !localDeal"
            @change="updateOperationalStatus($event.target.value)"
          >
            <option
              v-for="option in OPERATIONAL_OPTIONS"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <div class="crm-attendance-ai">
          <div class="crm-attendance-ai__top">
            <span class="crm-attendance-ai__status">
              <span class="i-lucide-bot size-3.5" />
              {{ aiLoading ? 'Carregando IA...' : aiModeLabel }}
            </span>
            <span
              class="crm-attendance-ai__mode"
              :class="
                humanControlled
                  ? 'bg-n-ruby-3 text-n-ruby-11'
                  : 'bg-n-teal-3 text-n-teal-11'
              "
            >
              {{ humanControlled ? 'Humano' : 'IA' }}
            </span>
            <div class="crm-attendance-ai__actions">
              <button
                type="button"
                class="crm-attendance-mini-button crm-attendance-mini-button--danger"
                :disabled="updatingAi || !hasConversation"
                @click="setAiMode('human_only')"
              >
                Assumir
              </button>
              <button
                type="button"
                class="crm-attendance-mini-button"
                :disabled="updatingAi || !hasConversation"
                @click="setAiMode('paused')"
              >
                Pausar
              </button>
              <button
                type="button"
                class="crm-attendance-mini-button crm-attendance-mini-button--ok"
                :disabled="updatingAi || !hasConversation"
                @click="setAiMode('auto')"
              >
                Retomar
              </button>
            </div>
          </div>
          <input
            v-model="handoffReason"
            class="crm-attendance-reason"
            placeholder="Motivo do handoff (opcional)"
          />
        </div>
      </div>

      <div
        ref="timelineRef"
        class="crm-attendance-timeline"
        :aria-busy="messagesLoading || loading"
      >
        <div v-if="loading && !timelineItems.length" class="crm-attendance-empty">
          <span class="i-lucide-loader-2 size-5 animate-spin" />
          Abrindo conversa...
        </div>

        <div v-else-if="!hasConversation" class="crm-attendance-empty">
          <span class="i-lucide-message-square-off size-5" />
          Lead sem conversa vinculada.
        </div>

        <div v-else-if="!canLoadMessages && !timelineItems.length" class="crm-attendance-empty">
          <span class="i-lucide-loader-2 size-5 animate-spin" />
          Preparando mensagens...
        </div>

        <template v-else>
          <div
            v-if="messagesLoading"
            class="crm-attendance-loading-strip"
          >
            <span class="i-lucide-loader-2 size-3.5 animate-spin" />
            Sincronizando mensagens...
          </div>

          <article
            v-if="shouldShowSummary"
            class="crm-attendance-summary"
          >
            <span class="i-lucide-sparkles size-4 text-n-amber-9" />
            <div class="min-w-0">
              <p>Resumo do atendimento</p>
              <strong>
                {{
                  summaryText ||
                  'Sem resumo salvo. Assuma o atendimento e registre o contexto.'
                }}
              </strong>
            </div>
          </article>

          <article
            v-for="item in timelineItems"
            :key="item.id"
            :ref="el => setTimelineItemRef(item.id, el)"
            class="crm-attendance-item"
            :class="{
              'crm-attendance-item--search-hit': activeSearchItemId === item.id,
            }"
          >
            <div v-if="item.type === 'event'" class="crm-attendance-event">
              <span class="size-3.5" :class="item.icon" />
              <span class="min-w-0 truncate">{{ item.label }}</span>
              <em v-if="item.meta">{{ item.meta }}</em>
            </div>

            <div
              v-else
              class="crm-attendance-message"
              :class="messageClass(item.message)"
            >
              <div class="crm-attendance-message__meta">
                <span>{{ messageSender(item.message) }}</span>
                <time>{{ formatDateTime(item.message.createdAt) }}</time>
              </div>
              <p v-if="item.message.content" class="whitespace-pre-wrap">
                {{ item.message.content }}
              </p>
              <div
                v-if="item.message.attachments.length"
                class="crm-attendance-attachments"
              >
                <a
                  v-for="attachment in item.message.attachments"
                  :key="attachment.id || attachment.fallback_title"
                  :href="attachment.data_url || attachment.external_url"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <span class="i-lucide-paperclip size-3.5" />
                  {{ attachmentLabel(attachment) }}
                </a>
              </div>
            </div>
          </article>
        </template>
      </div>

      <footer class="crm-attendance-composer">
        <p v-if="error" class="crm-attendance-error">{{ error }}</p>
        <textarea
          v-model="draft"
          rows="3"
          class="crm-attendance-input"
          aria-label="Responder ao cliente"
          :disabled="sending || !canLoadMessages"
          placeholder="Responder ao cliente"
          @keydown="onComposerKeydown"
        />
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs text-n-slate-10">
            {{ sending ? 'Enviando...' : 'WhatsApp / inbox conectado' }}
          </span>
          <button
            type="button"
            class="crm-attendance-send"
            :disabled="sending || !draft.trim() || !canLoadMessages"
            @click="sendDraft"
          >
            <span class="i-lucide-send-horizontal size-4" />
            Enviar
          </button>
        </div>
      </footer>
    </section>
  </div>
</template>

<style scoped>
.crm-attendance-layer {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: flex;
  justify-content: flex-end;
  padding: 0.75rem;
  pointer-events: none;
}

.crm-attendance-panel {
  display: flex;
  width: min(37rem, 46vw);
  min-width: 28rem;
  max-width: calc(100vw - 1.5rem);
  height: calc(100vh - 1.5rem);
  flex-direction: column;
  overflow: hidden;
  border: 1px solid rgb(var(--ds-shell-border) / 0.68);
  border-radius: 1rem;
  background:
    linear-gradient(
      180deg,
      rgb(var(--ds-shell-panel-glass)),
      rgb(var(--ds-shell-panel) / 0.92)
    );
  box-shadow:
    -28px 0 72px rgb(var(--ds-shell-shadow-strong)),
    inset 1px 0 0 rgb(255 255 255 / 0.1);
  backdrop-filter: blur(24px) saturate(1.18);
  pointer-events: auto;
}

.crm-attendance-header,
.crm-attendance-composer {
  flex-shrink: 0;
  border-color: rgb(var(--ds-shell-divider) / 0.78);
  background: rgb(var(--ds-shell-panel-strong) / 0.72);
}

.crm-attendance-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  border-bottom-width: 1px;
  padding: 0.85rem 0.9rem;
}

.crm-attendance-contact-head {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 0.75rem;
}

.crm-attendance-avatar {
  display: grid;
  width: 2.6rem;
  height: 2.6rem;
  flex: 0 0 auto;
  place-content: center;
  border: 1px solid rgb(var(--ds-shell-secondary) / 0.5);
  border-radius: 999px;
  background:
    radial-gradient(
      circle at 28% 22%,
      rgb(var(--ds-shell-secondary) / 0.7),
      transparent 44%
    ),
    rgb(var(--ds-shell-accent-soft));
  color: rgb(var(--ds-fg-default));
  font-size: 1rem;
  font-weight: 850;
}

.crm-attendance-header-meta {
  display: flex;
  min-width: 0;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin: 0.2rem 0 0.28rem;
}

.crm-attendance-chip {
  display: inline-flex;
  max-width: 100%;
  align-items: center;
  gap: 0.28rem;
  overflow: hidden;
  border: 1px solid rgb(var(--ds-shell-border) / 0.56);
  border-radius: 999px;
  background: rgb(var(--ds-shell-panel-sunken) / 0.72);
  padding: 0.22rem 0.55rem;
  color: rgb(var(--ds-fg-muted));
  font-size: 0.7rem;
  font-weight: 750;
  line-height: 1;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-attendance-chip--strong {
  border-color: rgb(var(--ds-shell-accent) / 0.54);
  background: rgb(var(--ds-shell-accent-soft) / 0.82);
  color: rgb(var(--ds-fg-default));
}

.crm-attendance-header-actions {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: 0.4rem;
}

.crm-attendance-action-button,
.crm-attendance-icon-button {
  display: inline-flex;
  height: 2rem;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  border: 1px solid rgb(var(--ds-shell-border) / 0.62);
  border-radius: 0.5rem;
  background: rgb(var(--ds-shell-panel-sunken) / 0.82);
  color: rgb(var(--ds-fg-muted));
  transition:
    background 0.16s ease,
    color 0.16s ease,
    border-color 0.16s ease;
}

.crm-attendance-action-button {
  min-width: 4.8rem;
  padding: 0 0.55rem;
  color: rgb(var(--ds-fg-default));
  font-size: 0.75rem;
  font-weight: 800;
}

.crm-attendance-icon-button {
  width: 2rem;
}

.crm-attendance-action-button:hover,
.crm-attendance-icon-button:hover {
  border-color: rgb(var(--ds-shell-focus) / 0.72);
  background: rgb(var(--ds-shell-accent-soft));
  color: rgb(var(--ds-fg-default));
}

.crm-attendance-action-button--disabled,
.crm-attendance-action-button--disabled:hover {
  cursor: not-allowed;
  border-color: rgb(var(--ds-shell-border) / 0.42);
  background: rgb(var(--ds-shell-panel-sunken) / 0.48);
  color: rgb(var(--ds-fg-disabled));
}

.crm-attendance-searchbar {
  display: grid;
  flex-shrink: 0;
  grid-template-columns: auto minmax(0, 1fr) auto auto auto auto;
  align-items: center;
  gap: 0.4rem;
  border-bottom: 1px solid rgb(var(--ds-shell-divider) / 0.76);
  background: rgb(var(--ds-shell-panel-sunken) / 0.56);
  padding: 0.55rem 0.75rem;
}

.crm-attendance-searchbar input {
  min-width: 0;
  height: 2rem;
  border: 1px solid rgb(var(--ds-shell-border) / 0.6);
  border-radius: 999px;
  background: rgb(var(--ds-shell-panel) / 0.92);
  color: rgb(var(--ds-fg-default));
  font-size: 0.85rem;
  outline: none;
  padding: 0 0.75rem;
}

.crm-attendance-searchbar input:focus {
  border-color: rgb(var(--ds-shell-focus));
  box-shadow: 0 0 0 3px rgb(var(--ds-shell-glow));
}

.crm-attendance-searchbar__count {
  color: rgb(var(--ds-fg-subtle));
  font-size: 0.72rem;
  font-weight: 750;
  white-space: nowrap;
}

.crm-attendance-searchbar__button {
  display: grid;
  width: 1.9rem;
  height: 1.9rem;
  place-content: center;
  border: 1px solid rgb(var(--ds-shell-border) / 0.58);
  border-radius: 999px;
  background: rgb(var(--ds-shell-panel) / 0.86);
  color: rgb(var(--ds-fg-muted));
}

.crm-attendance-searchbar__button:disabled {
  cursor: not-allowed;
  opacity: 0.45;
}

.crm-attendance-controls {
  display: grid;
  flex-shrink: 0;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.5rem;
  border-bottom: 1px solid rgb(var(--ds-shell-divider) / 0.76);
  padding: 0.6rem 0.75rem;
}

.crm-attendance-field {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.25rem;
  color: rgb(var(--ds-fg-subtle));
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
}

.crm-attendance-field select,
.crm-attendance-reason,
.crm-attendance-input {
  width: 100%;
  border: 1px solid rgb(var(--ds-shell-border) / 0.62);
  border-radius: 0.55rem;
  background: rgb(var(--ds-shell-panel-sunken) / 0.86);
  color: rgb(var(--ds-fg-default));
  outline: none;
}

.crm-attendance-field select:focus,
.crm-attendance-reason:focus,
.crm-attendance-input:focus {
  border-color: rgb(var(--ds-shell-focus));
  box-shadow: 0 0 0 3px rgb(var(--ds-shell-glow));
}

.crm-attendance-field select {
  height: 2.25rem;
  padding: 0 0.625rem;
  font-size: 0.875rem;
  font-weight: 600;
}

.crm-attendance-ai {
  display: grid;
  grid-column: 1 / -1;
  gap: 0.45rem;
  border: 1px solid rgb(var(--ds-shell-border) / 0.62);
  border-radius: 0.65rem;
  background:
    linear-gradient(
      135deg,
      rgb(var(--ds-shell-panel-sunken) / 0.62),
      rgb(var(--ds-shell-panel) / 0.4)
    );
  padding: 0.5rem;
}

.crm-attendance-ai__top {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  align-items: center;
  gap: 0.45rem;
}

.crm-attendance-ai__status {
  display: inline-flex;
  min-width: 0;
  align-items: center;
  gap: 0.35rem;
  overflow: hidden;
  color: rgb(var(--ds-fg-muted));
  font-size: 0.76rem;
  font-weight: 800;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-attendance-ai__mode {
  border-radius: 999px;
  padding: 0.18rem 0.5rem;
  font-size: 0.66rem;
  font-weight: 850;
  line-height: 1;
  white-space: nowrap;
}

.crm-attendance-ai__actions {
  display: inline-grid;
  grid-template-columns: repeat(3, auto);
  gap: 0.3rem;
}

.crm-attendance-reason,
.crm-attendance-input {
  resize: none;
  padding: 0.625rem;
  font-size: 0.875rem;
}

.crm-attendance-reason {
  height: 1.9rem;
  padding: 0 0.55rem;
  font-size: 0.78rem;
}

.crm-attendance-mini-button,
.crm-attendance-send {
  display: inline-flex;
  min-height: 2rem;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  border: 1px solid rgb(var(--ds-shell-border) / 0.62);
  border-radius: 0.5rem;
  background: rgb(var(--ds-shell-panel) / 0.9);
  color: rgb(var(--ds-fg-default));
  font-size: 0.78rem;
  font-weight: 800;
}

.crm-attendance-mini-button {
  min-height: 1.8rem;
  padding: 0 0.5rem;
  font-size: 0.72rem;
}

.crm-attendance-mini-button--danger {
  border-color: rgb(var(--ds-shell-danger) / 0.5);
  background: rgb(var(--ds-shell-danger-soft) / 0.82);
  color: rgb(var(--ds-shell-danger));
}

.crm-attendance-mini-button--ok {
  border-color: rgb(var(--ds-shell-secondary) / 0.5);
  background: rgb(var(--ds-shell-secondary-soft) / 0.82);
  color: rgb(var(--ds-shell-secondary));
}

.crm-attendance-mini-button:disabled,
.crm-attendance-send:disabled,
.crm-attendance-field select:disabled,
.crm-attendance-input:disabled {
  cursor: not-allowed;
  opacity: 0.62;
}

.crm-attendance-timeline {
  flex: 1;
  overflow-y: auto;
  background:
    linear-gradient(
      90deg,
      transparent 0,
      transparent calc(50% - 1px),
      rgb(var(--ds-shell-divider) / 0.7) 50%,
      transparent calc(50% + 1px)
    ),
    rgb(var(--ds-shell-panel-sunken) / 0.32);
  padding: 0.875rem 0.95rem;
}

.crm-attendance-empty {
  display: grid;
  min-height: 14rem;
  place-content: center;
  gap: 0.75rem;
  color: rgb(var(--ds-fg-subtle));
  font-size: 0.875rem;
  text-align: center;
}

.crm-attendance-summary {
  position: sticky;
  top: 0;
  z-index: 1;
  display: flex;
  gap: 0.65rem;
  margin-bottom: 0.75rem;
  border: 1px solid rgb(var(--ds-shell-warning) / 0.5);
  border-radius: 0.75rem;
  background: rgb(var(--ds-shell-warning-soft) / 0.92);
  padding: 0.7rem;
  box-shadow: 0 10px 24px rgb(15 23 42 / 0.1);
}

.crm-attendance-summary p {
  margin: 0 0 0.2rem;
  color: rgb(var(--ds-shell-warning));
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
}

.crm-attendance-summary strong {
  display: block;
  color: rgb(var(--ds-fg-default));
  font-size: 0.84rem;
  font-weight: 650;
  line-height: 1.4;
}

.crm-attendance-loading-strip {
  position: sticky;
  top: 0;
  z-index: 2;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-bottom: 0.65rem;
  border: 1px solid rgb(var(--ds-shell-border) / 0.62);
  border-radius: 999px;
  background: rgb(var(--ds-shell-panel) / 0.9);
  padding: 0.32rem 0.6rem;
  color: rgb(var(--ds-fg-subtle));
  font-size: 0.72rem;
  font-weight: 750;
  backdrop-filter: blur(10px);
}

.crm-attendance-item + .crm-attendance-item {
  margin-top: 0.75rem;
}

.crm-attendance-item--search-hit {
  scroll-margin-block: 7rem;
}

.crm-attendance-item--search-hit .crm-attendance-message,
.crm-attendance-item--search-hit .crm-attendance-event {
  outline: 2px solid rgb(var(--ds-shell-warning));
  outline-offset: 2px;
  box-shadow: 0 0 0 5px rgb(var(--ds-shell-warning) / 0.18);
}

.crm-attendance-event {
  display: flex;
  max-width: 92%;
  align-items: center;
  gap: 0.45rem;
  margin: 0.25rem auto;
  border: 1px solid rgb(var(--ds-shell-border) / 0.54);
  border-radius: 999px;
  background: rgb(var(--ds-shell-panel) / 0.82);
  padding: 0.35rem 0.65rem;
  color: rgb(var(--ds-fg-subtle));
  font-size: 0.72rem;
  font-weight: 700;
}

.crm-attendance-event em {
  min-width: 0;
  overflow: hidden;
  color: rgb(var(--ds-fg-disabled));
  font-style: normal;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-attendance-message {
  width: fit-content;
  max-width: min(86%, 27rem);
  border: 1px solid rgb(var(--ds-shell-border) / 0.58);
  border-radius: 0.78rem;
  padding: 0.6rem 0.72rem;
  box-shadow: 0 10px 24px rgb(var(--ds-shell-shadow-soft));
}

.crm-attendance-message--incoming {
  margin-right: auto;
  border-left: 3px solid rgb(var(--ds-shell-accent));
  background: rgb(var(--ds-shell-panel) / 0.98);
}

.crm-attendance-message--outgoing {
  margin-left: auto;
  border-color: rgb(var(--ds-shell-secondary) / 0.5);
  border-right: 3px solid rgb(var(--ds-shell-secondary));
  background: rgb(var(--ds-shell-secondary-soft) / 0.78);
}

.crm-attendance-message--private {
  margin-inline: auto;
  border-color: rgb(var(--ds-shell-warning) / 0.5);
  background: rgb(var(--ds-shell-warning-soft));
}

.crm-attendance-message__meta {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.25rem;
  color: rgb(var(--ds-fg-subtle));
  font-size: 0.68rem;
  font-weight: 800;
}

.crm-attendance-message__meta span {
  max-width: 12rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-attendance-message p {
  margin: 0;
  color: rgb(var(--ds-fg-default));
  font-size: 0.875rem;
  line-height: 1.42;
}

.crm-attendance-attachments {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.55rem;
}

.crm-attendance-attachments a {
  display: inline-flex;
  min-width: 0;
  max-width: 100%;
  align-items: center;
  gap: 0.3rem;
  overflow: hidden;
  border-radius: 999px;
  background: rgb(var(--ds-shell-panel-strong));
  padding: 0.25rem 0.55rem;
  color: rgb(var(--ds-fg-muted));
  font-size: 0.72rem;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-attendance-composer {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  border-top-width: 1px;
  padding: 0.75rem;
}

.crm-attendance-error {
  margin: 0;
  border-radius: 0.55rem;
  background: rgb(var(--ds-shell-danger-soft));
  padding: 0.45rem 0.6rem;
  color: rgb(var(--ds-shell-danger));
  font-size: 0.78rem;
  font-weight: 700;
}

.crm-attendance-send {
  min-height: 2.25rem;
  border-color: rgb(var(--ds-shell-accent) / 0.82);
  background: rgb(var(--ds-shell-accent));
  padding: 0 0.9rem;
  color: rgb(var(--ds-shell-accent-contrast));
}

@media (max-width: 1023px) {
  .crm-attendance-panel {
    width: min(31rem, calc(100vw - 1rem));
    min-width: 0;
  }
}

@media (max-width: 640px) {
  .crm-attendance-layer {
    padding: 0.5rem;
  }

  .crm-attendance-panel {
    width: calc(100vw - 1rem);
    height: calc(100vh - 1rem);
  }

  .crm-attendance-controls {
    grid-template-columns: 1fr;
  }

  .crm-attendance-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .crm-attendance-header-actions {
    width: 100%;
    flex-wrap: wrap;
  }

  .crm-attendance-action-button {
    flex: 1 1 auto;
  }

  .crm-attendance-searchbar {
    grid-template-columns: auto minmax(0, 1fr) auto auto auto;
  }

  .crm-attendance-searchbar__count {
    grid-column: 2 / -1;
  }

  .crm-attendance-ai__top {
    grid-template-columns: 1fr auto;
  }

  .crm-attendance-ai__actions {
    grid-column: 1 / -1;
  }
}
</style>

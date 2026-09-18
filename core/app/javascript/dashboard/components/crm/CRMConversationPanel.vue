<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
// 1.1/1.2 — painel de atendimento do Kanban composto com as peças upstream
// (`ConversationHeader` + `MessagesView`, que já embute o `ReplyBox`): mesma
// store, mesmo cable, anexos/áudio/nota privada/canned de graça. O drawer
// antigo reimplementava tudo isso à mão e ficava sem realtime.
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import CrmAPI from 'dashboard/api/crm';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { usePanelWidth } from 'dashboard/composables/usePanelWidth';
import ConversationHeader from 'dashboard/components/widgets/conversation/ConversationHeader.vue';
import MessagesView from 'dashboard/components/widgets/conversation/MessagesView.vue';
import CaptainConversationStateCard from 'dashboard/components/captain/CaptainConversationStateCard.vue';
import CRMDealOutcomeControl from './CRMDealOutcomeControl.vue';
import CRMNextActionBox from './CRMNextActionBox.vue';
import CRMScoreBadge from './CRMScoreBadge.vue';

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
  lossReasons: {
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
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
  { value: 'archived', label: 'Arquivado' },
];

const store = useStore();
const { dragging, panelStyle, readStoredWidth, startResize } = usePanelWidth(
  'crm-conversation-panel-width'
);

const localDeal = ref(null);
const loading = ref(false);
const updatingStage = ref(false);
const updatingStatus = ref(false);
const updatingOwner = ref(false);
const updatingOutcome = ref(false);
const conversationReady = ref(false);
const contextOpen = ref(true);
const error = ref('');
let loadToken = 0;

const currentChat = computed(() => store.getters.getSelectedChat);

const conversationDisplayId = computed(
  () =>
    localDeal.value?.conversation?.display_id ||
    localDeal.value?.conversation_display_id ||
    props.deal?.conversation?.display_id ||
    props.deal?.conversation_display_id ||
    ''
);

const hasConversation = computed(() => !!conversationDisplayId.value);

const conversationUrl = computed(() => {
  if (!conversationDisplayId.value) return '';
  return `/app/accounts/${props.accountId}/conversations/${conversationDisplayId.value}`;
});

const headerContactName = computed(
  () =>
    localDeal.value?.contact?.name ||
    localDeal.value?.contact_name ||
    props.deal?.contact?.name ||
    props.deal?.contact_name ||
    localDeal.value?.title ||
    'Contato sem nome'
);

const contactAvatarUrl = computed(
  () =>
    localDeal.value?.contact?.thumbnail ||
    localDeal.value?.contact?.avatar_url ||
    localDeal.value?.contact_thumbnail ||
    localDeal.value?.contact_avatar_url ||
    props.deal?.contact_thumbnail ||
    props.deal?.contact_avatar_url ||
    ''
);

const attendanceLabel = computed(() =>
  conversationDisplayId.value
    ? `Atendimento #${conversationDisplayId.value}`
    : 'Lead sem atendimento'
);

const currentStageId = computed(
  () =>
    localDeal.value?.crm_pipeline_stage_id ||
    props.deal?.crm_pipeline_stage_id ||
    ''
);

const currentOperationalStatus = computed(
  () =>
    localDeal.value?.operational_status ||
    props.deal?.operational_status ||
    'active'
);

const currentOwnerId = computed(
  () => localDeal.value?.owner_id || props.deal?.owner_id || ''
);

const currentDealStatus = computed(
  () => localDeal.value?.status || props.deal?.status || 'open'
);
const currentLossReasonId = computed(
  () =>
    localDeal.value?.crm_loss_reason_id || props.deal?.crm_loss_reason_id || ''
);
const currentLossReasonName = computed(
  () => localDeal.value?.loss_reason?.name || props.deal?.loss_reason?.name || ''
);
const currentLossNote = computed(
  () => localDeal.value?.lost_reason_note || props.deal?.lost_reason_note || ''
);

const nextAction = computed(
  () =>
    localDeal.value?.next_best_action ||
    localDeal.value?.summary ||
    props.deal?.next_best_action ||
    ''
);

const dealScore = computed(
  () => Number(localDeal.value?.lead_score ?? props.deal?.lead_score ?? 0)
);
const dealScoreClassification = computed(
  () =>
    localDeal.value?.score_classification ||
    props.deal?.score_classification ||
    ''
);

// 1.5: a nota privada que o Captain deixa no handoff vira faixa fixa no topo —
// o atendente que assume não precisa rolar a conversa para achar o contexto.
const handoffSummary = computed(
  () =>
    localDeal.value?.conversation?.handoff_summary ||
    props.deal?.conversation?.handoff_summary ||
    ''
);

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

async function openConversationInStore() {
  if (!conversationDisplayId.value) return;

  const { data } = await ConversationApi.show(conversationDisplayId.value);
  // UPDATE_CONVERSATION empurra para allConversations mesmo quando a conversa
  // estaria fora dos filtros da caixa de entrada; `setActiveChat` assume a
  // conversa já visível para o getter `getSelectedChat` e dispara o fetch de
  // mensagens — daí pra frente o cable mantém tudo atualizado.
  await store.dispatch('updateConversation', data);
  await store.dispatch('setActiveChat', { data });
  conversationReady.value = true;
}

async function loadContext() {
  if (!props.deal?.id || !show.value) return;

  loadToken += 1;
  const token = loadToken;
  loading.value = true;
  error.value = '';
  conversationReady.value = false;
  localDeal.value = { ...props.deal };

  try {
    await openConversationInStore();
    if (token !== loadToken) return;

    const { data } = await CrmAPI.getDeal(props.deal.id);
    if (token !== loadToken) return;

    localDeal.value = { ...props.deal, ...data };
    emit('dealUpdated', localDeal.value);
  } catch (e) {
    if (token !== loadToken) return;
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível carregar o atendimento.';
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
  } catch (e) {
    mergeDeal({ crm_pipeline_stage_id: previousStageId });
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível mover o lead.';
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
  } catch (e) {
    mergeDeal({ operational_status: previousStatus });
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível atualizar a situação.';
  } finally {
    updatingStatus.value = false;
  }
}

async function updateOwner(ownerId) {
  if (!localDeal.value?.id) return;

  const previousOwnerId = localDeal.value.owner_id;
  updatingOwner.value = true;
  mergeDeal({ owner_id: ownerId || null });

  try {
    const { data } = await CrmAPI.updateDeal(localDeal.value.id, {
      owner_id: ownerId || null,
    });
    mergeDeal(data);
  } catch (e) {
    mergeDeal({ owner_id: previousOwnerId });
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível trocar o responsável.';
  } finally {
    updatingOwner.value = false;
  }
}

async function markWon() {
  if (!localDeal.value?.id) return;
  updatingOutcome.value = true;
  error.value = '';

  try {
    const { data } = await CrmAPI.markDealWon(localDeal.value.id);
    mergeDeal(data);
  } catch (e) {
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível marcar o negócio como ganho.';
  } finally {
    updatingOutcome.value = false;
  }
}

async function markLost({ lossReasonId, note }) {
  if (!localDeal.value?.id) return;
  updatingOutcome.value = true;
  error.value = '';

  try {
    const { data } = await CrmAPI.markDealLost(
      localDeal.value.id,
      lossReasonId,
      note
    );
    mergeDeal(data);
  } catch (e) {
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível marcar o negócio como perdido.';
  } finally {
    updatingOutcome.value = false;
  }
}

async function reopenDeal() {
  if (!localDeal.value?.id) return;
  updatingOutcome.value = true;
  error.value = '';

  try {
    const { data } = await CrmAPI.reopenDeal(localDeal.value.id);
    mergeDeal(data);
  } catch (e) {
    error.value =
      e?.response?.data?.error ||
      e?.response?.data?.message ||
      'Não foi possível reabrir o negócio.';
  } finally {
    updatingOutcome.value = false;
  }
}

watch(
  [() => props.deal?.id, show],
  ([dealId, isOpen]) => {
    if (!isOpen) {
      loadToken += 1;
      loading.value = false;
      conversationReady.value = false;
      store.dispatch('clearSelectedState');
      return;
    }
    if (dealId) loadContext();
  },
  { immediate: true }
);

onMounted(() => {
  readStoredWidth();
});
</script>

<template>
  <woot-modal
    v-model:show="show"
    modal-type="right-aligned"
    full-width
    :on-close="() => {}"
  >
    <div
      class="relative ml-auto flex h-full min-h-screen flex-col bg-n-background text-n-slate-12"
      :style="panelStyle"
      data-testid="crm-conversation-panel"
    >
      <div
        role="separator"
        aria-orientation="vertical"
        aria-label="Redimensionar painel"
        class="absolute inset-y-0 left-0 z-20 w-1.5 cursor-ew-resize transition-colors hover:bg-n-brand/40"
        :class="{ 'bg-n-brand/60': dragging }"
        @pointerdown.prevent="startResize"
      />

      <header
        class="flex items-center gap-3 border-b border-ui-border-subtle/60 px-4 py-3"
      >
        <div class="flex min-w-0 flex-1 items-center gap-3">
          <div
            class="flex size-10 flex-shrink-0 items-center justify-center overflow-hidden rounded-full bg-n-brand-3 text-sm font-semibold text-n-brand-11"
          >
            <img
              v-if="contactAvatarUrl"
              class="size-full object-cover"
              :src="contactAvatarUrl"
              :alt="headerContactName"
            />
            <span v-else>{{ headerContactName.slice(0, 1).toUpperCase() }}</span>
          </div>
          <div class="min-w-0">
            <h2 class="m-0 truncate text-sm font-semibold text-n-slate-12">
              {{ headerContactName }}
            </h2>
            <p class="m-0 truncate text-xs text-n-slate-10">
              {{ attendanceLabel }}
            </p>
          </div>
        </div>
        <div class="flex flex-shrink-0 items-center gap-1">
          <a
            v-if="conversationUrl"
            :href="conversationUrl"
            class="flex size-8 items-center justify-center rounded-md text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
            title="Abrir conversa completa"
          >
            <span class="i-lucide-message-square-more size-4" />
          </a>
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-md text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
            title="Abrir ficha 360"
            @click="emit('openDealDrawer', localDeal || deal)"
          >
            <span class="i-lucide-panel-right-open size-4" />
          </button>
        </div>
      </header>

      <ConversationHeader
        v-if="conversationReady && currentChat.id"
        :chat="currentChat"
        :show-back-button="false"
      />

      <div
        v-if="localDeal"
        class="border-b border-ui-border-subtle/60 bg-n-slate-1 dark:bg-n-solid-2"
      >
        <button
          type="button"
          class="flex w-full items-center gap-2 px-4 py-2 text-left text-[0.6875rem] font-semibold uppercase tracking-wider text-n-slate-10 transition-colors hover:text-n-slate-12"
          :aria-expanded="contextOpen"
          @click="contextOpen = !contextOpen"
        >
          <span
            class="size-3.5 transition-transform"
            :class="
              contextOpen ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'
            "
          />
          <span class="truncate">
            {{ stageName(currentStageId) }} ·
            {{ statusLabel(currentOperationalStatus) }}
          </span>
          <CRMScoreBadge
            class="ml-auto"
            :score="dealScore"
            :classification="dealScoreClassification"
            size="sm"
          />
        </button>

        <div
          v-if="contextOpen"
          class="flex max-h-[45vh] flex-col gap-2 overflow-y-auto border-t border-ui-border-subtle/40 px-4 pb-3 pt-2"
        >
          <div class="grid grid-cols-3 gap-2">
            <label class="flex flex-col gap-1">
              <span
                class="text-[0.625rem] font-semibold uppercase tracking-wider text-n-slate-10"
              >
                Etapa
              </span>
              <select
                :value="currentStageId"
                :disabled="updatingStage"
                class="w-full truncate rounded-md border border-ui-border-subtle bg-n-background px-2 py-1.5 text-xs text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateStage($event.target.value)"
              >
                <option v-for="stage in stages" :key="stage.id" :value="stage.id">
                  {{ stage.name }}
                </option>
              </select>
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-[0.625rem] font-semibold uppercase tracking-wider text-n-slate-10"
              >
                Situação
              </span>
              <select
                :value="currentOperationalStatus"
                :disabled="updatingStatus"
                class="w-full truncate rounded-md border border-ui-border-subtle bg-n-background px-2 py-1.5 text-xs text-n-slate-12 outline-none focus:border-n-brand"
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
            <label class="flex flex-col gap-1">
              <span
                class="text-[0.625rem] font-semibold uppercase tracking-wider text-n-slate-10"
              >
                Responsável
              </span>
              <select
                :value="currentOwnerId"
                :disabled="updatingOwner"
                class="w-full truncate rounded-md border border-ui-border-subtle bg-n-background px-2 py-1.5 text-xs text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateOwner($event.target.value)"
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
            </label>
          </div>

          <CRMDealOutcomeControl
            :status="currentDealStatus"
            :loss-reasons="lossReasons"
            :loss-reason-id="currentLossReasonId"
            :loss-reason-name="currentLossReasonName"
            :loss-note="currentLossNote"
            :busy="updatingOutcome"
            @mark-won="markWon"
            @mark-lost="markLost"
            @reopen="reopenDeal"
          />

          <CRMNextActionBox
            v-if="nextAction"
            :action="nextAction"
            :urgency-level="localDeal.urgency_level"
            compact
            @schedule="emit('openDealDrawer', localDeal || deal)"
          />

          <CaptainConversationStateCard
            v-if="hasConversation"
            :conversation-display-id="conversationDisplayId"
          />
        </div>
      </div>

      <article
        v-if="handoffSummary"
        data-testid="crm-drawer-handoff-summary"
        class="mx-4 mt-3 flex items-start gap-2 rounded-lg border border-n-amber-6/40 bg-n-amber-2 px-3 py-2"
      >
        <span class="i-lucide-user-check mt-0.5 size-4 flex-shrink-0 text-n-amber-9" />
        <div class="min-w-0">
          <p class="m-0 text-[0.625rem] font-semibold uppercase tracking-wider text-n-amber-10">
            Handoff da IA
          </p>
          <p class="m-0 whitespace-pre-wrap text-xs text-n-slate-12">
            {{ handoffSummary }}
          </p>
        </div>
      </article>

      <p
        v-if="error"
        class="mx-4 mt-2 rounded-md bg-n-ruby-3 px-3 py-2 text-xs text-n-ruby-11"
        role="alert"
      >
        {{ error }}
      </p>

      <div class="flex min-h-0 flex-1 flex-col">
        <MessagesView v-if="conversationReady" />

        <div
          v-else
          class="flex flex-1 flex-col items-center justify-center gap-2 text-n-slate-10"
          :aria-busy="loading"
        >
          <template v-if="loading">
            <span class="i-lucide-loader-2 size-5 animate-spin" />
            Abrindo conversa…
          </template>
          <template v-else-if="!hasConversation">
            <span class="i-lucide-message-square-off size-5" />
            Lead sem conversa vinculada.
          </template>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

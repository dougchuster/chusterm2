<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationDisplayId: { type: [Number, String], required: true },
});

const route = useRoute();
const accountId = computed(() => route.params.accountId);
const copy = {
  ariaLabel: 'Controle inteligente do Capitão',
  eyebrow: 'Capitão · controle da conversa',
  team: 'Equipe',
  ai: 'IA',
  loading: 'Sincronizando contexto da conversa…',
  relationship: 'Relacionamento',
  qualification: 'Qualificação',
  confidenceSuffix: '% de confiança · ver evidências',
  scoreUnit: '/ 100',
  relationshipNotice:
    'A classificação ajuda a personalizar o atendimento, mas nunca transfere a conversa sozinha.',
  nextAction: 'Próxima melhor ação',
  nextActionFallback: 'Revisar dados do atendimento.',
  openDeal: 'Abrir negócio no CRM',
  documentsPrefix: 'Docs:',
  documentsStatusLabels: {
    pending: 'pendente',
    waiting_document: 'aguardando documento',
    requested: 'solicitado',
    parcial: 'parcial',
    received: 'recebidos',
    complete: 'completos',
  },
  scoreWhy: 'Por que este score?',
  interventionContext: 'Contexto para intervenção humana',
  protectedService: 'Atendimento protegido contra respostas concorrentes',
  controlNotice:
    'Score e identificação de Lead/Cliente orientam a equipe, mas não mudam o controle da conversa automaticamente.',
  updating: 'Atualizando controle…',
  saveReason: 'Salvar contexto',
  reasonSaved: 'Contexto sincronizado',
  reasonUnsaved: 'Alterações ainda não salvas',
  reasonPlaceholder:
    'Ex.: cliente pediu especialista, prazo crítico ou equipe assumiu',
};

const modes = [
  {
    id: 'auto',
    label: 'IA ativa',
    description: 'O Capitão responde e mantém a memória.',
    icon: 'i-lucide-sparkles',
  },
  {
    id: 'supervised',
    label: 'Supervisionada',
    description: 'A IA prepara o atendimento para revisão.',
    icon: 'i-lucide-scan-eye',
  },
  {
    id: 'paused',
    label: 'IA pausada',
    description: 'Nenhuma resposta automática será enviada.',
    icon: 'i-lucide-pause',
  },
  {
    id: 'human_only',
    label: 'Humano no controle',
    description: 'A conversa está sob responsabilidade da equipe.',
    icon: 'i-lucide-user-round-check',
  },
];

const state = ref(null);
const loading = ref(false);
const saving = ref(false);
const error = ref('');
const reason = ref('');
const persistedReason = ref('');
const isScoreExpanded = ref(false);
const isRelationshipExpanded = ref(false);
let conversationVersion = 0;

const currentMode = computed(() => state.value?.ai_mode || 'auto');
const currentModeDefinition = computed(
  () => modes.find(mode => mode.id === currentMode.value) || modes[0]
);
const humanControlled = computed(() =>
  ['paused', 'human_only'].includes(currentMode.value)
);
const isReasonDirty = computed(() => reason.value !== persistedReason.value);
const statusTone = computed(() => {
  if (currentMode.value === 'human_only') {
    return 'bg-ds-state-info-soft text-ds-state-info-fg';
  }
  if (currentMode.value === 'paused') {
    return 'bg-ds-state-warning-soft text-ds-state-warning-fg';
  }
  if (currentMode.value === 'supervised') {
    return 'bg-ds-accent-soft text-ds-accent';
  }
  return 'bg-ds-state-success-soft text-ds-state-success-fg';
});
const scoreValue = computed(() => Number(state.value?.score_total || 0));
const scoreLabel = computed(
  () => state.value?.score_classification || 'Sem classificação'
);
const scoreTone = computed(() => {
  if (scoreValue.value >= 80) {
    return 'bg-ds-state-success-soft text-ds-state-success-fg';
  }
  if (scoreValue.value >= 60) {
    return 'bg-ds-state-info-soft text-ds-state-info-fg';
  }
  if (scoreValue.value >= 40) {
    return 'bg-ds-state-warning-soft text-ds-state-warning-fg';
  }
  return 'bg-ds-bg-hover text-ds-fg-muted';
});
const relationship = computed(() => state.value?.relationship || {});
const relationshipLabel = computed(
  () => relationship.value.label || 'Não identificado'
);
const relationshipConfidence = computed(() =>
  Math.round(Number(relationship.value.confidence || 0) * 100)
);
const relationshipEvidence = computed(() => relationship.value.evidence || []);
const scoreFactorEntries = computed(() => {
  const factors = state.value?.score_factors;
  if (!factors || typeof factors !== 'object') return [];
  return Object.entries(factors)
    .map(([key, data]) => ({
      key,
      score: Number(data?.score || 0),
      maxScore: Number(data?.max_score || 0),
      evidence: data?.evidence || '',
    }))
    .filter(item => item.evidence);
});
const hasCrmContext = computed(
  () =>
    state.value?.crm_deal_id ||
    state.value?.crm_deal_next_best_action ||
    state.value?.crm_deal_legal_area ||
    state.value?.crm_deal_documents_status ||
    state.value?.crm_deal_owner_name
);
const crmDealUrl = computed(() => {
  if (!state.value?.crm_deal_id || !accountId.value) return '';
  return `/app/accounts/${accountId.value}/crm?deal_id=${state.value.crm_deal_id}`;
});
const handoffAt = computed(() => {
  if (!state.value?.handoff_at) return '';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(state.value.handoff_at));
});
const handoffMetadata = computed(() =>
  [state.value?.handoff_by_name || 'Sistema', handoffAt.value]
    .filter(Boolean)
    .join(' · ')
);
const scoreFactorValue = item => `${item.score}/${item.maxScore}`;

function isCurrentConversation(conversationDisplayId, version) {
  return (
    version === conversationVersion &&
    String(conversationDisplayId) === String(props.conversationDisplayId)
  );
}

function responseMatchesConversation(data, conversationDisplayId) {
  return (
    data?.conversation_display_id === undefined ||
    String(data.conversation_display_id) === String(conversationDisplayId)
  );
}

function applyServerState(data) {
  const serverReason = data.handoff_reason || '';
  state.value = data;
  reason.value = serverReason;
  persistedReason.value = serverReason;
}

function resetConversationState() {
  state.value = null;
  reason.value = '';
  persistedReason.value = '';
  error.value = '';
  loading.value = false;
  saving.value = false;
  isScoreExpanded.value = false;
  isRelationshipExpanded.value = false;
}

function setLoadError(requestError) {
  const status = requestError?.response?.status;
  if (status === 404) {
    error.value = 'Nenhum controle de IA foi encontrado nesta conversa.';
  } else if (status === 401 || status === 403) {
    error.value = 'Você não tem permissão para controlar a IA.';
  } else {
    error.value = 'Não foi possível carregar o controle da IA.';
  }
}

async function loadState(conversationDisplayId, version) {
  if (!conversationDisplayId) return;

  try {
    const { data } = await CaptainConversationStateAPI.show(
      conversationDisplayId
    );
    if (
      !isCurrentConversation(conversationDisplayId, version) ||
      !responseMatchesConversation(data, conversationDisplayId)
    ) {
      return;
    }
    applyServerState(data);
  } catch (requestError) {
    if (!isCurrentConversation(conversationDisplayId, version)) return;
    setLoadError(requestError);
  } finally {
    if (isCurrentConversation(conversationDisplayId, version)) {
      loading.value = false;
    }
  }
}

async function saveState(changes) {
  const conversationDisplayId = props.conversationDisplayId;
  const version = conversationVersion;
  if (!conversationDisplayId || !state.value || loading.value || saving.value) {
    return;
  }

  const reasonAtRequest = reason.value;
  saving.value = true;
  error.value = '';

  try {
    const { data } = await CaptainConversationStateAPI.update(
      conversationDisplayId,
      {
        ...changes,
        handoff_reason: reasonAtRequest,
      }
    );
    if (
      !isCurrentConversation(conversationDisplayId, version) ||
      !responseMatchesConversation(data, conversationDisplayId)
    ) {
      return;
    }
    applyServerState(data);
  } catch (requestError) {
    if (!isCurrentConversation(conversationDisplayId, version)) return;
    error.value =
      requestError?.response?.data?.error ||
      'Não foi possível atualizar o controle da IA.';
  } finally {
    if (isCurrentConversation(conversationDisplayId, version)) {
      saving.value = false;
    }
  }
}

function saveMode(mode) {
  return saveState({ ai_mode: mode });
}

function saveReason() {
  if (isReasonDirty.value) {
    saveState({});
  }
}

watch(
  () => props.conversationDisplayId,
  conversationDisplayId => {
    conversationVersion += 1;
    const version = conversationVersion;
    resetConversationState();
    if (!conversationDisplayId) return;
    loading.value = true;
    loadState(conversationDisplayId, version);
  },
  { immediate: true }
);
</script>

<template>
  <section
    class="overflow-hidden rounded-2xl bg-ds-bg-surface text-ds-fg-default shadow-md"
    :aria-label="copy.ariaLabel"
    :aria-busy="loading || saving"
  >
    <header class="bg-ds-bg-sunken px-4 py-4">
      <div class="flex items-start justify-between gap-3">
        <div class="flex min-w-0 items-center gap-3">
          <span
            class="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-ds-accent-soft text-ds-accent"
            aria-hidden="true"
          >
            <span class="i-lucide-sparkles size-5" />
          </span>
          <div class="min-w-0">
            <p
              class="m-0 text-[10px] font-semibold uppercase tracking-[0.2em] text-ds-fg-muted"
            >
              {{ copy.eyebrow }}
            </p>
            <h3
              class="m-0 mt-1 truncate font-manrope text-base font-semibold text-ds-fg-default"
            >
              {{ currentModeDefinition.label }}
            </h3>
          </div>
        </div>
        <span
          class="inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-semibold"
          :class="statusTone"
        >
          <span class="size-1.5 rounded-full bg-current" aria-hidden="true" />
          {{ humanControlled ? copy.team : copy.ai }}
        </span>
      </div>
      <p class="m-0 mt-3 text-xs leading-5 text-ds-fg-muted">
        {{ currentModeDefinition.description }}
      </p>
    </header>

    <div
      v-if="loading"
      class="flex items-center gap-2 px-4 py-8 text-sm text-ds-fg-muted"
      role="status"
      aria-live="polite"
    >
      <span
        class="i-lucide-loader-circle size-4 animate-spin"
        aria-hidden="true"
      />
      {{ copy.loading }}
    </div>

    <div v-else-if="state" class="space-y-4 p-4">
      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="mode in modes"
          :key="mode.id"
          type="button"
          class="group flex min-h-14 items-center gap-2.5 rounded-xl px-3 py-2 text-left transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-60"
          :class="
            currentMode === mode.id
              ? 'bg-ds-accent text-ds-fg-on-accent shadow-sm'
              : 'bg-ds-bg-sunken text-ds-fg-muted hover:bg-ds-bg-hover hover:text-ds-fg-default'
          "
          :aria-pressed="currentMode === mode.id"
          :aria-label="`${mode.label}. ${mode.description}`"
          :disabled="saving"
          @click="saveMode(mode.id)"
        >
          <span class="size-4 shrink-0" :class="mode.icon" aria-hidden="true" />
          <span class="text-xs font-semibold leading-4">{{ mode.label }}</span>
        </button>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <article class="rounded-xl bg-ds-bg-sunken p-3">
          <div class="flex items-center justify-between gap-2">
            <span
              class="text-[10px] font-semibold uppercase tracking-widest text-ds-fg-muted"
            >
              {{ copy.relationship }}
            </span>
            <span
              class="i-lucide-badge-check size-3.5 text-ds-state-success"
              aria-hidden="true"
            />
          </div>
          <p
            class="m-0 mt-2 font-manrope text-base font-semibold text-ds-fg-default"
          >
            {{ relationshipLabel }}
          </p>
          <button
            type="button"
            class="mt-1 inline-flex min-h-10 w-full items-center rounded-lg text-left text-[11px] text-ds-fg-muted transition-colors hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
            :aria-expanded="isRelationshipExpanded"
            :aria-controls="`captain-relationship-${conversationDisplayId}`"
            @click="isRelationshipExpanded = !isRelationshipExpanded"
          >
            {{ relationshipConfidence }}{{ copy.confidenceSuffix }}
          </button>
        </article>

        <article class="rounded-xl bg-ds-bg-sunken p-3">
          <div class="flex items-center justify-between gap-2">
            <span
              class="text-[10px] font-semibold uppercase tracking-widest text-ds-fg-muted"
            >
              {{ copy.qualification }}
            </span>
            <span
              class="i-lucide-gauge size-3.5 text-ds-accent"
              aria-hidden="true"
            />
          </div>
          <div class="mt-2 flex items-baseline gap-1.5">
            <strong class="font-manrope text-2xl text-ds-fg-default">{{
              scoreValue
            }}</strong>
            <span class="text-[10px] text-ds-fg-muted">{{
              copy.scoreUnit
            }}</span>
          </div>
          <span
            class="mt-1 inline-flex rounded-full px-2 py-0.5 text-[10px] font-semibold"
            :class="scoreTone"
          >
            {{ scoreLabel }}
          </span>
        </article>
      </div>

      <div
        v-if="isRelationshipExpanded"
        :id="`captain-relationship-${conversationDisplayId}`"
        class="rounded-xl bg-ds-bg-hover px-3 py-2.5 text-xs text-ds-fg-muted"
      >
        <p
          v-for="item in relationshipEvidence"
          :key="item.code"
          class="m-0 flex gap-2 py-1 leading-5"
        >
          <span
            class="i-lucide-check-circle-2 mt-1 size-3 shrink-0 text-ds-state-success"
            aria-hidden="true"
          />
          {{ item.description }}
        </p>
        <p class="m-0 mt-2 text-[11px] text-ds-fg-muted">
          {{ copy.relationshipNotice }}
        </p>
      </div>

      <article v-if="hasCrmContext" class="rounded-xl bg-ds-bg-sunken p-3">
        <div class="flex items-center justify-between gap-3">
          <div class="flex min-w-0 items-center gap-2">
            <span
              class="i-lucide-briefcase-business size-4 shrink-0 text-ds-accent"
              aria-hidden="true"
            />
            <div class="min-w-0">
              <p
                class="m-0 text-[10px] uppercase tracking-widest text-ds-fg-muted"
              >
                {{ copy.nextAction }}
              </p>
              <p
                class="m-0 mt-1 text-xs font-medium leading-5 text-ds-fg-default"
              >
                {{ state.crm_deal_next_best_action || copy.nextActionFallback }}
              </p>
            </div>
          </div>
          <a
            v-if="crmDealUrl"
            :href="crmDealUrl"
            class="flex size-10 shrink-0 items-center justify-center rounded-full bg-ds-accent text-ds-fg-on-accent transition-colors hover:bg-ds-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
            :aria-label="copy.openDeal"
          >
            <span class="i-lucide-arrow-up-right size-4" aria-hidden="true" />
          </a>
        </div>
        <div class="mt-3 flex flex-wrap gap-1.5 text-[10px] text-ds-fg-muted">
          <span
            v-if="state.crm_deal_legal_area"
            class="rounded-full bg-ds-bg-surface px-2 py-1"
          >
            {{ state.crm_deal_legal_area }}
          </span>
          <span
            v-if="state.crm_deal_documents_status"
            class="rounded-full bg-ds-bg-surface px-2 py-1"
          >
            {{ copy.documentsPrefix }}
            {{
              copy.documentsStatusLabels[state.crm_deal_documents_status] ||
              state.crm_deal_documents_status
            }}
          </span>
          <span
            v-if="state.crm_deal_owner_name"
            class="rounded-full bg-ds-bg-surface px-2 py-1"
          >
            {{ state.crm_deal_owner_name }}
          </span>
        </div>
      </article>

      <div v-if="scoreFactorEntries.length" class="rounded-xl bg-ds-bg-sunken">
        <button
          type="button"
          class="flex min-h-11 w-full items-center justify-between gap-2 rounded-xl px-3 py-3 text-left text-xs font-semibold text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          :aria-expanded="isScoreExpanded"
          :aria-controls="`captain-score-${conversationDisplayId}`"
          @click="isScoreExpanded = !isScoreExpanded"
        >
          <span class="flex items-center gap-2">
            <span
              class="i-lucide-list-checks size-4 text-ds-accent"
              aria-hidden="true"
            />
            {{ copy.scoreWhy }}
          </span>
          <span
            class="size-4 text-ds-fg-muted"
            :class="
              isScoreExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
            "
            aria-hidden="true"
          />
        </button>
        <div
          v-show="isScoreExpanded"
          :id="`captain-score-${conversationDisplayId}`"
          class="space-y-2 px-3 pb-3"
        >
          <div
            v-for="item in scoreFactorEntries"
            :key="item.key"
            class="rounded-lg bg-ds-bg-surface p-2.5"
          >
            <div class="flex items-center justify-between gap-2 text-[11px]">
              <span class="font-semibold text-ds-fg-default">{{
                item.key
              }}</span>
              <span class="text-ds-accent">{{ scoreFactorValue(item) }}</span>
            </div>
            <p class="m-0 mt-1 text-[11px] leading-4 text-ds-fg-muted">
              {{ item.evidence }}
            </p>
          </div>
        </div>
      </div>

      <label class="block">
        <span
          class="text-[10px] font-semibold uppercase tracking-widest text-ds-fg-muted"
        >
          {{ copy.interventionContext }}
        </span>
        <textarea
          v-model="reason"
          :disabled="saving"
          :aria-describedby="`captain-reason-status-${conversationDisplayId}`"
          rows="2"
          class="mt-2 w-full resize-none rounded-xl bg-ds-bg-sunken px-3 py-2.5 text-xs leading-5 text-ds-fg-default outline-none ring-1 ring-inset ring-ds-border placeholder:text-ds-fg-muted focus:ring-2 focus:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-60"
          :placeholder="copy.reasonPlaceholder"
          data-testid="captain-reason"
        />
      </label>

      <div class="flex items-center justify-between gap-3">
        <p
          :id="`captain-reason-status-${conversationDisplayId}`"
          class="m-0 text-[11px]"
          :class="
            isReasonDirty ? 'text-ds-state-warning-fg' : 'text-ds-fg-muted'
          "
          role="status"
          aria-live="polite"
          data-testid="captain-reason-status"
        >
          {{ isReasonDirty ? copy.reasonUnsaved : copy.reasonSaved }}
        </p>
        <button
          type="button"
          class="inline-flex min-h-10 shrink-0 items-center justify-center gap-2 rounded-xl bg-ds-accent px-3 text-xs font-semibold text-ds-fg-on-accent transition-colors hover:bg-ds-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
          :aria-label="copy.saveReason"
          :disabled="saving || !isReasonDirty"
          data-testid="captain-save-reason"
          @click="saveReason"
        >
          <span class="i-lucide-save size-4" aria-hidden="true" />
          {{ copy.saveReason }}
        </button>
      </div>

      <div
        v-if="humanControlled && state"
        class="rounded-xl bg-ds-state-info-soft p-3 text-xs text-ds-state-info"
      >
        <p class="m-0 flex items-center gap-2 font-semibold">
          <span class="i-lucide-shield-check size-4" aria-hidden="true" />
          {{ copy.protectedService }}
        </p>
        <p v-if="state.handoff_reason" class="m-0 mt-2 leading-5">
          {{ state.handoff_reason }}
        </p>
        <p
          v-if="handoffAt || state.handoff_by_name"
          class="m-0 mt-1 text-[11px] opacity-80"
        >
          {{ handoffMetadata }}
        </p>
      </div>

      <div
        class="rounded-xl bg-ds-bg-hover p-3 text-[11px] leading-5 text-ds-fg-muted"
      >
        <span
          class="i-lucide-info mr-1 inline-block size-3.5 align-text-bottom text-ds-accent"
          aria-hidden="true"
        />
        {{ copy.controlNotice }}
      </div>

      <div
        v-if="saving"
        class="flex items-center gap-2 text-xs text-ds-fg-muted"
        role="status"
        aria-live="polite"
      >
        <span
          class="i-lucide-loader-circle size-3.5 animate-spin"
          aria-hidden="true"
        />
        {{ copy.updating }}
      </div>
      <div
        v-if="error"
        role="alert"
        aria-live="assertive"
        class="rounded-xl bg-ds-state-danger-soft px-3 py-2 text-xs text-ds-state-danger"
      >
        {{ error }}
      </div>

      <NextButton
        v-if="humanControlled"
        label="Retomar atendimento com IA"
        icon="i-lucide-play"
        size="sm"
        class="w-full"
        :disabled="saving"
        @click="saveMode('auto')"
      />
    </div>

    <div
      v-else
      class="m-4 rounded-xl bg-ds-state-danger-soft px-3 py-3 text-xs text-ds-state-danger"
      role="alert"
      aria-live="assertive"
    >
      {{ error }}
    </div>
  </section>
</template>

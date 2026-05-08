<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class -->
<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const route = useRoute();
const accountId = computed(() => route.params.accountId);

const modes = [
  { id: 'auto', label: 'IA ativa' },
  { id: 'supervised', label: 'IA supervisionada' },
  { id: 'paused', label: 'IA pausada' },
  { id: 'human_only', label: 'Humano assumiu' },
];

const copy = {
  title: 'Capitão',
  human: 'Humano',
  ai: 'IA',
  loading: 'Carregando...',
  serviceMode: 'Modo de atendimento',
  interventionReason: 'Motivo da intervencao',
  scorePrefix: 'Score atual:',
  pointsSuffix: 'pts',
  flow: 'Fluxo:',
  deal: 'Deal vinculado:',
  nextAction: 'Próxima ação',
  legalArea: 'Area:',
  documents: 'Docs:',
  owner: 'Responsável:',
  viewDeal: 'Ver deal',
  scoreDetails: 'Ver detalhes do score',
  reason: 'Motivo:',
  summary: 'Gerar resumo',
  featureSoon: 'Funcionalidade em breve',
};

const state = ref(null);
const loading = ref(false);
const saving = ref(false);
const error = ref('');
const reason = ref('');
const isScoreExpanded = ref(false);

const currentMode = computed(() => state.value?.ai_mode || 'auto');
const modeLabel = computed(
  () => modes.find(mode => mode.id === currentMode.value)?.label || 'IA ativa'
);
const modeOptions = computed(() =>
  modes.map(mode => ({ label: mode.label, value: mode.id }))
);
const humanControlled = computed(() =>
  ['paused', 'human_only'].includes(currentMode.value)
);
const controlBadgeLabel = computed(() =>
  humanControlled.value ? copy.human : copy.ai
);
const scoreValueLabel = computed(
  () => `${state.value?.score_total || 0}${copy.pointsSuffix}`
);
const scoreClassificationLabel = computed(() =>
  state.value?.score_classification
    ? `- ${state.value.score_classification}`
    : ''
);
const currentNodeLabel = computed(() =>
  state.value?.current_node_id ? `(${state.value.current_node_id})` : ''
);
const dealIdLabel = computed(() =>
  state.value?.crm_deal_id ? `#${state.value.crm_deal_id}` : ''
);
const hasCrmDealDetails = computed(
  () =>
    state.value?.crm_deal_next_best_action ||
    state.value?.crm_deal_legal_area ||
    state.value?.crm_deal_documents_status ||
    state.value?.crm_deal_owner_name
);

const handoffAt = computed(() => {
  if (!state.value?.handoff_at) return null;
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(state.value.handoff_at));
});

const handoffInitials = computed(() => {
  const name = state.value?.handoff_by_name;
  if (!name) return '?';
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0].toUpperCase())
    .join('');
});

const scoreFactorEntries = computed(() => {
  const factors = state.value?.score_factors;
  if (!factors || typeof factors !== 'object') return [];
  return Object.entries(factors)
    .filter(([, data]) => Number(data?.score || 0) > 0)
    .map(([key, data]) => ({ key, evidence: data?.evidence || '' }))
    .filter(item => item.evidence);
});

function generateSummary() {
  error.value = copy.featureSoon;
}

const crmDealUrl = computed(() => {
  if (!state.value?.crm_deal_id || !accountId.value) return '';
  return `/app/accounts/${accountId.value}/crm?deal_id=${state.value.crm_deal_id}`;
});

async function loadState() {
  if (!props.conversationId) return;
  loading.value = true;
  error.value = '';

  try {
    const { data } = await CaptainConversationStateAPI.show(
      props.conversationId
    );
    state.value = data;
    reason.value = data.handoff_reason || '';
  } catch (e) {
    const status = e?.response?.status;
    if (status === 404) {
      error.value = 'Nenhum controle de IA encontrado para esta conversa.';
    } else if (status === 401 || status === 403) {
      error.value = 'Sem permissao para acessar o controle da IA.';
    } else {
      error.value =
        e?.response?.data?.message ||
        e?.message ||
        'Não foi possível carregar o controle da IA.';
    }
  } finally {
    loading.value = false;
  }
}

async function saveMode(mode) {
  if (!props.conversationId || saving.value) return;
  saving.value = true;
  error.value = '';

  try {
    const { data } = await CaptainConversationStateAPI.update(
      props.conversationId,
      {
        ai_mode: mode,
        handoff_reason: reason.value,
      }
    );
    state.value = data;
    reason.value = data.handoff_reason || '';
  } catch (e) {
    error.value =
      e?.response?.data?.message ||
      'Não foi possível atualizar o controle da IA.';
  } finally {
    saving.value = false;
  }
}

watch(() => props.conversationId, loadState, { immediate: true });
</script>

<template>
  <div class="rounded-lg border border-n-weak bg-n-slate-1 p-3 shadow-sm">
    <div class="mb-3 flex items-center justify-between gap-2">
      <div>
        <h3
          class="text-xs font-semibold uppercase tracking-wide text-n-slate-11"
        >
          {{ copy.title }}
        </h3>
        <p class="text-xs text-n-slate-10">{{ modeLabel }}</p>
      </div>
      <span
        class="rounded-full px-2 py-0.5 text-xs font-medium"
        :class="
          humanControlled
            ? 'bg-n-ruby-3 text-n-ruby-11'
            : 'bg-n-teal-3 text-n-teal-11'
        "
      >
        {{ controlBadgeLabel }}
      </span>
    </div>

    <div v-if="loading" class="text-xs text-n-slate-10">
      {{ copy.loading }}
    </div>
    <div v-else class="space-y-3">
      <div class="flex flex-col gap-1.5 text-xs text-n-slate-11">
        <span>{{ copy.serviceMode }}</span>
        <div
          class="w-full min-w-0"
          :class="{ 'pointer-events-none opacity-60': saving }"
        >
          <SelectMenu
            :model-value="currentMode"
            :options="modeOptions"
            :label="modeLabel"
            sub-menu-position="bottom"
            class="captain-mode-menu w-full"
            @update:model-value="saveMode"
          />
        </div>
      </div>

      <label class="flex flex-col gap-1 text-xs text-n-slate-11">
        {{ copy.interventionReason }}
        <textarea
          v-model="reason"
          :disabled="saving"
          rows="2"
          class="resize-none rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12 outline-none"
          placeholder="Ex.: cliente pediu humano, caso sensível, dúvida jurídica especifica"
        />
      </label>

      <div class="flex flex-wrap gap-1">
        <NextButton
          label="Pausar IA"
          size="xs"
          color="ruby"
          variant="faded"
          :disabled="saving || humanControlled"
          @click="saveMode('paused')"
        />
        <NextButton
          label="Retomar IA"
          size="xs"
          color="teal"
          variant="faded"
          :disabled="saving || currentMode === 'auto'"
          @click="saveMode('auto')"
        />
      </div>

      <div
        v-if="state"
        class="rounded bg-n-alpha-2 p-2 text-xs text-n-slate-10 space-y-0.5"
      >
        <div class="flex flex-wrap gap-1">
          <span>{{ copy.scorePrefix }}</span>
          <span>{{ scoreValueLabel }}</span>
          <span v-if="scoreClassificationLabel">
            {{ scoreClassificationLabel }}
          </span>
        </div>
        <div v-if="state.captain_flow_name" class="flex items-center gap-1">
          <span class="i-lucide-git-branch-plus size-3" />
          <span>{{ copy.flow }}</span>
          <span>{{ state.captain_flow_name }}</span>
          <span v-if="state.current_node_id" class="text-n-slate-9">
            {{ currentNodeLabel }}
          </span>
        </div>
      </div>

      <!-- Deal link when CRM deal is associated -->
      <div
        v-if="state?.crm_deal_id"
        class="flex items-center gap-2 rounded border border-n-weak bg-n-alpha-2 p-2 text-xs"
      >
        <span class="i-lucide-briefcase size-3.5 text-n-teal-11" />
        <span class="flex flex-1 gap-1 truncate text-n-slate-11">
          <span>{{ copy.deal }}</span>
          <span class="font-medium text-n-slate-12">{{ dealIdLabel }}</span>
        </span>
        <a
          v-if="crmDealUrl"
          :href="crmDealUrl"
          class="shrink-0 rounded bg-n-teal-3 px-2 py-0.5 text-[10px] font-medium text-n-teal-11 hover:bg-n-teal-4"
        >
          {{ copy.viewDeal }}
        </a>
      </div>

      <div
        v-if="hasCrmDealDetails"
        class="rounded-lg border border-n-weak bg-n-alpha-2 p-2 text-xs text-n-slate-11"
      >
        <div v-if="state.crm_deal_next_best_action" class="mb-2">
          <div
            class="mb-1 flex items-center gap-1 font-semibold text-n-slate-12"
          >
            <span class="i-lucide-list-checks size-3.5 text-n-teal-11" />
            <span>{{ copy.nextAction }}</span>
          </div>
          <p class="m-0 leading-5">{{ state.crm_deal_next_best_action }}</p>
        </div>
        <div class="grid grid-cols-1 gap-1 text-n-slate-10">
          <div v-if="state.crm_deal_legal_area" class="flex gap-1">
            <span>{{ copy.legalArea }}</span>
            <span class="text-n-slate-12">{{ state.crm_deal_legal_area }}</span>
          </div>
          <div v-if="state.crm_deal_documents_status" class="flex gap-1">
            <span>{{ copy.documents }}</span>
            <span class="text-n-slate-12">
              {{ state.crm_deal_documents_status }}
            </span>
          </div>
          <div v-if="state.crm_deal_owner_name" class="flex gap-1">
            <span>{{ copy.owner }}</span>
            <span class="text-n-slate-12">{{ state.crm_deal_owner_name }}</span>
          </div>
        </div>
      </div>

      <div
        v-if="state && state.score_factors && scoreFactorEntries.length > 0"
        class="rounded-lg border border-n-weak"
      >
        <button
          type="button"
          class="flex w-full items-center justify-between px-3 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
          @click="isScoreExpanded = !isScoreExpanded"
        >
          <span>{{ copy.scoreDetails }}</span>
          <span
            class="size-4 text-n-slate-10"
            :class="
              isScoreExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
            "
          />
        </button>
        <div v-show="isScoreExpanded" class="space-y-1 px-3 pb-3 pt-1">
          <p
            v-for="item in scoreFactorEntries"
            :key="item.key"
            class="m-0 text-xs leading-5 text-n-slate-11"
          >
            {{ item.evidence }}
          </p>
        </div>
      </div>

      <div v-if="humanControlled && state" class="space-y-2">
        <div
          v-if="handoffAt || state.handoff_by_name"
          class="rounded-lg border border-n-weak bg-n-alpha-2 p-2 text-xs"
        >
          <p v-if="handoffAt" class="m-0 text-n-slate-10">{{ handoffAt }}</p>
          <div
            v-if="state.handoff_by_name"
            class="mt-1.5 flex items-center gap-2"
          >
            <img
              v-if="state.handoff_by_avatar"
              :src="state.handoff_by_avatar"
              :alt="state.handoff_by_name"
              class="size-5 shrink-0 rounded-full object-cover"
              @error="event => (event.target.style.display = 'none')"
            />
            <span
              v-else
              class="flex size-5 shrink-0 items-center justify-center rounded-full bg-n-ruby-3 text-[10px] font-semibold text-n-ruby-11"
            >
              {{ handoffInitials }}
            </span>
            <span class="text-n-slate-12">{{ state.handoff_by_name }}</span>
          </div>
        </div>

        <div
          v-if="state.handoff_reason"
          class="rounded border border-n-weak bg-n-alpha-2 p-2 text-xs text-n-slate-11"
        >
          <span class="font-semibold text-n-slate-12">{{ copy.reason }}</span>
          {{ state.handoff_reason }}
        </div>

        <textarea
          v-if="state.context_summary"
          :value="state.context_summary"
          readonly
          rows="3"
          class="w-full resize-none rounded-lg border border-n-weak bg-n-alpha-2 px-2 py-1.5 text-xs text-n-slate-11 outline-none"
        />

        <button
          v-if="!state.context_summary"
          type="button"
          class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12 hover:bg-n-alpha-3"
          @click="generateSummary"
        >
          {{ copy.summary }}
        </button>
      </div>

      <div v-if="error" class="text-xs text-n-ruby-10">{{ error }}</div>
    </div>
  </div>
</template>

<style scoped>
.captain-mode-menu :deep(> button) {
  width: 100%;
  max-width: none;
  justify-content: space-between;
  border: 1px solid rgb(var(--slate-6));
  background: rgb(var(--slate-2));
  color: rgb(var(--slate-12));
}

.captain-mode-menu :deep(> div) {
  width: 100%;
  max-width: none;
  background: rgb(var(--slate-2));
}
</style>

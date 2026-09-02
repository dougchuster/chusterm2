<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CaptainScoreSettingsAPI from 'dashboard/api/captain/scoreSettings';

const SCORE_COMPONENTS = [
  { key: 'fit', label: 'Aderência' },
  { key: 'urgency', label: 'Urgência' },
  { key: 'economic', label: 'Potencial econômico' },
  { key: 'documents', label: 'Documentos' },
  { key: 'clarity', label: 'Clareza do caso' },
  { key: 'engagement', label: 'Engajamento' },
  { key: 'payment_capacity', label: 'Capacidade de pagamento' },
  { key: 'conflict', label: 'Conflito' },
];

const CLASSIFICATIONS = [
  { key: 'baixo_potencial', label: 'Frio', tone: 'slate' },
  { key: 'medio_potencial', label: 'Morno', tone: 'amber' },
  { key: 'qualificado', label: 'Quente', tone: 'teal' },
  { key: 'prioridade_alta', label: 'Prioridade alta', tone: 'ruby' },
];

const AI_MODES = [
  { key: 'auto', label: 'Automático' },
  { key: 'supervised', label: 'Supervisionado' },
  { key: 'paused', label: 'Pausado' },
  { key: 'human_only', label: 'Somente humano' },
];

const isFetching = ref(false);
const isSaving = ref(false);
const isSavingState = ref(false);
const defaults = ref({});
const campaigns = ref([]);
const recentStates = ref([]);
const selectedCampaignId = ref('');
const stateForm = ref(null);

const emptyConfig = () => ({
  score_model: 'previdenciario-planejamento-v1',
  memory_enabled: true,
  triage_enabled: true,
  classification_enabled: true,
  auto_move_on_score: false,
  weights: {},
  classification_thresholds: {},
  classification_labels: {},
  stage_mapping: {},
  memory_fields: [],
  triage_required_fields: [],
});

const form = ref(emptyConfig());

const splitText = value =>
  String(value || '')
    .split(/\n|,/)
    .map(item => item.trim())
    .filter(Boolean);

const selectedCampaign = computed(
  () =>
    campaigns.value.find(
      campaign => String(campaign.id) === selectedCampaignId.value
    ) || campaigns.value[0]
);

const hasCampaigns = computed(() => campaigns.value.length > 0);

const currentSummary = computed(
  () =>
    selectedCampaign.value?.score_summary || {
      total: 0,
      frio: 0,
      morno: 0,
      quente: 0,
      prioridade_alta: 0,
      sem_classificacao: 0,
    }
);

const memoryFieldsText = computed({
  get: () => (form.value.memory_fields || []).join('\n'),
  set: value => {
    form.value.memory_fields = splitText(value);
  },
});

const triageFieldsText = computed({
  get: () => (form.value.triage_required_fields || []).join('\n'),
  set: value => {
    form.value.triage_required_fields = splitText(value);
  },
});

const mergeObject = (fallback = {}, value = {}) => ({
  ...fallback,
  ...(value || {}),
});

const hydrateConfig = config => {
  const fallback = defaults.value || {};

  return {
    ...emptyConfig(),
    ...fallback,
    ...(config || {}),
    weights: mergeObject(fallback.weights, config?.weights),
    classification_thresholds: mergeObject(
      fallback.classification_thresholds,
      config?.classification_thresholds
    ),
    classification_labels: mergeObject(
      fallback.classification_labels,
      config?.classification_labels
    ),
    stage_mapping: mergeObject(fallback.stage_mapping, config?.stage_mapping),
    memory_fields: config?.memory_fields || fallback.memory_fields || [],
    triage_required_fields:
      config?.triage_required_fields || fallback.triage_required_fields || [],
  };
};

const fetchSettings = async () => {
  isFetching.value = true;
  try {
    const response = await CaptainScoreSettingsAPI.get();
    defaults.value = response.data.defaults || {};
    campaigns.value = response.data.campaigns || [];
    recentStates.value = response.data.recent_states || [];

    if (!selectedCampaignId.value && campaigns.value.length) {
      selectedCampaignId.value = String(campaigns.value[0].id);
    }

    if (selectedCampaign.value) {
      form.value = hydrateConfig(selectedCampaign.value.scoring_config);
    }
  } catch (error) {
    useAlert('Nao foi possivel carregar o sistema de score.');
  } finally {
    isFetching.value = false;
  }
};

const saveCampaign = async () => {
  if (!selectedCampaign.value) return;

  isSaving.value = true;
  try {
    const response = await CaptainScoreSettingsAPI.updateCampaign(
      selectedCampaign.value.id,
      form.value
    );
    const updatedCampaign = response.data.campaign;
    campaigns.value = campaigns.value.map(campaign =>
      campaign.id === updatedCampaign.id ? updatedCampaign : campaign
    );
    form.value = hydrateConfig(updatedCampaign.scoring_config);
    useAlert('Sistema de score atualizado.');
  } catch (error) {
    useAlert('Nao foi possivel salvar o sistema de score.');
  } finally {
    isSaving.value = false;
  }
};

const editState = state => {
  stateForm.value = {
    id: state.id,
    conversation_display_id: state.conversation_display_id,
    contact_name: state.contact_name,
    campaign_title: state.campaign_title,
    score_total: state.score_total || 0,
    score_classification: state.score_classification || 'baixo_potencial',
    ai_mode: state.ai_mode || 'auto',
    context_summary: state.context_summary || '',
    handoff_reason: state.handoff_reason || '',
  };
};

const saveState = async () => {
  if (!stateForm.value) return;

  isSavingState.value = true;
  try {
    const response = await CaptainScoreSettingsAPI.updateConversationState(
      stateForm.value.id,
      {
        score_total: stateForm.value.score_total,
        score_classification: stateForm.value.score_classification,
        ai_mode: stateForm.value.ai_mode,
        context_summary: stateForm.value.context_summary,
        handoff_reason: stateForm.value.handoff_reason,
      }
    );

    const updatedState = response.data.state;
    recentStates.value = recentStates.value.map(state =>
      state.id === updatedState.id ? updatedState : state
    );
    stateForm.value = null;
    await fetchSettings();
    useAlert('Memória e score da conversa atualizados.');
  } catch (error) {
    useAlert('Nao foi possivel atualizar a conversa.');
  } finally {
    isSavingState.value = false;
  }
};

const formatDate = value => {
  if (!value) return '-';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const classificationLabel = classification => {
  const item = CLASSIFICATIONS.find(entry => entry.key === classification);
  return item?.label || 'Sem classificação';
};

const bucketClass = bucket => {
  const classes = {
    frio: 'bg-n-slate-3 text-n-slate-11',
    morno: 'bg-n-amber-3 text-n-amber-11',
    quente: 'bg-n-teal-3 text-n-teal-11',
    sem_classificacao: 'bg-n-slate-2 text-n-slate-10',
  };

  return classes[bucket] || classes.sem_classificacao;
};

watch(selectedCampaign, campaign => {
  if (campaign) {
    form.value = hydrateConfig(campaign.scoring_config);
  }
});

onMounted(fetchSettings);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <PageLayout
    header-title="Sistema de Score"
    :show-pagination-footer="false"
    :show-assistant-switcher="false"
    :show-know-more="false"
    :is-fetching="isFetching"
  >
    <template #body>
      <div class="flex flex-col gap-6 pb-10">
        <section
          class="flex flex-col gap-2 border-b border-n-weak pb-5 text-n-slate-11"
        >
          <h1 class="text-xl font-medium text-n-slate-12">
            Score, memória e triagem por campanha
          </h1>
          <p class="max-w-3xl text-sm">
            Ajuste manualmente os pesos, cortes de classificação e campos que a
            IA deve guardar na memória persistente de cada conversa.
          </p>
        </section>

        <div
          v-if="!hasCampaigns"
          class="rounded-lg border border-n-weak bg-n-solid-2 p-6 text-sm text-n-slate-11"
        >
          Nenhuma campanha encontrada para configurar.
        </div>

        <div v-else class="grid gap-6 xl:grid-cols-[20rem_1fr]">
          <aside class="flex flex-col gap-3">
            <h2 class="text-sm font-medium text-n-slate-12">Campanhas</h2>
            <button
              v-for="campaign in campaigns"
              :key="campaign.id"
              type="button"
              class="flex w-full flex-col gap-2 rounded-lg border p-3 text-left transition-colors"
              :class="
                selectedCampaignId === String(campaign.id)
                  ? 'border-n-brand bg-n-brand/10'
                  : 'border-n-weak bg-n-solid-2 hover:bg-n-alpha-2'
              "
              @click="selectedCampaignId = String(campaign.id)"
            >
              <span class="text-sm font-medium text-n-slate-12">
                {{ campaign.title }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ campaign.captain_assistant_name || 'Sem agente vinculado' }}
              </span>
              <span class="grid grid-cols-3 gap-1 text-center text-[11px]">
                <span class="rounded bg-n-slate-3 px-1 py-0.5">
                  F {{ campaign.score_summary.frio }}
                </span>
                <span class="rounded bg-n-amber-3 px-1 py-0.5">
                  M {{ campaign.score_summary.morno }}
                </span>
                <span class="rounded bg-n-teal-3 px-1 py-0.5">
                  Q {{ campaign.score_summary.quente }}
                </span>
              </span>
            </button>
          </aside>

          <div class="flex min-w-0 flex-col gap-6">
            <section
              class="grid gap-3 rounded-lg border border-n-weak bg-n-solid-2 p-4 sm:grid-cols-5"
            >
              <div class="sm:col-span-2">
                <p class="text-xs uppercase text-n-slate-11">Campanha</p>
                <h2 class="mt-1 text-lg font-medium text-n-slate-12">
                  {{ selectedCampaign.title }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{ selectedCampaign.inbox_name || 'Sem caixa vinculada' }}
                </p>
              </div>
              <div class="rounded-md bg-n-slate-2 p-3">
                <p class="text-xs text-n-slate-11">Frio</p>
                <p class="text-2xl font-semibold text-n-slate-12">
                  {{ currentSummary.frio }}
                </p>
              </div>
              <div class="rounded-md bg-n-amber-3 p-3">
                <p class="text-xs text-n-amber-12">Morno</p>
                <p class="text-2xl font-semibold text-n-slate-12">
                  {{ currentSummary.morno }}
                </p>
              </div>
              <div class="rounded-md bg-n-teal-3 p-3">
                <p class="text-xs text-n-teal-12">Quente</p>
                <p class="text-2xl font-semibold text-n-slate-12">
                  {{ currentSummary.quente }}
                </p>
              </div>
            </section>

            <section
              class="flex flex-col gap-5 rounded-lg border border-n-weak bg-n-solid-2 p-4"
            >
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 class="text-base font-medium text-n-slate-12">
                    Regras da campanha
                  </h2>
                  <p class="text-sm text-n-slate-11">
                    Os valores salvos aqui substituem os padroes do CRM para
                    conversas originadas nesta campanha.
                  </p>
                </div>
                <Button
                  label="Salvar regras"
                  icon="i-lucide-save"
                  size="sm"
                  :is-loading="isSaving"
                  @click="saveCampaign"
                />
              </div>

              <div class="grid gap-3 md:grid-cols-4">
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input v-model="form.memory_enabled" type="checkbox" />
                  Memória persistente
                </label>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input v-model="form.triage_enabled" type="checkbox" />
                  Triagem estruturada
                </label>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input
                    v-model="form.classification_enabled"
                    type="checkbox"
                  />
                  Classificação ativa
                </label>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input v-model="form.auto_move_on_score" type="checkbox" />
                  Sugerir etapa pelo score
                </label>
              </div>

              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Modelo de score</span>
                <input
                  v-model="form.score_model"
                  class="h-10 rounded-md border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12"
                  type="text"
                />
              </label>

              <div class="grid gap-5 lg:grid-cols-2">
                <div class="flex flex-col gap-3">
                  <h3 class="text-sm font-medium text-n-slate-12">
                    Cortes frio / morno / quente
                  </h3>
                  <div class="grid gap-3 sm:grid-cols-2">
                    <label
                      v-for="classification in CLASSIFICATIONS"
                      :key="classification.key"
                      class="flex flex-col gap-1 text-sm"
                    >
                      <span class="text-n-slate-11">
                        {{ classification.label }}
                      </span>
                      <input
                        v-model.number="
                          form.classification_thresholds[classification.key]
                        "
                        class="h-10 rounded-md border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12"
                        min="0"
                        max="100"
                        type="number"
                      />
                    </label>
                  </div>
                </div>

                <div class="flex flex-col gap-3">
                  <h3 class="text-sm font-medium text-n-slate-12">
                    Pesos do score
                  </h3>
                  <div class="grid gap-3 sm:grid-cols-2">
                    <label
                      v-for="component in SCORE_COMPONENTS"
                      :key="component.key"
                      class="flex flex-col gap-1 text-sm"
                    >
                      <span class="text-n-slate-11">{{ component.label }}</span>
                      <input
                        v-model.number="form.weights[component.key]"
                        class="h-10 rounded-md border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12"
                        min="0"
                        max="100"
                        type="number"
                      />
                    </label>
                  </div>
                </div>
              </div>

              <div class="grid gap-5 lg:grid-cols-2">
                <label class="flex flex-col gap-2 text-sm">
                  <span class="font-medium text-n-slate-12">
                    Memória persistente da conversa
                  </span>
                  <textarea
                    v-model="memoryFieldsText"
                    class="min-h-40 rounded-md border border-n-weak bg-n-alpha-1 p-3 text-sm text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-2 text-sm">
                  <span class="font-medium text-n-slate-12">
                    Campos da triagem estruturada
                  </span>
                  <textarea
                    v-model="triageFieldsText"
                    class="min-h-40 rounded-md border border-n-weak bg-n-alpha-1 p-3 text-sm text-n-slate-12"
                  />
                </label>
              </div>
            </section>

            <section
              class="grid gap-5 rounded-lg border border-n-weak bg-n-solid-2 p-4 xl:grid-cols-[1fr_20rem]"
            >
              <div class="min-w-0">
                <div class="mb-3">
                  <h2 class="text-base font-medium text-n-slate-12">
                    Memórias recentes de conversa
                  </h2>
                  <p class="text-sm text-n-slate-11">
                    Edite manualmente o resumo persistente, score e modo de IA
                    quando precisar corrigir uma triagem.
                  </p>
                </div>
                <div class="overflow-x-auto">
                  <table class="w-full min-w-[52rem] text-left text-sm">
                    <thead
                      class="border-b border-n-weak text-xs text-n-slate-10"
                    >
                      <tr>
                        <th class="py-2 pr-3 font-medium">Conversa</th>
                        <th class="py-2 pr-3 font-medium">Contato</th>
                        <th class="py-2 pr-3 font-medium">Campanha</th>
                        <th class="py-2 pr-3 font-medium">Score</th>
                        <th class="py-2 pr-3 font-medium">Classe</th>
                        <th class="py-2 pr-3 font-medium">Atualizado</th>
                        <th class="py-2 pr-3 font-medium" />
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-n-weak">
                      <tr v-for="state in recentStates" :key="state.id">
                        <td class="py-2 pr-3 text-n-slate-12">
                          {{
                            state.conversation_display_id
                              ? `#${state.conversation_display_id}`
                              : 'Sem ID público'
                          }}
                        </td>
                        <td class="py-2 pr-3 text-n-slate-11">
                          {{ state.contact_name || '-' }}
                        </td>
                        <td class="py-2 pr-3 text-n-slate-11">
                          {{ state.campaign_title || '-' }}
                        </td>
                        <td class="py-2 pr-3 text-n-slate-12">
                          {{ state.score_total || 0 }}
                        </td>
                        <td class="py-2 pr-3">
                          <span
                            class="rounded px-2 py-1 text-xs font-medium"
                            :class="bucketClass(state.score_bucket)"
                          >
                            {{
                              classificationLabel(state.score_classification)
                            }}
                          </span>
                        </td>
                        <td class="py-2 pr-3 text-n-slate-10">
                          {{ formatDate(state.updated_at) }}
                        </td>
                        <td class="py-2 pr-3 text-right">
                          <button
                            type="button"
                            class="text-n-brand hover:underline"
                            @click="editState(state)"
                          >
                            Editar
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

              <form
                v-if="stateForm"
                class="flex flex-col gap-3 rounded-md bg-n-alpha-1 p-3"
                @submit.prevent="saveState"
              >
                <div>
                  <h3 class="text-sm font-medium text-n-slate-12">
                    Editar conversa #{{ stateForm.conversation_display_id }}
                  </h3>
                  <p class="text-xs text-n-slate-10">
                    {{ stateForm.contact_name || 'Contato sem nome' }}
                  </p>
                </div>
                <label class="flex flex-col gap-1 text-sm">
                  <span class="text-n-slate-11">Score</span>
                  <input
                    v-model.number="stateForm.score_total"
                    class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3"
                    min="0"
                    max="100"
                    type="number"
                  />
                </label>
                <label class="flex flex-col gap-1 text-sm">
                  <span class="text-n-slate-11">Classificação</span>
                  <select
                    v-model="stateForm.score_classification"
                    class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3"
                  >
                    <option
                      v-for="classification in CLASSIFICATIONS"
                      :key="classification.key"
                      :value="classification.key"
                    >
                      {{ classification.label }}
                    </option>
                  </select>
                </label>
                <label class="flex flex-col gap-1 text-sm">
                  <span class="text-n-slate-11">Modo da IA</span>
                  <select
                    v-model="stateForm.ai_mode"
                    class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3"
                  >
                    <option
                      v-for="mode in AI_MODES"
                      :key="mode.key"
                      :value="mode.key"
                    >
                      {{ mode.label }}
                    </option>
                  </select>
                </label>
                <label class="flex flex-col gap-1 text-sm">
                  <span class="text-n-slate-11">Resumo persistente</span>
                  <textarea
                    v-model="stateForm.context_summary"
                    class="min-h-28 rounded-md border border-n-weak bg-n-solid-1 p-3"
                  />
                </label>
                <label class="flex flex-col gap-1 text-sm">
                  <span class="text-n-slate-11">Motivo de handoff</span>
                  <textarea
                    v-model="stateForm.handoff_reason"
                    class="min-h-20 rounded-md border border-n-weak bg-n-solid-1 p-3"
                  />
                </label>
                <div class="flex justify-end gap-2">
                  <Button
                    label="Cancelar"
                    color="slate"
                    variant="ghost"
                    size="sm"
                    @click="stateForm = null"
                  />
                  <Button
                    label="Salvar"
                    icon="i-lucide-save"
                    size="sm"
                    :is-loading="isSavingState"
                    @click="saveState"
                  />
                </div>
              </form>
              <div
                v-else
                class="flex min-h-60 items-center justify-center rounded-md bg-n-alpha-1 p-4 text-center text-sm text-n-slate-10"
              >
                Selecione uma conversa para editar manualmente a memória,
                triagem e classificação.
              </div>
            </section>
          </div>
        </div>
      </div>
    </template>
  </PageLayout>
</template>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import CrmAPI from 'dashboard/api/crm';
import CampaignsAPI from 'dashboard/api/campaigns';

const SCORING_CRITERIA = [
  {
    key: 'fit',
    label: 'Aderência à área jurídica',
    default: 20,
    description: 'Lead tem área jurídica identificada',
  },
  {
    key: 'urgency',
    label: 'Urgência / Prazo',
    default: 15,
    description: 'Nível de urgência ou prazo judicial',
  },
  {
    key: 'economic',
    label: 'Potencial econômico',
    default: 15,
    description: 'Valor estimado do caso',
  },
  {
    key: 'documents',
    label: 'Documentação',
    default: 15,
    description: 'Status dos documentos enviados',
  },
  {
    key: 'clarity',
    label: 'Clareza dos fatos',
    default: 10,
    description: 'Resumo e tipo de caso preenchidos',
  },
  {
    key: 'engagement',
    label: 'Engajamento do cliente',
    default: 10,
    description: 'Nível de resposta e interação',
  },
  {
    key: 'payment_capacity',
    label: 'Capacidade de contratação',
    default: 10,
    description: 'Informação de capacidade financeira',
  },
  {
    key: 'conflict',
    label: 'Ausência de conflito de interesses',
    default: 5,
    description: 'Verificação de conflito concluída',
  },
];

const DEFAULT_WEIGHTS = Object.fromEntries(
  SCORING_CRITERIA.map(c => [c.key, c.default])
);

const DEFAULT_THRESHOLDS = {
  baixo_potencial: 0,
  medio_potencial: 40,
  qualificado: 60,
  prioridade_alta: 80,
};

const DEFAULT_STAGE_MAPPING = {
  baixo_potencial: 'novo-atendimento',
  medio_potencial: 'triagem-ia',
  qualificado: 'qualificado',
  prioridade_alta: 'consulta-reuniao',
};

const CLASSIFICATIONS = [
  { key: 'baixo_potencial', label: 'Baixo potencial' },
  { key: 'medio_potencial', label: 'Medio potencial' },
  { key: 'qualificado', label: 'Qualificado' },
  { key: 'prioridade_alta', label: 'Prioridade alta' },
];

const pipelines = ref([]);
const campaigns = ref([]);
const loading = ref(true);
const error = ref('');

const configs = reactive({});
const campaignConfigs = reactive({});
const saving = reactive({});
const campaignSaving = reactive({});
const savedOk = reactive({});
const campaignSavedOk = reactive({});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

function buildConfig(stored = {}) {
  const hasStored =
    stored && typeof stored === 'object' && Object.keys(stored).length > 0;
  const storedWeights = stored?.weights || stored || {};

  return {
    weights: Object.fromEntries(
      SCORING_CRITERIA.map(c => [
        c.key,
        hasStored && storedWeights[c.key] != null
          ? Number(storedWeights[c.key])
          : c.default,
      ])
    ),
    thresholds: {
      ...DEFAULT_THRESHOLDS,
      ...(stored?.classification_thresholds || stored?.thresholds || {}),
    },
    stageMapping: {
      ...DEFAULT_STAGE_MAPPING,
      ...(stored?.stage_mapping || {}),
    },
    autoMoveOnScore: stored?.auto_move_on_score !== false,
    pipelineId: stored?.crm_pipeline_id || '',
  };
}

function initConfig(pipeline) {
  configs[pipeline.id] = buildConfig(pipeline.scoring_config || {});
}

function initCampaignConfig(campaign) {
  campaignConfigs[campaign.id] = buildConfig(campaign.scoring_config || {});
  campaignConfigs[campaign.id].pipelineId =
    campaign.scoring_config?.crm_pipeline_id || pipelines.value[0]?.id || '';
}

async function loadData() {
  loading.value = true;
  error.value = '';
  try {
    const [pipelineRes, campaignRes] = await Promise.all([
      CrmAPI.getPipelines(),
      CampaignsAPI.get(),
    ]);
    pipelines.value = extractData(pipelineRes);
    campaigns.value = extractData(campaignRes);
    pipelines.value.forEach(initConfig);
    campaigns.value.forEach(initCampaignConfig);
  } catch {
    error.value = 'Erro ao carregar configurações de scoring';
  } finally {
    loading.value = false;
  }
}

function total(pipelineId) {
  return SCORING_CRITERIA.reduce(
    (sum, c) => sum + (Number(configs[pipelineId]?.weights?.[c.key]) || 0),
    0
  );
}

const totalFor = computed(() =>
  Object.fromEntries(pipelines.value.map(p => [p.id, total(p.id)]))
);

function campaignTotal(campaignId) {
  return SCORING_CRITERIA.reduce(
    (sum, c) =>
      sum + (Number(campaignConfigs[campaignId]?.weights?.[c.key]) || 0),
    0
  );
}

const campaignTotalFor = computed(() =>
  Object.fromEntries(campaigns.value.map(c => [c.id, campaignTotal(c.id)]))
);

function buildScoringPayload(config, { includePipelineId = false } = {}) {
  const payload = {
    weights: { ...config.weights },
    classification_thresholds: { ...config.thresholds },
    stage_mapping: { ...config.stageMapping },
    auto_move_on_score: config.autoMoveOnScore,
  };

  if (includePipelineId) {
    payload.crm_pipeline_id = config.pipelineId || null;
  }

  return payload;
}

async function savePipeline(pipeline) {
  saving[pipeline.id] = true;
  error.value = '';
  try {
    const config = configs[pipeline.id];
    await CrmAPI.updatePipeline(pipeline.id, {
      scoring_config: buildScoringPayload(config),
    });
    savedOk[pipeline.id] = true;
    setTimeout(() => {
      savedOk[pipeline.id] = false;
    }, 2000);
  } catch {
    error.value = `Erro ao salvar configuração do pipeline "${pipeline.name}"`;
  } finally {
    saving[pipeline.id] = false;
  }
}

async function saveCampaign(campaign) {
  campaignSaving[campaign.id] = true;
  error.value = '';
  try {
    await CampaignsAPI.update(campaign.id, {
      scoring_config: buildScoringPayload(campaignConfigs[campaign.id], {
        includePipelineId: true,
      }),
    });
    campaignSavedOk[campaign.id] = true;
    setTimeout(() => {
      campaignSavedOk[campaign.id] = false;
    }, 2000);
  } catch {
    error.value = `Erro ao salvar scoring da campanha "${campaign.title}"`;
  } finally {
    campaignSaving[campaign.id] = false;
  }
}

async function clearCampaignOverride(campaign) {
  campaignConfigs[campaign.id] = buildConfig({});
  campaignConfigs[campaign.id].pipelineId = pipelines.value[0]?.id || '';
  await CampaignsAPI.update(campaign.id, { scoring_config: {} });
  campaignSavedOk[campaign.id] = true;
  setTimeout(() => {
    campaignSavedOk[campaign.id] = false;
  }, 2000);
}

async function restoreDefaults(pipeline) {
  configs[pipeline.id].weights = { ...DEFAULT_WEIGHTS };
  configs[pipeline.id].thresholds = { ...DEFAULT_THRESHOLDS };
  configs[pipeline.id].stageMapping = { ...DEFAULT_STAGE_MAPPING };
  configs[pipeline.id].autoMoveOnScore = true;
  await savePipeline(pipeline);
}

function isDefault(pipelineId) {
  return SCORING_CRITERIA.every(
    c => configs[pipelineId]?.weights?.[c.key] === c.default
  );
}

function stageOptions(pipeline) {
  return pipeline.stages || [];
}

function pipelineForCampaign(campaignId) {
  const pipelineId = Number(campaignConfigs[campaignId]?.pipelineId);
  return (
    pipelines.value.find(pipeline => pipeline.id === pipelineId) ||
    pipelines.value[0]
  );
}

function campaignHasOverride(campaign) {
  return Object.keys(campaign.scoring_config || {}).length > 0;
}

onMounted(loadData);
</script>

<template>
  <div class="crm-scoring-page flex h-full flex-col overflow-auto p-4 sm:p-6">
    <div class="mb-6">
      <h1 class="text-xl font-bold text-n-slate-12">Configurador de Scoring</h1>
      <p class="text-sm text-n-slate-10">
        Defina os pesos de cada critério de pontuação por pipeline. A soma deve
        ser 100 para scoring calibrado.
      </p>
    </div>

    <div
      v-if="error"
      class="mb-4 rounded-xl border border-n-ruby-7 bg-n-ruby-2 px-4 py-3 text-sm text-n-ruby-11"
    >
      {{ error }}
    </div>

    <div
      v-if="loading"
      class="flex flex-1 items-center justify-center text-n-slate-10"
    >
      Carregando...
    </div>

    <div
      v-else-if="pipelines.length === 0"
      class="flex flex-1 flex-col items-center justify-center gap-4 text-n-slate-10"
    >
      <span class="i-lucide-sliders-horizontal size-12 text-n-slate-7" />
      <p class="text-lg font-medium">Nenhum pipeline encontrado</p>
    </div>

    <div v-else class="flex flex-col gap-6">
      <div
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        class="rounded-2xl border border-n-weak bg-n-slate-1 p-5"
      >
        <div class="mb-4 flex items-center gap-3">
          <div
            class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-n-slate-3"
          >
            <span
              class="i-lucide-sliders-horizontal size-[18px] text-n-slate-11"
            />
          </div>
          <div class="flex min-w-0 flex-1 items-center gap-2">
            <h2 class="text-base font-bold text-n-slate-12">
              {{ pipeline.name }}
            </h2>
            <span
              v-if="isDefault(pipeline.id)"
              class="rounded-lg bg-n-slate-3 px-2 py-0.5 text-xs font-medium text-n-slate-9"
            >
              padrão
            </span>
          </div>
        </div>

        <div
          class="mb-1 grid grid-cols-[1fr_80px_96px] gap-x-3 border-b border-n-weak pb-2"
        >
          <span class="text-xs font-semibold text-n-slate-10">Critério</span>
          <span class="text-xs font-semibold text-n-slate-10 text-center"
            >Peso</span
          >
          <span class="text-xs font-semibold text-n-slate-10 text-center"
            >Padrão</span
          >
        </div>

        <div class="flex flex-col divide-y divide-n-weak">
          <div
            v-for="criterion in SCORING_CRITERIA"
            :key="criterion.key"
            class="grid grid-cols-[1fr_80px_96px] items-center gap-x-3 py-2.5"
          >
            <div>
              <p class="text-sm text-n-slate-12">{{ criterion.label }}</p>
              <p class="text-xs text-n-slate-9">{{ criterion.description }}</p>
            </div>
            <input
              v-if="configs[pipeline.id]"
              v-model.number="configs[pipeline.id].weights[criterion.key]"
              type="number"
              min="0"
              max="100"
              class="w-full rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-center text-sm text-n-slate-12 outline-none focus:border-n-brand"
            />
            <span class="text-center text-xs text-n-slate-9">
              (padrão: {{ criterion.default }})
            </span>
          </div>
        </div>

        <div
          v-if="configs[pipeline.id]"
          class="mt-5 grid gap-4 border-t border-n-weak pt-4 lg:grid-cols-2"
        >
          <div>
            <div class="mb-3 flex items-center justify-between gap-2">
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  Faixas de classificacao
                </h3>
                <p class="text-xs text-n-slate-9">
                  Defina a pontuacao minima para cada categoria.
                </p>
              </div>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <label
                v-for="classification in CLASSIFICATIONS"
                :key="classification.key"
                class="flex flex-col gap-1 text-xs text-n-slate-10"
              >
                {{ classification.label }}
                <input
                  v-model.number="
                    configs[pipeline.id].thresholds[classification.key]
                  "
                  type="number"
                  min="0"
                  max="100"
                  class="rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
            </div>
          </div>

          <div>
            <div class="mb-3 flex items-center justify-between gap-2">
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  Mover no Kanban
                </h3>
                <p class="text-xs text-n-slate-9">
                  Escolha a etapa de destino para cada categoria.
                </p>
              </div>
              <label class="flex items-center gap-2 text-xs text-n-slate-10">
                <input
                  v-model="configs[pipeline.id].autoMoveOnScore"
                  type="checkbox"
                />
                Auto
              </label>
            </div>
            <div class="grid grid-cols-1 gap-2">
              <label
                v-for="classification in CLASSIFICATIONS"
                :key="classification.key"
                class="flex flex-col gap-1 text-xs text-n-slate-10"
              >
                {{ classification.label }}
                <select
                  v-model="
                    configs[pipeline.id].stageMapping[classification.key]
                  "
                  class="rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">Não mover</option>
                  <option
                    v-for="stage in stageOptions(pipeline)"
                    :key="stage.id"
                    :value="stage.slug"
                  >
                    {{ stage.name }}
                  </option>
                </select>
              </label>
            </div>
          </div>
        </div>

        <div class="mt-4 border-t border-n-weak pt-4">
          <div class="mb-3 flex items-center gap-2">
            <span class="text-sm font-semibold text-n-slate-11">Total:</span>
            <span
              class="text-sm font-bold"
              :class="
                totalFor[pipeline.id] === 100
                  ? 'text-n-teal-11'
                  : 'text-amber-600'
              "
            >
              {{ totalFor[pipeline.id] }}
            </span>
            <span
              v-if="totalFor[pipeline.id] === 100"
              class="text-xs text-n-teal-11"
            >
              — scoring calibrado
            </span>
            <span v-else class="text-xs text-amber-600">
              — Atenção: total deve ser 100 para scoring preciso
            </span>
          </div>

          <div
            v-if="savedOk[pipeline.id]"
            class="mb-3 rounded-xl border border-n-teal-7 bg-n-teal-2 px-4 py-3 text-sm text-n-teal-11"
          >
            Salvo com sucesso
          </div>

          <div class="flex items-center justify-end gap-2">
            <button
              class="rounded-lg px-4 py-2 text-sm font-medium text-n-slate-10 transition hover:bg-n-slate-3"
              :disabled="saving[pipeline.id]"
              @click="restoreDefaults(pipeline)"
            >
              Restaurar padrões
            </button>
            <button
              class="inline-flex items-center gap-1.5 rounded-xl bg-n-brand px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
              :disabled="saving[pipeline.id]"
              @click="savePipeline(pipeline)"
            >
              {{ saving[pipeline.id] ? 'Salvando...' : 'Salvar configuração' }}
            </button>
          </div>
        </div>
      </div>

      <div class="mt-2 border-t border-n-weak pt-6">
        <div class="mb-4">
          <h2 class="text-lg font-bold text-n-slate-12">
            Overrides por campanha
          </h2>
          <p class="text-sm text-n-slate-10">
            Use quando uma campanha precisar de pesos, faixas ou etapas
            diferentes do pipeline padrão. Ex.: uma campanha de aposentadoria,
            uma ação trabalhista ou qualquer outro nicho.
          </p>
        </div>

        <div
          v-if="campaigns.length === 0"
          class="rounded-xl border border-dashed border-n-weak p-4 text-sm text-n-slate-10"
        >
          Nenhuma campanha encontrada.
        </div>

        <div v-else class="flex flex-col gap-4">
          <div
            v-for="campaign in campaigns"
            :key="campaign.id"
            class="rounded-2xl border border-n-weak bg-n-slate-1 p-5"
          >
            <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <h3 class="truncate text-base font-bold text-n-slate-12">
                    {{ campaign.title }}
                  </h3>
                  <span
                    v-if="campaignHasOverride(campaign)"
                    class="rounded-lg bg-n-slate-3 px-2 py-0.5 text-xs font-medium text-n-slate-9"
                  >
                    override ativo
                  </span>
                </div>
                <p class="text-xs text-n-slate-9">
                  {{ campaign.campaign_type }} - {{ campaign.inbox?.name }}
                </p>
              </div>

              <label
                v-if="campaignConfigs[campaign.id]"
                class="flex min-w-[220px] flex-col gap-1 text-xs text-n-slate-10"
              >
                Pipeline de referência
                <select
                  v-model="campaignConfigs[campaign.id].pipelineId"
                  class="rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option
                    v-for="pipeline in pipelines"
                    :key="pipeline.id"
                    :value="pipeline.id"
                  >
                    {{ pipeline.name }}
                  </option>
                </select>
              </label>
            </div>

            <div
              v-if="campaignConfigs[campaign.id]"
              class="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]"
            >
              <div>
                <div
                  class="mb-1 grid grid-cols-[1fr_80px] gap-x-3 border-b border-n-weak pb-2"
                >
                  <span class="text-xs font-semibold text-n-slate-10">
                    Criterio
                  </span>
                  <span
                    class="text-center text-xs font-semibold text-n-slate-10"
                  >
                    Peso
                  </span>
                </div>
                <div class="flex flex-col divide-y divide-n-weak">
                  <div
                    v-for="criterion in SCORING_CRITERIA"
                    :key="criterion.key"
                    class="grid grid-cols-[1fr_80px] items-center gap-x-3 py-2"
                  >
                    <div>
                      <p class="text-sm text-n-slate-12">
                        {{ criterion.label }}
                      </p>
                      <p class="text-xs text-n-slate-9">
                        {{ criterion.description }}
                      </p>
                    </div>
                    <input
                      v-model.number="
                        campaignConfigs[campaign.id].weights[criterion.key]
                      "
                      type="number"
                      min="0"
                      max="100"
                      class="w-full rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-center text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    />
                  </div>
                </div>
              </div>

              <div class="grid gap-4">
                <div>
                  <h4 class="mb-2 text-sm font-semibold text-n-slate-12">
                    Faixas
                  </h4>
                  <div class="grid grid-cols-2 gap-2">
                    <label
                      v-for="classification in CLASSIFICATIONS"
                      :key="classification.key"
                      class="flex flex-col gap-1 text-xs text-n-slate-10"
                    >
                      {{ classification.label }}
                      <input
                        v-model.number="
                          campaignConfigs[campaign.id].thresholds[
                            classification.key
                          ]
                        "
                        type="number"
                        min="0"
                        max="100"
                        class="rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                      />
                    </label>
                  </div>
                </div>

                <div>
                  <div class="mb-2 flex items-center justify-between gap-2">
                    <h4 class="text-sm font-semibold text-n-slate-12">
                      Kanban
                    </h4>
                    <label
                      class="flex items-center gap-2 text-xs text-n-slate-10"
                    >
                      <input
                        v-model="campaignConfigs[campaign.id].autoMoveOnScore"
                        type="checkbox"
                      />
                      Auto
                    </label>
                  </div>
                  <div class="grid grid-cols-1 gap-2">
                    <label
                      v-for="classification in CLASSIFICATIONS"
                      :key="classification.key"
                      class="flex flex-col gap-1 text-xs text-n-slate-10"
                    >
                      {{ classification.label }}
                      <select
                        v-model="
                          campaignConfigs[campaign.id].stageMapping[
                            classification.key
                          ]
                        "
                        class="rounded-lg border border-n-weak bg-n-slate-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                      >
                        <option value="">Não mover</option>
                        <option
                          v-for="stage in stageOptions(
                            pipelineForCampaign(campaign.id)
                          )"
                          :key="stage.id"
                          :value="stage.slug"
                        >
                          {{ stage.name }}
                        </option>
                      </select>
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-4 border-t border-n-weak pt-4">
              <div class="mb-3 flex items-center gap-2">
                <span class="text-sm font-semibold text-n-slate-11">
                  Total:
                </span>
                <span
                  class="text-sm font-bold"
                  :class="
                    campaignTotalFor[campaign.id] === 100
                      ? 'text-n-teal-11'
                      : 'text-amber-600'
                  "
                >
                  {{ campaignTotalFor[campaign.id] }}
                </span>
              </div>

              <div
                v-if="campaignSavedOk[campaign.id]"
                class="mb-3 rounded-xl border border-n-teal-7 bg-n-teal-2 px-4 py-3 text-sm text-n-teal-11"
              >
                Salvo com sucesso
              </div>

              <div class="flex flex-wrap items-center justify-end gap-2">
                <button
                  class="rounded-lg px-4 py-2 text-sm font-medium text-n-slate-10 transition hover:bg-n-slate-3"
                  :disabled="campaignSaving[campaign.id]"
                  @click="clearCampaignOverride(campaign)"
                >
                  Remover override
                </button>
                <button
                  class="inline-flex items-center gap-1.5 rounded-xl bg-n-brand px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
                  :disabled="
                    campaignSaving[campaign.id] ||
                    campaignTotalFor[campaign.id] !== 100
                  "
                  @click="saveCampaign(campaign)"
                >
                  {{
                    campaignSaving[campaign.id]
                      ? 'Salvando...'
                      : 'Salvar campanha'
                  }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.crm-scoring-page {
  width: 100%;
  min-width: 0;
  color: rgb(var(--slate-12));
}

.crm-scoring-page :deep(*) {
  min-width: 0;
}

.crm-scoring-page :deep(input),
.crm-scoring-page :deep(select),
.crm-scoring-page :deep(textarea) {
  width: 100%;
  color: rgb(var(--slate-12));
}

@media (max-width: 640px) {
  .crm-scoring-page :deep(.grid-cols-\[1fr_80px_96px\]),
  .crm-scoring-page :deep(.grid-cols-\[1fr_80px\]) {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>

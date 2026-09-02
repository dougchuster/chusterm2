<script setup>
import { computed, reactive, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

import CrmAPI from 'dashboard/api/crm';
import CampaignsAPI from 'dashboard/api/campaigns';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsCheckbox,
  DsEmptyState,
  DsInput,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();

const SCORING_CRITERIA = [
  { key: 'fit', default: 20 },
  { key: 'urgency', default: 15 },
  { key: 'economic', default: 15 },
  { key: 'documents', default: 15 },
  { key: 'clarity', default: 10 },
  { key: 'engagement', default: 10 },
  { key: 'payment_capacity', default: 10 },
  { key: 'conflict', default: 5 },
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

const CLASSIFICATION_KEYS = [
  'baixo_potencial',
  'medio_potencial',
  'qualificado',
  'prioridade_alta',
];

const criterionCopy = computed(() => ({
  fit: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.FIT.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.FIT.DESCRIPTION'),
  },
  urgency: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.URGENCY.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.URGENCY.DESCRIPTION'),
  },
  economic: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.ECONOMIC.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.ECONOMIC.DESCRIPTION'),
  },
  documents: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.DOCUMENTS.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.DOCUMENTS.DESCRIPTION'),
  },
  clarity: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.CLARITY.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.CLARITY.DESCRIPTION'),
  },
  engagement: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.ENGAGEMENT.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.ENGAGEMENT.DESCRIPTION'),
  },
  payment_capacity: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.PAYMENT_CAPACITY.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.PAYMENT_CAPACITY.DESCRIPTION'),
  },
  conflict: {
    label: t('CRM.SCORING_CONFIG.CRITERIA.CONFLICT.LABEL'),
    description: t('CRM.SCORING_CONFIG.CRITERIA.CONFLICT.DESCRIPTION'),
  },
}));

const criteria = computed(() =>
  SCORING_CRITERIA.map(c => ({ ...c, ...criterionCopy.value[c.key] }))
);

const classificationLabels = computed(() => ({
  baixo_potencial: t('CRM.SCORING_CONFIG.CLASSIFICATIONS.BAIXO_POTENCIAL'),
  medio_potencial: t('CRM.SCORING_CONFIG.CLASSIFICATIONS.MEDIO_POTENCIAL'),
  qualificado: t('CRM.SCORING_CONFIG.CLASSIFICATIONS.QUALIFICADO'),
  prioridade_alta: t('CRM.SCORING_CONFIG.CLASSIFICATIONS.PRIORIDADE_ALTA'),
}));

const classifications = computed(() =>
  CLASSIFICATION_KEYS.map(key => ({
    key,
    label: classificationLabels.value[key],
  }))
);

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

const pipelineOptions = computed(() =>
  pipelines.value.map(p => ({ value: p.id, label: p.name }))
);

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
    autoMoveOnScore: stored?.auto_move_on_score === true,
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
    error.value = t('CRM.SCORING_CONFIG.LOAD_ERROR');
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
    // DsSelect emite string; a API espera o id numerico do pipeline.
    payload.crm_pipeline_id = config.pipelineId
      ? Number(config.pipelineId)
      : null;
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
    error.value = t('CRM.SCORING_CONFIG.SAVE_PIPELINE_ERROR', {
      name: pipeline.name,
    });
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
    error.value = t('CRM.SCORING_CONFIG.CAMPAIGNS.SAVE_ERROR', {
      title: campaign.title,
    });
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
  return pipeline?.stages || [];
}

function stageSelectOptions(pipeline) {
  return [
    { value: '', label: t('CRM.SCORING_CONFIG.NO_STAGE') },
    ...stageOptions(pipeline).map(stage => ({
      value: stage.slug,
      label: stage.name,
    })),
  ];
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

function campaignMeta(campaign) {
  return [campaign.campaign_type, campaign.inbox?.name]
    .filter(Boolean)
    .join(' - ');
}

onMounted(loadData);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="$t('CRM.SCORING_CONFIG.TITLE')"
      :breadcrumbs="[
        { label: $t('CRM.SCORING_CONFIG.BREADCRUMB') },
        { label: $t('CRM.SCORING_CONFIG.TITLE') },
      ]"
    />

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <p class="m-0 max-w-2xl text-ui-body-sm text-ui-text-muted">
        {{ $t('CRM.SCORING_CONFIG.SUBTITLE') }}
      </p>

      <div
        v-if="error"
        role="alert"
        class="rounded-ui-surface border border-ui-danger/20 bg-ui-danger-soft px-4 py-3 text-ui-body-sm text-ui-danger-foreground"
      >
        {{ error }}
      </div>

      <div
        v-if="loading"
        role="status"
        :aria-label="$t('CRM.SCORING_CONFIG.LOADING')"
        class="flex flex-col gap-4"
      >
        <span class="sr-only">{{ $t('CRM.SCORING_CONFIG.LOADING') }}</span>
        <DsSkeleton shape="block" class="h-72" />
        <DsSkeleton shape="block" class="h-72" />
      </div>

      <DsEmptyState
        v-else-if="!pipelines.length"
        :title="$t('CRM.SCORING_CONFIG.EMPTY_PIPELINES')"
      />

      <template v-else>
        <DsCard
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          as="section"
          :aria-label="pipeline.name"
        >
          <div class="mb-4 flex items-center gap-3">
            <div
              class="flex size-9 shrink-0 items-center justify-center rounded-ui-surface bg-ui-sunken"
            >
              <Icon
                icon="i-lucide-sliders-horizontal"
                class="size-5 text-ui-text-muted"
                aria-hidden="true"
              />
            </div>
            <div class="flex min-w-0 flex-1 flex-wrap items-center gap-2">
              <h2
                class="m-0 font-manrope text-ui-heading font-semibold text-ui-text"
              >
                {{ pipeline.name }}
              </h2>
              <DsBadge
                v-if="isDefault(pipeline.id)"
                :label="$t('CRM.SCORING_CONFIG.DEFAULT_BADGE')"
              />
            </div>
          </div>

          <div
            class="mb-1 hidden gap-x-3 border-b border-ui-border-subtle pb-2 sm:grid sm:grid-cols-[minmax(0,1fr)_5rem_6rem]"
          >
            <span class="text-ui-caption font-semibold text-ui-text-muted">
              {{ $t('CRM.SCORING_CONFIG.CRITERIA_HEADER') }}
            </span>
            <span
              class="text-center text-ui-caption font-semibold text-ui-text-muted"
            >
              {{ $t('CRM.SCORING_CONFIG.WEIGHT_HEADER') }}
            </span>
            <span
              class="text-center text-ui-caption font-semibold text-ui-text-muted"
            >
              {{ $t('CRM.SCORING_CONFIG.DEFAULT_HEADER') }}
            </span>
          </div>

          <div class="flex flex-col divide-y divide-ui-border-subtle">
            <div
              v-for="criterion in criteria"
              :key="criterion.key"
              class="grid gap-2 py-2.5 sm:grid-cols-[minmax(0,1fr)_5rem_6rem] sm:items-center sm:gap-x-3"
            >
              <div class="min-w-0">
                <p class="m-0 text-ui-body-sm text-ui-text">
                  {{ criterion.label }}
                </p>
                <p class="m-0 text-ui-caption text-ui-text-muted">
                  {{ criterion.description }}
                </p>
              </div>
              <DsInput
                v-if="configs[pipeline.id]"
                v-model="configs[pipeline.id].weights[criterion.key]"
                type="number"
                min="0"
                max="100"
                :label="
                  $t('CRM.SCORING_CONFIG.WEIGHT_ARIA', {
                    criterion: criterion.label,
                  })
                "
                hide-label
                class="text-center"
              />
              <span class="text-ui-caption text-ui-text-muted sm:text-center">
                {{
                  $t('CRM.SCORING_CONFIG.DEFAULT_VALUE', {
                    value: criterion.default,
                  })
                }}
              </span>
            </div>
          </div>

          <div
            v-if="configs[pipeline.id]"
            class="mt-5 grid gap-4 border-t border-ui-border-subtle pt-4 lg:grid-cols-2"
          >
            <div>
              <h3
                class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
              >
                {{ $t('CRM.SCORING_CONFIG.THRESHOLDS_TITLE') }}
              </h3>
              <p class="m-0 mb-3 mt-1 text-ui-caption text-ui-text-muted">
                {{ $t('CRM.SCORING_CONFIG.THRESHOLDS_SUBTITLE') }}
              </p>
              <div class="grid grid-cols-2 gap-2">
                <DsInput
                  v-for="classification in classifications"
                  :key="classification.key"
                  v-model="
                    configs[pipeline.id].thresholds[classification.key]
                  "
                  type="number"
                  min="0"
                  max="100"
                  :label="classification.label"
                />
              </div>
            </div>

            <div>
              <div class="mb-3 flex items-start justify-between gap-2">
                <div>
                  <h3
                    class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
                  >
                    {{ $t('CRM.SCORING_CONFIG.KANBAN_TITLE') }}
                  </h3>
                  <p class="m-0 mt-1 text-ui-caption text-ui-text-muted">
                    {{ $t('CRM.SCORING_CONFIG.KANBAN_SUBTITLE') }}
                  </p>
                </div>
                <DsCheckbox
                  v-model="configs[pipeline.id].autoMoveOnScore"
                  :label="$t('CRM.SCORING_CONFIG.AUTO_MOVE')"
                  class="mt-1"
                />
              </div>
              <div class="grid grid-cols-1 gap-2">
                <DsSelect
                  v-for="classification in classifications"
                  :key="classification.key"
                  v-model="
                    configs[pipeline.id].stageMapping[classification.key]
                  "
                  :label="classification.label"
                  :options="stageSelectOptions(pipeline)"
                />
              </div>
            </div>
          </div>

          <div class="mt-4 border-t border-ui-border-subtle pt-4">
            <div class="mb-3 flex items-center gap-2" aria-live="polite">
              <span class="text-ui-label font-semibold text-ui-text">
                {{ $t('CRM.SCORING_CONFIG.TOTAL_LABEL') }}
              </span>
              <span
                class="text-ui-label font-semibold"
                :class="
                  totalFor[pipeline.id] === 100
                    ? 'text-ui-success'
                    : 'text-ui-warning'
                "
              >
                {{ totalFor[pipeline.id] }}
              </span>
              <span
                v-if="totalFor[pipeline.id] === 100"
                class="inline-flex items-center gap-1 text-ui-caption text-ui-success"
              >
                <Icon
                  icon="i-lucide-circle-check"
                  class="size-3.5"
                  aria-hidden="true"
                />
                {{ $t('CRM.SCORING_CONFIG.TOTAL_OK') }}
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 text-ui-caption text-ui-warning"
              >
                <Icon
                  icon="i-lucide-triangle-alert"
                  class="size-3.5"
                  aria-hidden="true"
                />
                {{ $t('CRM.SCORING_CONFIG.TOTAL_WARNING') }}
              </span>
            </div>

            <div
              v-if="savedOk[pipeline.id]"
              role="status"
              class="mb-3 rounded-ui-surface border border-ui-success/20 bg-ui-success-soft px-4 py-3 text-ui-body-sm text-ui-success-foreground"
            >
              {{ $t('CRM.SCORING_CONFIG.SAVED') }}
            </div>

            <div class="flex flex-wrap items-center justify-end gap-2">
              <DsButton
                variant="ghost"
                :label="$t('CRM.SCORING_CONFIG.RESTORE_DEFAULTS')"
                :disabled="saving[pipeline.id]"
                @click="restoreDefaults(pipeline)"
              />
              <DsButton
                variant="primary"
                :label="
                  saving[pipeline.id]
                    ? $t('CRM.SCORING_CONFIG.SAVING')
                    : $t('CRM.SCORING_CONFIG.SAVE')
                "
                :loading="saving[pipeline.id]"
                @click="savePipeline(pipeline)"
              />
            </div>
          </div>
        </DsCard>

        <section
          aria-labelledby="scoring-campaigns-title"
          class="mt-2 border-t border-ui-border-subtle pt-6"
        >
          <div class="mb-4">
            <h2
              id="scoring-campaigns-title"
              class="m-0 font-manrope text-ui-title font-semibold text-ui-text"
            >
              {{ $t('CRM.SCORING_CONFIG.CAMPAIGNS.TITLE') }}
            </h2>
            <p class="m-0 mt-1 max-w-2xl text-ui-body-sm text-ui-text-muted">
              {{ $t('CRM.SCORING_CONFIG.CAMPAIGNS.SUBTITLE') }}
            </p>
          </div>

          <DsEmptyState
            v-if="!campaigns.length"
            :title="$t('CRM.SCORING_CONFIG.CAMPAIGNS.EMPTY')"
          />

          <div v-else class="flex flex-col gap-4">
            <DsCard
              v-for="campaign in campaigns"
              :key="campaign.id"
              as="article"
              :aria-label="campaign.title"
            >
              <div
                class="mb-4 flex flex-wrap items-start justify-between gap-3"
              >
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <h3
                      class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
                    >
                      {{ campaign.title }}
                    </h3>
                    <DsBadge
                      v-if="campaignHasOverride(campaign)"
                      :label="$t('CRM.SCORING_CONFIG.CAMPAIGNS.OVERRIDE_BADGE')"
                    />
                  </div>
                  <p class="m-0 mt-1 text-ui-caption text-ui-text-muted">
                    {{ campaignMeta(campaign) }}
                  </p>
                </div>

                <div
                  v-if="campaignConfigs[campaign.id]"
                  class="w-full sm:w-64"
                >
                  <DsSelect
                    v-model="campaignConfigs[campaign.id].pipelineId"
                    :label="$t('CRM.SCORING_CONFIG.CAMPAIGNS.PIPELINE_LABEL')"
                    :options="pipelineOptions"
                  />
                </div>
              </div>

              <div
                v-if="campaignConfigs[campaign.id]"
                class="grid gap-5 lg:grid-cols-2"
              >
                <div>
                  <div
                    class="mb-1 hidden gap-x-3 border-b border-ui-border-subtle pb-2 sm:grid sm:grid-cols-[minmax(0,1fr)_5rem]"
                  >
                    <span
                      class="text-ui-caption font-semibold text-ui-text-muted"
                    >
                      {{ $t('CRM.SCORING_CONFIG.CRITERIA_HEADER') }}
                    </span>
                    <span
                      class="text-center text-ui-caption font-semibold text-ui-text-muted"
                    >
                      {{ $t('CRM.SCORING_CONFIG.WEIGHT_HEADER') }}
                    </span>
                  </div>
                  <div class="flex flex-col divide-y divide-ui-border-subtle">
                    <div
                      v-for="criterion in criteria"
                      :key="criterion.key"
                      class="grid gap-2 py-2 sm:grid-cols-[minmax(0,1fr)_5rem] sm:items-center sm:gap-x-3"
                    >
                      <div class="min-w-0">
                        <p class="m-0 text-ui-body-sm text-ui-text">
                          {{ criterion.label }}
                        </p>
                        <p class="m-0 text-ui-caption text-ui-text-muted">
                          {{ criterion.description }}
                        </p>
                      </div>
                      <DsInput
                        v-model="
                          campaignConfigs[campaign.id].weights[criterion.key]
                        "
                        type="number"
                        min="0"
                        max="100"
                        :label="
                          $t('CRM.SCORING_CONFIG.WEIGHT_ARIA', {
                            criterion: criterion.label,
                          })
                        "
                        hide-label
                        class="text-center"
                      />
                    </div>
                  </div>
                </div>

                <div class="grid content-start gap-4">
                  <div>
                    <h4
                      class="m-0 mb-2 font-manrope text-ui-label font-semibold text-ui-text"
                    >
                      {{ $t('CRM.SCORING_CONFIG.CAMPAIGNS.THRESHOLDS_TITLE') }}
                    </h4>
                    <div class="grid grid-cols-2 gap-2">
                      <DsInput
                        v-for="classification in classifications"
                        :key="classification.key"
                        v-model="
                          campaignConfigs[campaign.id].thresholds[
                            classification.key
                          ]
                        "
                        type="number"
                        min="0"
                        max="100"
                        :label="classification.label"
                      />
                    </div>
                  </div>

                  <div>
                    <div class="mb-2 flex items-start justify-between gap-2">
                      <h4
                        class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
                      >
                        {{ $t('CRM.SCORING_CONFIG.CAMPAIGNS.KANBAN_TITLE') }}
                      </h4>
                      <DsCheckbox
                        v-model="campaignConfigs[campaign.id].autoMoveOnScore"
                        :label="$t('CRM.SCORING_CONFIG.AUTO_MOVE')"
                        class="mt-1"
                      />
                    </div>
                    <div class="grid grid-cols-1 gap-2">
                      <DsSelect
                        v-for="classification in classifications"
                        :key="classification.key"
                        v-model="
                          campaignConfigs[campaign.id].stageMapping[
                            classification.key
                          ]
                        "
                        :label="classification.label"
                        :options="
                          stageSelectOptions(pipelineForCampaign(campaign.id))
                        "
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div class="mt-4 border-t border-ui-border-subtle pt-4">
                <div class="mb-3 flex items-center gap-2" aria-live="polite">
                  <span class="text-ui-label font-semibold text-ui-text">
                    {{ $t('CRM.SCORING_CONFIG.TOTAL_LABEL') }}
                  </span>
                  <span
                    class="text-ui-label font-semibold"
                    :class="
                      campaignTotalFor[campaign.id] === 100
                        ? 'text-ui-success'
                        : 'text-ui-warning'
                    "
                  >
                    {{ campaignTotalFor[campaign.id] }}
                  </span>
                  <Icon
                    :icon="
                      campaignTotalFor[campaign.id] === 100
                        ? 'i-lucide-circle-check'
                        : 'i-lucide-triangle-alert'
                    "
                    class="size-4"
                    :class="
                      campaignTotalFor[campaign.id] === 100
                        ? 'text-ui-success'
                        : 'text-ui-warning'
                    "
                    aria-hidden="true"
                  />
                </div>

                <div
                  v-if="campaignSavedOk[campaign.id]"
                  role="status"
                  class="mb-3 rounded-ui-surface border border-ui-success/20 bg-ui-success-soft px-4 py-3 text-ui-body-sm text-ui-success-foreground"
                >
                  {{ $t('CRM.SCORING_CONFIG.SAVED') }}
                </div>

                <div class="flex flex-wrap items-center justify-end gap-2">
                  <DsButton
                    variant="ghost"
                    :label="$t('CRM.SCORING_CONFIG.CAMPAIGNS.REMOVE_OVERRIDE')"
                    :disabled="campaignSaving[campaign.id]"
                    @click="clearCampaignOverride(campaign)"
                  />
                  <DsButton
                    variant="primary"
                    :label="
                      campaignSaving[campaign.id]
                        ? $t('CRM.SCORING_CONFIG.SAVING')
                        : $t('CRM.SCORING_CONFIG.CAMPAIGNS.SAVE')
                    "
                    :loading="campaignSaving[campaign.id]"
                    :disabled="campaignTotalFor[campaign.id] !== 100"
                    @click="saveCampaign(campaign)"
                  />
                </div>
              </div>
            </DsCard>
          </div>
        </section>
      </template>
    </div>
  </section>
</template>

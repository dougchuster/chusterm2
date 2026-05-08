<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-alert, no-restricted-globals -->
<script setup>
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import CrmAPI from 'dashboard/api/crm';

const route = useRoute();
const router = useRouter();

const accountId = computed(() => Number(route.params.accountId));

const pipelines = ref([]);
const archivedPipelines = ref([]);
const archivedStages = ref({});
const stages = ref({});
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const success = ref('');
const showArchived = ref(false);
const selectedPipelineId = ref('');

const showDeleteModal = ref(false);
const deleteTarget = ref(null);
const deleteConfirmName = ref('');

const editingPipelineId = ref(null);
const showPipelineForm = ref(false);
const pipelineForm = reactive({
  name: '',
  slug: '',
  isDefault: false,
  position: 0,
});

const editingStageId = ref(null);
const showStageForm = ref(false);
const stageFormRef = ref(null);
const stageNameInputRef = ref(null);
const stageForm = reactive({
  pipelineId: '',
  name: '',
  probabilityPct: 0,
  expectedDurationDays: null,
  color: '#38bdf8',
});

const showScoringConfig = ref(false);
const scoringWeights = ref({});

const STAGE_COLORS = [
  '#38bdf8',
  '#3b82f6',
  '#8b5cf6',
  '#f59e0b',
  '#22c55e',
  '#14b8a6',
  '#f43f5e',
  '#6366f1',
  '#ec4899',
  '#84cc16',
  '#f97316',
];

const DEFAULT_WEIGHTS = {
  fit: 20,
  urgency: 15,
  economic: 15,
  documents: 15,
  clarity: 10,
  engagement: 10,
  payment_capacity: 10,
  conflict: 5,
};

const WEIGHT_LABELS = {
  fit: 'Aderência à área',
  urgency: 'Urgencia / Prazo',
  economic: 'Potencial econômico',
  documents: 'Documentação',
  clarity: 'Clareza dos fatos',
  engagement: 'Engajamento',
  payment_capacity: 'Capacidade financeira',
  conflict: 'Ausencia de conflito',
};

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const toNumber = value => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const normalizePipeline = pipeline => ({
  ...pipeline,
  isDefault: pipeline.is_default ?? pipeline.isDefault ?? false,
  scoringConfig: pipeline.scoring_config ?? pipeline.scoringConfig ?? {},
});

const normalizeStage = stage => {
  const durationHours =
    stage.expected_duration_hours ?? stage.expectedDurationHours ?? null;

  return {
    ...stage,
    pipelineId: stage.pipeline_id ?? stage.pipelineId,
    probabilityPct: toNumber(stage.probability_pct ?? stage.probabilityPct),
    expectedDurationHours: durationHours,
    expectedDurationDays:
      stage.expectedDurationDays ??
      (durationHours === null || durationHours === undefined
        ? null
        : Math.round(Number(durationHours) / 24)),
    requiredFields: stage.required_fields ?? stage.requiredFields ?? {},
  };
};

const activePipelines = computed(() => pipelines.value);
const selectedPipeline = computed(
  () =>
    activePipelines.value.find(
      pipeline => String(pipeline.id) === String(selectedPipelineId.value)
    ) || activePipelines.value[0]
);
const selectedStages = computed(
  () => stages.value[selectedPipeline.value?.id] || []
);
const defaultPipeline = computed(() =>
  activePipelines.value.find(pipeline => pipeline.isDefault)
);
const totalStagesCount = computed(() =>
  activePipelines.value.reduce(
    (total, pipeline) => total + (stages.value[pipeline.id] || []).length,
    0
  )
);
const averageProbability = computed(() => {
  if (!selectedStages.value.length) return 0;
  const total = selectedStages.value.reduce(
    (sum, stage) => sum + toNumber(stage.probabilityPct),
    0
  );
  return Math.round(total / selectedStages.value.length);
});
const canSavePipeline = computed(() => pipelineForm.name.trim().length > 1);
const canSaveStage = computed(() => {
  const probability = Number(stageForm.probabilityPct);
  const duration = stageForm.expectedDurationDays;
  const validDuration =
    duration === null || duration === '' || Number(duration) >= 0;

  return (
    stageForm.name.trim().length > 1 &&
    probability >= 0 &&
    probability <= 100 &&
    validDuration
  );
});
const pipelineFormPreviewSlug = computed(
  () => pipelineForm.slug || slugify(pipelineForm.name) || 'novo-pipeline'
);
const canConfirmDelete = computed(() => {
  if (!deleteTarget.value) return false;
  return deleteConfirmName.value.trim() === deleteTarget.value.name;
});

watch(selectedPipelineId, () => {
  resetStageForm();
  showScoringConfig.value = false;
});

function slugify(value) {
  return (value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
    .slice(0, 100);
}

function pipelineInitials(name) {
  const words = String(name || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (!words.length) return 'PL';
  return words
    .slice(0, 2)
    .map(word => word[0])
    .join('')
    .toUpperCase();
}

function notify(message) {
  success.value = message;
  window.setTimeout(() => {
    if (success.value === message) success.value = '';
  }, 2400);
}

function notifyPipelinesChanged() {
  window.dispatchEvent(new CustomEvent('crm:pipelines:changed'));
}

function apiError(err, fallback) {
  return err?.response?.data?.error || err?.response?.data?.message || fallback;
}

async function loadPipelines() {
  const response = await CrmAPI.getPipelines();
  pipelines.value = extractData(response).map(normalizePipeline);

  if (!pipelines.value.length) {
    selectedPipelineId.value = '';
    return;
  }

  const stillExists = pipelines.value.some(
    pipeline => String(pipeline.id) === String(selectedPipelineId.value)
  );
  if (!stillExists) {
    selectedPipelineId.value =
      pipelines.value.find(pipeline => pipeline.isDefault)?.id ||
      pipelines.value[0].id;
  }
}

async function loadStages(pipelineId) {
  if (!pipelineId) return;
  const response = await CrmAPI.getPipelineStages(pipelineId);
  stages.value[pipelineId] = extractData(response).map(normalizeStage);
}

async function loadAll() {
  loading.value = true;
  error.value = '';

  try {
    await loadPipelines();
    pipelines.value.forEach(initScoringWeights);
    await Promise.all(pipelines.value.map(pipeline => loadStages(pipeline.id)));
  } catch (err) {
    error.value = apiError(err, 'Não foi possível carregar os pipelines.');
  } finally {
    loading.value = false;
  }
}

onMounted(loadAll);

function goBack() {
  router.push({
    name: 'crm_dashboard',
    params: { accountId: accountId.value },
  });
}

function selectPipeline(pipelineId) {
  selectedPipelineId.value = pipelineId;
}

function resetPipelineForm() {
  editingPipelineId.value = null;
  showPipelineForm.value = false;
  pipelineForm.name = '';
  pipelineForm.slug = '';
  pipelineForm.isDefault = false;
  pipelineForm.position = pipelines.value.length;
}

function startNewPipeline() {
  resetPipelineForm();
  showPipelineForm.value = true;
}

function startEditPipeline(pipeline) {
  editingPipelineId.value = pipeline.id;
  showPipelineForm.value = true;
  pipelineForm.name = pipeline.name || '';
  pipelineForm.slug = pipeline.slug || '';
  pipelineForm.isDefault = pipeline.isDefault || false;
  pipelineForm.position = pipeline.position || 0;
}

function autoSlug() {
  pipelineForm.slug = slugify(pipelineForm.name);
}

async function savePipeline() {
  if (!canSavePipeline.value) {
    error.value = 'Informe um nome com pelo menos 2 caracteres.';
    return;
  }

  saving.value = true;
  error.value = '';

  try {
    const payload = {
      name: pipelineForm.name.trim(),
      slug: pipelineForm.slug.trim() || undefined,
      isDefault: pipelineForm.isDefault,
      position: pipelineForm.position,
    };

    if (editingPipelineId.value) {
      await CrmAPI.updatePipeline(editingPipelineId.value, payload);
      notify('Pipeline atualizado.');
    } else {
      const response = await CrmAPI.createPipeline(payload);
      const created = normalizePipeline(response.data);
      selectedPipelineId.value = created.id;
      notify('Pipeline criado.');
    }

    resetPipelineForm();
    await loadAll();
    notifyPipelinesChanged();
  } catch (err) {
    error.value = apiError(err, 'Erro ao salvar pipeline.');
  } finally {
    saving.value = false;
  }
}

async function archivePipeline(pipeline) {
  if (!confirm(`Arquivar pipeline "${pipeline.name}"?`)) return;

  saving.value = true;
  error.value = '';

  try {
    await CrmAPI.archivePipeline(pipeline.id);
    notify('Pipeline arquivado.');
    await loadAll();
    notifyPipelinesChanged();
  } catch (err) {
    error.value = apiError(err, 'Erro ao arquivar pipeline.');
  } finally {
    saving.value = false;
  }
}

function resetStageForm() {
  editingStageId.value = null;
  showStageForm.value = false;
  stageForm.pipelineId = '';
  stageForm.name = '';
  stageForm.probabilityPct = 0;
  stageForm.expectedDurationDays = null;
  stageForm.color = '#38bdf8';
}

async function revealStageForm() {
  await nextTick();
  stageFormRef.value?.scrollIntoView({
    behavior: 'smooth',
    block: 'nearest',
  });
  stageNameInputRef.value?.focus();
}

async function startNewStage() {
  if (!selectedPipeline.value) return;
  resetStageForm();
  showStageForm.value = true;
  stageForm.pipelineId = selectedPipeline.value.id;
  stageForm.name = '';
  stageForm.probabilityPct = 0;
  stageForm.expectedDurationDays = null;
  stageForm.color =
    STAGE_COLORS[selectedStages.value.length % STAGE_COLORS.length];
  await revealStageForm();
}

async function startEditStage(stage) {
  editingStageId.value = stage.id;
  showStageForm.value = true;
  stageForm.pipelineId = selectedPipeline.value.id;
  stageForm.name = stage.name || '';
  stageForm.probabilityPct = stage.probabilityPct ?? 0;
  stageForm.expectedDurationDays = stage.expectedDurationDays ?? null;
  stageForm.color = stage.color || '#38bdf8';
  await revealStageForm();
}

async function saveStage() {
  if (!canSaveStage.value) {
    error.value =
      'Revise nome, probabilidade entre 0 e 100 e duração maior ou igual a 0.';
    return;
  }

  const pipelineId = stageForm.pipelineId || selectedPipeline.value?.id;
  if (!pipelineId) return;

  saving.value = true;
  error.value = '';

  try {
    const payload = {
      name: stageForm.name.trim(),
      slug: slugify(stageForm.name),
      probabilityPct: Number(stageForm.probabilityPct),
      expectedDurationDays:
        stageForm.expectedDurationDays === '' ||
        stageForm.expectedDurationDays === null
          ? null
          : Number(stageForm.expectedDurationDays),
      color: stageForm.color,
    };

    if (editingStageId.value) {
      await CrmAPI.updatePipelineStage(
        pipelineId,
        editingStageId.value,
        payload
      );
      notify('Etapa atualizada.');
    } else {
      await CrmAPI.createPipelineStage(pipelineId, payload);
      notify('Etapa criada.');
    }

    resetStageForm();
    await loadStages(pipelineId);
  } catch (err) {
    error.value = apiError(err, 'Erro ao salvar etapa.');
  } finally {
    saving.value = false;
  }
}

async function archiveStage(stage) {
  if (!selectedPipeline.value) return;
  if (!confirm(`Arquivar etapa "${stage.name}"?`)) return;

  saving.value = true;
  error.value = '';

  try {
    await CrmAPI.archivePipelineStage(selectedPipeline.value.id, stage.id);
    notify('Etapa arquivada.');
    await loadStages(selectedPipeline.value.id);
  } catch (err) {
    error.value = apiError(err, 'Erro ao arquivar etapa.');
  } finally {
    saving.value = false;
  }
}

async function onStageReorder(newList) {
  if (!selectedPipeline.value) return;

  const pipelineId = selectedPipeline.value.id;
  stages.value[pipelineId] = newList;
  error.value = '';

  try {
    await Promise.all(
      newList.map((stage, index) =>
        CrmAPI.updatePipelineStage(pipelineId, stage.id, { position: index })
      )
    );
    notify('Ordem das etapas atualizada.');
  } catch (err) {
    error.value = apiError(err, 'Erro ao reordenar etapas.');
    await loadStages(pipelineId);
  }
}

function initScoringWeights(pipeline) {
  const saved = pipeline.scoringConfig || {};
  scoringWeights.value[pipeline.id] = {
    ...DEFAULT_WEIGHTS,
    ...(saved.weights || saved),
  };
}

function scoringTotal(pipelineId) {
  return Object.values(scoringWeights.value[pipelineId] || {}).reduce(
    (sum, value) => sum + toNumber(value),
    0
  );
}

function resetScoringWeights(pipelineId) {
  scoringWeights.value[pipelineId] = { ...DEFAULT_WEIGHTS };
}

async function saveScoringConfig() {
  if (!selectedPipeline.value) return;
  const pipelineId = selectedPipeline.value.id;

  if (scoringTotal(pipelineId) !== 100) {
    error.value = 'A soma do scoring precisa fechar exatamente em 100.';
    return;
  }

  saving.value = true;
  error.value = '';

  try {
    await CrmAPI.updatePipeline(pipelineId, {
      scoring_config: {
        ...(selectedPipeline.value.scoringConfig || {}),
        weights: scoringWeights.value[pipelineId],
      },
    });
    notify('Scoring atualizado.');
    showScoringConfig.value = false;
    await loadPipelines();
  } catch (err) {
    error.value = apiError(err, 'Erro ao salvar scoring.');
  } finally {
    saving.value = false;
  }
}

function openDeleteModal(target) {
  deleteTarget.value = target;
  deleteConfirmName.value = '';
  showDeleteModal.value = true;
}

function closeDeleteModal() {
  showDeleteModal.value = false;
  deleteTarget.value = null;
  deleteConfirmName.value = '';
}

async function confirmDelete() {
  if (!canConfirmDelete.value || !deleteTarget.value) return;

  const target = deleteTarget.value;
  saving.value = true;
  error.value = '';

  try {
    if (target.type === 'pipeline') {
      await CrmAPI.purgePipeline(target.id);
      notify('Pipeline deletado.');
    } else {
      await CrmAPI.purgePipelineStage(target.pipelineId, target.id);
      notify('Etapa deletada.');
    }

    closeDeleteModal();
    if (showArchived.value) await loadArchived();
    else await loadAll();
    if (target.type === 'pipeline') notifyPipelinesChanged();
  } catch (err) {
    error.value = apiError(
      err,
      `Erro ao deletar ${target.type === 'pipeline' ? 'pipeline' : 'etapa'}.`
    );
    closeDeleteModal();
  } finally {
    saving.value = false;
  }
}

async function toggleArchived() {
  showArchived.value = !showArchived.value;
  error.value = '';
  success.value = '';
  resetStageForm();

  if (showArchived.value) await loadArchived();
}

async function loadArchived() {
  loading.value = true;
  error.value = '';

  try {
    const response = await CrmAPI.getArchivedPipelines();
    archivedPipelines.value = extractData(response).map(normalizePipeline);
    const pairs = await Promise.all(
      archivedPipelines.value.map(async pipeline => {
        try {
          const stageResponse = await CrmAPI.getArchivedPipelineStages(
            pipeline.id
          );
          return [pipeline.id, extractData(stageResponse).map(normalizeStage)];
        } catch {
          return [pipeline.id, []];
        }
      })
    );
    archivedStages.value = Object.fromEntries(pairs);
  } catch (err) {
    error.value = apiError(err, 'Erro ao carregar itens arquivados.');
  } finally {
    loading.value = false;
  }
}

async function restorePipeline(pipeline) {
  saving.value = true;
  error.value = '';

  try {
    await CrmAPI.restorePipeline(pipeline.id);
    notify('Pipeline restaurado.');
    await loadArchived();
    notifyPipelinesChanged();
  } catch (err) {
    error.value = apiError(err, 'Erro ao restaurar pipeline.');
  } finally {
    saving.value = false;
  }
}

async function restoreStage(pipelineId, stage) {
  saving.value = true;
  error.value = '';

  try {
    await CrmAPI.restorePipelineStage(pipelineId, stage.id);
    notify('Etapa restaurada.');
    await loadArchived();
  } catch (err) {
    error.value = apiError(err, 'Erro ao restaurar etapa.');
  } finally {
    saving.value = false;
  }
}

function stageDurationText(stage) {
  if (!stage.expectedDurationDays) return 'Sem prazo';
  return `${stage.expectedDurationDays} dia(s)`;
}
</script>

<template>
  <div class="crm-pipeline-settings">
    <section class="crm-pipeline-hero">
      <div class="crm-pipeline-hero__main">
        <button class="crm-back-button" type="button" @click="goBack">
          <span class="i-lucide-chevron-left size-4" />
          Voltar
        </button>

        <div class="crm-pipeline-hero__title">
          <span class="crm-pipeline-hero__icon">PL</span>
          <div>
            <span class="crm-page-kicker">Configuração CRM</span>
            <h1>Configuração de Pipelines</h1>
            <p>Organize funis, etapas, probabilidades e scoring comercial.</p>
          </div>
        </div>
      </div>

      <div class="crm-pipeline-hero__actions">
        <button
          class="crm-secondary-action"
          :class="{ 'crm-secondary-action--active': showArchived }"
          type="button"
          @click="toggleArchived"
        >
          <span class="i-lucide-archive size-4" />
          {{ showArchived ? 'Voltar aos ativos' : 'Arquivados' }}
        </button>
        <button
          v-if="!showArchived"
          class="crm-primary-action"
          type="button"
          @click="startNewPipeline"
        >
          <span class="i-lucide-plus size-4" />
          Novo pipeline
        </button>
      </div>
    </section>

    <section v-if="!showArchived" class="crm-pipeline-stats">
      <article class="crm-stat crm-stat--blue">
        <span class="crm-stat__icon i-lucide-kanban-square size-5" />
        <div class="crm-stat__content">
          <small>Pipelines ativos</small>
          <strong>{{ activePipelines.length }}</strong>
          <p>Funis disponíveis para atendimento e vendas.</p>
        </div>
      </article>
      <article class="crm-stat crm-stat--teal">
        <span class="crm-stat__icon i-lucide-list-checks size-5" />
        <div class="crm-stat__content">
          <small>Etapas configuradas</small>
          <strong>{{ totalStagesCount }}</strong>
          <p>Passos ativos para organizar o progresso dos leads.</p>
        </div>
      </article>
      <article class="crm-stat crm-stat--amber">
        <span class="crm-stat__icon i-lucide-star size-5" />
        <div class="crm-stat__content">
          <small>Pipeline padrão</small>
          <strong>{{ defaultPipeline?.name || '-' }}</strong>
          <p>Funil usado como referência inicial do CRM.</p>
        </div>
      </article>
    </section>

    <div v-if="error" class="crm-alert crm-alert--error">
      <span class="i-lucide-circle-alert size-4" />
      {{ error }}
    </div>

    <div v-if="success" class="crm-alert crm-alert--success">
      <span class="i-lucide-circle-check size-4" />
      {{ success }}
    </div>

    <div v-if="loading" class="crm-loading">Carregando pipelines...</div>

    <section
      v-else-if="!showArchived && !activePipelines.length"
      class="crm-empty-state"
    >
      <span class="i-lucide-kanban-square size-12" />
      <h2>Nenhum pipeline configurado</h2>
      <p>Crie um funil para organizar leads, etapas e automações.</p>
      <button
        class="crm-primary-action"
        type="button"
        @click="startNewPipeline"
      >
        <span class="i-lucide-plus size-4" />
        Criar primeiro pipeline
      </button>
    </section>

    <section
      v-else-if="!showArchived"
      class="crm-pipeline-workspace"
      aria-label="Configuração de funis"
    >
      <aside class="crm-pipeline-nav">
        <div class="crm-pipeline-nav__head">
          <span>Funis criados</span>
          <button
            class="crm-nav-add-action"
            type="button"
            title="Novo pipeline"
            @click="startNewPipeline"
          >
            <span class="i-lucide-plus size-4" />
          </button>
        </div>

        <button
          v-for="pipeline in activePipelines"
          :key="pipeline.id"
          class="crm-pipeline-nav__item"
          :class="{
            'crm-pipeline-nav__item--active':
              String(pipeline.id) === String(selectedPipeline?.id),
          }"
          type="button"
          @click="selectPipeline(pipeline.id)"
        >
          <span class="crm-pipeline-nav__marker">
            {{ pipelineInitials(pipeline.name) }}
          </span>
          <span class="crm-pipeline-nav__content">
            <strong>{{ pipeline.name }}</strong>
            <small>
              {{ stages[pipeline.id]?.length || 0 }} etapa(s)
              <template v-if="pipeline.isDefault"> - padrão</template>
            </small>
          </span>
          <span class="i-lucide-chevron-right size-4" />
        </button>
      </aside>

      <article v-if="selectedPipeline" class="crm-pipeline-detail">
        <header class="crm-pipeline-detail__header">
          <div class="crm-pipeline-detail__identity">
            <span class="crm-pipeline-card__icon">
              {{ pipelineInitials(selectedPipeline.name) }}
            </span>
            <div>
              <div class="crm-pipeline-title-line">
                <h2>{{ selectedPipeline.name }}</h2>
                <span v-if="selectedPipeline.isDefault" class="crm-pill">
                  Padrão
                </span>
              </div>
              <p>
                {{ selectedStages.length }} etapa(s) cadastrada(s).
                Probabilidade media: {{ averageProbability }}%.
              </p>
            </div>
          </div>

          <div class="crm-pipeline-actions">
            <button
              class="crm-soft-action"
              type="button"
              @click.stop="startEditPipeline(selectedPipeline)"
            >
              <span class="i-lucide-pencil size-4" />
              Editar
            </button>
            <button
              class="crm-warning-action"
              type="button"
              @click="archivePipeline(selectedPipeline)"
            >
              <span class="i-lucide-archive size-4" />
              Arquivar
            </button>
            <button
              class="crm-danger-action"
              type="button"
              @click="
                openDeleteModal({
                  type: 'pipeline',
                  id: selectedPipeline.id,
                  name: selectedPipeline.name,
                })
              "
            >
              <span class="i-lucide-trash-2 size-4" />
              Deletar
            </button>
          </div>
        </header>

        <section class="crm-section-card">
          <div class="crm-section-card__head">
            <div>
              <span>Etapas do funil</span>
              <p>Arraste para reordenar e ajuste a probabilidade por etapa.</p>
            </div>
            <button
              class="crm-inline-action"
              type="button"
              @click="startNewStage"
            >
              <span class="i-lucide-plus size-4" />
              Adicionar etapa
            </button>
          </div>

          <div v-if="showStageForm" ref="stageFormRef" class="crm-stage-form">
            <div class="crm-stage-form__header">
              <span
                class="crm-stage-form__swatch"
                :style="{ backgroundColor: stageForm.color }"
              />
              <div>
                <h3>{{ editingStageId ? 'Editar etapa' : 'Nova etapa' }}</h3>
                <p>Configure nome, cor, probabilidade e prazo esperado.</p>
              </div>
            </div>

            <div class="crm-stage-form__grid">
              <label class="crm-field">
                <span>Nome *</span>
                <input
                  ref="stageNameInputRef"
                  v-model="stageForm.name"
                  type="text"
                  placeholder="Ex: Atendimento"
                />
              </label>

              <label class="crm-field">
                <span>Probabilidade (%)</span>
                <input
                  v-model.number="stageForm.probabilityPct"
                  type="number"
                  min="0"
                  max="100"
                />
              </label>

              <label class="crm-field">
                <span>Duração esperada (dias)</span>
                <input
                  v-model.number="stageForm.expectedDurationDays"
                  type="number"
                  min="0"
                  placeholder="Ex: 7"
                />
              </label>

              <div class="crm-field">
                <span>Cor</span>
                <div class="crm-color-field">
                  <input v-model="stageForm.color" type="color" />
                  <div class="crm-color-swatches">
                    <button
                      v-for="color in STAGE_COLORS"
                      :key="color"
                      class="crm-color-swatch"
                      :class="{
                        'crm-color-swatch--active': stageForm.color === color,
                      }"
                      :style="{ backgroundColor: color }"
                      type="button"
                      @click="stageForm.color = color"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div class="crm-panel-actions">
              <button
                :disabled="saving || !canSaveStage"
                class="crm-primary-action crm-primary-action--small"
                type="button"
                @click="saveStage"
              >
                {{ saving ? 'Salvando...' : 'Salvar etapa' }}
              </button>
              <button
                class="crm-soft-action"
                type="button"
                @click="resetStageForm"
              >
                Cancelar
              </button>
            </div>
          </div>

          <Draggable
            v-if="selectedStages.length"
            :model-value="selectedStages"
            item-key="id"
            handle=".stage-handle"
            ghost-class="crm-stage-row--ghost"
            class="crm-stage-list"
            @update:model-value="onStageReorder"
          >
            <template #item="{ element: stage, index }">
              <div
                class="crm-stage-row"
                :class="{
                  'crm-stage-row--editing': editingStageId === stage.id,
                }"
                :style="{ '--stage-color': stage.color || '#38bdf8' }"
              >
                <button
                  class="stage-handle crm-stage-drag"
                  type="button"
                  title="Arrastar etapa"
                >
                  <span aria-hidden="true" class="crm-stage-grip">
                    <span />
                    <span />
                    <span />
                  </span>
                </button>
                <span class="crm-stage-icon">
                  {{ index + 1 }}
                </span>
                <button
                  class="crm-stage-info crm-stage-info--button"
                  type="button"
                  title="Editar etapa"
                  @click.stop="startEditStage(stage)"
                >
                  <strong>{{ stage.name }}</strong>
                  <small>{{ stageDurationText(stage) }}</small>
                </button>
                <span class="crm-stage-chip">
                  <span class="i-lucide-percent size-3" />
                  {{ stage.probabilityPct ?? 0 }}%
                </span>
                <div class="crm-stage-actions">
                  <button
                    class="crm-icon-action"
                    type="button"
                    title="Editar etapa"
                    @pointerdown.stop
                    @mousedown.stop
                    @click.stop="startEditStage(stage)"
                  >
                    <span class="i-lucide-pencil size-4" />
                  </button>
                  <button
                    class="crm-icon-action crm-icon-action--warn"
                    type="button"
                    title="Arquivar etapa"
                    @pointerdown.stop
                    @mousedown.stop
                    @click.stop="archiveStage(stage)"
                  >
                    <span class="i-lucide-archive size-4" />
                  </button>
                  <button
                    class="crm-icon-action crm-icon-action--danger"
                    type="button"
                    title="Deletar etapa permanentemente"
                    @pointerdown.stop
                    @mousedown.stop
                    @click.stop.prevent="
                      $event.stopPropagation();
                      openDeleteModal({
                        type: 'stage',
                        id: stage.id,
                        name: stage.name,
                        pipelineId: selectedPipeline.id,
                      });
                    "
                  >
                    <span class="i-lucide-trash-2 size-4" />
                  </button>
                </div>
              </div>
            </template>
          </Draggable>

          <div v-else class="crm-empty-inline">
            <span class="i-lucide-list-plus size-8" />
            <strong>Este funil ainda não tem etapas</strong>
            <p>Adicione a primeira etapa para começar a organizar os leads.</p>
          </div>
        </section>

        <section class="crm-section-card">
          <div class="crm-section-card__head">
            <div>
              <span>Scoring</span>
              <p>Defina pesos usados para classificar leads neste funil.</p>
            </div>
            <button
              class="crm-inline-action"
              type="button"
              @click="showScoringConfig = !showScoringConfig"
            >
              <span class="i-lucide-settings size-4" />
              {{ showScoringConfig ? 'Ocultar' : 'Configurar pesos' }}
            </button>
          </div>

          <div v-if="showScoringConfig" class="crm-scoring-panel">
            <div class="crm-scoring-panel__header">
              <p>
                A soma dos criterios precisa fechar em <strong>100</strong>.
              </p>
              <span
                class="crm-scoring-total"
                :class="
                  scoringTotal(selectedPipeline.id) === 100
                    ? 'crm-scoring-total--ok'
                    : 'crm-scoring-total--error'
                "
              >
                Total: {{ scoringTotal(selectedPipeline.id) }}
              </span>
            </div>

            <div class="crm-weight-grid">
              <div
                v-for="(label, key) in WEIGHT_LABELS"
                :key="key"
                class="crm-weight-row"
              >
                <span>{{ label }}</span>
                <input
                  v-model.number="scoringWeights[selectedPipeline.id][key]"
                  class="crm-range"
                  type="range"
                  min="0"
                  max="50"
                  step="1"
                />
                <strong>{{ scoringWeights[selectedPipeline.id][key] }}</strong>
              </div>
            </div>

            <div class="crm-panel-actions">
              <button
                :disabled="saving || scoringTotal(selectedPipeline.id) !== 100"
                class="crm-primary-action crm-primary-action--small"
                type="button"
                @click="saveScoringConfig"
              >
                {{ saving ? 'Salvando...' : 'Salvar scoring' }}
              </button>
              <button
                class="crm-soft-action"
                type="button"
                @click="resetScoringWeights(selectedPipeline.id)"
              >
                Restaurar padroes
              </button>
            </div>
          </div>
        </section>
      </article>
    </section>

    <section v-else-if="!loading" class="crm-archived-view">
      <div v-if="!archivedPipelines.length" class="crm-empty-state">
        <span class="i-lucide-archive size-12" />
        <h2>Nenhum pipeline arquivado</h2>
        <p>Itens arquivados aparecerão aqui para restauração ou exclusão.</p>
      </div>

      <article
        v-for="pipeline in archivedPipelines"
        :key="pipeline.id"
        class="crm-archived-card"
      >
        <header>
          <div>
            <span class="crm-page-kicker">Arquivado</span>
            <h2>{{ pipeline.name }}</h2>
            <p>{{ archivedStages[pipeline.id]?.length || 0 }} etapa(s)</p>
          </div>
          <div class="crm-pipeline-actions">
            <button
              class="crm-soft-action"
              type="button"
              @click="restorePipeline(pipeline)"
            >
              <span class="i-lucide-rotate-ccw size-4" />
              Restaurar
            </button>
            <button
              class="crm-danger-action"
              type="button"
              @click="
                openDeleteModal({
                  type: 'pipeline',
                  id: pipeline.id,
                  name: pipeline.name,
                })
              "
            >
              <span class="i-lucide-trash-2 size-4" />
              Deletar
            </button>
          </div>
        </header>

        <div
          v-for="stage in archivedStages[pipeline.id] || []"
          :key="stage.id"
          class="crm-archived-stage"
        >
          <span>{{ stage.name }}</span>
          <div>
            <button
              class="crm-soft-action"
              type="button"
              @click="restoreStage(pipeline.id, stage)"
            >
              Restaurar etapa
            </button>
            <button
              class="crm-danger-action"
              type="button"
              @click="
                openDeleteModal({
                  type: 'stage',
                  id: stage.id,
                  name: stage.name,
                  pipelineId: pipeline.id,
                })
              "
            >
              Deletar
            </button>
          </div>
        </div>
      </article>
    </section>

    <div
      v-if="showPipelineForm"
      class="crm-modal-backdrop"
      @click.self="resetPipelineForm"
    >
      <div class="crm-pipeline-modal">
        <div class="crm-pipeline-modal__header">
          <div>
            <span class="crm-page-kicker">
              {{ editingPipelineId ? 'Edição' : 'Novo funil' }}
            </span>
            <h2>
              {{ editingPipelineId ? 'Editar pipeline' : 'Criar pipeline' }}
            </h2>
            <p>Defina nome, identificador e uso padrão do funil.</p>
          </div>
          <button
            class="crm-icon-action"
            type="button"
            @click="resetPipelineForm"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <div class="crm-pipeline-modal__body">
          <div class="crm-pipeline-modal__form">
            <label class="crm-field">
              <span>Nome *</span>
              <input
                v-model="pipelineForm.name"
                type="text"
                placeholder="Ex: Pipeline Jurídico"
                @blur="!pipelineForm.slug && autoSlug()"
              />
            </label>

            <label class="crm-field">
              <span>Slug</span>
              <div class="crm-slug-field">
                <input
                  v-model="pipelineForm.slug"
                  type="text"
                  placeholder="Gerado automaticamente"
                />
                <button class="crm-soft-action" type="button" @click="autoSlug">
                  Gerar
                </button>
              </div>
              <small
                >Usado em automações e integrações. Pode ficar vazio.</small
              >
            </label>

            <label class="crm-toggle-field">
              <input v-model="pipelineForm.isDefault" type="checkbox" />
              <span>
                <strong>Usar como pipeline padrão</strong>
                <small
                  >Novos leads entram neste funil quando não houver
                  outro.</small
                >
              </span>
            </label>
          </div>

          <aside class="crm-pipeline-preview">
            <span class="crm-pipeline-preview__icon i-lucide-kanban size-5" />
            <div>
              <span>Preview</span>
              <h3>{{ pipelineForm.name || 'Nome do pipeline' }}</h3>
              <p>{{ pipelineFormPreviewSlug }}</p>
            </div>
            <ul>
              <li>
                <span class="i-lucide-check size-4" />
                Etapas podem ser reordenadas por arraste
              </li>
              <li>
                <span class="i-lucide-check size-4" />
                Scoring configuravel por funil
              </li>
              <li>
                <span class="i-lucide-check size-4" />
                Integrado com leads, automações e atividades
              </li>
            </ul>
          </aside>
        </div>

        <div class="crm-pipeline-modal__footer">
          <button
            class="crm-soft-action"
            type="button"
            @click="resetPipelineForm"
          >
            Cancelar
          </button>
          <button
            :disabled="saving || !canSavePipeline"
            class="crm-primary-action"
            type="button"
            @click="savePipeline"
          >
            {{ saving ? 'Salvando...' : 'Salvar pipeline' }}
          </button>
        </div>
      </div>
    </div>

    <div
      v-if="showDeleteModal"
      class="crm-modal-backdrop"
      @click.self="closeDeleteModal"
    >
      <div class="crm-confirm-modal">
        <div class="crm-confirm-modal__icon">
          <span class="i-lucide-trash-2 size-5" />
        </div>
        <div>
          <span class="crm-page-kicker">Confirmação</span>
          <h2>Deletar permanentemente</h2>
          <p>
            Digite <strong>{{ deleteTarget?.name }}</strong> para confirmar.
            Esta ação não pode ser desfeita.
          </p>
        </div>
        <input
          v-model="deleteConfirmName"
          class="crm-confirm-input"
          type="text"
          placeholder="Digite o nome exatamente"
        />
        <div class="crm-panel-actions">
          <button
            class="crm-soft-action"
            type="button"
            @click="closeDeleteModal"
          >
            Cancelar
          </button>
          <button
            :disabled="saving || !canConfirmDelete"
            class="crm-danger-action"
            type="button"
            @click="confirmDelete"
          >
            {{ saving ? 'Deletando...' : 'Deletar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.crm-pipeline-settings {
  --crm-action-blue: #2563eb;
  --crm-action-blue-strong: #1d4ed8;
  --crm-action-blue-soft: #dbeafe;
  --crm-action-teal: #0f766e;
  --crm-action-amber: #b45309;
  --crm-action-ruby: #be123c;

  display: flex;
  flex: 1 1 0;
  align-self: stretch;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  max-height: 100%;
  box-sizing: border-box;
  flex-direction: column;
  gap: 1rem;
  overflow-x: hidden;
  overflow-y: auto;
  padding: 1.5rem 1.5rem 5rem;
  overscroll-behavior: contain;
  scroll-padding-bottom: 5rem;
  scrollbar-gutter: stable;
  color: rgb(var(--slate-12));
  background: radial-gradient(
      circle at top right,
      rgb(var(--brand-3) / 0.35),
      transparent 26rem
    ),
    rgb(var(--slate-2));
}

.crm-pipeline-settings :deep(*) {
  min-width: 0;
}

.crm-pipeline-settings :deep(button) {
  cursor: pointer;
}

.crm-pipeline-settings :deep(button:disabled) {
  cursor: not-allowed;
}

.crm-pipeline-settings :deep(input),
.crm-pipeline-settings :deep(select),
.crm-pipeline-settings :deep(textarea) {
  color: rgb(var(--slate-12));
}

.crm-pipeline-hero,
.crm-stat,
.crm-pipeline-nav,
.crm-pipeline-detail,
.crm-section-card,
.crm-stage-form,
.crm-pipeline-modal,
.crm-confirm-modal,
.crm-archived-card {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  background: rgb(var(--slate-1));
  box-shadow: 0 16px 45px rgb(15 23 42 / 0.05);
}

.crm-pipeline-hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.crm-pipeline-hero__main,
.crm-pipeline-hero__title,
.crm-pipeline-hero__actions,
.crm-pipeline-detail__identity,
.crm-pipeline-actions,
.crm-section-card__head,
.crm-panel-actions {
  display: flex;
  min-width: 0;
}

.crm-pipeline-hero__main,
.crm-pipeline-hero__title,
.crm-pipeline-detail__identity {
  align-items: center;
  gap: 0.85rem;
}

.crm-pipeline-hero__actions,
.crm-pipeline-actions {
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.5rem;
}

.crm-pipeline-hero__icon,
.crm-pipeline-card__icon,
.crm-pipeline-preview__icon {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid rgb(var(--brand-5));
  border-radius: 8px;
  color: #fff;
  font-size: 0.78rem;
  font-weight: 950;
  letter-spacing: 0;
  background: linear-gradient(135deg, rgb(var(--brand-2)), rgb(var(--blue-2)));
}

.crm-pipeline-hero__icon {
  width: 3rem;
  height: 3rem;
  background: linear-gradient(135deg, #2563eb, #0f766e);
  box-shadow: 0 14px 30px rgb(37 99 235 / 0.24);
}

.crm-pipeline-card__icon,
.crm-pipeline-preview__icon {
  width: 2.75rem;
  height: 2.75rem;
  background: linear-gradient(135deg, #2563eb, #4f46e5);
  box-shadow: 0 10px 22px rgb(37 99 235 / 0.2);
}

.crm-page-kicker {
  display: block;
  margin-bottom: 0.2rem;
  color: rgb(var(--brand-10));
  font-size: 0.72rem;
  font-weight: 900;
  letter-spacing: 0;
  text-transform: uppercase;
}

.crm-pipeline-hero h1,
.crm-pipeline-detail h2,
.crm-pipeline-modal h2,
.crm-confirm-modal h2,
.crm-empty-state h2 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-weight: 900;
  line-height: 1.15;
}

.crm-pipeline-hero h1,
.crm-pipeline-modal h2,
.crm-confirm-modal h2,
.crm-empty-state h2 {
  font-size: 1.35rem;
}

.crm-pipeline-detail h2 {
  font-size: 1.15rem;
}

.crm-pipeline-hero p,
.crm-pipeline-detail p,
.crm-section-card p,
.crm-stage-form p,
.crm-pipeline-modal p,
.crm-confirm-modal p,
.crm-empty-state p,
.crm-field small,
.crm-pipeline-preview p {
  margin: 0;
  color: rgb(var(--slate-10));
  font-size: 0.84rem;
  line-height: 1.45;
}

.crm-back-button,
.crm-primary-action,
.crm-secondary-action,
.crm-soft-action,
.crm-warning-action,
.crm-danger-action,
.crm-inline-action,
.crm-icon-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  font-weight: 850;
  outline: none;
  transition:
    background 160ms ease,
    border-color 160ms ease,
    color 160ms ease,
    box-shadow 160ms ease,
    transform 160ms ease;
}

.crm-back-button,
.crm-secondary-action,
.crm-soft-action {
  border: 1px solid rgb(var(--slate-5));
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-1));
}

.crm-back-button {
  gap: 0.4rem;
  height: 2.45rem;
  padding: 0 0.8rem;
  font-size: 0.82rem;
}

.crm-primary-action,
.crm-secondary-action,
.crm-warning-action,
.crm-danger-action {
  gap: 0.45rem;
  min-height: 2.5rem;
  padding: 0 0.9rem;
  font-size: 0.84rem;
  white-space: nowrap;
}

.crm-primary-action {
  border: 1px solid var(--crm-action-blue-strong);
  color: #fff !important;
  background-color: var(--crm-action-blue);
  background-image: linear-gradient(135deg, var(--crm-action-blue), #4f46e5);
  box-shadow: 0 12px 28px rgb(37 99 235 / 0.28);
  text-shadow: 0 1px 0 rgb(15 23 42 / 0.2);
}

.crm-primary-action span {
  color: currentColor;
}

.crm-warning-action {
  border: 1px solid rgb(var(--amber-6));
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-2));
}

.crm-danger-action {
  border: 1px solid rgb(var(--ruby-6));
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-primary-action--small {
  min-height: 2.3rem;
  padding-inline: 0.75rem;
  font-size: 0.78rem;
}

.crm-secondary-action--active,
.crm-secondary-action:hover:not(:disabled),
.crm-back-button:hover:not(:disabled),
.crm-soft-action:hover:not(:disabled),
.crm-inline-action:hover:not(:disabled) {
  border-color: rgb(var(--brand-6));
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-2));
}

.crm-primary-action:hover:not(:disabled) {
  transform: translateY(-1px);
  border-color: #1e40af;
  color: #fff !important;
  background-color: var(--crm-action-blue-strong);
  background-image: linear-gradient(
    135deg,
    var(--crm-action-blue-strong),
    #4338ca
  );
  box-shadow: 0 16px 34px rgb(37 99 235 / 0.36);
}

.crm-warning-action:hover:not(:disabled) {
  border-color: rgb(var(--amber-7));
  color: rgb(var(--amber-12));
  background: rgb(var(--amber-3));
}

.crm-danger-action:hover:not(:disabled) {
  border-color: rgb(var(--ruby-7));
  color: rgb(var(--ruby-12));
  background: rgb(var(--ruby-3));
}

.crm-primary-action:focus-visible,
.crm-secondary-action:focus-visible,
.crm-soft-action:focus-visible,
.crm-warning-action:focus-visible,
.crm-danger-action:focus-visible,
.crm-inline-action:focus-visible,
.crm-icon-action:focus-visible,
.crm-back-button:focus-visible,
.crm-pipeline-nav__item:focus-visible,
.crm-field input:focus,
.crm-confirm-input:focus {
  border-color: rgb(var(--brand-7));
  box-shadow: 0 0 0 3px rgb(var(--brand-4) / 0.28);
}

.crm-primary-action:disabled,
.crm-secondary-action:disabled,
.crm-soft-action:disabled,
.crm-warning-action:disabled,
.crm-danger-action:disabled,
.crm-inline-action:disabled {
  border-color: rgb(var(--slate-5));
  color: rgb(var(--slate-9)) !important;
  background: rgb(var(--slate-3));
  background-image: none;
  box-shadow: none;
  opacity: 1;
  transform: none;
}

.crm-pipeline-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-stat {
  position: relative;
  display: grid;
  grid-template-columns: 3.1rem minmax(0, 1fr);
  align-items: center;
  gap: 0.85rem;
  overflow: hidden;
  min-height: 7.4rem;
  padding: 1.05rem 1rem 1.05rem 1.15rem;
  isolation: isolate;
  transition:
    border-color 160ms ease,
    box-shadow 160ms ease,
    transform 160ms ease;
}

.crm-stat::before {
  position: absolute;
  inset-block: 0;
  left: 0;
  z-index: 1;
  width: 0.28rem;
  content: '';
}

.crm-stat::after {
  position: absolute;
  top: -3rem;
  right: -2.4rem;
  z-index: -1;
  width: 9rem;
  height: 9rem;
  border-radius: 999px;
  opacity: 0.6;
  content: '';
}

.crm-stat:hover {
  transform: translateY(-1px);
  box-shadow: 0 18px 40px rgb(15 23 42 / 0.1);
}

.crm-stat--blue::before {
  background: rgb(var(--blue-8));
}

.crm-stat--blue {
  border-color: rgb(var(--blue-5));
  background: linear-gradient(
      135deg,
      rgb(var(--blue-2) / 0.82),
      transparent 62%
    ),
    rgb(var(--slate-1));
}

.crm-stat--blue::after {
  background: rgb(var(--blue-4));
}

.crm-stat--teal::before {
  background: rgb(var(--teal-8));
}

.crm-stat--teal {
  border-color: rgb(var(--teal-5));
  background: linear-gradient(
      135deg,
      rgb(var(--teal-2) / 0.82),
      transparent 62%
    ),
    rgb(var(--slate-1));
}

.crm-stat--teal::after {
  background: rgb(var(--teal-4));
}

.crm-stat--amber::before {
  background: rgb(var(--amber-8));
}

.crm-stat--amber {
  border-color: rgb(var(--amber-5));
  background: linear-gradient(
      135deg,
      rgb(var(--amber-2) / 0.85),
      transparent 62%
    ),
    rgb(var(--slate-1));
}

.crm-stat--amber::after {
  background: rgb(var(--amber-4));
}

.crm-stat__icon {
  display: grid;
  width: 3.05rem;
  height: 3.05rem;
  place-items: center;
  border-radius: 12px;
  font-size: 1.12rem;
  box-shadow:
    inset 0 1px 0 rgb(255 255 255 / 0.5),
    0 14px 30px rgb(15 23 42 / 0.12);
}

.crm-stat--blue .crm-stat__icon {
  border: 1px solid rgb(var(--blue-5));
  color: #1d4ed8;
  background: linear-gradient(135deg, rgb(var(--blue-2)), rgb(var(--blue-4)));
}

.crm-stat--teal .crm-stat__icon {
  border: 1px solid rgb(var(--teal-5));
  color: #0f766e;
  background: linear-gradient(135deg, rgb(var(--teal-2)), rgb(var(--teal-4)));
}

.crm-stat--amber .crm-stat__icon {
  border: 1px solid rgb(var(--amber-5));
  color: #b45309;
  background: linear-gradient(135deg, rgb(var(--amber-2)), rgb(var(--amber-4)));
}

.crm-stat__content {
  display: grid;
  gap: 0.18rem;
  min-width: 0;
}

.crm-stat strong {
  overflow: hidden;
  color: rgb(var(--slate-12));
  font-size: clamp(1.35rem, 1.2rem + 0.45vw, 1.75rem);
  font-weight: 950;
  letter-spacing: 0;
  line-height: 1.05;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-stat small {
  color: rgb(var(--slate-11));
  font-size: 0.7rem;
  font-weight: 950;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.crm-stat p {
  margin: 0;
  color: rgb(var(--slate-10));
  font-size: 0.78rem;
  line-height: 1.35;
}

.dark .crm-stat,
[data-theme='dark'] .crm-stat,
.theme-dark .crm-stat {
  box-shadow: 0 18px 45px rgb(0 0 0 / 0.18);
}

.dark .crm-stat--blue,
[data-theme='dark'] .crm-stat--blue,
.theme-dark .crm-stat--blue {
  background: linear-gradient(
      135deg,
      rgb(var(--blue-3) / 0.58),
      transparent 62%
    ),
    rgb(var(--slate-2));
}

.dark .crm-stat--teal,
[data-theme='dark'] .crm-stat--teal,
.theme-dark .crm-stat--teal {
  background: linear-gradient(
      135deg,
      rgb(var(--teal-3) / 0.58),
      transparent 62%
    ),
    rgb(var(--slate-2));
}

.dark .crm-stat--amber,
[data-theme='dark'] .crm-stat--amber,
.theme-dark .crm-stat--amber {
  background: linear-gradient(
      135deg,
      rgb(var(--amber-3) / 0.5),
      transparent 62%
    ),
    rgb(var(--slate-2));
}

.dark .crm-stat::after,
[data-theme='dark'] .crm-stat::after,
.theme-dark .crm-stat::after {
  opacity: 0.28;
}

.dark .crm-stat--blue .crm-stat__icon,
[data-theme='dark'] .crm-stat--blue .crm-stat__icon,
.theme-dark .crm-stat--blue .crm-stat__icon {
  color: #93c5fd;
}

.dark .crm-stat--teal .crm-stat__icon,
[data-theme='dark'] .crm-stat--teal .crm-stat__icon,
.theme-dark .crm-stat--teal .crm-stat__icon {
  color: #5eead4;
}

.dark .crm-stat--amber .crm-stat__icon,
[data-theme='dark'] .crm-stat--amber .crm-stat__icon,
.theme-dark .crm-stat--amber .crm-stat__icon {
  color: #fbbf24;
}

.crm-alert {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border-radius: 8px;
  padding: 0.8rem 1rem;
  font-size: 0.85rem;
  font-weight: 800;
}

.crm-alert--error {
  border: 1px solid rgb(var(--ruby-6));
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-alert--success {
  border: 1px solid rgb(var(--teal-6));
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-loading,
.crm-empty-state {
  display: grid;
  place-items: center;
  gap: 0.75rem;
  min-height: 22rem;
  border: 1px dashed rgb(var(--slate-5));
  border-radius: 8px;
  padding: 2rem;
  color: rgb(var(--slate-10));
  text-align: center;
  background: rgb(var(--slate-1));
}

.crm-empty-state > span {
  color: rgb(var(--brand-9));
}

.crm-pipeline-workspace {
  display: grid;
  grid-template-columns: minmax(16rem, 20rem) minmax(0, 1fr);
  gap: 1rem;
  align-items: start;
}

.crm-pipeline-nav {
  position: sticky;
  top: 1rem;
  display: grid;
  gap: 0.6rem;
  padding: 0.9rem;
  background: linear-gradient(180deg, rgb(var(--slate-1)), rgb(var(--slate-2)));
}

.crm-pipeline-nav__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.15rem 0.15rem 0.4rem;
  color: rgb(var(--slate-11));
  font-size: 0.78rem;
  font-weight: 900;
  text-transform: uppercase;
}

.crm-nav-add-action {
  border-color: rgb(var(--blue-6));
  color: #fff;
  background: var(--crm-action-blue);
  box-shadow: 0 8px 18px rgb(37 99 235 / 0.22);
}

.crm-nav-add-action:hover {
  color: #fff;
  background: var(--crm-action-blue-strong);
}

.crm-pipeline-nav__item {
  position: relative;
  display: grid;
  grid-template-columns: 2.35rem minmax(0, 1fr) 1.6rem;
  align-items: center;
  gap: 0.65rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 0.72rem;
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-1));
  text-align: left;
  box-shadow: 0 8px 22px rgb(15 23 42 / 0.03);
  transition:
    border-color 160ms ease,
    background 160ms ease,
    box-shadow 160ms ease,
    transform 160ms ease;
}

.crm-pipeline-nav__item::before {
  position: absolute;
  inset-block: 0.55rem;
  left: 0;
  width: 0.22rem;
  border-radius: 0 999px 999px 0;
  background: transparent;
  content: '';
}

.crm-pipeline-nav__item:hover,
.crm-pipeline-nav__item--active {
  border-color: rgb(var(--blue-6));
  color: rgb(var(--slate-12));
  background: linear-gradient(135deg, rgb(var(--blue-2)), rgb(var(--slate-1)));
  box-shadow: 0 14px 28px rgb(37 99 235 / 0.11);
  transform: translateY(-1px);
}

.crm-pipeline-nav__item--active::before {
  background: var(--crm-action-blue);
}

.crm-pipeline-nav__marker {
  display: grid;
  width: 2.35rem;
  height: 2.35rem;
  place-items: center;
  border-radius: 8px;
  font-size: 0.72rem;
  font-weight: 950;
  letter-spacing: 0;
  color: var(--crm-action-blue-strong);
  background: var(--crm-action-blue-soft);
}

.crm-pipeline-nav__item--active .crm-pipeline-nav__marker {
  color: #fff;
  background: var(--crm-action-blue);
}

.crm-pipeline-nav__content {
  display: grid;
  gap: 0.1rem;
}

.crm-pipeline-nav__content strong {
  overflow: hidden;
  font-size: 0.86rem;
  font-weight: 900;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-pipeline-nav__content small {
  color: rgb(var(--slate-10));
  font-size: 0.72rem;
}

.crm-pipeline-detail {
  display: grid;
  gap: 1rem;
  padding: 1rem;
}

.crm-pipeline-detail__header,
.crm-section-card__head,
.crm-scoring-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.crm-pipeline-title-line {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.45rem;
}

.crm-pill {
  border: 1px solid rgb(var(--brand-5));
  border-radius: 999px;
  padding: 0.16rem 0.55rem;
  color: rgb(var(--brand-11));
  font-size: 0.68rem;
  font-weight: 900;
  background: rgb(var(--brand-2));
}

.crm-section-card {
  display: grid;
  gap: 0.85rem;
  padding: 1rem;
  background: linear-gradient(135deg, rgb(var(--slate-1)), rgb(var(--slate-2))),
    rgb(var(--slate-1));
}

.crm-section-card__head > div > span {
  color: rgb(var(--slate-12));
  font-size: 0.88rem;
  font-weight: 900;
}

.crm-inline-action {
  gap: 0.35rem;
  min-height: 2.2rem;
  border: 1px solid rgb(var(--brand-4));
  padding: 0 0.7rem;
  color: rgb(var(--brand-11));
  font-size: 0.78rem;
  background: rgb(var(--brand-1));
}

.crm-stage-list {
  display: grid;
  gap: 0.55rem;
}

.crm-stage-row {
  display: grid;
  grid-template-columns: 1.85rem 2.45rem minmax(10rem, 1fr) auto auto;
  align-items: center;
  gap: 0.75rem;
  border: 1px solid rgb(var(--slate-4));
  border-left: 5px solid var(--stage-color);
  border-radius: 8px;
  padding: 0.72rem 0.8rem;
  background: linear-gradient(
      90deg,
      color-mix(in srgb, var(--stage-color), transparent 93%),
      transparent 34%
    ),
    rgb(var(--slate-1));
  transition:
    border-color 160ms ease,
    background 160ms ease,
    box-shadow 160ms ease,
    transform 160ms ease;
}

.crm-stage-row:hover {
  border-color: color-mix(in srgb, var(--stage-color), rgb(var(--slate-4)) 35%);
  background: linear-gradient(
      90deg,
      color-mix(in srgb, var(--stage-color), transparent 88%),
      transparent 38%
    ),
    rgb(var(--slate-1));
  box-shadow: 0 14px 30px rgb(15 23 42 / 0.1);
  transform: translateY(-1px);
}

.crm-stage-row--ghost {
  opacity: 0.55;
}

.crm-stage-row--editing {
  border-color: color-mix(in srgb, var(--stage-color), rgb(var(--blue-6)) 45%);
  background: linear-gradient(
      90deg,
      color-mix(in srgb, var(--stage-color), transparent 82%),
      transparent 42%
    ),
    rgb(var(--blue-1));
  box-shadow:
    0 0 0 2px color-mix(in srgb, var(--stage-color), transparent 72%),
    0 16px 34px rgb(15 23 42 / 0.12);
}

.crm-stage-drag,
.crm-icon-action,
.crm-nav-add-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem;
  height: 2.25rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  color: rgb(var(--slate-10));
  background: rgb(var(--slate-1));
}

.crm-stage-drag {
  width: 1.85rem;
  height: 2.45rem;
  border-color: transparent;
  color: #64748b;
  background: transparent;
  cursor: grab;
  opacity: 1;
  padding: 0;
}

.crm-stage-drag:hover {
  border-color: transparent;
  color: color-mix(in srgb, var(--stage-color), #334155 18%);
  background: transparent;
  opacity: 1;
}

.crm-stage-drag:active {
  cursor: grabbing;
}

.crm-stage-grip {
  display: grid;
  gap: 0.22rem;
  width: 0.9rem;
  opacity: 0.78;
}

.crm-stage-grip span {
  display: block;
  width: 0.9rem;
  height: 0.14rem;
  border-radius: 999px;
  background: #64748b;
}

.crm-stage-drag:hover .crm-stage-grip {
  opacity: 1;
}

.crm-stage-drag:hover .crm-stage-grip span {
  background: color-mix(in srgb, var(--stage-color), #334155 28%);
}

.dark .crm-stage-drag,
[data-theme='dark'] .crm-stage-drag,
.theme-dark .crm-stage-drag {
  color: #94a3b8;
}

.dark .crm-stage-grip span,
[data-theme='dark'] .crm-stage-grip span,
.theme-dark .crm-stage-grip span {
  background: #cbd5e1;
}

.dark .crm-stage-drag:hover,
[data-theme='dark'] .crm-stage-drag:hover,
.theme-dark .crm-stage-drag:hover {
  color: color-mix(in srgb, var(--stage-color), #e2e8f0 28%);
}

.dark .crm-stage-drag:hover .crm-stage-grip span,
[data-theme='dark'] .crm-stage-drag:hover .crm-stage-grip span,
.theme-dark .crm-stage-drag:hover .crm-stage-grip span {
  background: color-mix(in srgb, var(--stage-color), #f8fafc 28%);
}

.crm-icon-action:hover,
.crm-nav-add-action:hover {
  border-color: rgb(var(--blue-5));
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-icon-action--warn:hover {
  border-color: rgb(var(--amber-5));
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-2));
}

.crm-icon-action--danger:hover {
  border-color: rgb(var(--ruby-5));
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-stage-icon {
  display: grid;
  width: 2.45rem;
  height: 2.45rem;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--stage-color), transparent 45%);
  border-radius: 999px;
  color: color-mix(in srgb, var(--stage-color), rgb(var(--slate-12)) 18%);
  font-size: 0.82rem;
  font-weight: 950;
  background: color-mix(in srgb, var(--stage-color), rgb(var(--slate-2)) 82%);
  box-shadow:
    inset 0 0 0 0.18rem rgb(var(--slate-1) / 0.68),
    0 8px 18px color-mix(in srgb, var(--stage-color), transparent 82%);
}

.crm-stage-info {
  display: grid;
  gap: 0.1rem;
}

.crm-stage-info--button {
  width: 100%;
  border: 0;
  padding: 0;
  text-align: left;
  background: transparent;
  cursor: pointer;
}

.crm-stage-info--button:hover strong,
.crm-stage-info--button:focus-visible strong {
  color: color-mix(in srgb, var(--stage-color), rgb(var(--blue-11)) 35%);
}

.crm-stage-info--button:focus-visible {
  border-radius: 6px;
  outline: 2px solid color-mix(in srgb, var(--stage-color), transparent 35%);
  outline-offset: 3px;
}

.crm-stage-info strong {
  overflow: hidden;
  color: rgb(var(--slate-12));
  font-size: 0.88rem;
  font-weight: 900;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-stage-info small {
  color: rgb(var(--slate-9));
  font-size: 0.73rem;
}

.crm-stage-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  border: 1px solid color-mix(in srgb, var(--stage-color), transparent 45%);
  border-radius: 999px;
  padding: 0.24rem 0.68rem;
  color: color-mix(in srgb, var(--stage-color), rgb(var(--slate-12)) 18%);
  font-size: 0.73rem;
  font-weight: 900;
  background: color-mix(in srgb, var(--stage-color), transparent 90%);
  white-space: nowrap;
}

.crm-stage-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.3rem;
}

.crm-empty-inline {
  display: grid;
  justify-items: center;
  gap: 0.3rem;
  border: 1px dashed rgb(var(--slate-5));
  border-radius: 8px;
  padding: 1.5rem;
  color: rgb(var(--slate-10));
  text-align: center;
  background: rgb(var(--slate-2));
}

.crm-empty-inline span {
  color: rgb(var(--brand-9));
}

.crm-empty-inline strong {
  color: rgb(var(--slate-12));
  font-size: 0.95rem;
}

.crm-stage-form,
.crm-scoring-panel {
  margin-bottom: 0.85rem;
  padding: 1rem;
  background: linear-gradient(135deg, rgb(var(--brand-1)), transparent),
    rgb(var(--slate-1));
}

.crm-stage-form__header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.85rem;
}

.crm-stage-form__swatch {
  width: 2.4rem;
  height: 2.4rem;
  flex: 0 0 auto;
  border: 3px solid rgb(var(--slate-1));
  border-radius: 8px;
  box-shadow: 0 0 0 1px rgb(var(--slate-5));
}

.crm-stage-form__header h3 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 0.98rem;
  font-weight: 900;
}

.crm-stage-form__grid {
  display: grid;
  grid-template-columns:
    minmax(12rem, 1.25fr) minmax(8rem, 0.7fr) minmax(9rem, 0.8fr)
    minmax(15rem, 1fr);
  gap: 0.75rem;
}

.crm-field {
  display: grid;
  gap: 0.35rem;
}

.crm-field > span {
  color: rgb(var(--slate-10));
  font-size: 0.76rem;
  font-weight: 900;
}

.crm-field input,
.crm-slug-field input,
.crm-confirm-input {
  width: 100%;
  height: 2.6rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  padding: 0 0.75rem;
  color: rgb(var(--slate-12));
  background: rgb(var(--slate-1));
  outline: none;
}

.crm-color-field,
.crm-slug-field {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.crm-color-field input[type='color'] {
  width: 2.55rem;
  padding: 0.15rem;
  cursor: pointer;
}

.crm-color-swatches {
  display: flex;
  flex-wrap: wrap;
  gap: 0.32rem;
}

.crm-color-swatch {
  width: 1.35rem;
  height: 1.35rem;
  border: 2px solid transparent;
  border-radius: 999px;
}

.crm-color-swatch--active {
  border-color: rgb(var(--slate-12));
  transform: scale(1.08);
}

.crm-panel-actions {
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1rem;
}

.crm-scoring-panel__header {
  margin-bottom: 0.9rem;
}

.crm-scoring-total {
  flex: 0 0 auto;
  border-radius: 999px;
  padding: 0.25rem 0.65rem;
  font-size: 0.74rem;
  font-weight: 900;
}

.crm-scoring-total--ok {
  border: 1px solid rgb(var(--teal-5));
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-scoring-total--error {
  border: 1px solid rgb(var(--ruby-5));
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-weight-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-weight-row {
  display: grid;
  grid-template-columns: minmax(9rem, 1fr) minmax(7rem, 1fr) 2.25rem;
  align-items: center;
  gap: 0.6rem;
}

.crm-weight-row span {
  color: rgb(var(--slate-11));
  font-size: 0.76rem;
}

.crm-weight-row strong {
  color: rgb(var(--slate-12));
  font-size: 0.78rem;
  text-align: right;
}

.crm-range {
  accent-color: rgb(var(--brand-9));
}

.crm-modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 1rem;
  background: rgb(15 23 42 / 0.48);
}

.crm-pipeline-modal,
.crm-confirm-modal {
  width: min(56rem, 100%);
  overflow: hidden;
}

.crm-confirm-modal {
  display: grid;
  gap: 0.85rem;
  max-width: 30rem;
  padding: 1rem;
}

.crm-confirm-modal__icon {
  display: grid;
  width: 2.5rem;
  height: 2.5rem;
  place-items: center;
  border: 1px solid rgb(var(--ruby-5));
  border-radius: 8px;
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-pipeline-modal__header,
.crm-pipeline-modal__footer {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.crm-pipeline-modal__header {
  border-bottom: 1px solid rgb(var(--slate-4));
}

.crm-pipeline-modal__footer {
  align-items: center;
  border-top: 1px solid rgb(var(--slate-4));
}

.crm-pipeline-modal__body {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(18rem, 0.9fr);
  gap: 1rem;
  padding: 1rem;
}

.crm-pipeline-modal__form {
  display: grid;
  align-content: start;
  gap: 0.9rem;
}

.crm-toggle-field {
  display: flex;
  gap: 0.7rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 0.8rem;
  background: rgb(var(--slate-2));
}

.crm-toggle-field input {
  width: 1rem;
  height: 1rem;
  margin-top: 0.15rem;
}

.crm-toggle-field span {
  display: grid;
  gap: 0.15rem;
}

.crm-toggle-field strong {
  color: rgb(var(--slate-12));
  font-size: 0.85rem;
}

.crm-toggle-field small {
  color: rgb(var(--slate-10));
  font-size: 0.76rem;
}

.crm-pipeline-preview {
  display: grid;
  align-content: start;
  gap: 0.85rem;
  border: 1px solid rgb(var(--brand-4));
  border-radius: 8px;
  padding: 1rem;
  background: linear-gradient(145deg, rgb(var(--brand-2)), transparent),
    rgb(var(--slate-2));
}

.crm-pipeline-preview > div > span {
  color: rgb(var(--brand-10));
  font-size: 0.72rem;
  font-weight: 900;
  text-transform: uppercase;
}

.crm-pipeline-preview h3 {
  margin: 0.2rem 0 0;
  color: rgb(var(--slate-12));
  font-size: 1.05rem;
  font-weight: 900;
}

.crm-pipeline-preview ul {
  display: grid;
  gap: 0.55rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.crm-pipeline-preview li {
  display: flex;
  gap: 0.45rem;
  color: rgb(var(--slate-11));
  font-size: 0.8rem;
}

.crm-pipeline-preview li span {
  flex: 0 0 auto;
  color: rgb(var(--teal-10));
}

.crm-archived-view {
  display: grid;
  gap: 1rem;
}

.crm-archived-card {
  display: grid;
  gap: 0.75rem;
  padding: 1rem;
}

.crm-archived-card header,
.crm-archived-stage {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.crm-archived-card h2 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 1rem;
  font-weight: 900;
}

.crm-archived-stage {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 0.7rem;
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-2));
}

.crm-archived-stage > div {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

@media (max-width: 1180px) {
  .crm-pipeline-workspace,
  .crm-stage-form__grid,
  .crm-weight-grid,
  .crm-pipeline-modal__body {
    grid-template-columns: 1fr;
  }

  .crm-pipeline-nav {
    position: static;
  }
}

@media (max-width: 900px) {
  .crm-pipeline-settings {
    padding: 1rem 1rem 5rem;
  }

  .crm-pipeline-hero,
  .crm-pipeline-detail__header,
  .crm-section-card__head,
  .crm-scoring-panel__header,
  .crm-archived-card header,
  .crm-archived-stage {
    align-items: stretch;
    flex-direction: column;
  }

  .crm-pipeline-stats {
    grid-template-columns: 1fr;
  }

  .crm-pipeline-hero__main {
    align-items: flex-start;
    flex-direction: column;
  }

  .crm-pipeline-hero__actions,
  .crm-pipeline-actions {
    justify-content: flex-start;
  }
}

@media (max-width: 760px) {
  .crm-primary-action,
  .crm-secondary-action,
  .crm-soft-action,
  .crm-warning-action,
  .crm-danger-action,
  .crm-inline-action {
    width: 100%;
  }

  .crm-stage-row {
    grid-template-columns: 1.25rem 2.45rem minmax(0, 1fr);
  }

  .crm-stage-chip,
  .crm-stage-actions {
    grid-column: 3 / -1;
    justify-content: flex-start;
    width: fit-content;
  }

  .crm-weight-row {
    grid-template-columns: 1fr;
  }

  .crm-weight-row strong {
    text-align: left;
  }

  .crm-pipeline-modal__footer,
  .crm-panel-actions {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>

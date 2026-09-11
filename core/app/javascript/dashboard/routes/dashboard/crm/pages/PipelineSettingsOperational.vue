<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';

import CrmAPI from 'dashboard/api/crm';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsDrawer,
  DsInput,
  DsModal,
  DsSelect,
} from 'dashboard/design-system/components';
import { SettingsPageTemplate } from 'dashboard/design-system/templates';

const route = useRoute();
const router = useRouter();
const accountId = computed(() => Number(route.params.accountId));
const pipelines = ref([]);
const stages = ref({});
const archivedPipelines = ref([]);
const archivedStages = ref({});
const selectedPipelineId = ref('');
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const success = ref('');
const showArchived = ref(false);
const panel = ref('');
const editingId = ref(null);
const deleteTarget = ref(null);
const deleteName = ref('');
const scoringWeights = ref({});

const pipelineForm = reactive({
  name: '',
  slug: '',
  isDefault: false,
  position: 0,
});
const stageForm = reactive({
  name: '',
  probabilityPct: 0,
  expectedDurationDays: null,
  color: '#3b82f6',
});

const COLORS = [
  '#38bdf8',
  '#3b82f6',
  '#8b5cf6',
  '#f59e0b',
  '#22c55e',
  '#14b8a6',
  '#f43f5e',
  '#6366f1',
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
  urgency: 'Urgência e prazo',
  economic: 'Potencial econômico',
  documents: 'Documentação',
  clarity: 'Clareza dos fatos',
  engagement: 'Engajamento',
  payment_capacity: 'Capacidade financeira',
  conflict: 'Ausência de conflito',
};

const selectedPipeline = computed(
  () =>
    pipelines.value.find(
      pipeline => String(pipeline.id) === String(selectedPipelineId.value)
    ) || pipelines.value[0]
);
const selectedStages = computed(() => stages.value[selectedPipeline.value?.id] || []);
const totalStages = computed(() =>
  pipelines.value.reduce(
    (total, pipeline) => total + (stages.value[pipeline.id] || []).length,
    0
  )
);
const averageProbability = computed(() => {
  if (!selectedStages.value.length) return 0;
  return Math.round(
    selectedStages.value.reduce(
      (total, stage) => total + Number(stage.probabilityPct || 0),
      0
    ) / selectedStages.value.length
  );
});
const scoringTotal = computed(() =>
  Object.values(scoringWeights.value[selectedPipeline.value?.id] || {}).reduce(
    (total, value) => total + (Number(value) || 0),
    0
  )
);
const panelTitle = computed(() => {
  if (panel.value === 'pipeline')
    return editingId.value ? 'Editar pipeline' : 'Novo pipeline';
  if (panel.value === 'stage')
    return editingId.value ? 'Editar etapa' : 'Nova etapa';
  return 'Configurar scoring';
});
const deleteAllowed = computed(
  () => deleteName.value.trim() === deleteTarget.value?.name
);
const pipelineOptions = computed(() =>
  pipelines.value.map(pipeline => ({
    value: String(pipeline.id),
    label: pipeline.isDefault ? `${pipeline.name} · Padrão` : pipeline.name,
  }))
);

function extract(response) {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data || [];
}
function normalizePipeline(pipeline) {
  return {
    ...pipeline,
    isDefault: pipeline.is_default ?? pipeline.isDefault ?? false,
    scoringConfig: pipeline.scoring_config ?? pipeline.scoringConfig ?? {},
  };
}
function normalizeStage(stage) {
  const hours = stage.expected_duration_hours ?? stage.expectedDurationHours;
  return {
    ...stage,
    probabilityPct: Number(stage.probability_pct ?? stage.probabilityPct ?? 0),
    expectedDurationDays:
      stage.expectedDurationDays ??
      (hours === null || hours === undefined ? null : Math.round(Number(hours) / 24)),
  };
}
function apiError(requestError, fallback) {
  return (
    requestError?.response?.data?.error ||
    requestError?.response?.data?.message ||
    fallback
  );
}
function slugify(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
    .slice(0, 100);
}
function stageColorClass(color) {
  return (
    {
      '#38bdf8': 'bg-n-blue-9',
      '#3b82f6': 'bg-n-blue-10',
      '#8b5cf6': 'bg-n-violet-9',
      '#f59e0b': 'bg-n-amber-9',
      '#22c55e': 'bg-n-teal-9',
      '#14b8a6': 'bg-n-teal-10',
      '#f43f5e': 'bg-n-ruby-9',
      '#6366f1': 'bg-n-violet-10',
    }[color] || 'bg-ui-brand'
  );
}
function notify(message) {
  success.value = message;
  window.setTimeout(() => {
    if (success.value === message) success.value = '';
  }, 2600);
}
function notifyChanged() {
  window.dispatchEvent(new CustomEvent('crm:pipelines:changed'));
}

async function loadPipelines() {
  pipelines.value = extract(await CrmAPI.getPipelines()).map(normalizePipeline);
  if (!pipelines.value.some(item => String(item.id) === String(selectedPipelineId.value))) {
    selectedPipelineId.value =
      pipelines.value.find(item => item.isDefault)?.id || pipelines.value[0]?.id || '';
  }
  pipelines.value.forEach(pipeline => {
    scoringWeights.value[pipeline.id] = {
      ...DEFAULT_WEIGHTS,
      ...(pipeline.scoringConfig?.weights || pipeline.scoringConfig || {}),
    };
  });
}
async function loadStages(pipelineId) {
  if (!pipelineId) return;
  stages.value[pipelineId] = extract(
    await CrmAPI.getPipelineStages(pipelineId)
  ).map(normalizeStage);
}
async function loadAll() {
  loading.value = true;
  error.value = '';
  try {
    await loadPipelines();
    await Promise.all(pipelines.value.map(item => loadStages(item.id)));
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível carregar os pipelines.');
  } finally {
    loading.value = false;
  }
}

function openPipeline(pipeline = null) {
  editingId.value = pipeline?.id || null;
  Object.assign(pipelineForm, {
    name: pipeline?.name || '',
    slug: pipeline?.slug || '',
    isDefault: Boolean(pipeline?.isDefault),
    position: pipeline?.position || pipelines.value.length,
  });
  panel.value = 'pipeline';
}
function openStage(stage = null) {
  editingId.value = stage?.id || null;
  Object.assign(stageForm, {
    name: stage?.name || '',
    probabilityPct: stage?.probabilityPct ?? 0,
    expectedDurationDays: stage?.expectedDurationDays ?? null,
    color:
      stage?.color || COLORS[selectedStages.value.length % COLORS.length],
  });
  panel.value = 'stage';
}
function openScoring() {
  editingId.value = null;
  panel.value = 'scoring';
}
function closePanel() {
  panel.value = '';
  editingId.value = null;
}

async function savePipeline() {
  if (pipelineForm.name.trim().length < 2) {
    error.value = 'Informe um nome com pelo menos 2 caracteres.';
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      name: pipelineForm.name.trim(),
      slug: pipelineForm.slug.trim() || slugify(pipelineForm.name),
      isDefault: pipelineForm.isDefault,
      position: Number(pipelineForm.position) || 0,
    };
    if (editingId.value) {
      await CrmAPI.updatePipeline(editingId.value, payload);
      notify('Pipeline atualizado.');
    } else {
      const response = await CrmAPI.createPipeline(payload);
      selectedPipelineId.value = response.data.id;
      notify('Pipeline criado.');
    }
    closePanel();
    await loadAll();
    notifyChanged();
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível salvar o pipeline.');
  } finally {
    saving.value = false;
  }
}

async function saveStage() {
  const probability = Number(stageForm.probabilityPct);
  if (
    stageForm.name.trim().length < 2 ||
    probability < 0 ||
    probability > 100 ||
    Number(stageForm.expectedDurationDays || 0) < 0
  ) {
    error.value = 'Revise nome, probabilidade e duração da etapa.';
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      name: stageForm.name.trim(),
      slug: slugify(stageForm.name),
      probabilityPct: probability,
      expectedDurationDays:
        stageForm.expectedDurationDays === '' ||
        stageForm.expectedDurationDays === null
          ? null
          : Number(stageForm.expectedDurationDays),
      color: stageForm.color,
    };
    if (editingId.value) {
      await CrmAPI.updatePipelineStage(
        selectedPipeline.value.id,
        editingId.value,
        payload
      );
      notify('Etapa atualizada.');
    } else {
      await CrmAPI.createPipelineStage(selectedPipeline.value.id, payload);
      notify('Etapa criada.');
    }
    closePanel();
    await loadStages(selectedPipeline.value.id);
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível salvar a etapa.');
  } finally {
    saving.value = false;
  }
}

async function saveScoring() {
  if (scoringTotal.value !== 100) {
    error.value = 'A soma dos pesos precisa fechar exatamente em 100.';
    return;
  }
  saving.value = true;
  try {
    await CrmAPI.updatePipeline(selectedPipeline.value.id, {
      scoring_config: {
        ...(selectedPipeline.value.scoringConfig || {}),
        weights: scoringWeights.value[selectedPipeline.value.id],
      },
    });
    notify('Scoring atualizado.');
    closePanel();
    await loadPipelines();
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível salvar o scoring.');
  } finally {
    saving.value = false;
  }
}

async function reorderStages(newList) {
  const pipelineId = selectedPipeline.value.id;
  stages.value[pipelineId] = newList;
  try {
    await Promise.all(
      newList.map((stage, position) =>
        CrmAPI.updatePipelineStage(pipelineId, stage.id, { position })
      )
    );
    notify('Ordem atualizada.');
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível reordenar as etapas.');
    await loadStages(pipelineId);
  }
}

async function archivePipeline(pipeline) {
  saving.value = true;
  try {
    await CrmAPI.archivePipeline(pipeline.id);
    notify('Pipeline arquivado.');
    await loadAll();
    notifyChanged();
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível arquivar o pipeline.');
  } finally {
    saving.value = false;
  }
}
async function archiveStage(stage) {
  saving.value = true;
  try {
    await CrmAPI.archivePipelineStage(selectedPipeline.value.id, stage.id);
    notify('Etapa arquivada.');
    await loadStages(selectedPipeline.value.id);
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível arquivar a etapa.');
  } finally {
    saving.value = false;
  }
}

async function toggleArchived() {
  showArchived.value = !showArchived.value;
  if (!showArchived.value) return;
  loading.value = true;
  try {
    archivedPipelines.value = extract(await CrmAPI.getArchivedPipelines()).map(
      normalizePipeline
    );
    const pairs = await Promise.all(
      archivedPipelines.value.map(async pipeline => {
        try {
          return [
            pipeline.id,
            extract(await CrmAPI.getArchivedPipelineStages(pipeline.id)).map(
              normalizeStage
            ),
          ];
        } catch {
          return [pipeline.id, []];
        }
      })
    );
    archivedStages.value = Object.fromEntries(pairs);
  } finally {
    loading.value = false;
  }
}
async function restorePipeline(pipeline) {
  await CrmAPI.restorePipeline(pipeline.id);
  notify('Pipeline restaurado.');
  await toggleArchived();
  await toggleArchived();
  notifyChanged();
}
async function restoreStage(pipelineId, stage) {
  await CrmAPI.restorePipelineStage(pipelineId, stage.id);
  notify('Etapa restaurada.');
  await toggleArchived();
  await toggleArchived();
}

function requestDelete(target) {
  deleteTarget.value = target;
  deleteName.value = '';
}
async function confirmDelete() {
  if (!deleteAllowed.value) return;
  saving.value = true;
  try {
    if (deleteTarget.value.type === 'pipeline') {
      await CrmAPI.purgePipeline(deleteTarget.value.id);
      notifyChanged();
    } else {
      await CrmAPI.purgePipelineStage(
        deleteTarget.value.pipelineId,
        deleteTarget.value.id
      );
    }
    notify('Item excluído permanentemente.');
    deleteTarget.value = null;
    await toggleArchived();
    await toggleArchived();
  } catch (requestError) {
    error.value = apiError(requestError, 'Não foi possível excluir o item.');
  } finally {
    saving.value = false;
  }
}

watch(selectedPipelineId, closePanel);
onMounted(loadAll);
</script>

<template>
  <SettingsPageTemplate
    title="Configuração do pipeline"
    :breadcrumbs="[{ label: 'CRM' }, { label: 'Configuração do pipeline' }]"
    :loading="loading"
    :empty="!loading && !pipelines.length && !showArchived"
    empty-title="Nenhum pipeline configurado."
  >
    <template #actions>
      <DsButton variant="secondary" icon="i-lucide-arrow-left" label="Voltar" @click="router.push({ name: 'crm_dashboard', params: { accountId } })" />
      <DsButton
        variant="secondary"
        :icon="showArchived ? 'i-lucide-layout-list' : 'i-lucide-archive'"
        :label="showArchived ? 'Ver ativos' : 'Ver arquivados'"
        @click="toggleArchived"
      />
      <DsButton v-if="!showArchived" variant="primary" icon="i-lucide-plus" label="Novo pipeline" @click="openPipeline()" />
    </template>

    <template #navigation>
      <div v-if="!showArchived">
        <DsSelect
          v-model="selectedPipelineId"
          label="Pipeline"
          hide-label
          :options="pipelineOptions"
          class="lg:hidden"
        />
        <div class="hidden gap-2 lg:flex lg:flex-col">
          <button
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            type="button"
            class="flex min-h-10 items-center justify-between gap-2 rounded-ui-control border px-3 py-2 text-left text-ui-body-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
            :class="String(selectedPipelineId) === String(pipeline.id) ? 'border-ui-brand bg-ui-brand-soft text-ui-brand' : 'border-transparent text-ui-text-muted hover:bg-ui-hover hover:text-ui-text'"
            @click="selectedPipelineId = pipeline.id"
          >
            <span class="truncate">{{ pipeline.name }}</span>
            <DsBadge v-if="pipeline.isDefault" label="Padrão" variant="brand" />
          </button>
        </div>
      </div>
      <div v-else class="rounded-ui-surface border border-ui-border-subtle bg-ui-sunken p-3 text-ui-body-sm text-ui-text-muted">
        Itens arquivados podem ser restaurados ou excluídos definitivamente.
      </div>
    </template>

    <div v-if="!showArchived && selectedPipeline" class="flex flex-col gap-5">
      <section class="grid gap-3 sm:grid-cols-3" aria-label="Resumo do pipeline">
        <DsCard padding="sm"><p class="m-0 text-ui-caption text-ui-text-muted">Pipelines ativos</p><strong class="mt-1 block text-ui-heading tabular-nums">{{ pipelines.length }}</strong></DsCard>
        <DsCard padding="sm"><p class="m-0 text-ui-caption text-ui-text-muted">Etapas configuradas</p><strong class="mt-1 block text-ui-heading tabular-nums">{{ totalStages }}</strong></DsCard>
        <DsCard padding="sm"><p class="m-0 text-ui-caption text-ui-text-muted">Probabilidade média</p><strong class="mt-1 block text-ui-heading tabular-nums">{{ averageProbability }}%</strong></DsCard>
      </section>

      <section>
        <div class="mb-3 flex flex-wrap items-start justify-between gap-3">
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="m-0 text-ui-title font-semibold">{{ selectedPipeline.name }}</h2>
              <DsBadge v-if="selectedPipeline.isDefault" label="Pipeline padrão" variant="brand" />
            </div>
            <p class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted">/{{ selectedPipeline.slug }} · {{ selectedStages.length }} etapas</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <DsButton variant="secondary" icon="i-lucide-gauge" label="Scoring" @click="openScoring" />
            <DsButton variant="secondary" icon="i-lucide-pencil" label="Editar" @click="openPipeline(selectedPipeline)" />
            <DsButton variant="ghost" icon="i-lucide-archive" aria-label="Arquivar pipeline" @click="archivePipeline(selectedPipeline)" />
          </div>
        </div>

        <Draggable
          :model-value="selectedStages"
          item-key="id"
          handle=".stage-handle"
          class="flex flex-col gap-2"
          @update:model-value="reorderStages"
        >
          <template #item="{ element: stage, index }">
            <DsCard padding="sm">
              <div class="flex items-center gap-3">
                <button type="button" class="stage-handle grid size-10 shrink-0 cursor-grab place-items-center rounded-ui-control border border-ui-border-subtle bg-ui-sunken text-ui-text-muted" :aria-label="`Reordenar ${stage.name}`">
                  <span class="i-lucide-grip-vertical size-4" aria-hidden="true" />
                </button>
                <span
                  class="size-2.5 shrink-0 rounded-full"
                  :class="stageColorClass(stage.color)"
                  aria-hidden="true"
                />
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <h3 class="m-0 truncate text-ui-body font-semibold">{{ stage.name }}</h3>
                    <DsBadge :label="`${stage.probabilityPct}%`" variant="neutral" />
                  </div>
                  <p class="mb-0 mt-1 text-ui-caption text-ui-text-muted">Etapa {{ index + 1 }} · {{ stage.expectedDurationDays ? `${stage.expectedDurationDays} dias` : 'Sem prazo' }}</p>
                </div>
                <DsButton variant="ghost" icon="i-lucide-pencil" :aria-label="`Editar ${stage.name}`" @click="openStage(stage)" />
                <DsButton variant="ghost" icon="i-lucide-archive" :aria-label="`Arquivar ${stage.name}`" @click="archiveStage(stage)" />
              </div>
            </DsCard>
          </template>
        </Draggable>
        <DsButton class="mt-3" variant="secondary" icon="i-lucide-plus" label="Adicionar etapa" @click="openStage()" />
      </section>
    </div>

    <div v-else-if="showArchived" class="flex flex-col gap-4">
      <div>
        <h2 class="m-0 text-ui-title font-semibold">Itens arquivados</h2>
        <p class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted">Restaure configurações ou confirme a exclusão definitiva pelo nome.</p>
      </div>
      <DsCard v-for="pipeline in archivedPipelines" :key="pipeline.id">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div><h3 class="m-0 text-ui-body font-semibold">{{ pipeline.name }}</h3><p class="mb-0 mt-1 text-ui-caption text-ui-text-muted">{{ (archivedStages[pipeline.id] || []).length }} etapas arquivadas</p></div>
          <div class="flex gap-2">
            <DsButton variant="secondary" icon="i-lucide-rotate-ccw" label="Restaurar" @click="restorePipeline(pipeline)" />
            <DsButton variant="danger" icon="i-lucide-trash-2" aria-label="Excluir pipeline definitivamente" @click="requestDelete({ type: 'pipeline', ...pipeline })" />
          </div>
        </div>
        <div v-if="(archivedStages[pipeline.id] || []).length" class="mt-4 divide-y divide-ui-border-subtle border-t border-ui-border-subtle">
          <div v-for="stage in archivedStages[pipeline.id]" :key="stage.id" class="flex flex-wrap items-center justify-between gap-2 py-3">
            <span class="text-ui-body-sm">{{ stage.name }}</span>
            <div class="flex gap-2">
              <DsButton size="sm" variant="ghost" label="Restaurar" @click="restoreStage(pipeline.id, stage)" />
              <DsButton size="sm" variant="ghost" icon="i-lucide-trash-2" :aria-label="`Excluir ${stage.name} definitivamente`" @click="requestDelete({ type: 'stage', pipelineId: pipeline.id, ...stage })" />
            </div>
          </div>
        </div>
      </DsCard>
      <p v-if="!archivedPipelines.length" class="text-ui-body-sm text-ui-text-muted">Nenhum pipeline arquivado.</p>
    </div>
  </SettingsPageTemplate>

  <DsDrawer :open="Boolean(panel)" :title="panelTitle" :loading="saving" @close="closePanel">
    <form v-if="panel === 'pipeline'" id="pipeline-form" class="flex flex-col gap-4" @submit.prevent="savePipeline">
      <DsInput v-model="pipelineForm.name" label="Nome do pipeline" placeholder="Ex.: Pipeline de Vendas" required />
      <DsInput v-model="pipelineForm.slug" label="Identificador" :placeholder="slugify(pipelineForm.name) || 'pipeline'" description="Usado internamente nas integrações." />
      <DsInput v-model="pipelineForm.position" type="number" min="0" label="Posição" />
      <label class="flex items-center gap-2 text-ui-body-sm"><input v-model="pipelineForm.isDefault" type="checkbox" class="size-4 accent-ui-brand" /> Definir como pipeline padrão</label>
    </form>

    <form v-else-if="panel === 'stage'" id="stage-form" class="flex flex-col gap-4" @submit.prevent="saveStage">
      <DsInput v-model="stageForm.name" label="Nome da etapa" placeholder="Ex.: Análise documental" required />
      <DsInput v-model="stageForm.probabilityPct" type="number" min="0" max="100" label="Probabilidade (%)" />
      <DsInput v-model="stageForm.expectedDurationDays" type="number" min="0" label="Prazo esperado (dias)" />
      <fieldset class="flex flex-col gap-2">
        <legend class="text-ui-label font-medium">Cor de identificação</legend>
        <div class="flex flex-wrap gap-2">
          <label v-for="color in COLORS" :key="color" class="relative grid size-10 cursor-pointer place-items-center rounded-ui-control border border-ui-border-subtle">
            <input v-model="stageForm.color" type="radio" :value="color" class="sr-only" />
            <span
              class="size-5 rounded-full"
              :class="[
                stageColorClass(color),
                { 'ring-2 ring-ui-border-focus ring-offset-2 ring-offset-ui-elevated': stageForm.color === color },
              ]"
            />
            <span v-if="stageForm.color === color" class="i-lucide-check absolute size-3 text-ui-text-inverse" aria-hidden="true" />
            <span class="sr-only">{{ color }}</span>
          </label>
        </div>
      </fieldset>
    </form>

    <form v-else-if="panel === 'scoring'" id="scoring-form" class="flex flex-col gap-4" @submit.prevent="saveScoring">
      <div class="flex items-center justify-between rounded-ui-surface border border-ui-border-subtle bg-ui-sunken p-3">
        <span class="text-ui-body-sm font-medium">Total dos pesos</span>
        <DsBadge :label="`${scoringTotal}/100`" :variant="scoringTotal === 100 ? 'success' : 'warning'" />
      </div>
      <DsInput
        v-for="(label, key) in WEIGHT_LABELS"
        :key="key"
        v-model="scoringWeights[selectedPipeline.id][key]"
        type="number"
        min="0"
        max="100"
        :label="label"
      />
      <DsButton variant="ghost" label="Restaurar pesos recomendados" icon="i-lucide-rotate-ccw" @click="scoringWeights[selectedPipeline.id] = { ...DEFAULT_WEIGHTS }" />
    </form>

    <template #footer>
      <div class="flex justify-end gap-2">
        <DsButton variant="secondary" label="Cancelar" @click="closePanel" />
        <DsButton
          type="submit"
          :form="panel === 'pipeline' ? 'pipeline-form' : panel === 'stage' ? 'stage-form' : 'scoring-form'"
          variant="primary"
          label="Salvar"
          :loading="saving"
        />
      </div>
    </template>
  </DsDrawer>

  <DsModal
    :open="Boolean(deleteTarget)"
    title="Excluir definitivamente"
    :description="`Digite “${deleteTarget?.name || ''}” para confirmar. Esta ação não pode ser desfeita.`"
    confirm-label="Excluir definitivamente"
    dangerous
    :disabled="!deleteAllowed"
    :loading="saving"
    @close="deleteTarget = null"
    @confirm="confirmDelete"
  >
    <DsInput v-model="deleteName" label="Nome para confirmação" autocomplete="off" />
  </DsModal>

  <div class="pointer-events-none fixed bottom-4 left-1/2 z-ui-toast flex w-[min(92vw,32rem)] -translate-x-1/2 flex-col gap-2">
    <div v-if="error" role="alert" class="rounded-ui-surface border border-ui-danger bg-ui-danger-soft px-4 py-3 text-ui-body-sm text-ui-danger-foreground">{{ error }}</div>
    <div v-if="success" role="status" class="rounded-ui-surface border border-ui-success bg-ui-success-soft px-4 py-3 text-ui-body-sm text-ui-success">{{ success }}</div>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import CrmAPI from 'dashboard/api/crm';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DsBadge from 'dashboard/design-system/components/DsBadge.vue';
import DsButton from 'dashboard/design-system/components/DsButton.vue';
import DsCard from 'dashboard/design-system/components/DsCard.vue';
import DsEmptyState from 'dashboard/design-system/components/DsEmptyState.vue';
import DsInput from 'dashboard/design-system/components/DsInput.vue';
import DsModal from 'dashboard/design-system/components/DsModal.vue';
import DsSelect from 'dashboard/design-system/components/DsSelect.vue';
import DsSkeleton from 'dashboard/design-system/components/DsSkeleton.vue';
import { DsPageHeader } from 'dashboard/design-system/templates';
import AutomationFlowBuilder from '../components/automation/AutomationFlowBuilder.vue';

const { t } = useI18n();

const rules = ref([]);
const pipelines = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const isBuilderOpen = ref(false);
const editingRule = ref(null);
const deletingRule = ref(null);

const filters = reactive({
  search: '',
  status: '',
  stage_id: '',
});

const PRIORITY_BADGE_VARIANTS = {
  critica: 'danger',
  alta: 'warning',
  baixa: 'neutral',
};

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const allStages = computed(() =>
  pipelines.value.flatMap(pipeline =>
    (pipeline.stages || []).map(stage => ({
      id: stage.id,
      name: stage.name,
      pipelineName: pipeline.name,
    }))
  )
);

const stageMap = computed(() => {
  const map = {};
  allStages.value.forEach(stage => {
    map[stage.id] = `${stage.pipelineName} / ${stage.name}`;
  });
  return map;
});

const actionKindOptions = computed(() => [
  { value: 'ligacao', label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.LIGACAO') },
  {
    value: 'solicitacao_documentos',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.SOLICITACAO_DOCUMENTOS'),
  },
  { value: 'follow_up', label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.FOLLOW_UP') },
  { value: 'reuniao', label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.REUNIAO') },
  {
    value: 'revisao_juridica',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.REVISAO_JURIDICA'),
  },
  {
    value: 'analise_documental',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ANALISE_DOCUMENTAL'),
  },
  {
    value: 'retorno_cliente',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.RETORNO_CLIENTE'),
  },
  {
    value: 'envio_proposta',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ENVIO_PROPOSTA'),
  },
  {
    value: 'envio_contrato',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ENVIO_CONTRATO'),
  },
  {
    value: 'arquivamento',
    label: t('CRM.AUTOMATION_RULES.ACTION_KINDS.ARQUIVAMENTO'),
  },
]);

const priorityOptions = computed(() => [
  { value: 'baixa', label: t('CRM.AUTOMATION_RULES.PRIORITIES.BAIXA') },
  { value: 'normal', label: t('CRM.AUTOMATION_RULES.PRIORITIES.NORMAL') },
  { value: 'alta', label: t('CRM.AUTOMATION_RULES.PRIORITIES.ALTA') },
  { value: 'critica', label: t('CRM.AUTOMATION_RULES.PRIORITIES.CRITICA') },
]);

const conditionFieldOptions = computed(() => [
  {
    value: 'legal_area',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.LEGAL_AREA'),
  },
  {
    value: 'case_type',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.CASE_TYPE'),
  },
  {
    value: 'urgency_level',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.URGENCY_LEVEL'),
  },
  {
    value: 'score_total',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.SCORE_TOTAL'),
  },
  {
    value: 'relationship_status',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.RELATIONSHIP_STATUS'),
  },
  {
    value: 'lifecycle_stage',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.LIFECYCLE_STAGE'),
  },
  {
    value: 'has_phone',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.HAS_PHONE'),
  },
  {
    value: 'campaign_opt_out',
    label: t('CRM.AUTOMATION_RULES.CONDITION_FIELDS.CAMPAIGN_OPT_OUT'),
  },
]);

const conditionOperatorOptions = computed(() => [
  { value: 'eq', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.EQ') },
  { value: 'not_eq', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.NOT_EQ') },
  { value: 'present', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.PRESENT') },
  { value: 'blank', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.BLANK') },
  { value: 'gt', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.GT') },
  { value: 'gte', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.GTE') },
  { value: 'lt', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.LT') },
  { value: 'lte', label: t('CRM.AUTOMATION_RULES.CONDITION_OPERATORS.LTE') },
]);

const statusFilterOptions = computed(() => [
  { value: '', label: t('CRM.AUTOMATION_RULES.FILTERS.STATUS_ALL') },
  { value: 'active', label: t('CRM.AUTOMATION_RULES.FILTERS.STATUS_ACTIVE') },
  { value: 'paused', label: t('CRM.AUTOMATION_RULES.FILTERS.STATUS_PAUSED') },
]);

const stageOptions = computed(() =>
  allStages.value.map(stage => ({
    value: stage.id,
    label: `${stage.pipelineName} / ${stage.name}`,
  }))
);

const stageFilterOptions = computed(() => [
  { value: '', label: t('CRM.AUTOMATION_RULES.FILTERS.STAGE_ALL') },
  ...stageOptions.value,
]);

const normalized = value =>
  String(value || '')
    .toLowerCase()
    .trim();

const filteredRules = computed(() => {
  const search = normalized(filters.search);
  return rules.value.filter(rule => {
    const stageLabel = stageMap.value[rule.crm_pipeline_stage_id] || '';
    const matchesSearch =
      !search ||
      [
        rule.name,
        rule.action_config?.title,
        rule.action_config?.description,
        stageLabel,
      ]
        .map(normalized)
        .some(value => value.includes(search));
    const matchesStatus =
      !filters.status ||
      (filters.status === 'active' ? rule.is_active : !rule.is_active);
    const matchesStage =
      !filters.stage_id ||
      String(rule.crm_pipeline_stage_id) === String(filters.stage_id);
    return matchesSearch && matchesStatus && matchesStage;
  });
});

const summary = computed(() => {
  const active = rules.value.filter(rule => rule.is_active).length;
  const paused = rules.value.length - active;
  const fast = rules.value.filter(
    rule => Number(rule.action_config?.due_in_hours || 0) <= 12
  ).length;
  const critical = rules.value.filter(
    rule => rule.action_config?.priority === 'critica'
  ).length;

  return [
    {
      key: 'total',
      label: t('CRM.AUTOMATION_RULES.SUMMARY.TOTAL'),
      value: rules.value.length,
    },
    { key: 'active', label: t('CRM.AUTOMATION_RULES.SUMMARY.ACTIVE'), value: active },
    { key: 'paused', label: t('CRM.AUTOMATION_RULES.SUMMARY.PAUSED'), value: paused },
    { key: 'fast', label: t('CRM.AUTOMATION_RULES.SUMMARY.FAST'), value: fast },
    {
      key: 'critical',
      label: t('CRM.AUTOMATION_RULES.SUMMARY.CRITICAL'),
      value: critical,
    },
  ];
});

function labelFor(options, value) {
  return options.find(opt => opt.value === value)?.label || value;
}

function actionKindLabel(kind) {
  return labelFor(actionKindOptions.value, kind);
}

function priorityLabel(priority) {
  return labelFor(priorityOptions.value, priority);
}

function priorityBadgeVariant(priority) {
  return PRIORITY_BADGE_VARIANTS[priority] || 'brand';
}

function conditionLabel(condition) {
  const field = labelFor(conditionFieldOptions.value, condition.field);
  const operator = labelFor(conditionOperatorOptions.value, condition.operator);
  if (['present', 'blank'].includes(condition.operator)) {
    return `${field} ${operator}`;
  }
  return `${field} ${operator} ${condition.value || '-'}`;
}

function openNew() {
  editingRule.value = {
    name: '',
    trigger_event: 'stage_entered',
    crm_pipeline_stage_id: allStages.value[0]?.id || '',
    action_type: 'create_activity',
    action_config: {
      kind: 'follow_up',
      title: '',
      description: '',
      priority: 'normal',
      due_in_hours: 24,
      conditions: [],
    },
  };
  isBuilderOpen.value = true;
}

function openEdit(rule) {
  editingRule.value = { ...rule };
  isBuilderOpen.value = true;
}

function closeBuilder() {
  isBuilderOpen.value = false;
  editingRule.value = null;
}

function clearFilters() {
  filters.search = '';
  filters.status = '';
  filters.stage_id = '';
}

async function loadData() {
  loading.value = true;
  error.value = '';
  try {
    const [rulesRes, pipelinesRes] = await Promise.all([
      CrmAPI.getAutomationRules(),
      CrmAPI.getPipelines(),
    ]);
    rules.value = extractData(rulesRes);
    pipelines.value = extractData(pipelinesRes);
  } catch {
    error.value = t('CRM.AUTOMATION_RULES.ERROR_LOAD');
  } finally {
    loading.value = false;
  }
}

async function handleSaveRule(payload) {
  saving.value = true;
  error.value = '';

  try {
    if (editingRule.value?.id) {
      await CrmAPI.updateAutomationRule(editingRule.value.id, payload);
    } else {
      await CrmAPI.createAutomationRule(payload);
    }
    closeBuilder();
    await loadData();
  } catch (err) {
    error.value =
      err?.response?.data?.error ||
      err?.response?.data?.message ||
      t('CRM.AUTOMATION_RULES.ERROR_SAVE');
  } finally {
    saving.value = false;
  }
}

async function toggleActive(rule) {
  try {
    await CrmAPI.updateAutomationRule(rule.id, { is_active: !rule.is_active });
    await loadData();
  } catch {
    error.value = t('CRM.AUTOMATION_RULES.ERROR_TOGGLE');
  }
}

function requestDelete(rule) {
  deletingRule.value = rule;
}

async function confirmDelete() {
  if (!deletingRule.value) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteAutomationRule(deletingRule.value.id);
    deletingRule.value = null;
    await loadData();
  } catch {
    error.value = t('CRM.AUTOMATION_RULES.ERROR_DELETE');
  } finally {
    saving.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <!-- Builder View -->
    <AutomationFlowBuilder
      v-if="isBuilderOpen"
      :initial-rule="editingRule"
      :pipelines="pipelines"
      :saving="saving"
      @save="handleSaveRule"
      @cancel="closeBuilder"
    />

    <!-- List View -->
    <template v-else>
      <DsPageHeader
        :title="$t('CRM.AUTOMATION_RULES.TITLE')"
        :breadcrumbs="[
          { label: $t('CRM.AUTOMATION_RULES.BREADCRUMB') },
          { label: $t('CRM.AUTOMATION_RULES.TITLE') },
        ]"
      >
        <template #actions>
          <DsButton
            icon="i-lucide-plus"
            variant="primary"
            :label="$t('CRM.AUTOMATION_RULES.NEW_RULE')"
            @click="openNew"
          />
        </template>
      </DsPageHeader>

      <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
        <div>
          <p
            class="m-0 text-ui-caption font-medium uppercase tracking-wide text-ui-brand"
          >
            {{ $t('CRM.AUTOMATION_RULES.EYEBROW') }}
          </p>
          <p class="m-0 mt-1 max-w-2xl text-ui-body-sm text-ui-text-muted">
            {{ $t('CRM.AUTOMATION_RULES.SUBTITLE') }}
          </p>
        </div>

        <DsCard
          as="section"
          padding="none"
          :aria-label="$t('CRM.AUTOMATION_RULES.SUMMARY.TITLE')"
        >
          <dl class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5">
            <div
              v-for="item in summary"
              :key="item.key"
              class="flex min-w-0 flex-col gap-1 p-3 sm:p-4"
            >
              <dt
                class="truncate text-ui-caption font-medium uppercase tracking-wide text-ui-text-muted"
              >
                {{ item.label }}
              </dt>
              <dd
                class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
              >
                {{ item.value }}
              </dd>
            </div>
          </dl>
        </DsCard>

        <div
          class="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-[minmax(0,1fr)_auto_auto_auto] xl:items-end"
        >
          <DsInput
            v-model="filters.search"
            type="search"
            :label="$t('CRM.AUTOMATION_RULES.FILTERS.SEARCH_LABEL')"
            hide-label
            :placeholder="$t('CRM.AUTOMATION_RULES.FILTERS.SEARCH_PLACEHOLDER')"
          >
            <template #prefix>
              <Icon icon="i-lucide-search" class="size-4" />
            </template>
          </DsInput>
          <DsSelect
            v-model="filters.status"
            :label="$t('CRM.AUTOMATION_RULES.FILTERS.STATUS_LABEL')"
            hide-label
            :options="statusFilterOptions"
            class="xl:w-44"
          />
          <DsSelect
            v-model="filters.stage_id"
            :label="$t('CRM.AUTOMATION_RULES.FILTERS.STAGE_LABEL')"
            hide-label
            :options="stageFilterOptions"
            class="xl:w-64"
          />
          <DsButton
            variant="ghost"
            :label="$t('CRM.AUTOMATION_RULES.FILTERS.CLEAR')"
            @click="clearFilters"
          />
        </div>

        <div
          v-if="error"
          role="alert"
          class="rounded-ui-control border border-ui-danger/20 bg-ui-danger-soft px-3 py-2 text-ui-body-sm text-ui-danger-foreground"
        >
          {{ error }}
        </div>

        <div
          v-if="loading"
          role="status"
          :aria-label="$t('CRM.AUTOMATION_RULES.LOADING')"
          class="flex flex-col gap-3"
        >
          <span class="sr-only">{{ $t('CRM.AUTOMATION_RULES.LOADING') }}</span>
          <DsSkeleton v-for="row in 3" :key="row" shape="block" class="h-28" />
        </div>

        <DsEmptyState
          v-else-if="filteredRules.length === 0"
          :title="$t('CRM.AUTOMATION_RULES.EMPTY_TITLE')"
        >
          <template #action>
            <p class="m-0 max-w-md text-ui-body-sm text-ui-text-muted">
              {{ $t('CRM.AUTOMATION_RULES.EMPTY_DESCRIPTION') }}
            </p>
            <DsButton
              icon="i-lucide-plus"
              variant="primary"
              :label="$t('CRM.AUTOMATION_RULES.EMPTY_ACTION')"
              @click="openNew"
            />
          </template>
        </DsEmptyState>

        <div v-else class="flex flex-col gap-3">
          <DsCard v-for="rule in filteredRules" :key="rule.id" as="article">
            <div class="flex flex-col gap-3 sm:flex-row sm:items-start">
              <div
                aria-hidden="true"
                class="grid size-10 shrink-0 place-items-center rounded-ui-control bg-ui-brand-soft text-ui-brand"
              >
                <Icon icon="i-lucide-zap" class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-center gap-2">
                  <h2
                    class="m-0 min-w-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
                  >
                    {{ rule.name }}
                  </h2>
                  <DsBadge
                    :variant="rule.is_active ? 'success' : 'neutral'"
                    :label="
                      rule.is_active
                        ? $t('CRM.AUTOMATION_RULES.CARD.STATUS_ACTIVE')
                        : $t('CRM.AUTOMATION_RULES.CARD.STATUS_PAUSED')
                    "
                  />
                </div>
                <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
                  {{ $t('CRM.AUTOMATION_RULES.CARD.TRIGGER_PREFIX') }}
                  <strong class="font-medium text-ui-text">
                    {{
                      stageMap[rule.crm_pipeline_stage_id] ||
                      $t('CRM.AUTOMATION_RULES.CARD.STAGE_UNLINKED')
                    }}
                  </strong>
                </p>
                <div class="mt-2 flex flex-wrap gap-1.5">
                  <DsBadge
                    variant="brand"
                    :label="actionKindLabel(rule.action_config?.kind)"
                  />
                  <DsBadge
                    :variant="priorityBadgeVariant(rule.action_config?.priority)"
                    :label="priorityLabel(rule.action_config?.priority)"
                  />
                  <DsBadge
                    variant="neutral"
                    :label="
                      $t('CRM.AUTOMATION_RULES.CARD.DUE', {
                        hours: rule.action_config?.due_in_hours ?? 24,
                      })
                    "
                  />
                  <DsBadge
                    v-if="rule.action_config?.conditions?.length"
                    variant="neutral"
                    :label="
                      $t(
                        'CRM.AUTOMATION_RULES.CARD.CONDITIONS_COUNT',
                        rule.action_config.conditions.length
                      )
                    "
                  />
                </div>
                <ul
                  v-if="rule.action_config?.conditions?.length"
                  class="m-0 mt-2 flex list-disc flex-col gap-1 pl-4 text-ui-caption text-ui-text-muted"
                >
                  <li
                    v-for="(condition, index) in rule.action_config.conditions"
                    :key="`${rule.id}-condition-${index}`"
                  >
                    {{ conditionLabel(condition) }}
                  </li>
                </ul>
                <p class="m-0 mt-2 text-ui-body-sm font-medium text-ui-text">
                  {{
                    rule.action_config?.title ||
                    $t('CRM.AUTOMATION_RULES.CARD.UNTITLED')
                  }}
                </p>
                <p
                  v-if="rule.action_config?.description"
                  class="m-0 mt-1 text-ui-body-sm text-ui-text-muted"
                >
                  {{ rule.action_config.description }}
                </p>
              </div>
              <div class="flex shrink-0 flex-wrap gap-2 sm:flex-col sm:items-stretch">
                <DsButton
                  size="sm"
                  variant="secondary"
                  :icon="rule.is_active ? 'i-lucide-pause' : 'i-lucide-play'"
                  :label="
                    rule.is_active
                      ? $t('CRM.AUTOMATION_RULES.CARD.PAUSE')
                      : $t('CRM.AUTOMATION_RULES.CARD.ACTIVATE')
                  "
                  @click="toggleActive(rule)"
                />
                <DsButton
                  size="sm"
                  variant="secondary"
                  icon="i-lucide-pencil"
                  :label="$t('CRM.AUTOMATION_RULES.CARD.EDIT')"
                  @click="openEdit(rule)"
                />
                <DsButton
                  size="sm"
                  variant="danger"
                  icon="i-lucide-trash-2"
                  :label="$t('CRM.AUTOMATION_RULES.CARD.DELETE')"
                  @click="requestDelete(rule)"
                />
              </div>
            </div>
          </DsCard>
        </div>
      </div>

      <DsModal
        :open="!!deletingRule"
        dangerous
        :title="$t('CRM.AUTOMATION_RULES.DELETE_MODAL.TITLE')"
        :description="
          $t('CRM.AUTOMATION_RULES.DELETE_MODAL.DESCRIPTION', {
            name: deletingRule?.name || '',
          })
        "
        :confirm-label="$t('CRM.AUTOMATION_RULES.DELETE_MODAL.CONFIRM')"
        :cancel-label="$t('CRM.AUTOMATION_RULES.DELETE_MODAL.CANCEL')"
        :loading="saving"
        @close="deletingRule = null"
        @confirm="confirmDelete"
      />
    </template>
  </section>
</template>

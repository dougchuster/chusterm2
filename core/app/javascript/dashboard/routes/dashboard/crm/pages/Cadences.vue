<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import CrmAPI from 'dashboard/api/crm';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsCheckbox,
  DsDrawer,
  DsEmptyState,
  DsInput,
  DsModal,
  DsSelect,
  DsSkeleton,
  DsTextarea,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();

const cadences = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const showModal = ref(false);
const editingId = ref(null);
const archiveTarget = ref(null);

const CHANNELS = computed(() => [
  {
    value: 'whatsapp',
    label: t('CRM.CADENCES.CHANNELS.WHATSAPP'),
    icon: 'i-lucide-message-circle',
  },
  {
    value: 'email',
    label: t('CRM.CADENCES.CHANNELS.EMAIL'),
    icon: 'i-lucide-mail',
  },
  {
    value: 'sms',
    label: t('CRM.CADENCES.CHANNELS.SMS'),
    icon: 'i-lucide-smartphone',
  },
  {
    value: 'task',
    label: t('CRM.CADENCES.CHANNELS.TASK'),
    icon: 'i-lucide-list-checks',
  },
]);

const STATUSES = computed(() => [
  { value: 'draft', label: t('CRM.CADENCES.STATUSES.DRAFT') },
  { value: 'active', label: t('CRM.CADENCES.STATUSES.ACTIVE') },
  { value: 'paused', label: t('CRM.CADENCES.STATUSES.PAUSED') },
]);

const ACTION_TYPES = computed(() => [
  {
    value: 'send_message',
    label: t('CRM.CADENCES.ACTIONS.SEND_MESSAGE'),
    icon: 'i-lucide-send',
  },
  {
    value: 'create_activity',
    label: t('CRM.CADENCES.ACTIONS.CREATE_ACTIVITY'),
    icon: 'i-lucide-calendar-plus',
  },
  {
    value: 'wait',
    label: t('CRM.CADENCES.ACTIONS.WAIT'),
    icon: 'i-lucide-clock-3',
  },
]);

const CONDITION_MISS_BEHAVIORS = computed(() => [
  { value: 'skip_step', label: t('CRM.CADENCES.CONDITION_MISS.SKIP_STEP') },
  {
    value: 'pause_enrollment',
    label: t('CRM.CADENCES.CONDITION_MISS.PAUSE_ENROLLMENT'),
  },
  {
    value: 'cancel_enrollment',
    label: t('CRM.CADENCES.CONDITION_MISS.CANCEL_ENROLLMENT'),
  },
]);

const STATUS_BADGE_VARIANTS = {
  draft: 'neutral',
  active: 'success',
  paused: 'warning',
};

const conditionPlaceholder =
  '[{"field":"score_total","operator":"gte","value":70}]';

const TEMPLATE_DEFS = [
  {
    key: 'lead_sem_resposta',
    i18nKey: 'LEAD_SEM_RESPOSTA',
    icon: 'i-lucide-message-circle-warning',
    channel: 'whatsapp',
    steps: [
      { i18nKey: 'STEP_1', wait_hours: 0, action_type: 'send_message' },
      { i18nKey: 'STEP_2', wait_hours: 24, action_type: 'create_activity' },
      { i18nKey: 'STEP_3', wait_hours: 72, action_type: 'send_message' },
    ],
  },
  {
    key: 'documentos_pendentes',
    i18nKey: 'DOCUMENTOS_PENDENTES',
    icon: 'i-lucide-files',
    channel: 'whatsapp',
    steps: [
      { i18nKey: 'STEP_1', wait_hours: 0, action_type: 'send_message' },
      { i18nKey: 'STEP_2', wait_hours: 48, action_type: 'send_message' },
    ],
  },
  {
    key: 'consulta_agendada',
    i18nKey: 'CONSULTA_AGENDADA',
    icon: 'i-lucide-calendar-check',
    channel: 'whatsapp',
    steps: [
      { i18nKey: 'STEP_1', wait_hours: 0, action_type: 'send_message' },
      { i18nKey: 'STEP_2', wait_hours: 24, action_type: 'send_message' },
    ],
  },
  {
    key: 'reativacao_lead_frio',
    i18nKey: 'REATIVACAO_LEAD_FRIO',
    icon: 'i-lucide-snowflake',
    channel: 'whatsapp',
    steps: [
      { i18nKey: 'STEP_1', wait_hours: 0, action_type: 'send_message' },
      { i18nKey: 'STEP_2', wait_hours: 48, action_type: 'create_activity' },
    ],
  },
  {
    key: 'pos_atendimento',
    i18nKey: 'POS_ATENDIMENTO',
    icon: 'i-lucide-heart-handshake',
    channel: 'whatsapp',
    steps: [
      { i18nKey: 'STEP_1', wait_hours: 24, action_type: 'send_message' },
      { i18nKey: 'STEP_2', wait_hours: 72, action_type: 'create_activity' },
    ],
  },
  {
    key: 'cliente_base_remarketing',
    i18nKey: 'CLIENTE_BASE_REMARKETING',
    icon: 'i-lucide-megaphone',
    channel: 'whatsapp',
    steps: [
      { i18nKey: 'STEP_1', wait_hours: 0, action_type: 'send_message' },
      { i18nKey: 'STEP_2', wait_hours: 48, action_type: 'create_activity' },
    ],
  },
];

const templateModels = computed(() =>
  TEMPLATE_DEFS.map(def => ({
    key: def.key,
    icon: def.icon,
    channel: def.channel,
    name: t(`CRM.CADENCES.TEMPLATES.${def.i18nKey}.NAME`),
    description: t(`CRM.CADENCES.TEMPLATES.${def.i18nKey}.DESCRIPTION`),
    steps: def.steps.map(step => ({
      wait_hours: step.wait_hours,
      action_type: step.action_type,
      name: t(
        `CRM.CADENCES.TEMPLATES.${def.i18nKey}.STEPS.${step.i18nKey}.NAME`
      ),
      template_body: t(
        `CRM.CADENCES.TEMPLATES.${def.i18nKey}.STEPS.${step.i18nKey}.BODY`
      ),
    })),
  }))
);

const statusFilterOptions = computed(() => [
  { value: '', label: t('CRM.CADENCES.FILTERS.ALL_STATUSES') },
  ...STATUSES.value,
]);

const channelFilterOptions = computed(() => [
  { value: '', label: t('CRM.CADENCES.FILTERS.ALL_CHANNELS') },
  ...CHANNELS.value,
]);

const blankStep = position => ({
  name: t('CRM.CADENCES.STEP.DEFAULT_NAME', { position }),
  position,
  channel: 'whatsapp',
  action_type: 'send_message',
  wait_hours: position === 1 ? 0 : 24,
  template_body: '',
  action_config: { conditions: [], condition_miss: 'skip_step' },
  condition_miss: 'skip_step',
  conditions_json: '[]',
  is_active: true,
});

const form = reactive({
  name: '',
  status: 'draft',
  channel: 'whatsapp',
  starts_at: '',
  steps: [blankStep(1)],
});

const filters = reactive({
  search: '',
  status: '',
  channel: '',
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const activeCadences = computed(
  () => cadences.value.filter(cadence => cadence.status === 'active').length
);

const pausedCadences = computed(
  () => cadences.value.filter(cadence => cadence.status === 'paused').length
);

const totalSteps = computed(() =>
  cadences.value.reduce(
    (total, cadence) => total + (cadence.steps?.length || 0),
    0
  )
);

const stats = computed(() => [
  {
    key: 'total',
    label: t('CRM.CADENCES.STATS.TOTAL.LABEL'),
    value: cadences.value.length,
    hint: t('CRM.CADENCES.STATS.TOTAL.HINT'),
    valueClass: '',
  },
  {
    key: 'active',
    label: t('CRM.CADENCES.STATS.ACTIVE.LABEL'),
    value: activeCadences.value,
    hint: t('CRM.CADENCES.STATS.ACTIVE.HINT'),
    valueClass: 'text-ui-success',
  },
  {
    key: 'paused',
    label: t('CRM.CADENCES.STATS.PAUSED.LABEL'),
    value: pausedCadences.value,
    hint: t('CRM.CADENCES.STATS.PAUSED.HINT'),
    valueClass: 'text-ui-warning',
  },
  {
    key: 'steps',
    label: t('CRM.CADENCES.STATS.STEPS.LABEL'),
    value: totalSteps.value,
    hint: t('CRM.CADENCES.STATS.STEPS.HINT'),
    valueClass: 'text-ui-brand',
  },
]);

const filteredCadences = computed(() => {
  const search = filters.search.toLowerCase().trim();
  return cadences.value.filter(cadence => {
    const searchable = [
      cadence.name,
      cadence.channel,
      labelFor(CHANNELS.value, cadence.channel),
      cadence.status,
      labelFor(STATUSES.value, cadence.status),
      ...(cadence.steps || []).flatMap(step => [
        step.name,
        step.action_type,
        labelFor(ACTION_TYPES.value, step.action_type),
        step.template_body,
      ]),
    ];

    const matchesSearch =
      !search ||
      searchable
        .filter(Boolean)
        .some(value => String(value).toLowerCase().includes(search));
    const matchesStatus = !filters.status || cadence.status === filters.status;
    const matchesChannel =
      !filters.channel || cadence.channel === filters.channel;
    return matchesSearch && matchesStatus && matchesChannel;
  });
});

const isFormValid = computed(
  () =>
    form.name.trim() &&
    form.steps.length > 0 &&
    form.steps.every(
      step => step.name.trim() && step.channel && step.action_type
    )
);

const drawerTitle = computed(() =>
  editingId.value
    ? t('CRM.CADENCES.DRAWER.TITLE_EDIT')
    : t('CRM.CADENCES.DRAWER.TITLE_NEW')
);

const drawerDescription = computed(() =>
  editingId.value
    ? t('CRM.CADENCES.DRAWER.DESCRIPTION_EDIT')
    : t('CRM.CADENCES.DRAWER.DESCRIPTION_NEW')
);

function labelFor(list, value) {
  return list.find(item => item.value === value)?.label || value || '-';
}

function iconFor(list, value, fallback = 'i-lucide-circle') {
  return list.find(item => item.value === value)?.icon || fallback;
}

function clearFilters() {
  filters.search = '';
  filters.status = '';
  filters.channel = '';
}

function statusBadgeVariant(status) {
  return STATUS_BADGE_VARIANTS[status] || 'neutral';
}

function resetForm() {
  editingId.value = null;
  form.name = '';
  form.status = 'draft';
  form.channel = 'whatsapp';
  form.starts_at = '';
  form.steps = [blankStep(1)];
}

function normalizeTemplateStep(step, index, channel = 'whatsapp') {
  return {
    ...blankStep(index + 1),
    ...step,
    position: index + 1,
    channel: step.channel || channel,
    action_config: {
      conditions: step.conditions || [],
      condition_miss: step.condition_miss || 'skip_step',
    },
    condition_miss: step.condition_miss || 'skip_step',
    conditions_json: JSON.stringify(step.conditions || [], null, 2),
    is_active: step.is_active !== false,
  };
}

function openNew() {
  resetForm();
  showModal.value = true;
}

function openTemplate(template) {
  resetForm();
  form.name = template.name;
  form.channel = template.channel;
  form.steps = template.steps.map((step, index) =>
    normalizeTemplateStep(step, index, template.channel)
  );
  showModal.value = true;
}

function openEdit(cadence) {
  editingId.value = cadence.id;
  form.name = cadence.name || '';
  form.status = cadence.status || 'draft';
  form.channel = cadence.channel || 'whatsapp';
  form.starts_at = cadence.starts_at ? cadence.starts_at.slice(0, 16) : '';
  form.steps = (cadence.steps?.length ? cadence.steps : [blankStep(1)]).map(
    (step, index) => ({
      id: step.id,
      name:
        step.name || t('CRM.CADENCES.STEP.DEFAULT_NAME', { position: index + 1 }),
      position: step.position || index + 1,
      channel: step.channel || cadence.channel || 'whatsapp',
      action_type: step.action_type || 'send_message',
      wait_hours: step.wait_hours ?? (index === 0 ? 0 : 24),
      template_body: step.template_body || '',
      action_config: step.action_config || {},
      condition_miss: step.action_config?.condition_miss || 'skip_step',
      conditions_json: JSON.stringify(
        step.action_config?.conditions || [],
        null,
        2
      ),
      is_active: step.is_active !== false,
    })
  );
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
  resetForm();
}

function addStep() {
  form.steps.push(blankStep(form.steps.length + 1));
}

function removeStep(index) {
  if (form.steps.length === 1) return;
  form.steps.splice(index, 1);
  form.steps.forEach((step, stepIndex) => {
    step.position = stepIndex + 1;
    step.name =
      step.name ||
      t('CRM.CADENCES.STEP.DEFAULT_NAME', { position: stepIndex + 1 });
  });
}

function duplicateStep(index) {
  const current = form.steps[index];
  form.steps.splice(index + 1, 0, {
    ...current,
    id: undefined,
    name: t('CRM.CADENCES.STEP.DUPLICATED_NAME', { name: current.name }),
    position: index + 2,
  });
  form.steps.forEach((step, stepIndex) => {
    step.position = stepIndex + 1;
  });
}

async function loadCadences() {
  loading.value = true;
  error.value = '';
  try {
    cadences.value = extractData(await CrmAPI.getCadences());
  } catch {
    error.value = t('CRM.CADENCES.ERROR.LOAD');
  } finally {
    loading.value = false;
  }
}

async function saveCadence() {
  if (!isFormValid.value) return;
  saving.value = true;
  error.value = '';
  let stepsPayload = [];
  try {
    stepsPayload = form.steps.map((step, index) => ({
      id: step.id,
      name: step.name.trim(),
      position: index + 1,
      channel: step.channel,
      action_type: step.action_type,
      wait_hours: Number(step.wait_hours || 0),
      template_body: step.template_body?.trim() || null,
      action_config: actionConfigForStep(step),
      is_active: step.is_active,
    }));
  } catch (err) {
    error.value = err.message;
    saving.value = false;
    return;
  }

  const payload = {
    name: form.name.trim(),
    status: form.status,
    channel: form.channel,
    starts_at: form.starts_at || null,
    steps: stepsPayload,
  };

  try {
    if (editingId.value) {
      await CrmAPI.updateCadence(editingId.value, payload);
    } else {
      await CrmAPI.createCadence(payload);
    }
    closeModal();
    await loadCadences();
  } catch (err) {
    error.value =
      err?.response?.data?.error || t('CRM.CADENCES.ERROR.SAVE');
  } finally {
    saving.value = false;
  }
}

function actionConfigForStep(step) {
  const actionConfig = {
    ...(step.action_config || {}),
    condition_miss: step.condition_miss || 'skip_step',
  };
  const rawConditions = step.conditions_json?.trim();
  const conditions = rawConditions ? JSON.parse(rawConditions) : [];
  if (!Array.isArray(conditions)) {
    throw new Error(t('CRM.CADENCES.ERROR.CONDITIONS_JSON'));
  }
  actionConfig.conditions = conditions;
  return actionConfig;
}

async function toggleStatus(cadence) {
  const status = cadence.status === 'active' ? 'paused' : 'active';
  try {
    await CrmAPI.updateCadence(cadence.id, { status });
    await loadCadences();
  } catch {
    error.value = t('CRM.CADENCES.ERROR.STATUS');
  }
}

function deleteCadence(cadence) {
  archiveTarget.value = cadence;
}

function closeArchiveModal() {
  if (saving.value) return;
  archiveTarget.value = null;
}

async function confirmArchive() {
  if (!archiveTarget.value) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteCadence(archiveTarget.value.id);
    archiveTarget.value = null;
    await loadCadences();
  } catch {
    error.value = t('CRM.CADENCES.ERROR.ARCHIVE');
  } finally {
    saving.value = false;
  }
}

onMounted(loadCadences);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="$t('CRM.CADENCES.TITLE')"
      :breadcrumbs="[
        { label: $t('CRM.CADENCES.BREADCRUMB') },
        { label: $t('CRM.CADENCES.TITLE') },
      ]"
    >
      <template #actions>
        <DsButton
          variant="primary"
          icon="i-lucide-plus"
          :label="$t('CRM.CADENCES.NEW')"
          @click="openNew"
        />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <p class="m-0 max-w-3xl text-ui-body-sm text-ui-text-muted">
        {{ $t('CRM.CADENCES.SUBTITLE') }}
      </p>

      <DsCard
        as="section"
        padding="none"
        :aria-label="$t('CRM.CADENCES.STATS.SECTION_LABEL')"
      >
        <dl class="grid grid-cols-2 lg:grid-cols-4">
          <div
            v-for="stat in stats"
            :key="stat.key"
            class="flex min-w-0 flex-col gap-1 p-3 sm:p-4"
          >
            <dt
              class="truncate text-ui-caption font-medium uppercase tracking-wide text-ui-text-muted"
            >
              {{ stat.label }}
            </dt>
            <dd
              class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
              :class="stat.valueClass"
            >
              {{ stat.value }}
            </dd>
            <span class="truncate text-ui-caption text-ui-text-subtle">
              {{ stat.hint }}
            </span>
          </div>
        </dl>
      </DsCard>

      <div class="flex flex-col gap-3 lg:flex-row lg:items-end">
        <div class="min-w-0 flex-1">
          <DsInput
            v-model="filters.search"
            type="search"
            :label="$t('CRM.CADENCES.FILTERS.SEARCH_LABEL')"
            hide-label
            :placeholder="$t('CRM.CADENCES.FILTERS.SEARCH_PLACEHOLDER')"
          >
            <template #prefix>
              <Icon icon="i-lucide-search" class="size-4" />
            </template>
          </DsInput>
        </div>
        <div class="grid grid-cols-2 gap-3 lg:flex lg:items-end">
          <div class="min-w-0 lg:w-44">
            <DsSelect
              v-model="filters.status"
              :label="$t('CRM.CADENCES.FILTERS.STATUS_LABEL')"
              hide-label
              :options="statusFilterOptions"
            />
          </div>
          <div class="min-w-0 lg:w-44">
            <DsSelect
              v-model="filters.channel"
              :label="$t('CRM.CADENCES.FILTERS.CHANNEL_LABEL')"
              hide-label
              :options="channelFilterOptions"
            />
          </div>
          <DsButton
            variant="ghost"
            icon="i-lucide-filter-x"
            :label="$t('CRM.CADENCES.FILTERS.CLEAR')"
            @click="clearFilters"
          />
        </div>
      </div>

      <DsCard as="section" padding="sm" aria-labelledby="cadence-templates">
        <div
          class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between"
        >
          <div class="min-w-0">
            <h2
              id="cadence-templates"
              class="m-0 text-ui-caption font-semibold uppercase tracking-wide text-ui-text-muted"
            >
              {{ $t('CRM.CADENCES.TEMPLATES.KICKER') }}
            </h2>
            <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
              {{ $t('CRM.CADENCES.TEMPLATES.DESCRIPTION') }}
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <DsButton
              v-for="template in templateModels"
              :key="template.key"
              size="sm"
              variant="secondary"
              :icon="template.icon"
              :label="template.name"
              :aria-label="
                $t('CRM.CADENCES.TEMPLATES.USE', { name: template.name })
              "
              @click="openTemplate(template)"
            />
          </div>
        </div>
      </DsCard>

      <div
        v-if="error && !showModal && !archiveTarget"
        role="alert"
        class="flex items-center gap-2 rounded-ui-control bg-ui-danger-soft px-3 py-2 text-ui-body-sm text-ui-danger-foreground"
      >
        <Icon
          icon="i-lucide-circle-alert"
          class="size-4 shrink-0"
          aria-hidden="true"
        />
        {{ error }}
      </div>

      <div
        v-if="loading"
        role="status"
        :aria-label="$t('CRM.CADENCES.LOADING')"
        class="flex flex-col gap-4"
      >
        <span class="sr-only">{{ $t('CRM.CADENCES.LOADING') }}</span>
        <div class="grid grid-cols-1 gap-4 lg:grid-cols-2 2xl:grid-cols-3">
          <DsSkeleton
            v-for="card in 6"
            :key="card"
            shape="block"
            class="h-56"
          />
        </div>
      </div>

      <DsEmptyState
        v-else-if="filteredCadences.length === 0"
        :title="$t('CRM.CADENCES.EMPTY.TITLE')"
      >
        <template #action>
          <p class="m-0 max-w-md text-ui-body-sm text-ui-text-muted">
            {{ $t('CRM.CADENCES.EMPTY.DESCRIPTION') }}
          </p>
          <DsButton
            variant="primary"
            icon="i-lucide-plus"
            :label="$t('CRM.CADENCES.EMPTY.ACTION')"
            @click="openNew"
          />
        </template>
      </DsEmptyState>

      <div
        v-else
        class="grid grid-cols-1 gap-4 lg:grid-cols-2 2xl:grid-cols-3"
      >
        <DsCard
          v-for="cadence in filteredCadences"
          :key="cadence.id"
          as="article"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex min-w-0 items-start gap-3">
              <span
                class="flex size-10 shrink-0 items-center justify-center rounded-ui-surface bg-ui-brand-soft text-ui-brand-foreground"
                aria-hidden="true"
              >
                <Icon
                  :icon="iconFor(CHANNELS, cadence.channel, 'i-lucide-send')"
                  class="size-5"
                />
              </span>
              <div class="min-w-0">
                <h2
                  class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
                >
                  {{ cadence.name }}
                </h2>
                <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
                  <DsBadge
                    :variant="statusBadgeVariant(cadence.status)"
                    :label="labelFor(STATUSES, cadence.status)"
                  />
                  <DsBadge
                    variant="neutral"
                    :label="labelFor(CHANNELS, cadence.channel)"
                  />
                  <DsBadge
                    variant="neutral"
                    :label="
                      $t('CRM.CADENCES.CARD.STEPS_COUNT', {
                        count: cadence.steps?.length || 0,
                      })
                    "
                  />
                </div>
              </div>
            </div>

            <div class="flex shrink-0 items-center gap-1">
              <DsButton
                :icon="
                  cadence.status === 'active'
                    ? 'i-lucide-pause'
                    : 'i-lucide-play'
                "
                size="sm"
                variant="ghost"
                :aria-label="
                  cadence.status === 'active'
                    ? $t('CRM.CADENCES.CARD.PAUSE')
                    : $t('CRM.CADENCES.CARD.ACTIVATE')
                "
                @click="toggleStatus(cadence)"
              />
              <DsButton
                icon="i-lucide-pencil"
                size="sm"
                variant="ghost"
                :aria-label="$t('CRM.CADENCES.CARD.EDIT')"
                @click="openEdit(cadence)"
              />
              <DsButton
                icon="i-lucide-archive"
                size="sm"
                variant="ghost"
                :aria-label="$t('CRM.CADENCES.CARD.ARCHIVE')"
                @click="deleteCadence(cadence)"
              />
            </div>
          </div>

          <ol class="m-0 mt-4 flex list-none flex-col gap-2 p-0">
            <li
              v-for="step in cadence.steps"
              :key="step.id"
              class="flex items-start gap-3 rounded-ui-control bg-ui-sunken p-2"
              :class="{ 'opacity-60': step.is_active === false }"
            >
              <span
                class="flex size-6 shrink-0 items-center justify-center rounded-full bg-ui-brand-soft text-ui-caption font-semibold text-ui-brand-foreground"
                aria-hidden="true"
              >
                {{ step.position }}
              </span>
              <div class="min-w-0">
                <div class="flex items-center gap-1.5">
                  <Icon
                    :icon="
                      iconFor(ACTION_TYPES, step.action_type, 'i-lucide-circle')
                    "
                    class="size-4 shrink-0 text-ui-text-muted"
                    aria-hidden="true"
                  />
                  <strong
                    class="truncate text-ui-body-sm font-medium text-ui-text"
                  >
                    {{ step.name }}
                  </strong>
                </div>
                <p class="m-0 mt-0.5 text-ui-caption text-ui-text-muted">
                  {{
                    $t('CRM.CADENCES.CARD.STEP_META', {
                      action: labelFor(ACTION_TYPES, step.action_type),
                      hours: step.wait_hours,
                    })
                  }}
                  <span v-if="step.action_config?.conditions?.length">
                    {{
                      $t('CRM.CADENCES.CARD.STEP_CONDITIONS', {
                        count: step.action_config.conditions.length,
                      })
                    }}
                  </span>
                </p>
                <span v-if="step.is_active === false" class="sr-only">
                  {{ $t('CRM.CADENCES.CARD.STEP_INACTIVE') }}
                </span>
              </div>
            </li>
          </ol>
        </DsCard>
      </div>
    </div>

    <DsDrawer
      :open="showModal"
      :title="drawerTitle"
      :description="drawerDescription"
      :loading="saving"
      @close="closeModal"
    >
      <div class="flex flex-col gap-6">
        <div
          v-if="error"
          role="alert"
          class="flex items-center gap-2 rounded-ui-control bg-ui-danger-soft px-3 py-2 text-ui-body-sm text-ui-danger-foreground"
        >
          <Icon
            icon="i-lucide-circle-alert"
            class="size-4 shrink-0"
            aria-hidden="true"
          />
          {{ error }}
        </div>

        <section aria-labelledby="cadence-details-title">
          <div class="mb-3 flex items-start gap-2">
            <Icon
              icon="i-lucide-settings-2"
              class="mt-0.5 size-4 shrink-0 text-ui-text-muted"
              aria-hidden="true"
            />
            <div class="min-w-0">
              <h3
                id="cadence-details-title"
                class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
              >
                {{ $t('CRM.CADENCES.FORM.DETAILS_TITLE') }}
              </h3>
              <p class="m-0 mt-0.5 text-ui-caption text-ui-text-muted">
                {{ $t('CRM.CADENCES.FORM.DETAILS_DESCRIPTION') }}
              </p>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <DsInput
                v-model="form.name"
                :label="$t('CRM.CADENCES.FORM.NAME')"
                :placeholder="$t('CRM.CADENCES.FORM.NAME_PLACEHOLDER')"
              />
            </div>
            <DsSelect
              v-model="form.status"
              :label="$t('CRM.CADENCES.FORM.STATUS')"
              :options="STATUSES"
            />
            <DsSelect
              v-model="form.channel"
              :label="$t('CRM.CADENCES.FORM.CHANNEL')"
              :options="CHANNELS"
            />
            <DsInput
              v-model="form.starts_at"
              type="datetime-local"
              :label="$t('CRM.CADENCES.FORM.STARTS_AT')"
            />
          </div>
        </section>

        <section aria-labelledby="cadence-steps-title">
          <div
            class="mb-3 flex flex-wrap items-start justify-between gap-3"
          >
            <div class="flex min-w-0 items-start gap-2">
              <Icon
                icon="i-lucide-list-plus"
                class="mt-0.5 size-4 shrink-0 text-ui-text-muted"
                aria-hidden="true"
              />
              <div class="min-w-0">
                <h3
                  id="cadence-steps-title"
                  class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
                >
                  {{ $t('CRM.CADENCES.FORM.STEPS_TITLE') }}
                </h3>
                <p class="m-0 mt-0.5 text-ui-caption text-ui-text-muted">
                  {{ $t('CRM.CADENCES.FORM.STEPS_DESCRIPTION') }}
                </p>
              </div>
            </div>
            <DsButton
              size="sm"
              variant="secondary"
              icon="i-lucide-plus"
              :label="$t('CRM.CADENCES.FORM.ADD_STEP')"
              @click="addStep"
            />
          </div>

          <div class="flex flex-col gap-3">
            <DsCard
              v-for="(step, index) in form.steps"
              :key="index"
              as="section"
              padding="sm"
              :aria-label="
                $t('CRM.CADENCES.STEP.TITLE', { position: index + 1 })
              "
            >
              <div class="flex items-start justify-between gap-3">
                <div class="flex min-w-0 items-center gap-2">
                  <span
                    class="flex size-6 shrink-0 items-center justify-center rounded-full bg-ui-brand-soft text-ui-caption font-semibold text-ui-brand-foreground"
                    aria-hidden="true"
                  >
                    {{ index + 1 }}
                  </span>
                  <div class="min-w-0">
                    <strong
                      class="block truncate text-ui-body-sm font-semibold text-ui-text"
                    >
                      {{ $t('CRM.CADENCES.STEP.TITLE', { position: index + 1 }) }}
                    </strong>
                    <small class="text-ui-caption text-ui-text-muted">
                      {{
                        $t('CRM.CADENCES.STEP.SUMMARY', {
                          action: labelFor(ACTION_TYPES, step.action_type),
                          hours: step.wait_hours || 0,
                        })
                      }}
                    </small>
                  </div>
                </div>
                <div class="flex shrink-0 items-center gap-1">
                  <DsButton
                    icon="i-lucide-copy"
                    size="sm"
                    variant="ghost"
                    :aria-label="$t('CRM.CADENCES.STEP.DUPLICATE')"
                    @click="duplicateStep(index)"
                  />
                  <DsButton
                    icon="i-lucide-trash-2"
                    size="sm"
                    variant="ghost"
                    :disabled="form.steps.length === 1"
                    :aria-label="$t('CRM.CADENCES.STEP.REMOVE')"
                    @click="removeStep(index)"
                  />
                </div>
              </div>

              <div class="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <DsInput
                    v-model="step.name"
                    :label="$t('CRM.CADENCES.STEP.NAME')"
                  />
                </div>
                <DsSelect
                  v-model="step.channel"
                  :label="$t('CRM.CADENCES.STEP.CHANNEL')"
                  :options="CHANNELS"
                />
                <DsSelect
                  v-model="step.action_type"
                  :label="$t('CRM.CADENCES.STEP.ACTION')"
                  :options="ACTION_TYPES"
                />
                <DsInput
                  v-model="step.wait_hours"
                  type="number"
                  min="0"
                  :label="$t('CRM.CADENCES.STEP.WAIT_HOURS')"
                />
                <div class="flex items-end pb-1">
                  <DsCheckbox
                    v-model="step.is_active"
                    :label="$t('CRM.CADENCES.STEP.ACTIVE')"
                  />
                </div>
                <div class="sm:col-span-2">
                  <DsTextarea
                    v-model="step.template_body"
                    :rows="3"
                    :label="$t('CRM.CADENCES.STEP.BODY_LABEL')"
                    :placeholder="$t('CRM.CADENCES.STEP.BODY_PLACEHOLDER')"
                  />
                </div>
                <DsSelect
                  v-model="step.condition_miss"
                  :label="$t('CRM.CADENCES.STEP.CONDITION_MISS_LABEL')"
                  :options="CONDITION_MISS_BEHAVIORS"
                />
                <div class="sm:col-span-2">
                  <DsTextarea
                    v-model="step.conditions_json"
                    class="font-mono"
                    :rows="3"
                    :label="$t('CRM.CADENCES.STEP.CONDITIONS_LABEL')"
                    :placeholder="conditionPlaceholder"
                  />
                </div>
              </div>
            </DsCard>
          </div>
        </section>
      </div>

      <template #footer>
        <div class="flex flex-wrap justify-end gap-2">
          <DsButton
            variant="secondary"
            :label="$t('CRM.CADENCES.DRAWER.CANCEL')"
            :disabled="saving"
            @click="closeModal"
          />
          <DsButton
            variant="primary"
            :label="
              saving
                ? $t('CRM.CADENCES.DRAWER.SAVING')
                : $t('CRM.CADENCES.DRAWER.SAVE')
            "
            :loading="saving"
            :disabled="!isFormValid"
            @click="saveCadence"
          />
        </div>
      </template>
    </DsDrawer>

    <DsModal
      :open="Boolean(archiveTarget)"
      dangerous
      :title="$t('CRM.CADENCES.ARCHIVE_MODAL.TITLE')"
      :description="
        $t('CRM.CADENCES.ARCHIVE_MODAL.DESCRIPTION', {
          name: archiveTarget?.name || '',
        })
      "
      :confirm-label="$t('CRM.CADENCES.ARCHIVE_MODAL.CONFIRM')"
      :cancel-label="$t('CRM.CADENCES.ARCHIVE_MODAL.CANCEL')"
      :loading="saving"
      @close="closeArchiveModal"
      @confirm="confirmArchive"
    >
      <div
        v-if="error"
        role="alert"
        class="flex items-center gap-2 rounded-ui-control bg-ui-danger-soft px-3 py-2 text-ui-body-sm text-ui-danger-foreground"
      >
        <Icon
          icon="i-lucide-circle-alert"
          class="size-4 shrink-0"
          aria-hidden="true"
        />
        {{ error }}
      </div>
    </DsModal>
  </section>
</template>

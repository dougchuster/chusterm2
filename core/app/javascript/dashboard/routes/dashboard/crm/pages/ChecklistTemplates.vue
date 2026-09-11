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
  DsEmptyState,
  DsInput,
  DsModal,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();

const templates = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const showModal = ref(false);
const editingId = ref(null);
const archiveTarget = ref(null);

const filters = reactive({
  search: '',
  case_type: '',
  legal_area: '',
});

const blankItem = () => ({
  key: '',
  title: '',
  kind: 'document',
  required: true,
});

const form = reactive({
  name: '',
  case_type: '',
  legal_area: '',
  position: 0,
  items: [blankItem()],
});

const itemKindOptions = computed(() => [
  { value: 'document', label: t('CRM.CHECKLIST_TEMPLATES.KINDS.DOCUMENT') },
  { value: 'task', label: t('CRM.CHECKLIST_TEMPLATES.KINDS.TASK') },
  { value: 'validation', label: t('CRM.CHECKLIST_TEMPLATES.KINDS.VALIDATION') },
]);

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const normalized = value =>
  String(value || '')
    .toLowerCase()
    .trim();

const caseTypeOptions = computed(() => {
  const values = templates.value.map(item => item.case_type).filter(Boolean);
  return [...new Set(values)].sort();
});

const legalAreaOptions = computed(() => {
  const values = templates.value.map(item => item.legal_area).filter(Boolean);
  return [...new Set(values)].sort();
});

const caseTypeFilterOptions = computed(() => [
  { value: '', label: t('CRM.CHECKLIST_TEMPLATES.FILTERS.ALL_CASE_TYPES') },
  ...caseTypeOptions.value.map(value => ({ value, label: value })),
]);

const legalAreaFilterOptions = computed(() => [
  { value: '', label: t('CRM.CHECKLIST_TEMPLATES.FILTERS.ALL_LEGAL_AREAS') },
  ...legalAreaOptions.value.map(value => ({ value, label: value })),
]);

const filteredTemplates = computed(() => {
  const search = normalized(filters.search);
  return templates.value.filter(template => {
    const matchesSearch =
      !search ||
      [template.name, template.case_type, template.legal_area]
        .map(normalized)
        .some(value => value.includes(search));
    const matchesCase =
      !filters.case_type || template.case_type === filters.case_type;
    const matchesArea =
      !filters.legal_area || template.legal_area === filters.legal_area;
    return matchesSearch && matchesCase && matchesArea;
  });
});

const summary = computed(() => {
  const totalItems = templates.value.reduce(
    (sum, template) => sum + (template.items?.length || 0),
    0
  );
  const requiredItems = templates.value.reduce(
    (sum, template) =>
      sum + (template.items || []).filter(item => item.required).length,
    0
  );

  return [
    {
      key: 'templates',
      label: t('CRM.CHECKLIST_TEMPLATES.SUMMARY.ACTIVE_TEMPLATES'),
      value: templates.value.length,
    },
    {
      key: 'areas',
      label: t('CRM.CHECKLIST_TEMPLATES.SUMMARY.LEGAL_AREAS'),
      value: legalAreaOptions.value.length,
    },
    {
      key: 'items',
      label: t('CRM.CHECKLIST_TEMPLATES.SUMMARY.TOTAL_ITEMS'),
      value: totalItems,
    },
    {
      key: 'required',
      label: t('CRM.CHECKLIST_TEMPLATES.SUMMARY.REQUIRED_ITEMS'),
      value: requiredItems,
    },
  ];
});

function labelForKind(value) {
  return (
    itemKindOptions.value.find(option => option.value === value)?.label ||
    value
  );
}

function resetForm() {
  editingId.value = null;
  form.name = '';
  form.case_type = '';
  form.legal_area = '';
  form.position = 0;
  form.items = [blankItem()];
}

function openNew() {
  resetForm();
  showModal.value = true;
}

function openEdit(template) {
  editingId.value = template.id;
  form.name = template.name || '';
  form.case_type = template.case_type || '';
  form.legal_area = template.legal_area || '';
  form.position = template.position || 0;
  form.items = (template.items?.length ? template.items : [blankItem()]).map(
    item => ({
      key: item.key || '',
      title: item.title || '',
      kind: item.kind || 'document',
      required: item.required !== false,
    })
  );
  showModal.value = true;
}

function closeModal() {
  if (saving.value) return;
  showModal.value = false;
  resetForm();
}

function addItem() {
  form.items.push(blankItem());
}

function removeItem(index) {
  if (form.items.length === 1) return;
  form.items.splice(index, 1);
}

async function loadTemplates() {
  loading.value = true;
  error.value = '';
  try {
    templates.value = extractData(await CrmAPI.getChecklistTemplates());
  } catch {
    error.value = t('CRM.CHECKLIST_TEMPLATES.ERROR_LOAD');
  } finally {
    loading.value = false;
  }
}

async function saveTemplate() {
  if (!form.name.trim()) return;

  saving.value = true;
  error.value = '';

  const payload = {
    name: form.name.trim(),
    case_type: form.case_type.trim() || null,
    legal_area: form.legal_area.trim() || null,
    position: Number(form.position || 0),
    items: form.items
      .filter(item => item.title.trim())
      .map((item, index) => ({
        key: item.key.trim() || `item_${index + 1}`,
        title: item.title.trim(),
        kind: item.kind,
        required: item.required,
      })),
  };

  try {
    if (editingId.value) {
      await CrmAPI.updateChecklistTemplate(editingId.value, payload);
    } else {
      await CrmAPI.createChecklistTemplate(payload);
    }
    showModal.value = false;
    resetForm();
    await loadTemplates();
  } catch (err) {
    error.value =
      err?.response?.data?.error || t('CRM.CHECKLIST_TEMPLATES.ERROR_SAVE');
  } finally {
    saving.value = false;
  }
}

function requestArchive(template) {
  archiveTarget.value = template;
}

async function confirmArchive() {
  if (!archiveTarget.value) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteChecklistTemplate(archiveTarget.value.id);
    archiveTarget.value = null;
    await loadTemplates();
  } catch {
    error.value = t('CRM.CHECKLIST_TEMPLATES.ERROR_ARCHIVE');
    archiveTarget.value = null;
  } finally {
    saving.value = false;
  }
}

function clearFilters() {
  filters.search = '';
  filters.case_type = '';
  filters.legal_area = '';
}

const isFormValid = computed(
  () => form.name.trim() && form.items.some(item => item.title.trim())
);

onMounted(loadTemplates);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="$t('CRM.CHECKLIST_TEMPLATES.TITLE')"
      :breadcrumbs="[
        { label: $t('CRM.CHECKLIST_TEMPLATES.BREADCRUMB') },
        { label: $t('CRM.CHECKLIST_TEMPLATES.TITLE') },
      ]"
    >
      <template #actions>
        <DsButton
          icon="i-lucide-plus"
          variant="primary"
          :label="$t('CRM.CHECKLIST_TEMPLATES.NEW_TEMPLATE')"
          @click="openNew"
        />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <div>
        <p
          class="m-0 text-ui-caption font-medium uppercase tracking-wide text-ui-brand"
        >
          {{ $t('CRM.CHECKLIST_TEMPLATES.EYEBROW') }}
        </p>
        <p class="m-0 mt-1 max-w-2xl text-ui-body-sm text-ui-text-muted">
          {{ $t('CRM.CHECKLIST_TEMPLATES.SUBTITLE') }}
        </p>
      </div>

      <DsCard
        as="section"
        padding="none"
        :aria-label="$t('CRM.CHECKLIST_TEMPLATES.SUMMARY.TITLE')"
      >
        <dl class="grid grid-cols-2 lg:grid-cols-4">
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

      <div class="flex flex-col gap-2 lg:flex-row lg:items-center">
        <DsInput
          v-model="filters.search"
          type="search"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FILTERS.SEARCH_LABEL')"
          hide-label
          :placeholder="$t('CRM.CHECKLIST_TEMPLATES.FILTERS.SEARCH_PLACEHOLDER')"
          class="min-w-0 flex-1"
        >
          <template #prefix>
            <Icon icon="i-lucide-search" class="size-4" />
          </template>
        </DsInput>
        <DsSelect
          v-model="filters.case_type"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FILTERS.CASE_TYPE_LABEL')"
          hide-label
          :options="caseTypeFilterOptions"
          class="min-w-0 lg:w-56"
        />
        <DsSelect
          v-model="filters.legal_area"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FILTERS.LEGAL_AREA_LABEL')"
          hide-label
          :options="legalAreaFilterOptions"
          class="min-w-0 lg:w-56"
        />
        <DsButton
          variant="secondary"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FILTERS.CLEAR')"
          @click="clearFilters"
        />
      </div>

      <div
        v-if="error && !showModal"
        role="alert"
        class="rounded-ui-surface border border-ui-danger bg-ui-danger-soft px-4 py-3 text-ui-body-sm text-ui-danger-foreground"
      >
        {{ error }}
      </div>

      <div
        v-if="loading"
        role="status"
        :aria-label="$t('CRM.CHECKLIST_TEMPLATES.LOADING')"
        class="flex flex-col gap-4"
      >
        <span class="sr-only">{{ $t('CRM.CHECKLIST_TEMPLATES.LOADING') }}</span>
        <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
          <DsSkeleton
            v-for="card in 4"
            :key="card"
            shape="block"
            class="h-40"
          />
        </div>
      </div>

      <DsEmptyState
        v-else-if="filteredTemplates.length === 0"
        :title="$t('CRM.CHECKLIST_TEMPLATES.EMPTY_TITLE')"
      >
        <template #action>
          <p class="m-0 max-w-md text-ui-body-sm text-ui-text-muted">
            {{ $t('CRM.CHECKLIST_TEMPLATES.EMPTY_DESCRIPTION') }}
          </p>
          <DsButton
            variant="primary"
            :label="$t('CRM.CHECKLIST_TEMPLATES.EMPTY_ACTION')"
            @click="openNew"
          />
        </template>
      </DsEmptyState>

      <div v-else class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <DsCard
          v-for="template in filteredTemplates"
          :key="template.id"
          as="article"
          class="flex flex-col gap-3 sm:flex-row sm:items-start"
        >
          <span
            aria-hidden="true"
            class="grid size-10 shrink-0 place-items-center rounded-ui-control bg-ui-brand-soft text-ui-brand"
          >
            <Icon icon="i-lucide-list-checks" class="size-5" />
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex min-w-0 items-center justify-between gap-2">
              <h2
                class="m-0 truncate font-manrope text-ui-heading font-semibold text-ui-text"
              >
                {{ template.name }}
              </h2>
              <span class="shrink-0 text-ui-caption text-ui-text-subtle">
                {{
                  $t(
                    'CRM.CHECKLIST_TEMPLATES.CARD.ITEMS_COUNT',
                    template.items?.length || 0
                  )
                }}
              </span>
            </div>
            <div class="mt-2 flex flex-wrap gap-1.5">
              <DsBadge
                v-if="template.case_type"
                variant="brand"
                :label="template.case_type"
              />
              <DsBadge
                v-if="template.legal_area"
                variant="info"
                :label="template.legal_area"
              />
              <DsBadge
                variant="neutral"
                :label="
                  $t(
                    'CRM.CHECKLIST_TEMPLATES.CARD.REQUIRED_COUNT',
                    (template.items || []).filter(item => item.required).length
                  )
                "
              />
            </div>
            <ol class="m-0 mt-3 flex list-none flex-col gap-1.5 p-0">
              <li
                v-for="item in (template.items || []).slice(0, 3)"
                :key="item.key || item.title"
                class="flex items-center justify-between gap-2 rounded-ui-control bg-ui-sunken px-3 py-2"
              >
                <span class="truncate text-ui-body-sm text-ui-text">
                  {{ item.title }}
                </span>
                <span class="shrink-0 text-ui-caption text-ui-text-subtle">
                  {{ labelForKind(item.kind) }}
                </span>
              </li>
            </ol>
          </div>
          <div class="flex shrink-0 flex-wrap gap-2 sm:flex-col">
            <DsButton
              size="sm"
              variant="ghost"
              icon="i-lucide-pencil"
              :label="$t('CRM.CHECKLIST_TEMPLATES.CARD.EDIT')"
              @click="openEdit(template)"
            />
            <DsButton
              size="sm"
              variant="ghost"
              icon="i-lucide-archive"
              :label="$t('CRM.CHECKLIST_TEMPLATES.CARD.ARCHIVE')"
              @click="requestArchive(template)"
            />
          </div>
        </DsCard>
      </div>
    </div>

    <DsModal
      id="checklist-template-form"
      :open="showModal"
      :title="
        editingId
          ? $t('CRM.CHECKLIST_TEMPLATES.FORM.EDIT_TITLE')
          : $t('CRM.CHECKLIST_TEMPLATES.FORM.NEW_TITLE')
      "
      :description="$t('CRM.CHECKLIST_TEMPLATES.FORM.DESCRIPTION')"
      :loading="saving"
      @close="closeModal"
    >
      <div
        v-if="error"
        role="alert"
        class="mb-3 rounded-ui-surface border border-ui-danger bg-ui-danger-soft px-4 py-3 text-ui-body-sm text-ui-danger-foreground"
      >
        {{ error }}
      </div>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <DsInput
          v-model="form.name"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.NAME_LABEL')"
          :placeholder="$t('CRM.CHECKLIST_TEMPLATES.FORM.NAME_PLACEHOLDER')"
        />
        <DsInput
          v-model="form.case_type"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.CASE_TYPE_LABEL')"
          :placeholder="$t('CRM.CHECKLIST_TEMPLATES.FORM.CASE_TYPE_PLACEHOLDER')"
        />
        <DsInput
          v-model="form.legal_area"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.LEGAL_AREA_LABEL')"
          :placeholder="
            $t('CRM.CHECKLIST_TEMPLATES.FORM.LEGAL_AREA_PLACEHOLDER')
          "
        />
        <DsInput
          v-model="form.position"
          type="number"
          min="0"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.POSITION_LABEL')"
        />
      </div>

      <div class="mt-4 flex items-center justify-between gap-2">
        <h3 class="m-0 text-ui-label font-semibold text-ui-text">
          {{ $t('CRM.CHECKLIST_TEMPLATES.FORM.ITEMS_TITLE') }}
        </h3>
        <DsButton
          size="sm"
          variant="secondary"
          icon="i-lucide-plus"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.ADD_ITEM')"
          @click="addItem"
        />
      </div>

      <ol class="m-0 mt-3 flex list-none flex-col gap-3 p-0">
        <li
          v-for="(item, index) in form.items"
          :key="index"
          class="flex flex-col gap-2 rounded-ui-surface bg-ui-sunken p-3"
        >
          <div class="flex items-start gap-2">
            <DsInput
              v-model="item.title"
              :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.ITEM_TITLE_LABEL')"
              hide-label
              :placeholder="
                $t('CRM.CHECKLIST_TEMPLATES.FORM.ITEM_TITLE_PLACEHOLDER')
              "
              class="min-w-0 flex-1"
            />
            <DsButton
              icon="i-lucide-trash-2"
              variant="ghost"
              :aria-label="$t('CRM.CHECKLIST_TEMPLATES.FORM.REMOVE_ITEM')"
              :disabled="form.items.length === 1"
              @click="removeItem(index)"
            />
          </div>
          <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <DsInput
              v-model="item.key"
              :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.ITEM_KEY_LABEL')"
              hide-label
              :placeholder="
                $t('CRM.CHECKLIST_TEMPLATES.FORM.ITEM_KEY_PLACEHOLDER')
              "
            />
            <DsSelect
              v-model="item.kind"
              :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.ITEM_KIND_LABEL')"
              hide-label
              :options="itemKindOptions"
            />
          </div>
          <DsCheckbox
            v-model="item.required"
            :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.ITEM_REQUIRED')"
          />
        </li>
      </ol>

      <template #footer>
        <DsButton
          variant="secondary"
          :label="$t('CRM.CHECKLIST_TEMPLATES.FORM.CANCEL')"
          :disabled="saving"
          @click="closeModal"
        />
        <DsButton
          variant="primary"
          :label="
            saving
              ? $t('CRM.CHECKLIST_TEMPLATES.FORM.SAVING')
              : $t('CRM.CHECKLIST_TEMPLATES.FORM.SAVE')
          "
          :loading="saving"
          :disabled="!isFormValid"
          @click="saveTemplate"
        />
      </template>
    </DsModal>

    <DsModal
      id="checklist-template-archive"
      :open="Boolean(archiveTarget)"
      :title="$t('CRM.CHECKLIST_TEMPLATES.ARCHIVE_CONFIRM.TITLE')"
      :description="
        $t('CRM.CHECKLIST_TEMPLATES.ARCHIVE_CONFIRM.DESCRIPTION', {
          name: archiveTarget?.name || '',
        })
      "
      :confirm-label="$t('CRM.CHECKLIST_TEMPLATES.ARCHIVE_CONFIRM.CONFIRM')"
      :cancel-label="$t('CRM.CHECKLIST_TEMPLATES.ARCHIVE_CONFIRM.CANCEL')"
      dangerous
      :loading="saving"
      @close="archiveTarget = null"
      @confirm="confirmArchive"
    />
  </section>
</template>

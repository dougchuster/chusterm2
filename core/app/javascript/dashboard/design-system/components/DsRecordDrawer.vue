<script setup>
import { computed, getCurrentInstance, ref, useSlots, watch } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useDsTranslate } from '../useDsTranslate';
import DsAvatar from './DsAvatar.vue';
import DsButton from './DsButton.vue';
import DsDrawer from './DsDrawer.vue';
import DsEmptyState from './DsEmptyState.vue';
import DsInput from './DsInput.vue';
import DsSelect from './DsSelect.vue';
import DsSkeleton from './DsSkeleton.vue';
import DsTabs from './DsTabs.vue';

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  avatarUrl: { type: String, default: '' },
  avatarName: { type: String, default: '' },
  tabs: { type: Array, default: null },
  activeTab: { type: String, default: 'overview' },
  loading: { type: Boolean, default: false },
  fields: { type: Array, default: () => [] },
  quickActions: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'close',
  'update:activeTab',
  'fieldUpdate',
  'quickAction',
]);

const slots = useSlots();

const instance = getCurrentInstance();
const { translate } = useDsTranslate();

const defaultTabs = computed(() => [
  {
    id: 'overview',
    value: 'overview',
    label: translate('RECORD_DRAWER.TABS.OVERVIEW', 'Overview'),
    icon: 'i-lucide-file-text',
  },
  {
    id: 'timeline',
    value: 'timeline',
    label: translate('RECORD_DRAWER.TABS.TIMELINE', 'Timeline'),
    icon: 'i-lucide-history',
  },
  {
    id: 'notes',
    value: 'notes',
    label: translate('RECORD_DRAWER.TABS.NOTES', 'Notes'),
    icon: 'i-lucide-notebook-pen',
  },
]);

const normalizedTabs = computed(() => {
  const sourceTabs =
    props.tabs && props.tabs.length > 0 ? props.tabs : defaultTabs.value;
  return sourceTabs.map(tab => ({
    ...tab,
    id: tab.id || tab.value,
    value: tab.id || tab.value,
  }));
});

const currentActiveTab = ref(props.activeTab || 'overview');

watch(
  () => props.activeTab,
  newTab => {
    if (newTab && newTab !== currentActiveTab.value) {
      currentActiveTab.value = newTab;
    }
  }
);

const handleTabChange = tabValue => {
  currentActiveTab.value = tabValue;
  emit('update:activeTab', tabValue);
};

// Inline Edit State
const editingFieldId = ref(null);
const draftValue = ref('');

const startEdit = field => {
  if (field.editable === false || props.loading) return;
  editingFieldId.value = field.id;
  draftValue.value =
    field.value !== undefined && field.value !== null ? field.value : '';
};

const cancelEdit = () => {
  editingFieldId.value = null;
  draftValue.value = '';
};

const saveEdit = field => {
  const previousValue = field.value;
  const newValue = draftValue.value;
  editingFieldId.value = null;
  emit('fieldUpdate', {
    fieldId: field.id,
    value: newValue,
    previousValue,
  });
};

const getDisplayValue = field => {
  if (field.value === undefined || field.value === null || field.value === '') {
    return '';
  }
  if (field.editType === 'select' && Array.isArray(field.options)) {
    const matchingOption = field.options.find(
      opt => String(opt.value) === String(field.value)
    );
    if (matchingOption) {
      return matchingOption.label;
    }
  }
  return String(field.value);
};

const hasFooter = computed(
  () =>
    Boolean(slots.footer) ||
    (Array.isArray(props.quickActions) && props.quickActions.length > 0)
);

const titleId = computed(() => `${instance?.uid || 'record-drawer'}-title`);
</script>

<template>
  <DsDrawer
    :open="open"
    :loading="loading"
    size="xl"
    :aria-labelledby="titleId"
    @close="emit('close')"
  >
    <template #header>
      <header
        class="flex shrink-0 flex-col border-b border-ui-border-subtle bg-ui-elevated p-4"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex min-w-0 flex-1 items-center gap-3">
            <DsAvatar
              :src="avatarUrl"
              :name="avatarName || title || 'Record'"
              size="lg"
              :loading="loading"
            />
            <div class="min-w-0 flex-1">
              <div v-if="loading" class="flex flex-col gap-1.5">
                <DsSkeleton class="h-6 w-44" />
                <DsSkeleton class="h-4 w-28" />
              </div>
              <template v-else>
                <h2
                  :id="titleId"
                  class="m-0 truncate text-ui-heading font-semibold text-ui-text"
                >
                  {{ title }}
                </h2>
                <p
                  v-if="subtitle"
                  class="m-0 truncate text-ui-body-sm text-ui-text-muted"
                >
                  {{ subtitle }}
                </p>
              </template>
            </div>
          </div>
          <DsButton
            icon="i-lucide-x"
            size="sm"
            variant="ghost"
            :aria-label="translate('RECORD_DRAWER.CLOSE', 'Close record panel')"
            :disabled="loading"
            @click="emit('close')"
          />
        </div>

        <div class="mt-4">
          <DsTabs
            :model-value="currentActiveTab"
            :tabs="normalizedTabs"
            :label="
              translate('RECORD_DRAWER.TABS_LABEL', 'Record details navigation')
            "
            :disabled="loading"
            @update:model-value="handleTabChange"
          />
        </div>
      </header>
    </template>

    <!-- Drawer Body by Active Tab -->
    <div class="min-h-0 flex-1">
      <!-- Overview Tab -->
      <div v-if="currentActiveTab === 'overview'" class="space-y-3">
        <slot name="overview" :fields="fields" :loading="loading">
          <!-- Loading Skeletons -->
          <div v-if="loading" class="space-y-3">
            <div
              v-for="index in 4"
              :key="index"
              class="rounded-ui-surface border border-ui-border-subtle bg-ui-surface p-3"
            >
              <DsSkeleton class="mb-2 h-3.5 w-24" />
              <DsSkeleton class="h-5 w-48" />
            </div>
          </div>

          <!-- Empty Fields State -->
          <DsEmptyState
            v-else-if="!fields || fields.length === 0"
            icon="i-lucide-file-text"
            :title="
              translate(
                'RECORD_DRAWER.FIELDS.EMPTY_TITLE',
                'No fields to display'
              )
            "
            :description="
              translate(
                'RECORD_DRAWER.FIELDS.EMPTY_DESCRIPTION',
                'There are no fields configured for this record.'
              )
            "
          />

          <!-- Fields List -->
          <div v-else class="space-y-3">
            <div
              v-for="field in fields"
              :key="field.id"
              class="group rounded-ui-surface border border-ui-border-subtle bg-ui-surface p-3 transition-colors duration-ui-fast"
              :class="{
                'ring-2 ring-ui-border-focus': editingFieldId === field.id,
              }"
            >
              <!-- Editing Mode -->
              <div
                v-if="editingFieldId === field.id"
                class="flex flex-col gap-2"
                data-testid="field-editor"
              >
                <span class="text-ui-caption font-medium text-ui-text-muted">
                  {{ field.label }}
                </span>
                <div class="flex items-center gap-2">
                  <div class="min-w-0 flex-1">
                    <DsSelect
                      v-if="field.editType === 'select'"
                      :id="`drawer-field-${field.id}`"
                      v-model="draftValue"
                      :options="field.options || []"
                      hide-label
                      :label="field.label"
                      autofocus
                      @keydown.esc.stop="cancelEdit"
                      @keydown.enter.stop="saveEdit(field)"
                    />
                    <DsInput
                      v-else
                      :id="`drawer-field-${field.id}`"
                      v-model="draftValue"
                      :type="field.editType === 'number' ? 'number' : 'text'"
                      hide-label
                      :label="field.label"
                      autofocus
                      @enter="saveEdit(field)"
                      @keydown.esc.stop="cancelEdit"
                    />
                  </div>
                  <DsButton
                    icon="i-lucide-check"
                    size="sm"
                    variant="primary"
                    :aria-label="translate('RECORD_DRAWER.FIELDS.SAVE', 'Save')"
                    data-testid="field-save-button"
                    @click.stop="saveEdit(field)"
                  />
                  <DsButton
                    icon="i-lucide-x"
                    size="sm"
                    variant="ghost"
                    :aria-label="
                      translate('RECORD_DRAWER.FIELDS.CANCEL', 'Cancel')
                    "
                    data-testid="field-cancel-button"
                    @click.stop="cancelEdit"
                  />
                </div>
              </div>

              <!-- Display Mode -->
              <div
                v-else
                :role="field.editable !== false ? 'button' : undefined"
                :tabindex="field.editable !== false ? 0 : undefined"
                :aria-label="
                  field.editable !== false
                    ? `${translate('RECORD_DRAWER.FIELDS.CLICK_TO_EDIT', 'Click to edit')} ${field.label}`
                    : undefined
                "
                class="flex items-center justify-between gap-2"
                :class="{
                  'cursor-pointer': field.editable !== false,
                }"
                data-testid="field-display"
                @click="startEdit(field)"
                @keydown.enter.prevent="startEdit(field)"
                @keydown.space.prevent="startEdit(field)"
              >
                <div class="min-w-0 flex-1">
                  <p class="m-0 text-ui-caption font-medium text-ui-text-muted">
                    {{ field.label }}
                  </p>
                  <p class="m-0 truncate text-ui-body text-ui-text">
                    <span v-if="getDisplayValue(field)">
                      {{ getDisplayValue(field) }}
                    </span>
                    <span v-else class="italic text-ui-text-subtle">
                      {{ translate('RECORD_DRAWER.FIELDS.NOT_SET', '—') }}
                    </span>
                  </p>
                </div>
                <div
                  v-if="field.editable !== false"
                  class="opacity-0 transition-opacity duration-ui-fast group-hover:opacity-100 group-focus-within:opacity-100"
                  aria-hidden="true"
                >
                  <Icon
                    icon="i-lucide-pencil"
                    class="size-4 text-ui-text-muted"
                  />
                </div>
              </div>
            </div>
          </div>
        </slot>
      </div>

      <!-- Timeline Tab -->
      <div v-else-if="currentActiveTab === 'timeline'" class="space-y-3">
        <slot name="timeline">
          <DsEmptyState
            icon="i-lucide-history"
            :title="
              translate(
                'RECORD_DRAWER.TIMELINE.EMPTY_TITLE',
                'No activity recorded'
              )
            "
            :description="
              translate(
                'RECORD_DRAWER.TIMELINE.EMPTY_DESCRIPTION',
                'Activities, messages, and timeline events will appear here.'
              )
            "
          />
        </slot>
      </div>

      <!-- Notes Tab -->
      <div v-else-if="currentActiveTab === 'notes'" class="space-y-3">
        <slot name="notes">
          <DsEmptyState
            icon="i-lucide-notebook-pen"
            :title="
              translate('RECORD_DRAWER.NOTES.EMPTY_TITLE', 'No notes yet')
            "
            :description="
              translate(
                'RECORD_DRAWER.NOTES.EMPTY_DESCRIPTION',
                'Add notes to keep track of important context.'
              )
            "
          />
        </slot>
      </div>

      <!-- Dynamic Custom Tab -->
      <div v-else class="space-y-3">
        <slot :name="currentActiveTab">
          <DsEmptyState
            icon="i-lucide-file-text"
            :title="
              translate('RECORD_DRAWER.CUSTOM_TAB.EMPTY_TITLE', 'No content')
            "
            :description="
              translate(
                'RECORD_DRAWER.CUSTOM_TAB.EMPTY_DESCRIPTION',
                'No content available for this tab.'
              )
            "
          />
        </slot>
      </div>
    </div>

    <!-- Quick Actions Footer -->
    <template v-if="hasFooter" #footer>
      <slot name="footer">
        <div
          v-if="quickActions && quickActions.length > 0"
          class="flex flex-wrap items-center gap-2"
          role="toolbar"
          :aria-label="
            translate('RECORD_DRAWER.QUICK_ACTIONS_LABEL', 'Quick actions')
          "
        >
          <DsButton
            v-for="action in quickActions"
            :key="action.id"
            :label="action.label"
            :icon="action.icon"
            :variant="action.variant || 'secondary'"
            :disabled="loading"
            @click="emit('quickAction', action.id)"
          />
        </div>
      </slot>
    </template>
  </DsDrawer>
</template>

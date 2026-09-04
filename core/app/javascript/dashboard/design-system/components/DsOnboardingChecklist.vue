<script setup>
import { ref, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useDsTranslate } from '../useDsTranslate';
import DsButton from './DsButton.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  steps: {
    type: Array,
    default: null,
  },
  accountId: {
    type: [String, Number],
    default: '',
  },
  modelValue: {
    type: Boolean,
    default: true,
  },
  floating: {
    type: Boolean,
    default: true,
  },
  dismissible: {
    type: Boolean,
    default: true,
  },
  persist: {
    type: Boolean,
    default: true,
  },
  persistKey: {
    type: String,
    default: 'chusterm_onboarding_ftue',
  },
  title: {
    type: String,
    default: '',
  },
  subtitle: {
    type: String,
    default: '',
  },
  showDemoDataAction: {
    type: Boolean,
    default: true,
  },
  demoDataLabel: {
    type: String,
    default: '',
  },
  collapsedLabel: {
    type: String,
    default: '',
  },
  initialCompletedIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'update:modelValue',
  'update:completedSteps',
  'stepClick',
  'stepToggle',
  'stepAction',
  'demoData',
  'dismiss',
  'complete',
]);

let router = null;
try {
  router = useRouter();
} catch (e) {
  // outside router context
}

const { translate } = useDsTranslate();

const getStorage = () => {
  if (typeof localStorage !== 'undefined') {
    return localStorage;
  }
  if (typeof window !== 'undefined' && window.localStorage) {
    return window.localStorage;
  }
  return null;
};

const DEFAULT_STEPS = [
  {
    id: 'connect_channel',
    titleKey: 'ONBOARDING_CHECKLIST.STEPS.CONNECT_CHANNEL.TITLE',
    defaultTitle: 'Connect WhatsApp Channel',
    descriptionKey: 'ONBOARDING_CHECKLIST.STEPS.CONNECT_CHANNEL.DESCRIPTION',
    defaultDescription:
      'Connect your account via Evolution API, Baileys, or Cloud API to send and receive messages.',
    actionLabelKey: 'ONBOARDING_CHECKLIST.STEPS.CONNECT_CHANNEL.ACTION',
    defaultActionLabel: 'Connect Channel',
    icon: 'i-lucide-message-circle',
    path: '/app/accounts/:accountId/settings/inboxes/new',
    route: 'settings_inbox_new',
  },
  {
    id: 'import_contacts',
    titleKey: 'ONBOARDING_CHECKLIST.STEPS.IMPORT_CONTACTS.TITLE',
    defaultTitle: 'Import Contacts',
    descriptionKey: 'ONBOARDING_CHECKLIST.STEPS.IMPORT_CONTACTS.DESCRIPTION',
    defaultDescription:
      'Upload your CSV lead spreadsheet or sync contacts to start sales cadences.',
    actionLabelKey: 'ONBOARDING_CHECKLIST.STEPS.IMPORT_CONTACTS.ACTION',
    defaultActionLabel: 'Import Contacts',
    icon: 'i-lucide-users',
    path: '/app/accounts/:accountId/contacts',
    route: 'contacts_dashboard',
  },
  {
    id: 'create_pipeline',
    titleKey: 'ONBOARDING_CHECKLIST.STEPS.CREATE_PIPELINE.TITLE',
    defaultTitle: 'Create First Pipeline',
    descriptionKey: 'ONBOARDING_CHECKLIST.STEPS.CREATE_PIPELINE.DESCRIPTION',
    defaultDescription:
      'Structure your sales process stages in CRM and configure sales cadences.',
    actionLabelKey: 'ONBOARDING_CHECKLIST.STEPS.CREATE_PIPELINE.ACTION',
    defaultActionLabel: 'Create Pipeline',
    icon: 'i-lucide-kanban',
    path: '/app/accounts/:accountId/crm/board',
    route: 'crm_board',
  },
  {
    id: 'send_message',
    titleKey: 'ONBOARDING_CHECKLIST.STEPS.SEND_MESSAGE.TITLE',
    defaultTitle: 'Send First Message',
    descriptionKey: 'ONBOARDING_CHECKLIST.STEPS.SEND_MESSAGE.DESCRIPTION',
    defaultDescription:
      'Start a direct chat in Inbox or test qualification for your active pipeline.',
    actionLabelKey: 'ONBOARDING_CHECKLIST.STEPS.SEND_MESSAGE.ACTION',
    defaultActionLabel: 'Open Inbox',
    icon: 'i-lucide-send',
    path: '/app/accounts/:accountId/conversations',
    route: 'inbox_conversation',
  },
];

const activeSteps = computed(() =>
  Array.isArray(props.steps) && props.steps.length > 0
    ? props.steps
    : DEFAULT_STEPS
);

const getStepTitle = step => {
  if (step.title) return step.title;
  if (step.titleKey) {
    return translate(step.titleKey, step.defaultTitle || '');
  }
  return step.defaultTitle || '';
};

const getStepDescription = step => {
  if (step.description !== undefined && step.description !== null) {
    return step.description;
  }
  if (step.descriptionKey) {
    return translate(step.descriptionKey, step.defaultDescription || '');
  }
  return step.defaultDescription || '';
};

const getStepActionLabel = step => {
  if (step.actionLabel) return step.actionLabel;
  if (step.actionLabelKey) {
    return translate(step.actionLabelKey, step.defaultActionLabel || '');
  }
  return step.defaultActionLabel || '';
};

const storageKey = computed(() => {
  const accountSuffix =
    props.accountId !== undefined &&
    props.accountId !== null &&
    props.accountId !== ''
      ? `_${props.accountId}`
      : '';
  return `${props.persistKey}${accountSuffix}`;
});

const isExpanded = ref(props.modelValue);
const isDismissed = ref(false);
const completedSet = ref(new Set(props.initialCompletedIds || []));

const isStepCompleted = id => completedSet.value.has(id);

const findFirstIncompleteId = () => {
  const steps = activeSteps.value;
  const first = steps.find(s => !isStepCompleted(s.id));
  return first ? first.id : steps[0]?.id || null;
};

const activeStepId = ref(null);

const resolvedSteps = computed(() =>
  activeSteps.value.map(step => ({
    ...step,
    title: getStepTitle(step),
    description: getStepDescription(step),
    actionLabel: getStepActionLabel(step),
    completed: isStepCompleted(step.id),
    active: activeStepId.value === step.id,
  }))
);

const totalSteps = computed(() => resolvedSteps.value.length);
const completedCount = computed(
  () => resolvedSteps.value.filter(s => s.completed).length
);
const progressPercent = computed(() =>
  totalSteps.value
    ? Math.round((completedCount.value / totalSteps.value) * 100)
    : 0
);
const isAllDone = computed(
  () => totalSteps.value > 0 && completedCount.value === totalSteps.value
);

const progressPercentText = computed(() => `${progressPercent.value}%`);
const stepRatioText = computed(
  () => `${completedCount.value}/${totalSteps.value}`
);

const displayTitle = computed(
  () =>
    props.title || translate('ONBOARDING_CHECKLIST.TITLE', 'Activation Guide')
);

const displayCollapsedLabel = computed(
  () =>
    props.collapsedLabel ||
    translate('ONBOARDING_CHECKLIST.COLLAPSED_LABEL', 'Getting Started')
);

const displayDemoDataLabel = computed(
  () =>
    props.demoDataLabel ||
    translate('ONBOARDING_CHECKLIST.DEMO_DATA_LABEL', 'Enable Demo Data')
);

const headerSubtitle = computed(() => {
  if (props.subtitle) return props.subtitle;
  return translate(
    'ONBOARDING_CHECKLIST.PROGRESS_SUBTITLE',
    '{completed} of {total} tasks completed ({percent}%)',
    {
      completed: completedCount.value,
      total: totalSteps.value,
      percent: progressPercent.value,
    }
  );
});

const labelExpand = computed(() =>
  translate('ONBOARDING_CHECKLIST.EXPAND', 'Expand Activation Guide')
);
const labelCollapse = computed(() =>
  translate('ONBOARDING_CHECKLIST.COLLAPSE', 'Collapse')
);
const labelClose = computed(() =>
  translate('ONBOARDING_CHECKLIST.CLOSE', 'Close')
);
const labelRegion = computed(() =>
  translate('ONBOARDING_CHECKLIST.REGION', 'Activation Guide')
);
const labelCompletionTitle = computed(() =>
  translate('ONBOARDING_CHECKLIST.COMPLETION_TITLE', 'All set!')
);
const labelCompletionSubtitle = computed(() =>
  translate(
    'ONBOARDING_CHECKLIST.COMPLETION_SUBTITLE',
    'You completed all activation steps.'
  )
);
const labelPending = computed(() =>
  translate('ONBOARDING_CHECKLIST.MARK_PENDING', 'Mark pending')
);
const labelDone = computed(() =>
  translate('ONBOARDING_CHECKLIST.MARK_COMPLETED', 'Mark completed')
);

const loadPersistedState = () => {
  const completed = new Set(props.initialCompletedIds || []);
  let expanded = props.modelValue;
  let dismissed = false;

  const storage = getStorage();
  if (props.persist && storage) {
    try {
      const raw = storage.getItem(storageKey.value);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed.completedSteps)) {
          parsed.completedSteps.forEach(id => completed.add(id));
        }
        if (typeof parsed.isExpanded === 'boolean') {
          expanded = parsed.isExpanded;
        }
        if (typeof parsed.isDismissed === 'boolean') {
          dismissed = parsed.isDismissed;
        }
      }
    } catch (e) {
      // Ignore JSON error
    }
  }

  completedSet.value = completed;
  isExpanded.value = expanded;
  isDismissed.value = dismissed;
  activeStepId.value = findFirstIncompleteId();
};

// Initial state sync
loadPersistedState();

// Synchronize state reactively when accountId, persistKey or persist changes
watch(
  () => [props.accountId, props.persistKey, props.persist],
  () => {
    loadPersistedState();
  }
);

watch(
  () => props.modelValue,
  val => {
    if (typeof val === 'boolean') {
      isExpanded.value = val;
    }
  }
);

watch(
  () => props.initialCompletedIds,
  newIds => {
    if (Array.isArray(newIds)) {
      const nextSet = new Set(completedSet.value);
      newIds.forEach(id => nextSet.add(id));
      completedSet.value = nextSet;
      activeStepId.value = findFirstIncompleteId();
    }
  },
  { deep: true }
);

const savePersistedState = () => {
  const storage = getStorage();
  if (!props.persist || !storage) {
    return;
  }

  try {
    const payload = {
      completedSteps: Array.from(completedSet.value),
      isExpanded: isExpanded.value,
      isDismissed: isDismissed.value,
    };
    storage.setItem(storageKey.value, JSON.stringify(payload));
  } catch (e) {
    // Ignore storage quota errors
  }
};

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value;
  emit('update:modelValue', isExpanded.value);
  savePersistedState();
};

const openStep = stepId => {
  activeStepId.value = activeStepId.value === stepId ? null : stepId;
  emit('stepClick', { stepId, active: activeStepId.value === stepId });
};

const toggleStep = step => {
  const willBeCompleted = !completedSet.value.has(step.id);
  const nextSet = new Set(completedSet.value);
  if (willBeCompleted) {
    nextSet.add(step.id);
  } else {
    nextSet.delete(step.id);
  }

  completedSet.value = nextSet;

  const completedArray = Array.from(completedSet.value);
  emit('stepToggle', {
    stepId: step.id,
    completed: willBeCompleted,
    completedSteps: completedArray,
  });
  emit('update:completedSteps', completedArray);

  savePersistedState();

  if (isAllDone.value) {
    emit('complete', { completedSteps: completedArray });
  } else if (willBeCompleted) {
    activeStepId.value = findFirstIncompleteId();
  }
};

const resolveStepPath = step => {
  if (!step || !step.path) return '';
  const currentAccountId =
    props.accountId !== undefined &&
    props.accountId !== null &&
    props.accountId !== ''
      ? props.accountId
      : router?.currentRoute?.value?.params?.accountId || '';

  if (currentAccountId) {
    return step.path.replace(
      ':accountId',
      encodeURIComponent(String(currentAccountId))
    );
  }

  // When accountId is empty / not present, safely normalize path without malformed double slashes
  return (
    step.path
      .replace(/(^|\/)accounts\/:accountId(\/|$)/, '$1')
      .replace(/:accountId/g, '')
      .replace(/\/+/g, '/')
      .replace(/\/$/, '') || '/'
  );
};

const handleStepAction = (step, index) => {
  const path = resolveStepPath(step);
  const targetAccountId =
    props.accountId !== undefined &&
    props.accountId !== null &&
    props.accountId !== ''
      ? props.accountId
      : router?.currentRoute?.value?.params?.accountId || undefined;

  emit('stepAction', {
    step,
    index,
    path,
    route: step.route,
  });

  if (router && typeof router.push === 'function' && (path || step.route)) {
    try {
      const navigationPromise = path
        ? router.push(path)
        : router.push({
            name: step.route,
            params: targetAccountId ? { accountId: targetAccountId } : {},
          });
      if (navigationPromise && typeof navigationPromise.catch === 'function') {
        navigationPromise.catch(() => {});
      }
    } catch (e) {
      // Ignore navigation errors
    }
  }
};

const handleDemoData = () => {
  emit('demoData');
};

const dismiss = () => {
  isDismissed.value = true;
  emit('dismiss');
  savePersistedState();
};
</script>

<template>
  <aside
    v-if="!isDismissed"
    :class="[
      floating
        ? 'fixed bottom-5 right-5 z-40 w-[calc(100vw-2.5rem)] max-w-sm sm:w-96 sm:max-w-md'
        : 'w-full max-w-md',
    ]"
    data-testid="ds-onboarding-checklist"
  >
    <!-- Collapsed Trigger Pill -->
    <button
      v-if="!isExpanded"
      type="button"
      data-testid="onboarding-collapsed-trigger"
      class="group inline-flex w-full items-center justify-between gap-3 rounded-full border border-ui-border-subtle bg-ui-surface/95 px-4 py-2.5 text-ui-body-sm font-medium text-ui-text shadow-ui-overlay backdrop-blur transition-all duration-ui-fast hover:border-ui-border-strong hover:bg-ui-elevated focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
      :aria-expanded="false"
      :aria-label="labelExpand"
      @click="toggleExpand"
    >
      <div class="flex items-center gap-2.5 min-w-0">
        <div
          class="flex size-6 shrink-0 items-center justify-center rounded-full bg-ui-brand-soft text-ui-brand-foreground"
        >
          <Icon icon="i-lucide-sparkles" class="size-3.5" />
        </div>
        <span class="truncate">{{
          displayTitle || displayCollapsedLabel
        }}</span>
      </div>

      <div class="flex items-center gap-2 shrink-0">
        <span
          class="inline-flex items-center rounded-full bg-ui-brand px-2 py-0.5 text-xs font-semibold text-ui-text-inverse"
          :class="{ 'bg-ui-success': isAllDone }"
        >
          {{ stepRatioText }}
        </span>
        <Icon
          icon="i-lucide-chevron-up"
          class="size-4 text-ui-text-muted transition-transform group-hover:-translate-y-0.5"
        />
      </div>
    </button>

    <!-- Expanded Checklist Card -->
    <div
      v-else
      data-testid="onboarding-expanded-card"
      class="flex flex-col overflow-hidden rounded-ui-surface border border-ui-border bg-ui-surface shadow-ui-overlay transition-all duration-ui-base"
      role="region"
      :aria-label="labelRegion"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between border-b border-ui-border-subtle bg-ui-elevated px-4 py-3.5"
      >
        <div class="flex items-center gap-2.5 min-w-0">
          <div
            class="flex size-7 shrink-0 items-center justify-center rounded-lg bg-ui-brand-soft text-ui-brand-foreground"
          >
            <Icon icon="i-lucide-sparkles" class="size-4" />
          </div>
          <div class="min-w-0">
            <h3
              class="m-0 truncate text-ui-body font-semibold text-ui-text leading-snug"
            >
              {{ displayTitle }}
            </h3>
            <p class="m-0 text-ui-caption text-ui-text-muted truncate">
              {{ headerSubtitle }}
            </p>
          </div>
        </div>

        <div class="flex items-center gap-1 text-ui-text-muted shrink-0">
          <button
            type="button"
            data-testid="onboarding-collapse-button"
            class="flex size-7 items-center justify-center rounded-ui-control text-ui-text-muted hover:bg-ui-hover hover:text-ui-text focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ui-border-focus"
            :title="labelCollapse"
            :aria-label="labelCollapse"
            @click="toggleExpand"
          >
            <Icon icon="i-lucide-chevron-down" class="size-4" />
          </button>

          <button
            v-if="dismissible"
            type="button"
            data-testid="onboarding-dismiss-button"
            class="flex size-7 items-center justify-center rounded-ui-control text-ui-text-muted hover:bg-ui-hover hover:text-ui-text focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ui-border-focus"
            :title="labelClose"
            :aria-label="labelClose"
            @click="dismiss"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </div>
      </div>

      <!-- Progress Bar -->
      <div
        class="h-1.5 w-full bg-ui-sunken overflow-hidden"
        role="progressbar"
        :aria-valuenow="progressPercent"
        aria-valuemin="0"
        aria-valuemax="100"
      >
        <div
          data-testid="onboarding-progress-fill"
          class="h-full transition-all duration-300 ease-out"
          :class="isAllDone ? 'bg-ui-success' : 'bg-ui-brand'"
          :style="{ width: progressPercentText }"
        />
      </div>

      <!-- Completion Banner (if 100%) -->
      <div
        v-if="isAllDone"
        data-testid="onboarding-complete-banner"
        class="m-3 flex items-center gap-3 rounded-ui-control border border-ui-success/20 bg-ui-success-soft p-3 text-ui-body-sm text-ui-success-foreground"
      >
        <Icon
          icon="i-lucide-party-popper"
          class="size-5 shrink-0 text-ui-success"
        />
        <div class="flex-1">
          <p class="font-medium m-0">{{ labelCompletionTitle }}</p>
          <p class="text-ui-caption text-ui-success-foreground/80 m-0">
            {{ labelCompletionSubtitle }}
          </p>
        </div>
      </div>

      <!-- Step List -->
      <div
        class="flex max-h-80 flex-col gap-1 overflow-y-auto p-2 scrollbar-thin"
      >
        <div
          v-for="(step, idx) in resolvedSteps"
          :key="step.id"
          :data-testid="`onboarding-step-${step.id}`"
          class="group flex flex-col rounded-ui-control border transition-all duration-ui-fast"
          :class="[
            step.completed
              ? 'border-transparent bg-ui-sunken/40 opacity-75'
              : step.active
                ? 'border-ui-border-strong bg-ui-elevated/80 shadow-sm'
                : 'border-transparent bg-transparent hover:bg-ui-hover/60',
          ]"
        >
          <!-- Step Header Row -->
          <div
            class="flex cursor-pointer items-center justify-between p-2.5 select-none"
            role="button"
            tabindex="0"
            :aria-expanded="step.active"
            :aria-controls="`step-body-${step.id}`"
            @click="openStep(step.id)"
            @keydown.enter.prevent="openStep(step.id)"
            @keydown.space.prevent="openStep(step.id)"
          >
            <div class="flex items-center gap-2.5 min-w-0">
              <!-- Custom Checkbox Button -->
              <button
                type="button"
                :data-testid="`step-checkbox-${step.id}`"
                class="flex size-5 shrink-0 items-center justify-center rounded-full border transition-all duration-ui-fast focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
                :class="[
                  step.completed
                    ? 'border-ui-success bg-ui-success text-white'
                    : 'border-ui-border-strong bg-ui-surface text-transparent hover:border-ui-brand',
                ]"
                :aria-label="
                  step.completed
                    ? translate(
                        'ONBOARDING_CHECKLIST.MARK_STEP_PENDING',
                        'Mark {title} as pending',
                        { title: step.title }
                      )
                    : translate(
                        'ONBOARDING_CHECKLIST.MARK_STEP_COMPLETED',
                        'Mark {title} as completed',
                        { title: step.title }
                      )
                "
                @click.stop="toggleStep(step)"
              >
                <Icon icon="i-lucide-check" class="size-3 stroke-[3]" />
              </button>

              <!-- Step Title -->
              <span
                class="truncate text-ui-body-sm font-medium transition-colors"
                :class="[
                  step.completed
                    ? 'text-ui-text-muted line-through'
                    : 'text-ui-text group-hover:text-ui-brand',
                ]"
              >
                {{ step.title }}
              </span>
            </div>

            <div class="flex items-center gap-1.5 shrink-0">
              <Icon
                :icon="step.icon"
                class="size-4 text-ui-text-muted transition-colors group-hover:text-ui-text"
              />
              <Icon
                :icon="
                  step.active ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
                "
                class="size-3.5 text-ui-text-muted"
              />
            </div>
          </div>

          <!-- Step Expanded Body -->
          <div
            v-if="step.active"
            :id="`step-body-${step.id}`"
            :data-testid="`step-body-${step.id}`"
            class="flex flex-col gap-2.5 px-3 pb-3 pt-0 text-ui-body-sm"
          >
            <p
              v-if="step.description"
              class="m-0 text-ui-caption text-ui-text-muted leading-relaxed"
            >
              {{ step.description }}
            </p>

            <div class="flex items-center gap-2 pt-1">
              <DsButton
                v-if="step.actionLabel"
                size="sm"
                variant="primary"
                :label="step.actionLabel"
                :icon="step.icon"
                :data-testid="`step-action-button-${step.id}`"
                @click="handleStepAction(step, idx)"
              />
              <DsButton
                size="sm"
                variant="ghost"
                :label="step.completed ? labelPending : labelDone"
                :data-testid="`step-toggle-button-${step.id}`"
                @click="toggleStep(step)"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Footer Action: Demo / Mock Data -->
      <div
        v-if="showDemoDataAction"
        class="flex items-center justify-between border-t border-ui-border-subtle bg-ui-sunken/40 px-3.5 py-2.5"
      >
        <button
          type="button"
          data-testid="onboarding-demo-data-button"
          class="inline-flex items-center gap-1.5 text-ui-caption font-medium text-ui-text-muted hover:text-ui-brand transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ui-border-focus"
          @click="handleDemoData"
        >
          <Icon icon="i-lucide-sparkles" class="size-3.5 text-ui-brand" />
          <span>{{ displayDemoDataLabel }}</span>
        </button>

        <span
          data-testid="onboarding-percent-indicator"
          class="text-ui-caption text-ui-text-subtle font-medium"
        >
          {{ progressPercentText }}
        </span>
      </div>
    </div>
  </aside>
  <div v-else class="hidden" />
</template>

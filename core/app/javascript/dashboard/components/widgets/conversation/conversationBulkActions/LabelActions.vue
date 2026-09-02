<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { vOnClickOutside } from '@vueuse/components';

const props = defineProps({
  contextScope: {
    type: String,
    default: 'conversation',
    validator: value => ['contact', 'conversation', 'all'].includes(value),
  },
});

const emit = defineEmits(['close', 'assign']);

const { t } = useI18n();

const labels = useMapGetter('labels/getLabels');

const query = ref('');
const selectedLabels = ref([]);
const dialogRef = ref(null);

const filteredLabels = computed(() => {
  const scopedLabels = labels.value.filter(label => {
    const scope = label.scope || 'both';
    return (
      props.contextScope === 'all' ||
      scope === 'both' ||
      scope === props.contextScope
    );
  });

  if (!query.value) return scopedLabels;

  const normalizedQuery = query.value.toLowerCase();
  return scopedLabels.filter(label =>
    [label.title, label.slug, label.category, label.description]
      .filter(Boolean)
      .some(value => value.toLowerCase().includes(normalizedQuery))
  );
});

const groupedLabels = computed(() => {
  const categoryLabels = {
    area: 'Setor jurídico',
    temperature: 'Temperatura',
    relationship: 'Relacionamento',
    status: 'Status',
    document: 'Documentos',
    origin: 'Origem',
    risk: 'Risco',
    service: 'Atendimento',
    uncategorized: 'Outras etiquetas',
  };

  const groups = filteredLabels.value.reduce((acc, label) => {
    const category = label.category || 'uncategorized';
    if (!acc[category]) {
      acc[category] = {
        key: category,
        title: categoryLabels[category] || category,
        labels: [],
      };
    }

    acc[category].labels.push(label);
    return acc;
  }, {});

  return Object.values(groups).sort((a, b) => {
    if (a.key === 'uncategorized') return 1;
    if (b.key === 'uncategorized') return -1;
    return a.title.localeCompare(b.title);
  });
});

const hasLabels = computed(() => filteredLabels.value.length > 0);

const onClose = () => {
  emit('close');
};

const focusLabelOption = event => {
  const options = Array.from(
    dialogRef.value?.querySelectorAll('[data-label-option]') || []
  );
  if (!options.length) return;

  const activeIndex = options.indexOf(document.activeElement);
  let nextIndex;

  if (event.key === 'Home') {
    nextIndex = 0;
  } else if (event.key === 'End') {
    nextIndex = options.length - 1;
  } else if (event.key === 'ArrowDown') {
    nextIndex = activeIndex < 0 ? 0 : (activeIndex + 1) % options.length;
  } else {
    nextIndex =
      activeIndex < 0
        ? options.length - 1
        : (activeIndex - 1 + options.length) % options.length;
  }

  event.preventDefault();
  options[nextIndex].focus();
};

const onPanelKeydown = event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    event.stopPropagation();
    onClose();
    return;
  }

  if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
    focusLabelOption(event);
  }
};

const handleAssign = () => {
  if (selectedLabels.value.length > 0) {
    emit('assign', selectedLabels.value);
  }
};
</script>

<template>
  <div
    ref="dialogRef"
    v-on-click-outside="onClose"
    class="absolute top-12 z-20 flex w-[min(18rem,calc(100vw-1rem))] origin-top-right flex-col overflow-hidden rounded-xl bg-ds-bg-elevated/95 text-ds-fg-default shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle backdrop-blur-xl ltr:right-2 rtl:left-2"
    role="dialog"
    :aria-label="t('BULK_ACTION.LABELS.ASSIGN_LABELS')"
    @keydown="onPanelKeydown"
  >
    <span
      class="absolute -top-1.5 z-10 size-3 rotate-45 border-l border-t border-ds-border-subtle bg-ds-bg-elevated ltr:right-[var(--triangle-position)] rtl:left-[var(--triangle-position)]"
      aria-hidden="true"
    />
    <div
      class="flex min-h-11 items-center justify-between border-b border-ds-border-subtle px-3 py-2"
    >
      <span class="text-sm font-semibold text-ds-fg-default">
        {{ t('BULK_ACTION.LABELS.ASSIGN_LABELS') }}
      </span>
      <button
        type="button"
        class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        :aria-label="t('GENERAL.CLOSE')"
        @click="onClose"
      >
        <span class="i-lucide-x size-4" aria-hidden="true" />
      </button>
    </div>
    <div class="flex min-h-0 max-h-80 flex-col">
      <header class="bg-ds-bg-elevated/95 p-2 backdrop-blur-sm">
        <div class="relative flex items-center">
          <span
            class="i-lucide-search pointer-events-none absolute size-4 text-ds-fg-subtle ltr:left-3 rtl:right-3"
            aria-hidden="true"
          />
          <input
            v-model="query"
            type="search"
            :placeholder="t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')"
            :aria-label="t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')"
            class="reset-base mb-0 h-9 w-full rounded-lg border border-ds-border-subtle bg-ds-bg-sunken py-2 text-sm text-ds-fg-default outline-none placeholder:text-ds-fg-subtle focus:border-ds-border-focus focus:ring-2 focus:ring-ds-border-focus/30 ltr:pl-9 ltr:pr-3 rtl:pl-3 rtl:pr-9"
            autofocus
          />
        </div>
      </header>
      <ul
        v-if="hasLabels"
        class="m-0 flex-1 list-none overflow-y-auto px-1.5 pb-1.5"
        role="group"
        :aria-label="t('BULK_ACTION.LABELS.ASSIGN_LABELS')"
      >
        <template v-for="group in groupedLabels" :key="group.key">
          <li
            class="px-2.5 pb-1 pt-2 text-[0.625rem] font-semibold uppercase tracking-[0.12em] text-ds-fg-subtle"
            role="presentation"
          >
            {{ group.title }}
          </li>
          <li v-for="label in group.labels" :key="label.id" class="m-0 p-0">
            <label
              class="flex min-h-10 cursor-pointer items-center rounded-lg px-2.5 py-2 text-ds-fg-default transition-colors hover:bg-ds-bg-hover has-[:checked]:bg-ds-bg-active"
            >
              <input
                v-model="selectedLabels"
                type="checkbox"
                :value="label.title"
                data-label-option
                class="my-0 shrink-0 cursor-pointer accent-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus ltr:mr-2.5 rtl:ml-2.5"
                :aria-label="label.display_title || label.title"
              />
              <span class="min-w-0 flex-1 truncate text-sm">
                {{ label.display_title || label.title }}
              </span>
              <span
                class="size-3 shrink-0 rounded border border-ds-border-subtle"
                :style="{ backgroundColor: label.color }"
                aria-hidden="true"
              />
            </label>
          </li>
        </template>
      </ul>
      <div
        v-else
        class="flex min-h-24 items-center justify-center p-3 text-center"
        role="status"
        aria-live="polite"
      >
        <span class="text-sm text-ds-fg-muted">
          {{ t('BULK_ACTION.LABELS.NO_LABELS_FOUND') }}
        </span>
      </div>
      <footer class="border-t border-ds-border-subtle p-2">
        <button
          type="button"
          class="inline-flex h-9 w-full items-center justify-center rounded-lg bg-ds-accent px-3 text-sm font-semibold text-ds-fg-on-accent transition-colors hover:bg-ds-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="!selectedLabels.length"
          @click="handleAssign"
        >
          {{ t('BULK_ACTION.LABELS.ASSIGN_SELECTED_LABELS') }}
        </button>
      </footer>
    </div>
  </div>
</template>

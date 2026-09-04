<script setup>
import { computed } from 'vue';

import { useDsTranslate } from '../useDsTranslate';
import DsButton from './DsButton.vue';

const props = defineProps({
  count: { type: Number, default: 0 },
  actions: { type: Array, default: () => [] },
});

const emit = defineEmits(['action', 'clear']);

const { translate } = useDsTranslate();

const countLabel = computed(() =>
  translate('BULK_ACTION_BAR.SELECTED_COUNT', '{count} selected', {
    count: props.count,
  })
);

const clearLabel = computed(() =>
  translate('BULK_ACTION_BAR.CLEAR_SELECTION', 'Clear selection')
);
</script>

<template>
  <Transition
    enter-active-class="transition duration-ui-base ease-out"
    enter-from-class="opacity-0 translate-y-4"
    enter-to-class="opacity-100 translate-y-0"
    leave-active-class="transition duration-ui-fast ease-in"
    leave-from-class="opacity-100 translate-y-0"
    leave-to-class="opacity-0 translate-y-4"
  >
    <div
      v-if="count > 0"
      role="toolbar"
      :aria-label="countLabel"
      class="fixed bottom-6 left-1/2 z-ui-overlay flex -translate-x-1/2 items-center gap-3 rounded-ui-surface border border-ui-border-subtle bg-ui-surface/90 px-4 py-2.5 text-ui-text shadow-ui-overlay backdrop-blur-md"
    >
      <div class="flex items-center gap-2">
        <span
          class="inline-flex items-center rounded-full bg-ui-brand-soft px-2.5 py-0.5 text-ui-caption font-semibold text-ui-brand"
        >
          {{ countLabel }}
        </span>
      </div>

      <div
        v-if="actions.length"
        class="h-4 w-px bg-ui-border-subtle"
        aria-hidden="true"
      />

      <div v-if="actions.length" class="flex items-center gap-1.5">
        <DsButton
          v-for="actionItem in actions"
          :key="actionItem.id"
          :label="actionItem.label"
          :icon="actionItem.icon"
          :variant="actionItem.variant || 'secondary'"
          size="sm"
          @click="emit('action', actionItem.id)"
        />
      </div>

      <div class="h-4 w-px bg-ui-border-subtle" aria-hidden="true" />

      <DsButton
        variant="ghost"
        size="sm"
        icon="i-lucide-x"
        :label="clearLabel"
        :aria-label="clearLabel"
        @click="emit('clear')"
      />
    </div>
  </Transition>
</template>

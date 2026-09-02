<script setup>
import { computed } from 'vue';

import DsSkeleton from './DsSkeleton.vue';

const props = defineProps({
  as: { type: String, default: 'div' },
  interactive: { type: Boolean, default: false },
  selected: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
  padding: {
    type: String,
    default: 'md',
    validator: value => ['none', 'sm', 'md'].includes(value),
  },
});

const emit = defineEmits(['click']);

const element = computed(() => (props.interactive ? 'button' : props.as));
const paddingClasses = computed(
  () => ({ none: '', sm: 'p-3', md: 'p-4' })[props.padding]
);
</script>

<template>
  <component
    :is="element"
    :type="interactive ? 'button' : undefined"
    :disabled="interactive ? disabled || loading : undefined"
    :aria-busy="loading || undefined"
    :aria-pressed="interactive ? selected : undefined"
    class="w-full rounded-ui-surface border border-ui-border-subtle bg-ui-surface text-left text-ui-text"
    :class="[
      paddingClasses,
      {
        'transition-colors duration-ui-fast hover:border-ui-border-strong hover:bg-ui-hover active:bg-ui-active focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus focus-visible:ring-offset-2 focus-visible:ring-offset-ui-canvas':
          interactive && !disabled,
        'border-ui-brand bg-ui-brand-soft': selected,
        'cursor-not-allowed opacity-60': disabled,
      },
    ]"
    @click="!disabled && !loading && emit('click', $event)"
  >
    <slot v-if="!loading" />
    <div v-else class="flex flex-col gap-3">
      <DsSkeleton class="h-4 w-2/5" />
      <DsSkeleton class="h-4 w-full" />
      <DsSkeleton class="h-4 w-4/5" />
    </div>
  </component>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  variant: {
    type: String,
    default: 'outlined',
    validator: v => ['flat', 'outlined', 'elevated'].includes(v),
  },
  padding: {
    type: String,
    default: 'md',
    validator: v => ['none', 'sm', 'md', 'lg'].includes(v),
  },
  interactive: { type: Boolean, default: false },
});

const emit = defineEmits(['click']);

const VARIANT_CLASSES = {
  flat: 'bg-ds-bg-surface',
  outlined: 'bg-ds-bg-surface border border-ds-border-subtle',
  elevated: 'bg-ds-bg-elevated shadow-[var(--ds-shadow-md)]',
};

const PADDING_CLASSES = {
  none: '',
  sm: 'p-3',
  md: 'p-4',
  lg: 'p-6',
};

const variantClass = computed(() => VARIANT_CLASSES[props.variant]);
const paddingClass = computed(() => PADDING_CLASSES[props.padding]);
const interactiveClass = computed(() =>
  props.interactive
    ? 'cursor-pointer transition-colors hover:bg-ds-bg-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ds-border-focus'
    : ''
);

const handleKeydown = e => {
  if (!props.interactive) return;
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    emit('click', e);
  }
};
</script>

<template>
  <div
    class="rounded-lg"
    :class="[variantClass, paddingClass, interactiveClass]"
    :role="interactive ? 'button' : undefined"
    :tabindex="interactive ? 0 : undefined"
    @click="interactive && emit('click', $event)"
    @keydown="handleKeydown"
  >
    <slot />
  </div>
</template>

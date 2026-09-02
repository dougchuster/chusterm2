<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

import DsButton from './DsButton.vue';

const props = defineProps({
  label: { type: String, default: '' },
  ariaLabel: { type: String, default: '' },
  icon: { type: [String, Object, Function], default: 'i-lucide-ellipsis' },
  align: {
    type: String,
    default: 'end',
    validator: value => ['start', 'end'].includes(value),
  },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const rootRef = ref(null);
const open = ref(false);

const alignmentClasses = computed(() =>
  props.align === 'start' ? 'left-0' : 'right-0'
);

const close = () => {
  open.value = false;
};

const toggle = () => {
  if (!props.disabled && !props.loading) open.value = !open.value;
};

const handleDocumentPointer = event => {
  if (!rootRef.value?.contains(event.target)) close();
};

const handleDocumentKeydown = event => {
  if (event.key === 'Escape') close();
};

onMounted(() => {
  document.addEventListener('pointerdown', handleDocumentPointer);
  document.addEventListener('keydown', handleDocumentKeydown);
});

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', handleDocumentPointer);
  document.removeEventListener('keydown', handleDocumentKeydown);
});
</script>

<template>
  <div ref="rootRef" class="relative inline-flex">
    <slot name="trigger" :open="open" :toggle="toggle">
      <DsButton
        :label="label"
        :icon="icon"
        variant="secondary"
        size="sm"
        :disabled="disabled"
        :loading="loading"
        aria-haspopup="menu"
        :aria-label="ariaLabel || undefined"
        :aria-expanded="open"
        @click="toggle"
      />
    </slot>
    <div
      v-if="open"
      role="menu"
      class="absolute top-full z-ui-overlay mt-2 min-w-48 overflow-hidden rounded-ui-surface border border-ui-border bg-ui-elevated p-1 shadow-ui-overlay"
      :class="alignmentClasses"
      @click="close"
    >
      <slot :close="close" />
    </div>
  </div>
</template>

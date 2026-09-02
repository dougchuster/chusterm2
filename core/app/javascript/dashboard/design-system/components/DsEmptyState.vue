<script setup>
import DsButton from './DsButton.vue';

defineProps({
  title: { type: String, required: true },
  actionLabel: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['action']);
</script>

<template>
  <div
    class="flex min-h-40 flex-col items-center justify-center gap-4 rounded-ui-surface border border-dashed border-ui-border p-6 text-center"
  >
    <p class="m-0 max-w-xl text-ui-body text-ui-text-muted">{{ title }}</p>
    <slot name="action">
      <DsButton
        v-if="actionLabel"
        variant="primary"
        :label="actionLabel"
        :disabled="disabled"
        :loading="loading"
        @click="emit('action')"
      />
    </slot>
  </div>
</template>

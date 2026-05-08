<script setup>
import { computed, useId } from 'vue';

const props = defineProps({
  label: { type: String, default: '' },
  helper: { type: String, default: '' },
  error: { type: String, default: '' },
  required: { type: Boolean, default: false },
});

// Vue 3.5+: useId. Cai num fallback para versões anteriores.
const id =
  typeof useId === 'function'
    ? useId()
    : `ff-${Math.random().toString(36).slice(2, 10)}`;
const helperId = computed(() => (props.helper ? `${id}-helper` : undefined));
const errorId = computed(() => (props.error ? `${id}-error` : undefined));
const describedBy = computed(
  () => [errorId.value, helperId.value].filter(Boolean).join(' ') || undefined
);
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label
      v-if="label"
      :for="id"
      class="text-sm font-medium text-ds-fg-default"
    >
      {{ label }}
      <span v-if="required" class="text-ds-state-danger" aria-hidden="true">
        *
      </span>
    </label>
    <slot :id="id" :described-by="describedBy" :invalid="!!error" />
    <p
      v-if="error"
      :id="errorId"
      class="text-xs text-ds-state-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <p v-else-if="helper" :id="helperId" class="text-xs text-ds-fg-muted">
      {{ helper }}
    </p>
  </div>
</template>

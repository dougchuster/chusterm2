<script setup>
import { computed, getCurrentInstance } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  id: { type: String, default: '' },
  label: { type: String, default: '' },
  description: { type: String, default: '' },
  indeterminate: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'change']);

const { uid } = getCurrentInstance();
const checkboxId = computed(() => props.id || `ds-checkbox-${uid}`);
const descriptionId = computed(() => `${checkboxId.value}-description`);

const updateValue = event => {
  emit('update:modelValue', event.target.checked);
  emit('change', event);
};
</script>

<template>
  <label
    :for="checkboxId"
    class="group inline-flex min-w-0 items-start gap-2 rounded-ui-control text-ui-body text-ui-text"
    :class="{
      'cursor-pointer': !disabled && !loading,
      'cursor-not-allowed opacity-60': disabled || loading,
    }"
  >
    <span class="relative mt-1 flex size-4 shrink-0">
      <input
        :id="checkboxId"
        :checked="modelValue"
        :indeterminate="indeterminate"
        type="checkbox"
        :disabled="disabled || loading"
        :aria-describedby="description ? descriptionId : undefined"
        :aria-busy="loading || undefined"
        class="peer absolute inset-0 m-0 size-4 appearance-none rounded-ui-control border border-ui-border bg-ui-surface outline-none transition-colors duration-ui-fast hover:enabled:border-ui-border-strong checked:border-ui-brand checked:bg-ui-brand indeterminate:border-ui-brand indeterminate:bg-ui-brand focus-visible:ring-2 focus-visible:ring-ui-border-focus focus-visible:ring-offset-2 focus-visible:ring-offset-ui-canvas disabled:bg-ui-sunken"
        @change="updateValue"
      />
      <Icon
        v-if="loading"
        icon="i-lucide-loader-circle"
        class="pointer-events-none absolute inset-0 size-4 animate-spin text-ui-text-muted"
        aria-hidden="true"
      />
      <Icon
        v-else
        :icon="indeterminate ? 'i-lucide-minus' : 'i-lucide-check'"
        class="pointer-events-none absolute inset-0 size-4 text-white opacity-0 peer-checked:opacity-100 peer-indeterminate:opacity-100"
        aria-hidden="true"
      />
    </span>
    <span class="min-w-0">
      <span v-if="label" class="block font-medium">{{ label }}</span>
      <span
        v-if="description"
        :id="descriptionId"
        class="block text-ui-caption text-ui-text-muted"
      >
        {{ description }}
      </span>
    </span>
  </label>
</template>

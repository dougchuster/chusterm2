<script setup>
import { computed, getCurrentInstance } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: [String, Number, Boolean], default: '' },
  id: { type: String, default: '' },
  label: { type: String, default: '' },
  hideLabel: { type: Boolean, default: false },
  options: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  message: { type: String, default: '' },
  state: {
    type: String,
    default: 'default',
    validator: value => ['default', 'error', 'success'].includes(value),
  },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'change']);

defineOptions({ inheritAttrs: false });

const { uid } = getCurrentInstance();
const selectId = computed(() => props.id || `ds-select-${uid}`);
const messageId = computed(() => `${selectId.value}-message`);

const stateClasses = computed(
  () =>
    ({
      default:
        'border-ui-border hover:border-ui-border-strong focus:border-ui-border-focus',
      error: 'border-ui-danger hover:border-ui-danger focus:border-ui-danger',
      success:
        'border-ui-success hover:border-ui-success focus:border-ui-success',
    })[props.state]
);

const updateValue = event => {
  emit('update:modelValue', event.target.value);
  emit('change', event);
};
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1">
    <label
      v-if="label"
      :for="selectId"
      class="text-ui-label font-medium text-ui-text"
      :class="{ 'sr-only': hideLabel }"
    >
      {{ label }}
    </label>
    <div class="relative">
      <select
        :id="selectId"
        v-bind="$attrs"
        :value="modelValue"
        :disabled="disabled || loading"
        :aria-invalid="state === 'error' || undefined"
        :aria-describedby="message ? messageId : undefined"
        :aria-busy="loading || undefined"
        class="reset-base m-0 h-10 w-full appearance-none rounded-ui-control border bg-ui-surface py-0 pl-3 pr-10 text-ui-body text-ui-text outline-none transition-colors duration-ui-fast focus:ring-2 focus:ring-ui-border-focus/20 disabled:cursor-not-allowed disabled:bg-ui-sunken disabled:text-ui-text-disabled max-sm:h-11"
        :class="stateClasses"
        @change="updateValue"
      >
        <option v-if="placeholder" value="" disabled>
          {{ placeholder }}
        </option>
        <option
          v-for="option in options"
          :key="option.value"
          :value="option.value"
          :disabled="option.disabled"
        >
          {{ option.label }}
        </option>
      </select>
      <span
        class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3"
      >
        <Icon
          :icon="loading ? 'i-lucide-loader-circle' : 'i-lucide-chevron-down'"
          class="size-4 text-ui-text-muted"
          :class="{ 'animate-spin': loading }"
          aria-hidden="true"
        />
      </span>
    </div>
    <p
      v-if="message"
      :id="messageId"
      class="m-0 text-ui-caption"
      :class="state === 'error' ? 'text-ui-danger' : 'text-ui-text-muted'"
      :role="state === 'error' ? 'alert' : undefined"
    >
      {{ message }}
    </p>
  </div>
</template>

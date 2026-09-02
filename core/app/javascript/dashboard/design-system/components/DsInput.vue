<script setup>
import { computed, getCurrentInstance } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  id: { type: String, default: '' },
  label: { type: String, default: '' },
  hideLabel: { type: Boolean, default: false },
  description: { type: String, default: '' },
  message: { type: String, default: '' },
  state: {
    type: String,
    default: 'default',
    validator: value => ['default', 'error', 'success'].includes(value),
  },
  type: { type: String, default: 'text' },
  placeholder: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update:modelValue',
  'blur',
  'focus',
  'input',
  'enter',
]);

defineOptions({ inheritAttrs: false });

const { uid } = getCurrentInstance();
const inputId = computed(() => props.id || `ds-input-${uid}`);
const messageId = computed(() => `${inputId.value}-message`);

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

const messageClasses = computed(
  () =>
    ({
      default: 'text-ui-text-muted',
      error: 'text-ui-danger',
      success: 'text-ui-success',
    })[props.state]
);

const updateValue = event => {
  const value =
    props.type === 'number' && event.target.value !== ''
      ? Number(event.target.value)
      : event.target.value;
  emit('update:modelValue', value);
  emit('input', event);
};
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1">
    <label
      v-if="label"
      :for="inputId"
      class="text-ui-label font-medium text-ui-text"
      :class="{ 'sr-only': hideLabel }"
    >
      {{ label }}
    </label>
    <p
      v-if="description && !hideLabel"
      class="m-0 text-ui-caption text-ui-text-muted"
    >
      {{ description }}
    </p>
    <div class="relative">
      <span
        v-if="$slots.prefix"
        class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-ui-text-subtle"
      >
        <slot name="prefix" />
      </span>
      <input
        :id="inputId"
        v-bind="$attrs"
        :value="modelValue"
        :type="type"
        :placeholder="placeholder"
        :disabled="disabled || loading"
        :aria-invalid="state === 'error' || undefined"
        :aria-describedby="message ? messageId : undefined"
        :aria-busy="loading || undefined"
        class="reset-base m-0 h-10 w-full rounded-ui-control border bg-ui-surface py-0 pr-3 text-ui-body text-ui-text outline-none transition-colors duration-ui-fast placeholder:text-ui-text-subtle focus:ring-2 focus:ring-ui-border-focus/20 disabled:cursor-not-allowed disabled:bg-ui-sunken disabled:text-ui-text-disabled max-sm:h-11"
        :class="[
          stateClasses,
          {
            'pl-10': $slots.prefix,
            'pl-3': !$slots.prefix,
            'pr-10': loading,
          },
        ]"
        @input="updateValue"
        @focus="emit('focus', $event)"
        @blur="emit('blur', $event)"
        @keyup.enter="emit('enter', $event)"
      />
      <span
        v-if="loading"
        class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3"
      >
        <Icon
          icon="i-lucide-loader-circle"
          class="size-4 animate-spin text-ui-text-muted"
          aria-hidden="true"
        />
      </span>
    </div>
    <p
      v-if="message"
      :id="messageId"
      class="m-0 text-ui-caption"
      :class="messageClasses"
      :role="state === 'error' ? 'alert' : undefined"
    >
      {{ message }}
    </p>
  </div>
</template>

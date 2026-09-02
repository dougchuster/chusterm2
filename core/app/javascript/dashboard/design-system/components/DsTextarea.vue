<script setup>
import { computed, getCurrentInstance } from 'vue';

const props = defineProps({
  modelValue: { type: String, default: '' },
  id: { type: String, default: '' },
  label: { type: String, default: '' },
  hideLabel: { type: Boolean, default: false },
  placeholder: { type: String, default: '' },
  message: { type: String, default: '' },
  state: {
    type: String,
    default: 'default',
    validator: value => ['default', 'error', 'success'].includes(value),
  },
  rows: { type: Number, default: 3 },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'blur', 'focus', 'input']);

defineOptions({ inheritAttrs: false });

const { uid } = getCurrentInstance();
const textareaId = computed(() => props.id || `ds-textarea-${uid}`);
const messageId = computed(() => `${textareaId.value}-message`);

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
  emit('input', event);
};
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1">
    <label
      v-if="label"
      :for="textareaId"
      class="text-ui-label font-medium text-ui-text"
      :class="{ 'sr-only': hideLabel }"
    >
      {{ label }}
    </label>
    <textarea
      :id="textareaId"
      v-bind="$attrs"
      :value="modelValue"
      :rows="rows"
      :placeholder="placeholder"
      :disabled="disabled || loading"
      :aria-invalid="state === 'error' || undefined"
      :aria-describedby="message ? messageId : undefined"
      :aria-busy="loading || undefined"
      class="reset-base m-0 w-full resize-y rounded-ui-control border bg-ui-surface px-3 py-2 text-ui-body text-ui-text outline-none transition-colors duration-ui-fast placeholder:text-ui-text-subtle focus:ring-2 focus:ring-ui-border-focus/20 disabled:cursor-not-allowed disabled:bg-ui-sunken disabled:text-ui-text-disabled"
      :class="stateClasses"
      @input="updateValue"
      @focus="emit('focus', $event)"
      @blur="emit('blur', $event)"
    />
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

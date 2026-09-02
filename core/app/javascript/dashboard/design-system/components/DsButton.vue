<script setup>
import { computed, useSlots } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  label: { type: [String, Number], default: '' },
  icon: { type: [String, Object, Function], default: '' },
  trailingIcon: { type: Boolean, default: false },
  variant: {
    type: String,
    default: 'secondary',
    validator: value =>
      ['primary', 'secondary', 'ghost', 'danger'].includes(value),
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md'].includes(value),
  },
  type: {
    type: String,
    default: 'button',
    validator: value => ['button', 'submit', 'reset'].includes(value),
  },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const slots = useSlots();

const isIconOnly = computed(() => !props.label && !slots.default);
const isDisabled = computed(() => props.disabled || props.loading);

const variantClasses = computed(
  () =>
    ({
      primary:
        'bg-ui-brand text-ui-text-inverse hover:enabled:bg-ui-brand-hover active:enabled:bg-ui-brand-active',
      secondary:
        'border border-ui-border bg-ui-surface text-ui-text hover:enabled:bg-ui-hover active:enabled:bg-ui-active',
      ghost:
        'bg-transparent text-ui-text-muted hover:enabled:bg-ui-hover hover:enabled:text-ui-text active:enabled:bg-ui-active',
      danger:
        'bg-ui-danger-solid text-white hover:enabled:brightness-95 active:enabled:brightness-90',
    })[props.variant]
);

const sizeClasses = computed(() => {
  if (isIconOnly.value) {
    return props.size === 'sm'
      ? 'h-8 w-8 max-sm:h-11 max-sm:w-11'
      : 'h-10 w-10 max-sm:h-11 max-sm:w-11';
  }

  return props.size === 'sm'
    ? 'h-8 px-3 max-sm:min-h-11'
    : 'h-10 px-4 max-sm:min-h-11';
});
</script>

<template>
  <button
    :type="type"
    :disabled="isDisabled"
    :aria-busy="loading || undefined"
    class="inline-flex shrink-0 items-center justify-center gap-2 rounded-ui-control text-ui-label font-medium transition-colors duration-ui-fast focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus focus-visible:ring-offset-2 focus-visible:ring-offset-ui-canvas disabled:cursor-not-allowed disabled:text-ui-text-disabled disabled:opacity-60"
    :class="[variantClasses, sizeClasses, { 'flex-row-reverse': trailingIcon }]"
  >
    <Spinner v-if="loading" class="size-4 shrink-0" />
    <Icon v-else-if="icon" :icon="icon" class="size-4 shrink-0" />
    <slot>
      <span v-if="label" class="truncate">{{ label }}</span>
    </slot>
  </button>
</template>

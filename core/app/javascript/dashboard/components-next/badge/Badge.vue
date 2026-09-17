<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  label: { type: [String, Number], default: '' },
  variant: {
    type: String,
    default: 'neutral',
    validator: v =>
      ['neutral', 'accent', 'info', 'success', 'warning', 'danger'].includes(v),
  },
  size: {
    type: String,
    default: 'md',
    validator: v => ['sm', 'md'].includes(v),
  },
  icon: { type: [String, Object, Function], default: '' },
  outline: { type: Boolean, default: false },
});

const VARIANT_CLASSES = {
  neutral: {
    soft: 'bg-ds-bg-sunken text-ds-fg-muted border-ds-border-subtle',
    outline: 'bg-transparent text-ds-fg-muted border-ds-border',
  },
  accent: {
    soft: 'bg-ds-accent-soft text-ds-accent border-ds-accent/20',
    outline: 'bg-transparent text-ds-accent border-ds-accent',
  },
  info: {
    soft: 'bg-ds-state-info-soft text-ds-state-info-fg border-ds-state-info/20',
    outline: 'bg-transparent text-ds-state-info border-ds-state-info',
  },
  success: {
    soft: 'bg-ds-state-success-soft text-ds-state-success-fg border-ds-state-success/20',
    outline: 'bg-transparent text-ds-state-success border-ds-state-success',
  },
  warning: {
    soft: 'bg-ds-state-warning-soft text-ds-state-warning-fg border-ds-state-warning/20',
    outline: 'bg-transparent text-ds-state-warning border-ds-state-warning',
  },
  danger: {
    soft: 'bg-ds-state-danger-soft text-ds-state-danger-fg border-ds-state-danger/20',
    outline: 'bg-transparent text-ds-state-danger border-ds-state-danger',
  },
};

const SIZE_CLASSES = {
  sm: 'h-5 px-1.5 text-xs gap-1',
  md: 'h-6 px-2 text-xs gap-1.5',
};

const variantClass = computed(
  () => VARIANT_CLASSES[props.variant][props.outline ? 'outline' : 'soft']
);
const sizeClass = computed(() => SIZE_CLASSES[props.size]);
const iconSize = computed(() => (props.size === 'sm' ? 'size-3' : 'size-3.5'));
</script>

<template>
  <span
    class="inline-flex items-center font-medium rounded-md border whitespace-nowrap"
    :class="[variantClass, sizeClass]"
  >
    <slot name="icon">
      <Icon
        v-if="icon"
        :icon="icon"
        class="flex-shrink-0"
        :class="[iconSize]"
      />
    </slot>
    <slot>
      <span v-if="label">{{ label }}</span>
    </slot>
  </span>
</template>

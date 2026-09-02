<script setup>
import { computed } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  label: { type: [String, Number], default: '' },
  icon: { type: [String, Object, Function], default: '' },
  variant: {
    type: String,
    default: 'neutral',
    validator: value =>
      ['neutral', 'brand', 'success', 'warning', 'danger', 'info'].includes(
        value
      ),
  },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const variantClasses = computed(
  () =>
    ({
      neutral: 'border-ui-border-subtle bg-ui-sunken text-ui-text-muted',
      brand: 'border-ui-brand/20 bg-ui-brand-soft text-ui-brand-foreground',
      success:
        'border-ui-success/20 bg-ui-success-soft text-ui-success-foreground',
      warning:
        'border-ui-warning/20 bg-ui-warning-soft text-ui-warning-foreground',
      danger: 'border-ui-danger/20 bg-ui-danger-soft text-ui-danger-foreground',
      info: 'border-ui-info/20 bg-ui-info-soft text-ui-info-foreground',
    })[props.variant]
);
</script>

<template>
  <span
    class="inline-flex min-h-6 items-center gap-1 rounded-ui-control border px-2 text-ui-caption font-medium"
    :class="[variantClasses, { 'opacity-60': disabled }]"
    :aria-busy="loading || undefined"
  >
    <Icon
      v-if="loading"
      icon="i-lucide-loader-circle"
      class="size-3 animate-spin"
      aria-hidden="true"
    />
    <Icon v-else-if="icon" :icon="icon" class="size-3" aria-hidden="true" />
    <slot>{{ label }}</slot>
  </span>
</template>

<script setup>
import { computed } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

import { useDsTranslate } from '../useDsTranslate';
import DsButton from './DsButton.vue';

const props = defineProps({
  title: { type: String, default: '' },
  message: { type: String, required: true },
  variant: {
    type: String,
    default: 'info',
    validator: value =>
      ['info', 'success', 'warning', 'danger'].includes(value),
  },
  dismissible: { type: Boolean, default: true },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['dismiss']);

const { translate } = useDsTranslate();

const dismissLabel = computed(() =>
  translate('TOAST.DISMISS', 'Dismiss notification')
);

const variantClasses = computed(
  () =>
    ({
      info: 'border-ui-info/30 bg-ui-info-soft text-ui-info',
      success: 'border-ui-success/30 bg-ui-success-soft text-ui-success',
      warning: 'border-ui-warning/30 bg-ui-warning-soft text-ui-warning',
      danger: 'border-ui-danger/30 bg-ui-danger-soft text-ui-danger',
    })[props.variant]
);

const icon = computed(
  () =>
    ({
      info: 'i-lucide-info',
      success: 'i-lucide-circle-check',
      warning: 'i-lucide-triangle-alert',
      danger: 'i-lucide-circle-alert',
    })[props.variant]
);
</script>

<template>
  <div
    :role="variant === 'danger' ? 'alert' : 'status'"
    :aria-live="variant === 'danger' ? 'assertive' : 'polite'"
    :aria-busy="loading || undefined"
    class="flex w-full items-start gap-3 rounded-ui-surface border p-3 shadow-ui-raised"
    :class="[variantClasses, { 'opacity-60': disabled }]"
  >
    <Icon
      :icon="loading ? 'i-lucide-loader-circle' : icon"
      class="mt-1 size-4 shrink-0"
      :class="{ 'animate-spin': loading }"
      aria-hidden="true"
    />
    <div class="min-w-0 flex-1">
      <p v-if="title" class="m-0 text-ui-body font-semibold">{{ title }}</p>
      <p class="m-0 text-ui-body-sm">{{ message }}</p>
    </div>
    <DsButton
      v-if="dismissible"
      icon="i-lucide-x"
      size="sm"
      variant="ghost"
      :aria-label="dismissLabel"
      :disabled="disabled || loading"
      @click="emit('dismiss')"
    />
  </div>
</template>

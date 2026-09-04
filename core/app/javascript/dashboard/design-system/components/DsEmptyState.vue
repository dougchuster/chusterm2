<script setup>
import { computed } from 'vue';
import DsButton from './DsButton.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: [String, Object, Function], default: '' },
  actionLabel: { type: String, default: '' },
  actionIcon: { type: [String, Object, Function], default: '' },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
  secondaryActionLabel: { type: String, default: '' },
  secondaryActionIcon: {
    type: [String, Object, Function],
    default: 'i-lucide-sparkles',
  },
  secondaryDisabled: { type: Boolean, default: false },
  secondaryLoading: { type: Boolean, default: false },
  secondaryVariant: { type: String, default: 'secondary' },
});

const emit = defineEmits(['action', 'secondaryAction']);

const hasActions = computed(() =>
  Boolean(props.actionLabel || props.secondaryActionLabel)
);

const onSecondaryAction = () => {
  emit('secondaryAction');
};
</script>

<template>
  <div
    class="flex min-h-40 flex-col items-center justify-center gap-4 rounded-ui-surface border border-dashed border-ui-border bg-ui-surface/40 p-6 text-center"
  >
    <slot name="icon">
      <div
        v-if="icon"
        class="flex size-10 items-center justify-center rounded-full border border-ui-border-subtle bg-ui-sunken text-ui-text-muted"
      >
        <Icon :icon="icon" class="size-5" />
      </div>
    </slot>

    <div class="flex max-w-xl flex-col items-center gap-1">
      <p class="m-0 text-ui-body text-ui-text-muted">{{ title }}</p>
      <p v-if="description" class="m-0 text-ui-body-sm text-ui-text-subtle">
        {{ description }}
      </p>
      <slot />
    </div>

    <slot name="actions">
      <div
        v-if="hasActions"
        class="flex flex-wrap items-center justify-center gap-2.5 pt-1"
      >
        <slot name="action">
          <DsButton
            v-if="actionLabel"
            variant="primary"
            :label="actionLabel"
            :icon="actionIcon"
            :disabled="disabled"
            :loading="loading"
            @click="emit('action')"
          />
        </slot>

        <slot name="secondaryAction">
          <DsButton
            v-if="secondaryActionLabel"
            :variant="secondaryVariant"
            :label="secondaryActionLabel"
            :icon="secondaryActionIcon"
            :disabled="secondaryDisabled"
            :loading="secondaryLoading"
            @click="onSecondaryAction"
          />
        </slot>
      </div>
    </slot>
  </div>
</template>

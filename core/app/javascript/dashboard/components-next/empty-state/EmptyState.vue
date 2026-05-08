<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  icon: { type: [String, Object, Function], default: '' },
  title: { type: String, default: '' },
  description: { type: String, default: '' },
});
</script>

<template>
  <div
    class="flex flex-col items-center justify-center text-center py-16 px-6 gap-4"
  >
    <div
      v-if="icon || $slots.icon"
      class="flex items-center justify-center w-12 h-12 rounded-full bg-ds-bg-sunken text-ds-fg-muted"
    >
      <slot name="icon">
        <Icon v-if="icon" :icon="icon" class="size-6" />
      </slot>
    </div>
    <div class="flex flex-col gap-1 max-w-md">
      <h3 v-if="title" class="text-base font-semibold text-ds-fg-default">
        {{ title }}
      </h3>
      <p v-if="description" class="text-sm text-ds-fg-muted">
        {{ description }}
      </p>
    </div>
    <div v-if="$slots.actions" class="flex items-center gap-2 mt-2">
      <slot name="actions" />
    </div>
  </div>
</template>

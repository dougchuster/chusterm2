<script>
export default {
  props: {
    title: { type: String, required: true },
    value: { type: [String, Number], default: '' },
    compact: { type: Boolean, default: false },
  },
};
</script>

<template>
  <div class="overflow-auto" :class="compact ? 'px-0 py-0' : 'px-4 py-3'">
    <div class="mb-1.5 flex items-center justify-between">
      <span class="text-sm font-medium text-ds-fg-default">
        {{ title }}
      </span>
      <slot name="button" />
    </div>
    <div v-if="value" class="break-words text-sm text-ds-fg-muted">
      <slot>
        {{ value }}
      </slot>
    </div>
  </div>
</template>

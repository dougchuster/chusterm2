<script setup>
defineProps({
  title: { type: String, default: '' },
  description: { type: String, default: '' },
});
</script>

<template>
  <header
    class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 pb-4 border-b border-ds-border-subtle"
  >
    <div class="flex flex-col gap-1 min-w-0">
      <div class="flex items-center gap-2 min-w-0">
        <slot name="title">
          <h1
            v-if="title"
            class="text-xl font-semibold text-ds-fg-default truncate"
          >
            {{ title }}
          </h1>
        </slot>
        <slot name="badge" />
      </div>
      <slot name="description">
        <p v-if="description" class="text-sm text-ds-fg-muted">
          {{ description }}
        </p>
      </slot>
    </div>
    <div v-if="$slots.actions" class="flex items-center gap-2 flex-shrink-0">
      <slot name="actions" />
    </div>
  </header>
</template>

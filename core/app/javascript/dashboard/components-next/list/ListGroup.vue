<script setup>
defineProps({
  bordered: { type: Boolean, default: true },
  divided: { type: Boolean, default: true },
});
</script>

<template>
  <div
    class="rounded-lg overflow-hidden bg-ds-bg-surface"
    :class="{
      'border border-ds-border-subtle': bordered,
      'divide-y divide-ds-border-subtle': divided,
    }"
  >
    <slot />
  </div>
</template>

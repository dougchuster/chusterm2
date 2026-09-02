<script setup>
import { computed } from 'vue';

const props = defineProps({
  shape: {
    type: String,
    default: 'line',
    validator: value => ['line', 'block', 'circle'].includes(value),
  },
});

const shapeClasses = computed(
  () =>
    ({
      line: 'h-4 rounded-ui-control',
      block: 'min-h-12 rounded-ui-surface',
      circle: 'aspect-square rounded-full',
    })[props.shape]
);
</script>

<template>
  <span
    aria-hidden="true"
    class="block animate-pulse bg-ui-sunken"
    :class="shapeClasses"
  />
</template>

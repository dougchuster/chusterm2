<script>
import FeaturePlaceholder from './FeaturePlaceholder.vue';
export default {
  components: { FeaturePlaceholder },
  props: {
    message: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="flex h-full flex-col items-center justify-center">
    <div
      class="m-4 grid size-24 place-items-center rounded-3xl bg-ds-accent-soft text-ds-accent"
      aria-hidden="true"
    >
      <span class="i-lucide-messages-square size-11" />
    </div>
    <span class="text-center text-sm font-medium text-ds-fg-default">
      {{ message }}
      <br />
    </span>
    <!-- Cmd bar, keyboard shortcuts placeholder -->
    <FeaturePlaceholder />
  </div>
</template>

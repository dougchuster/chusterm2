<script setup>
import Icon from '../../components-next/icon/Icon.vue';
defineProps({
  content: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <div
    class="flex flex-col gap-2 rounded-lg border border-ds-border-subtle bg-ds-bg-sunken p-3 transition-colors duration-200 hover:bg-ds-bg-hover"
  >
    <div class="flex items-start gap-2">
      <Icon
        icon="i-lucide-sparkles"
        class="mt-0.5 size-4 shrink-0 text-ds-accent"
      />
      <div class="text-sm text-ds-fg-default">
        {{ content }}
      </div>
    </div>
  </div>
</template>

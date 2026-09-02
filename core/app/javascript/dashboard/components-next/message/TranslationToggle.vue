<script setup>
import { defineProps, defineEmits } from 'vue';

defineProps({
  showingOriginal: Boolean,
});

defineEmits(['toggle']);
</script>

<template>
  <button
    type="button"
    class="rounded-md text-xs font-medium text-ds-fg-muted outline-none transition-colors hover:text-ds-fg-default hover:underline focus-visible:ring-2 focus-visible:ring-ds-border-focus"
    @click="$emit('toggle')"
  >
    {{
      showingOriginal
        ? $t('CONVERSATION.VIEW_TRANSLATED')
        : $t('CONVERSATION.VIEW_ORIGINAL')
    }}
  </button>
</template>

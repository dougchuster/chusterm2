<script setup>
defineProps({
  message: {
    type: Object,
    required: true,
  },
});
</script>

<template>
  <div
    class="max-w-80 rounded-xl bg-ds-bg-sunken p-3 text-ds-fg-default ring-1 ring-inset ring-ds-border-subtle"
  >
    <span v-dompurify-html="message.content" class="prose prose-bubble" />
  </div>
</template>

<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
defineProps({
  message: {
    type: Object,
    required: true,
  },
});
</script>

<template>
  <div
    class="max-w-80 divide-y divide-ds-border-subtle rounded-xl bg-ds-bg-sunken text-ds-fg-default ring-1 ring-inset ring-ds-border-subtle"
  >
    <div class="p-3">
      <span
        v-dompurify-html="message.content"
        class="prose prose-bubble font-medium text-sm"
      />
    </div>
    <div class="p-3 flex items-center justify-center">
      <Button
        type="button"
        label="See options"
        link
        class="hover:!no-underline"
      />
    </div>
  </div>
</template>

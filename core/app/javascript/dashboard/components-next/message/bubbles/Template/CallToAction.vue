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
  <div class="flex max-w-80 flex-col gap-2.5 text-ds-fg-default">
    <div
      class="rounded-xl bg-ds-bg-sunken p-3 ring-1 ring-inset ring-ds-border-subtle"
    >
      <span
        v-dompurify-html="message.content"
        class="prose prose-bubble font-medium text-sm"
      />
    </div>
    <div class="flex gap-2">
      <Button
        type="button"
        label="Call us"
        color="primary"
        variant="faded"
        class="w-full"
      />
      <Button
        type="button"
        label="Visit our website"
        color="primary"
        variant="faded"
        class="w-full"
      />
    </div>
  </div>
</template>

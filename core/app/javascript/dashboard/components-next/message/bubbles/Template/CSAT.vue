<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  message: {
    type: Object,
    required: true,
  },
  buttonText: {
    type: String,
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
        class="text-sm font-medium prose prose-bubble"
      />
    </div>
    <div class="flex gap-2">
      <Button
        type="button"
        :label="buttonText"
        color="primary"
        variant="faded"
        class="w-full"
      />
    </div>
  </div>
</template>

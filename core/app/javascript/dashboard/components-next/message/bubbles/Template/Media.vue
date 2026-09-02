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
    class="flex max-w-80 flex-col gap-2.5 rounded-xl bg-ds-bg-sunken p-3 text-ds-fg-default ring-1 ring-inset ring-ds-border-subtle"
  >
    <img
      alt=""
      :src="message.image_url"
      class="max-h-44 w-full rounded-lg object-cover"
    />
    <span
      v-dompurify-html="message.content"
      class="prose prose-bubble font-medium text-sm"
    />
  </div>
</template>

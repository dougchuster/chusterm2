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
    <div class="px-3 py-2.5">
      <img
        alt=""
        :src="message.image_url"
        class="max-h-44 w-full rounded-lg object-cover"
      />
      <div class="pt-2.5 flex flex-col gap-2">
        <h6 class="font-semibold">{{ message.title }}</h6>
        <span
          v-dompurify-html="message.content"
          class="prose prose-bubble text-sm"
        />
      </div>
    </div>
    <div class="p-3 flex items-center justify-center">
      <Button
        type="button"
        label="Call us to order"
        link
        class="hover:!no-underline"
      />
    </div>
    <div class="p-3 flex items-center justify-center">
      <Button
        type="button"
        label="Visit our store"
        link
        class="hover:!no-underline"
      />
    </div>
  </div>
</template>

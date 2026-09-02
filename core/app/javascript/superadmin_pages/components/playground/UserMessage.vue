<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <div class="w-full mb-4 flex items-center justify-end">
    <div
      v-dompurify-html="message"
      class="inline-block rounded-md bg-n-brand px-4 py-3 text-sm text-white"
    />
  </div>
</template>

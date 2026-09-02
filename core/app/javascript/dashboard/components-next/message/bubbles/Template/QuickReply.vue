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
        label="No, that will be all"
        link
        class="hover:!no-underline"
      >
        <template #icon>
          <svg
            width="15"
            height="15"
            viewBox="0 0 15 15"
            fill="none"
            class="stroke-ds-accent"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M.667 6.654 5.315.667v3.326c7.968 0 8.878 6.46 8.656 10.007l-.005-.027c-.334-1.79-.474-4.658-8.65-4.658v3.327z"
              stroke-width="1.333"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </template>
      </Button>
    </div>
    <div class="p-3 flex items-center justify-center">
      <Button
        type="button"
        label="I want to talk to an agents"
        link
        class="hover:!no-underline"
      >
        <template #icon>
          <svg
            width="15"
            height="15"
            viewBox="0 0 15 15"
            fill="none"
            class="stroke-ds-accent"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M.667 6.654 5.315.667v3.326c7.968 0 8.878 6.46 8.656 10.007l-.005-.027c-.334-1.79-.474-4.658-8.65-4.658v3.327z"
              stroke-width="1.333"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </template>
      </Button>
    </div>
  </div>
</template>

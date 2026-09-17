<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
  noRecordsFound: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: '',
  },
  noRecordsMessage: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="flex h-full w-full flex-col gap-5">
    <slot name="header" />
    <main class="flex min-h-0 flex-1 flex-col gap-4">
      <slot name="preBody" />
      <section
        class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl bg-ui-surface shadow-ui-raised"
      >
        <slot v-if="isLoading" name="loading">
          <div
            class="flex min-h-72 items-center justify-center p-8 text-center"
          >
            <woot-loading-state :message="loadingMessage" />
          </div>
        </slot>
        <div
          v-else-if="noRecordsFound"
          class="flex min-h-72 flex-col items-center justify-center gap-3 p-8 text-center"
        >
          <div
            class="flex size-11 items-center justify-center rounded-xl bg-ui-sunken"
          >
            <Icon icon="i-lucide-inbox" class="size-5 text-ui-text-muted" />
          </div>
          <p class="mb-0 max-w-md text-base text-ui-text-muted">
            {{ noRecordsMessage }}
          </p>
        </div>
        <div v-else class="settings-layout__body min-h-0 flex-1">
          <slot name="body" />
        </div>
      </section>
      <slot />
    </main>
  </div>
</template>

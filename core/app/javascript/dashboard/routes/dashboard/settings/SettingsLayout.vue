<script setup>
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
        class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-lg border border-n-weak bg-n-solid-2"
      >
        <slot v-if="isLoading" name="loading">
          <div
            class="flex min-h-72 items-center justify-center p-8 text-center"
          >
            <woot-loading-state :message="loadingMessage" />
          </div>
        </slot>
        <p
          v-else-if="noRecordsFound"
          class="flex min-h-72 items-center justify-center p-8 text-center text-base text-n-slate-11"
        >
          {{ noRecordsMessage }}
        </p>
        <div v-else class="settings-layout__body min-h-0 flex-1">
          <slot name="body" />
        </div>
      </section>
      <slot />
    </main>
  </div>
</template>

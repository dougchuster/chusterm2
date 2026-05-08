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
  <div class="settings-layout flex h-full w-full flex-col gap-6 font-inter">
    <slot name="header" />
    <main class="settings-layout__content flex min-h-0 flex-1 flex-col gap-4">
      <slot name="preBody" />
      <section class="settings-layout__panel flex min-h-0 flex-1 flex-col">
        <slot v-if="isLoading" name="loading">
          <div class="settings-layout__state">
            <woot-loading-state :message="loadingMessage" />
          </div>
        </slot>
        <p
          v-else-if="noRecordsFound"
          class="settings-layout__state text-base text-n-slate-11"
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

<style scoped>
.settings-layout__content {
  position: relative;
}

.settings-layout__panel {
  position: relative;
  overflow: hidden;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 12px;
  background: rgb(var(--bg-card));
  box-shadow: 0 12px 34px rgba(var(--shell-shadow));
}

.settings-layout__panel::before {
  display: none;
}

.settings-layout__state {
  display: flex;
  min-height: 18rem;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  text-align: center;
}
</style>

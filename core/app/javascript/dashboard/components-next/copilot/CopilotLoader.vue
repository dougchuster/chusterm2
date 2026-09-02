<script>
// Copilot Loader Component
</script>

<template>
  <div
    class="flex justify-start"
    role="status"
    aria-live="polite"
    aria-atomic="true"
  >
    <div class="flex items-center space-x-2">
      <span class="font-medium text-ds-accent">
        {{ $t('CAPTAIN.COPILOT.LOADER') }}
      </span>
      <div class="flex space-x-1">
        <div
          class="size-2 animate-bounce rounded-full bg-ds-accent [animation-delay:-0.3s]"
        />
        <div
          class="size-2 animate-bounce rounded-full bg-ds-accent [animation-delay:-0.15s]"
        />
        <div class="size-2 animate-bounce rounded-full bg-ds-accent" />
      </div>
    </div>
  </div>
</template>

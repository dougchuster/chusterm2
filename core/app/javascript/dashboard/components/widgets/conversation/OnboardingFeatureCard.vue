<script setup>
defineProps({
  imageSrc: {
    type: String,
    default: '',
  },
  imageAlt: {
    type: String,
    default: '',
  },
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  to: {
    type: String,
    default: '',
  },
  linkText: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="flex h-full w-full flex-col rounded-2xl border border-ds-border-subtle bg-ds-bg-elevated p-4 shadow-[var(--ds-shadow-sm)]"
  >
    <div class="flex-1 flex items-center justify-center">
      <img :src="imageSrc" :alt="imageAlt" class="h-36 w-auto mx-auto" />
    </div>
    <div class="mt-auto">
      <p
        class="font-manrope text-base font-semibold tracking-[0.3px] text-ds-fg-default"
      >
        {{ title }}
      </p>
      <p class="text-sm text-ds-fg-muted">
        {{ description }}
      </p>
      <router-link
        v-if="to"
        :to="{ name: to }"
        class="inline-flex items-center gap-2 rounded text-sm font-medium text-ds-accent no-underline hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      >
        <span>{{ linkText }}</span>
        <span class="i-lucide-arrow-right size-4" aria-hidden="true" />
      </router-link>
    </div>
  </div>
</template>

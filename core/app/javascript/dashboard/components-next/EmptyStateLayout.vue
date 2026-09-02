<script setup>
import Policy from 'dashboard/components/policy.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  subtitle: {
    type: String,
    required: true,
  },
  actionPerms: {
    type: Array,
    default: () => [],
  },
  showBackdrop: {
    type: Boolean,
    default: true,
  },
});
</script>

<template>
  <section class="flex min-h-72 w-full items-center justify-center px-4 py-10">
    <div
      class="flex w-full max-w-2xl flex-col items-center rounded-lg border border-dashed border-n-weak bg-n-solid-2 px-6 py-10 text-center sm:px-10"
    >
      <div
        class="mb-4 grid size-10 place-items-center rounded-md bg-n-alpha-2 text-n-slate-11"
        :class="{ 'border border-n-weak': !showBackdrop }"
        aria-hidden="true"
      >
        <span class="i-lucide-inbox size-5" />
      </div>
      <h2 class="text-xl font-medium text-n-slate-12">
        {{ title }}
      </h2>
      <p v-if="subtitle" class="mt-2 max-w-xl text-sm text-n-slate-11">
        {{ subtitle }}
      </p>
      <Policy :permissions="actionPerms">
        <div class="mt-6">
          <slot name="actions" />
        </div>
      </Policy>
    </div>
  </section>
</template>

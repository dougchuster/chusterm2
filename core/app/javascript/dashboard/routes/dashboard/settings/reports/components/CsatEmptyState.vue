<script setup>
defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: 'i-lucide-message-square-off',
  },
});
</script>

<template>
  <div class="px-4 py-12 text-center sm:px-6">
    <div
      class="mx-auto max-w-xl rounded-lg border border-dashed border-ui-border-subtle bg-ui-sunken/50 px-5 py-9"
    >
      <div
        class="mx-auto mb-4 flex size-12 items-center justify-center rounded-full bg-n-alpha-2"
      >
        <i :class="icon" class="size-8 text-n-slate-10" />
      </div>
      <h3 class="mb-0 text-lg font-semibold text-n-slate-12">
        {{ title }}
      </h3>
      <p
        v-if="description"
        class="mx-auto mt-2 max-w-md text-sm leading-6 text-n-slate-11"
      >
        {{ description }}
      </p>
    </div>
  </div>
</template>

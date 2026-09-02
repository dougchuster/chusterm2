<script setup>
import Icon from 'next/icon/Icon.vue';

defineProps({
  label: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="pointer-events-none flex min-h-8 select-none items-center gap-2.5 rounded-lg px-3 py-1.5 text-ds-shell-muted"
  >
    <Icon v-if="icon" :icon="icon" class="size-[18px]" />
    <span
      class="flex-grow text-[0.7rem] font-semibold uppercase leading-4 tracking-wide"
    >
      {{ label }}
    </span>
  </div>
</template>

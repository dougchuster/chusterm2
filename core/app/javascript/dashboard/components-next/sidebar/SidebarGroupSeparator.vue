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
    class="flex items-center gap-2.5 px-3 py-1.5 rounded-lg min-h-8 text-n-slate-9 select-none pointer-events-none"
  >
    <Icon v-if="icon" :icon="icon" class="size-[18px]" />
    <span
      class="text-[0.7rem] font-semibold uppercase leading-4 flex-grow opacity-60"
    >
      {{ label }}
    </span>
  </div>
</template>

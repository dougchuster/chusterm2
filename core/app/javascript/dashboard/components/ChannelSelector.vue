<script setup>
import Icon from 'next/icon/Icon.vue';

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
    required: true,
  },
  isComingSoon: {
    type: Boolean,
    default: false,
  },
  badge: {
    type: String,
    default: '',
  },
  badgeVariant: {
    type: String,
    default: 'warning',
    validator: value => ['warning', 'success', 'neutral'].includes(value),
  },
});
</script>

<template>
  <button
    class="relative bg-n-solid-1 gap-6 cursor-pointer rounded-2xl flex flex-col justify-start transition-all duration-200 ease-in -m-px py-6 px-5 items-start border border-solid border-ui-border-subtle"
    :class="{
      'hover:enabled:border-n-blue-9 hover:enabled:shadow-md disabled:opacity-60 disabled:cursor-not-allowed':
        !isComingSoon,
      'cursor-not-allowed disabled:opacity-80': isComingSoon,
    }"
  >
    <span
      v-if="badge"
      class="absolute top-3 right-3 px-2 py-0.5 rounded-md text-label-small font-medium"
      :class="{
        'bg-n-amber-3 text-n-amber-11': badgeVariant === 'warning',
        'bg-n-teal-3 text-n-teal-11': badgeVariant === 'success',
        'bg-n-alpha-2 text-n-slate-11': badgeVariant === 'neutral',
      }"
    >
      {{ badge }}
    </span>
    <div
      class="flex size-10 items-center justify-center rounded-full bg-n-alpha-2"
    >
      <Icon :icon="icon" class="text-n-slate-10 size-6" />
    </div>

    <div class="flex flex-col items-start gap-1.5">
      <h3 class="text-n-slate-12 text-sm text-start font-medium capitalize">
        {{ title }}
      </h3>
      <p class="text-n-slate-11 text-start text-sm">
        {{ description }}
      </p>
    </div>

    <div
      v-if="isComingSoon"
      class="absolute inset-0 flex items-center justify-center backdrop-blur-[2px] rounded-2xl bg-gradient-to-br from-n-surface-1/90 via-n-surface-1/70 to-n-surface-1/95 cursor-not-allowed"
    >
      <span class="text-n-slate-12 font-medium text-sm">
        {{ $t('CHANNEL_SELECTOR.COMING_SOON') }} 🚀
      </span>
    </div>
  </button>
</template>

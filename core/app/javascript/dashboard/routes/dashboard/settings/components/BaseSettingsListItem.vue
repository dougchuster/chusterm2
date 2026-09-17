<script setup>
defineProps({
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="group relative flex w-full flex-col justify-between gap-4 rounded-xl bg-ui-surface p-4 shadow-ui-raised transition-shadow duration-ui-base hover:shadow-ui-overlay sm:flex-row sm:p-5"
  >
    <slot name="leftSection">
      <div
        class="flex min-w-0 w-full max-w-[480px] flex-col items-start gap-2.5"
      >
        <div
          class="flex w-full items-center justify-between gap-3 whitespace-nowrap sm:justify-normal"
        >
          <h3
            class="w-fit justify-between truncate font-manrope font-semibold tracking-tight text-ui-text sm:justify-normal"
          >
            <slot name="title">
              {{ title }}
            </slot>
          </h3>
          <slot name="label" />
        </div>
        <p
          class="line-clamp-2 w-full max-w-[25rem] text-ui-body-sm text-ui-text-muted"
        >
          <slot name="description">
            {{ description }}
          </slot>
        </p>
      </div>
    </slot>

    <!-- right side section -->
    <slot name="rightSection" />

    <!-- actions section -->
    <div
      v-if="$slots.actions"
      class="absolute flex-col items-center hidden gap-1 border-none ltr:-right-3 rtl:-left-3 top-3 group-hover:flex"
    >
      <slot name="actions" />
    </div>
  </div>
</template>

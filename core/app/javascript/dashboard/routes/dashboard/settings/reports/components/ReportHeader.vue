<script setup>
import BackButton from 'dashboard/components/widgets/BackButton.vue';

defineProps({
  headerTitle: {
    required: true,
    type: String,
  },
  headerDescription: {
    type: String,
    default: '',
  },
  hasBackButton: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <section class="border-b border-n-weak pb-5 pt-5">
    <div>
      <BackButton v-if="hasBackButton" compact class="mb-3" />

      <div
        class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between"
      >
        <div class="min-w-0 max-w-3xl">
          <div class="flex items-center gap-3">
            <h1 class="mb-0 text-xl font-semibold text-n-slate-12 sm:text-2xl">
              {{ headerTitle }}
            </h1>
          </div>
          <p
            v-if="headerDescription"
            class="mb-0 mt-2 max-w-3xl text-sm leading-6 text-n-slate-11"
          >
            {{ headerDescription }}
          </p>
        </div>

        <div v-if="$slots.default" class="flex-shrink-0">
          <slot />
        </div>
      </div>
    </div>
  </section>
</template>

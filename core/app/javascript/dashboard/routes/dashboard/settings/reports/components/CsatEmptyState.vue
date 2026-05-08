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
  <div class="csat-empty-state px-6 py-14 text-center">
    <div class="csat-empty-state__panel mx-auto max-w-xl">
      <div class="csat-empty-state__icon-wrap mx-auto mb-5">
        <i :class="icon" class="size-8 text-n-slate-10" />
      </div>
      <span class="csat-empty-state__eyebrow">Feedback signal</span>
      <h3 class="csat-empty-state__title mb-0 mt-3 text-n-slate-12">
        {{ title }}
      </h3>
      <p v-if="description" class="csat-empty-state__description mx-auto mt-3 max-w-md">
        {{ description }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.csat-empty-state__panel {
  border: 1px dashed rgba(var(--shell-border-strong));
  border-radius: 1.5rem;
  padding: 2.25rem 1.5rem;
  background: linear-gradient(
    180deg,
    rgb(var(--slate-2) / 0.52) 0%,
    rgb(var(--slate-1) / 0.36) 100%
  );
}

.csat-empty-state__icon-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 4.25rem;
  height: 4.25rem;
  border-radius: 9999px;
  border: 1px solid rgba(var(--shell-border));
  background: rgb(var(--slate-2) / 0.72);
}

.csat-empty-state__eyebrow {
  display: inline-flex;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgb(var(--slate-10));
}

.csat-empty-state__title {
  font-family: Manrope, sans-serif;
  font-size: 1.3rem;
  font-weight: 700;
  letter-spacing: -0.03em;
}

.csat-empty-state__description {
  font-size: 0.94rem;
  line-height: 1.8;
  color: rgb(var(--slate-10));
}
</style>

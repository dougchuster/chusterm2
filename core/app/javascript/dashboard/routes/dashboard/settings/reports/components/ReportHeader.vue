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
  <section class="report-header pb-6 pt-3">
    <div class="report-header__panel">
      <BackButton v-if="hasBackButton" compact class="report-header__back" />

      <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <div class="min-w-0 max-w-3xl">
          <span class="report-header__eyebrow">Performance narrative</span>
          <div class="mt-3 flex items-center gap-3">
            <div class="report-header__orb" />
            <h1 class="report-header__title mb-0 text-n-slate-12">
              {{ headerTitle }}
            </h1>
          </div>
          <p
            v-if="headerDescription"
            class="report-header__description mb-0 mt-3 line-clamp-5 sm:line-clamp-none"
          >
            {{ headerDescription }}
          </p>
        </div>

        <div v-if="$slots.default" class="report-header__actions flex-shrink-0">
          <slot />
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.report-header__panel {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--shell-border-strong));
  border-radius: 1.75rem;
  padding: 1.35rem 1.5rem;
  background: linear-gradient(
    180deg,
    rgba(var(--shell-panel-strong)) 0%,
    rgb(var(--slate-1) / 0.98) 100%
  );
  box-shadow: 0 24px 54px rgb(var(--slate-1) / 0.26);
}

.report-header__panel::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  background:
    radial-gradient(circle at top right, rgba(var(--shell-glow-primary)) 0%, transparent 28%),
    linear-gradient(180deg, rgb(255 255 255 / 0.04), transparent 24%);
}

.report-header__back {
  position: relative;
  z-index: 1;
  margin-bottom: 0.75rem;
}

.report-header__eyebrow {
  position: relative;
  z-index: 1;
  display: inline-flex;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgb(var(--slate-10));
}

.report-header__orb {
  position: relative;
  z-index: 1;
  width: 0.85rem;
  height: 0.85rem;
  border-radius: 9999px;
  background: rgba(var(--shell-glow-primary));
  box-shadow: 0 0 0 0.35rem rgb(var(--slate-2) / 0.72);
}

.report-header__title {
  position: relative;
  z-index: 1;
  font-family: Manrope, sans-serif;
  font-size: clamp(1.5rem, 2.5vw, 2.35rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.02;
}

.report-header__description {
  position: relative;
  z-index: 1;
  font-size: 0.98rem;
  line-height: 1.8;
  color: rgb(var(--slate-11));
}

.report-header__actions {
  position: relative;
  z-index: 1;
}
</style>

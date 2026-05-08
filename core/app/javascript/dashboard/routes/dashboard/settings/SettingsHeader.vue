<script>
import BackButton from '../../../components/widgets/BackButton.vue';

export default {
  components: {
    BackButton,
  },
  props: {
    headerTitle: {
      default: '',
      type: String,
    },
    icon: {
      default: '',
      type: String,
    },
    showBackButton: { type: Boolean, default: false },
    backUrl: {
      type: [String, Object],
      default: '',
    },
    backButtonLabel: {
      type: String,
      default: '',
    },
  },
  computed: {
    headerBadgeLabel() {
      return this.showBackButton
        ? 'Edi\u00e7\u00e3o'
        : 'Configura\u00e7\u00f5es';
    },
    headerStatusLabel() {
      return 'Painel unificado';
    },
    resolvedIcon() {
      const iconMap = {
        'flash-settings': 'i-lucide-toy-brick',
        'people-team': 'i-lucide-users',
        'mail-inbox-all': 'i-lucide-inbox',
        'credit-card-person': 'i-lucide-credit-card',
      };

      return iconMap[this.icon] || this.icon || 'i-lucide-settings-2';
    },
  },
};
</script>

<template>
  <div class="settings-header mb-5 flex items-center justify-between gap-4">
    <div
      class="settings-header__panel flex w-full items-center justify-between gap-6"
    >
      <div class="min-w-0 flex-1">
        <div class="settings-header__meta">
          <BackButton
            v-if="showBackButton"
            :button-label="backButtonLabel"
            :back-url="backUrl"
            compact
            class="settings-header__back"
          />
          <span v-if="showBackButton" class="settings-header__meta-divider" />
          <span class="settings-header__eyebrow">
            {{ headerBadgeLabel }}
          </span>
        </div>

        <div class="mt-2 flex min-w-0 items-center gap-3">
          <div class="settings-header__icon-chip">
            <i :class="resolvedIcon" class="text-base text-n-slate-12" />
          </div>
          <h1 class="settings-header__title mb-0 text-n-slate-12">
            <slot />
            <span>{{ headerTitle }}</span>
          </h1>
        </div>
      </div>

      <div class="settings-header__status hidden lg:flex">
        {{ headerStatusLabel }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.settings-header__panel {
  padding: 0.95rem 1rem;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 12px;
  background: rgb(var(--bg-card));
  box-shadow: 0 12px 34px rgba(var(--shell-shadow));
}

.settings-header__meta {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 0.55rem;
}

.settings-header__meta-divider {
  width: 1px;
  height: 0.9rem;
  flex-shrink: 0;
  background: rgb(var(--border-weak));
}

.settings-header__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.3rem 0.65rem;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 9999px;
  font-family: Manrope, sans-serif;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0;
  text-transform: uppercase;
  color: rgb(var(--slate-11));
  background: rgb(var(--surface-2));
}

.settings-header__title {
  min-width: 0;
  font-family: Manrope, sans-serif;
  font-size: clamp(1.35rem, 1.8vw, 1.85rem);
  font-weight: 700;
  line-height: 1.1;
  overflow-wrap: anywhere;
}

.settings-header__icon-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem;
  height: 2.5rem;
  flex-shrink: 0;
  border-radius: 10px;
  background: rgb(var(--surface-2));
  border: 1px solid rgb(var(--border-weak));
}

.settings-header__status {
  align-items: center;
  padding: 0.55rem 0.8rem;
  border-radius: 9999px;
  border: 1px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2));
  color: rgb(var(--slate-11));
  font-size: 0.82rem;
  white-space: nowrap;
}

.settings-header__back :deep(button),
.settings-header__back {
  white-space: nowrap;
}

@media (max-width: 640px) {
  .settings-header {
    margin-bottom: 0.75rem;
  }

  .settings-header__panel {
    flex-direction: column;
    align-items: stretch;
    gap: 1rem;
    padding: 0.9rem;
  }

  .settings-header__icon-chip {
    width: 2.25rem;
    height: 2.25rem;
  }
}
</style>

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
  <div class="mb-4 flex items-center justify-between gap-4">
    <div
      class="flex w-full items-center justify-between gap-4 border-b border-ui-border-subtle/60 pb-4"
    >
      <div class="flex min-w-0 flex-1 items-center gap-3">
        <BackButton
          v-if="showBackButton"
          :button-label="backButtonLabel"
          :back-url="backUrl"
          compact
          class="shrink-0"
        />
        <div
          class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-n-alpha-2"
        >
          <i :class="resolvedIcon" class="text-base text-n-slate-11" />
        </div>
        <h1 class="mb-0 min-w-0 text-xl font-semibold text-n-slate-12">
          <slot />
          <span>{{ headerTitle }}</span>
        </h1>
      </div>
    </div>
  </div>
</template>

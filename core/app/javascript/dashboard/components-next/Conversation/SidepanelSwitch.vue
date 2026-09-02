<script setup>
import { useUISettings } from 'dashboard/composables/useUISettings';
import { computed } from 'vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

const { updateUISettings } = useUISettings();

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showCopilotTab = computed(() =>
  isFeatureEnabledonAccount.value(currentAccountId.value, FEATURE_FLAGS.CAPTAIN)
);

const { uiSettings } = useUISettings();
const isContactSidebarOpen = computed(
  () => uiSettings.value.is_contact_sidebar_open
);
const isCopilotPanelOpen = computed(
  () => uiSettings.value.is_copilot_panel_open
);

const toggleConversationSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: !isContactSidebarOpen.value,
    is_copilot_panel_open: false,
  });
};

const handleConversationSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: true,
    is_copilot_panel_open: false,
  });
};

const handleCopilotSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: true,
  });
};

const keyboardEvents = {
  'Alt+KeyO': {
    action: toggleConversationSidebarToggle,
  },
};
useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div
    class="absolute top-36 flex flex-col items-center justify-center gap-1.5 rounded-full border border-ds-border-subtle bg-ds-bg-elevated/90 p-1.5 shadow-[var(--ds-shadow-sm)] backdrop-blur-lg ltr:right-2 rtl:left-2 xl:top-24"
  >
    <button
      v-tooltip.top="$t('CONVERSATION.SIDEBAR.CONTACT')"
      type="button"
      class="inline-flex size-9 items-center justify-center rounded-full text-ds-fg-muted outline-none transition-colors duration-150 hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus active:scale-95"
      :class="{
        'bg-ds-accent-soft text-ds-accent shadow-[var(--ds-shadow-xs)]':
          isContactSidebarOpen,
      }"
      :aria-label="$t('CONVERSATION.SIDEBAR.CONTACT')"
      :aria-pressed="isContactSidebarOpen"
      @click="handleConversationSidebarToggle"
    >
      <span class="i-lucide-contact-round size-4" aria-hidden="true" />
    </button>
    <button
      v-if="showCopilotTab"
      v-tooltip.bottom="$t('CONVERSATION.SIDEBAR.COPILOT')"
      type="button"
      class="inline-flex size-9 items-center justify-center rounded-full text-ds-fg-muted outline-none transition-colors duration-150 hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus active:scale-95"
      :class="{
        'bg-ds-accent-soft text-ds-accent shadow-[var(--ds-shadow-xs)]':
          isCopilotPanelOpen,
      }"
      :aria-label="$t('CONVERSATION.SIDEBAR.COPILOT')"
      :aria-pressed="isCopilotPanelOpen"
      @click="handleCopilotSidebarToggle"
    >
      <span class="i-lucide-sparkles size-4" aria-hidden="true" />
    </button>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useEventListener } from '@vueuse/core';

const route = useRoute();

const { uiSettings, updateUISettings } = useUISettings();

// 4.5/F11: quando a barra de ações em massa do board está visível no rodapé,
// o launcher sobe para não sobrepor os botões da barra.
const bulkBarVisible = ref(false);
useEventListener(window, 'crm:bulk-bar:visible', event => {
  bulkBarVisible.value = Boolean(event.detail);
});

const isConversationRoute = computed(() => {
  const CONVERSATION_ROUTES = [
    'inbox_conversation',
    'conversation_through_inbox',
    'conversations_through_label',
    'team_conversations_through_label',
    'conversations_through_folders',
    'conversation_through_mentions',
    'conversation_through_unattended',
    'conversation_through_participating',
    'inbox_view_conversation',
  ];
  return CONVERSATION_ROUTES.includes(route.name);
});

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showCopilotLauncher = computed(() => {
  const isCaptainEnabled = isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CAPTAIN
  );
  return (
    isCaptainEnabled &&
    !uiSettings.value.is_copilot_panel_open &&
    !isConversationRoute.value
  );
});
const toggleSidebar = () => {
  updateUISettings({
    is_copilot_panel_open: !uiSettings.value.is_copilot_panel_open,
    is_contact_sidebar_open: false,
  });
};
</script>

<template>
  <div
    v-if="showCopilotLauncher"
    class="fixed ltr:right-4 rtl:left-4 z-50 transition-[bottom] duration-200"
    :class="bulkBarVisible ? 'bottom-24' : 'bottom-4'"
  >
    <ButtonGroup
      class="rounded-full bg-ds-bg-elevated/90 p-1 shadow-lg ring-1 ring-ds-border-subtle backdrop-blur-lg transition-shadow hover:shadow-xl"
    >
      <Button
        :aria-label="$t('CAPTAIN.COPILOT.TITLE')"
        icon="i-woot-captain"
        no-animation
        class="!rounded-full !bg-ds-bg-surface !text-ds-accent text-xl transition-all duration-200 ease-out hover:!bg-ds-bg-hover"
        lg
        @click="toggleSidebar"
      />
    </ButtonGroup>
  </div>
  <template v-else />
</template>

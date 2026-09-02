<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';

defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggle']);

const route = useRoute();

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

const toggleSidebar = () => {
  emit('toggle');
};
</script>

<template>
  <div
    v-if="!isConversationRoute"
    id="mobile-sidebar-launcher"
    class="fixed bottom-4 ltr:left-4 rtl:right-4 z-40 transition-transform duration-200 ease-out block md:hidden"
    :class="[
      {
        'ltr:translate-x-48 rtl:-translate-x-48': isMobileSidebarOpen,
      },
    ]"
  >
    <ButtonGroup
      class="rounded-full bg-ds-shell-panel/90 p-1 shadow-[var(--ds-shadow-md)] ring-1 ring-inset ring-ds-shell-border backdrop-blur-lg"
    >
      <Button
        :aria-label="$t('HELP_CENTER.EDIT_HEADER.OPEN_SIDEBAR')"
        icon="i-lucide-menu"
        no-animation
        class="!rounded-full !bg-ds-shell-panel-strong !text-ds-shell-fg text-xl transition-colors duration-150 hover:!bg-ds-shell-hover focus-visible:!ring-2 focus-visible:!ring-ds-shell-focus"
        lg
        @click.stop="toggleSidebar"
      />
    </ButtonGroup>
  </div>
  <template v-else />
</template>

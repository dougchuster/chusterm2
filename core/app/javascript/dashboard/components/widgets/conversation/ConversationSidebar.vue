<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import ContactPanel from 'dashboard/routes/dashboard/conversation/ContactPanel.vue';
import CopilotSidebarPanel from './copilot/CopilotSidebarPanel.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useEventListener, useWindowSize } from '@vueuse/core';
import { chatConversationIdentifiers } from 'dashboard/helper/conversationIdentifier';

const props = defineProps({
  currentChat: {
    required: true,
    type: Object,
  },
  customWidth: {
    type: Number,
    default: 0,
  },
});

const SIDEBAR_STATIC_BREAKPOINT = 1440;
const FOCUSABLE_SELECTOR = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

const { uiSettings, updateUISettings } = useUISettings();
const { width: windowWidth } = useWindowSize();
const sidebarRef = ref(null);
const backdropRef = ref(null);
const previouslyFocusedElement = ref(null);
const inertedElements = new Map();

const conversationIdentifiers = computed(() =>
  chatConversationIdentifiers(props.currentChat)
);

const activeTab = computed(() => {
  const {
    is_contact_sidebar_open: isContactSidebarOpen,
    is_copilot_panel_open: isCopilotPanelOpen,
  } = uiSettings.value;

  if (isContactSidebarOpen) {
    return 0;
  }
  if (isCopilotPanelOpen) {
    return 1;
  }
  return null;
});

const isOverlayLayout = computed(
  () => windowWidth.value < SIDEBAR_STATIC_BREAKPOINT
);
const isOverlayOpen = computed(
  () => isOverlayLayout.value && activeTab.value !== null
);

const sidebarStyle = computed(() => {
  if (isOverlayLayout.value || !props.customWidth) {
    return undefined;
  }
  return {
    width: `${props.customWidth}px`,
    minWidth: `${props.customWidth}px`,
  };
});

const closeContactPanel = () => {
  if (isOverlayOpen.value) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    });
  }
};

const getFocusableElements = () => {
  if (!sidebarRef.value) {
    return [];
  }

  return Array.from(
    sidebarRef.value.querySelectorAll(FOCUSABLE_SELECTOR)
  ).filter(element => {
    const style = window.getComputedStyle(element);
    return (
      element.getAttribute('aria-hidden') !== 'true' &&
      element.getAttribute('aria-disabled') !== 'true' &&
      style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      element.getClientRects().length > 0
    );
  });
};

const setBackgroundInert = () => {
  const sidebar = sidebarRef.value;
  const parent = sidebar?.parentElement;

  if (!parent || inertedElements.size) {
    return;
  }

  Array.from(parent.children).forEach(element => {
    if (element === sidebar || element === backdropRef.value) {
      return;
    }

    inertedElements.set(element, {
      hadInertAttribute: element.hasAttribute('inert'),
      ariaHidden: element.getAttribute('aria-hidden'),
    });
    element.setAttribute('inert', '');
    element.setAttribute('aria-hidden', 'true');
  });
};

const restoreBackground = () => {
  inertedElements.forEach((state, element) => {
    if (!state.hadInertAttribute) {
      element.removeAttribute('inert');
    }

    if (state.ariaHidden === null) {
      element.removeAttribute('aria-hidden');
    } else {
      element.setAttribute('aria-hidden', state.ariaHidden);
    }
  });
  inertedElements.clear();
};

const restoreFocus = () => {
  const target = previouslyFocusedElement.value;
  previouslyFocusedElement.value = null;

  if (!target) {
    return;
  }

  nextTick(() => {
    if (target.isConnected) {
      target.focus();
    }
  });
};

const activateOverlay = async () => {
  const sidebar = sidebarRef.value;

  if (!sidebar || typeof document === 'undefined') {
    return;
  }

  const activeElement = document.activeElement;
  if (
    activeElement instanceof HTMLElement &&
    !sidebar.contains(activeElement)
  ) {
    previouslyFocusedElement.value = activeElement;
  }

  setBackgroundInert();
  await nextTick();

  const [firstFocusableElement] = getFocusableElements();
  (firstFocusableElement || sidebar).focus();
};

const deactivateOverlay = () => {
  restoreBackground();
  restoreFocus();
};

const trapFocus = event => {
  const sidebar = sidebarRef.value;
  const focusableElements = getFocusableElements();

  if (!sidebar || !focusableElements.length) {
    event.preventDefault();
    sidebar?.focus();
    return;
  }

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];
  const activeElement = document.activeElement;

  if (event.shiftKey) {
    if (activeElement === firstElement || !sidebar.contains(activeElement)) {
      event.preventDefault();
      lastElement.focus();
    }
    return;
  }

  if (activeElement === lastElement || !sidebar.contains(activeElement)) {
    event.preventDefault();
    firstElement.focus();
  }
};

useEventListener('keydown', event => {
  if (!isOverlayOpen.value) {
    return;
  }

  if (event.key === 'Escape') {
    event.preventDefault();
    event.stopPropagation();
    closeContactPanel();
    return;
  }

  if (event.key === 'Tab') {
    trapFocus(event);
  }
});

watch(isOverlayOpen, isOpen => {
  if (isOpen) {
    activateOverlay();
  } else {
    deactivateOverlay();
  }
});

onMounted(() => {
  if (isOverlayOpen.value) {
    activateOverlay();
  }
});

onBeforeUnmount(deactivateOverlay);
</script>

<template>
  <div
    v-if="isOverlayLayout && activeTab !== null"
    ref="backdropRef"
    class="fixed inset-0 z-30 bg-ds-bg-canvas/60 backdrop-blur-[2px] min-[1440px]:hidden"
    aria-hidden="true"
    @click="closeContactPanel"
  />
  <aside
    ref="sidebarRef"
    class="conversation-sidebar-shell fixed inset-y-0 z-40 flex h-dvh w-full max-w-[430px] flex-col overflow-hidden bg-ds-bg-elevated shadow-[var(--ds-shadow-xl)] outline-none ltr:right-0 rtl:left-0 min-[1440px]:static min-[1440px]:z-auto min-[1440px]:h-full min-[1440px]:w-[400px] min-[1440px]:min-w-[400px] min-[1440px]:max-w-none min-[1440px]:shadow-none"
    :role="isOverlayOpen ? 'dialog' : 'complementary'"
    :aria-modal="isOverlayOpen ? 'true' : undefined"
    :aria-label="
      activeTab === 1
        ? $t('CONVERSATION.SIDEBAR.COPILOT')
        : $t('CONVERSATION.SIDEBAR.CONTACT')
    "
    :style="sidebarStyle"
    tabindex="-1"
  >
    <div
      class="conversation-sidebar-body flex flex-1 overflow-y-auto bg-ds-bg-elevated"
    >
      <ContactPanel
        v-if="activeTab === 0"
        :conversation-id="conversationIdentifiers.displayId"
        :conversation-database-id="conversationIdentifiers.databaseId"
        :inbox-id="currentChat.inbox_id"
      />
      <CopilotSidebarPanel
        v-else-if="activeTab === 1"
        :conversation-id="conversationIdentifiers.displayId"
      />
    </div>
  </aside>
</template>

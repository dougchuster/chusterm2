import { ref, computed } from 'vue';
import { useEventListener } from '@vueuse/core';
import { useUISettings } from 'dashboard/composables/useUISettings';

export const DEFAULT_LIST_WIDTH = 360;
export const MIN_LIST_WIDTH = 280;
export const MAX_LIST_WIDTH = 540;

export const DEFAULT_SIDEBAR_WIDTH = 400;
export const MIN_SIDEBAR_WIDTH = 320;
export const MAX_SIDEBAR_WIDTH = 600;

export function useCockpitResize() {
  const { uiSettings, updateUISettings } = useUISettings();

  const conversationListWidth = ref(
    Number(uiSettings.value?.conversation_list_width) || DEFAULT_LIST_WIDTH
  );
  const contactSidebarWidth = ref(
    Number(uiSettings.value?.conversation_sidebar_width) ||
      DEFAULT_SIDEBAR_WIDTH
  );

  const isResizingList = ref(false);
  const isResizingSidebar = ref(false);

  const startX = ref(0);
  const startWidth = ref(0);

  const isRTL = computed(() => {
    if (typeof document === 'undefined') return false;
    return document.documentElement.dir === 'rtl';
  });

  const getClientX = event =>
    event.touches ? event.touches[0].clientX : event.clientX;

  const setListWidth = width => {
    conversationListWidth.value = Math.max(
      MIN_LIST_WIDTH,
      Math.min(MAX_LIST_WIDTH, width)
    );
  };

  const saveListWidth = () => {
    updateUISettings({ conversation_list_width: conversationListWidth.value });
  };

  const resetListWidth = () => {
    conversationListWidth.value = DEFAULT_LIST_WIDTH;
    saveListWidth();
  };

  const setSidebarWidth = width => {
    contactSidebarWidth.value = Math.max(
      MIN_SIDEBAR_WIDTH,
      Math.min(MAX_SIDEBAR_WIDTH, width)
    );
  };

  const saveSidebarWidth = () => {
    updateUISettings({
      conversation_sidebar_width: contactSidebarWidth.value,
    });
  };

  const resetSidebarWidth = () => {
    contactSidebarWidth.value = DEFAULT_SIDEBAR_WIDTH;
    saveSidebarWidth();
  };

  const onListResizeStart = event => {
    isResizingList.value = true;
    startX.value = getClientX(event);
    startWidth.value = conversationListWidth.value;

    if (typeof document !== 'undefined') {
      Object.assign(document.body.style, {
        cursor: 'col-resize',
        userSelect: 'none',
      });
    }
    if (event.preventDefault) {
      event.preventDefault();
    }
  };

  const onSidebarResizeStart = event => {
    isResizingSidebar.value = true;
    startX.value = getClientX(event);
    startWidth.value = contactSidebarWidth.value;

    if (typeof document !== 'undefined') {
      Object.assign(document.body.style, {
        cursor: 'col-resize',
        userSelect: 'none',
      });
    }
    if (event.preventDefault) {
      event.preventDefault();
    }
  };

  const onResizeMove = event => {
    if (isResizingList.value) {
      const delta = isRTL.value
        ? startX.value - getClientX(event)
        : getClientX(event) - startX.value;
      setListWidth(startWidth.value + delta);
    } else if (isResizingSidebar.value) {
      // Sidebar is on the right side in LTR, so dragging left (smaller X) increases sidebar width
      const delta = isRTL.value
        ? getClientX(event) - startX.value
        : startX.value - getClientX(event);
      setSidebarWidth(startWidth.value + delta);
    }
  };

  const onResizeEnd = () => {
    if (isResizingList.value) {
      isResizingList.value = false;
      saveListWidth();
    }
    if (isResizingSidebar.value) {
      isResizingSidebar.value = false;
      saveSidebarWidth();
    }

    if (typeof document !== 'undefined') {
      Object.assign(document.body.style, { cursor: '', userSelect: '' });
    }
  };

  const onListResizeKeydown = event => {
    const step = event.shiftKey ? 32 : 8;
    const direction = isRTL.value ? -1 : 1;
    const widthChange = {
      ArrowLeft: -step * direction,
      ArrowRight: step * direction,
    }[event.key];

    if (widthChange) {
      event.preventDefault();
      setListWidth(conversationListWidth.value + widthChange);
      saveListWidth();
      return;
    }

    if (event.key === 'Home' || event.key === 'End') {
      event.preventDefault();
      setListWidth(event.key === 'Home' ? MIN_LIST_WIDTH : MAX_LIST_WIDTH);
      saveListWidth();
    }
  };

  const onSidebarResizeKeydown = event => {
    const step = event.shiftKey ? 32 : 8;
    // For right sidebar in LTR, ArrowLeft expands width (+step), ArrowRight shrinks (-step)
    const widthChange = {
      ArrowLeft: isRTL.value ? -step : step,
      ArrowRight: isRTL.value ? step : -step,
    }[event.key];

    if (widthChange) {
      event.preventDefault();
      setSidebarWidth(contactSidebarWidth.value + widthChange);
      saveSidebarWidth();
      return;
    }

    if (event.key === 'Home' || event.key === 'End') {
      event.preventDefault();
      setSidebarWidth(
        event.key === 'Home' ? MIN_SIDEBAR_WIDTH : MAX_SIDEBAR_WIDTH
      );
      saveSidebarWidth();
    }
  };

  if (typeof document !== 'undefined') {
    useEventListener(document, 'mousemove', onResizeMove);
    useEventListener(document, 'mouseup', onResizeEnd);
    useEventListener(document, 'touchmove', onResizeMove, { passive: false });
    useEventListener(document, 'touchend', onResizeEnd);
  }

  return {
    conversationListWidth,
    contactSidebarWidth,
    isResizingList,
    isResizingSidebar,
    setListWidth,
    saveListWidth,
    resetListWidth,
    setSidebarWidth,
    saveSidebarWidth,
    resetSidebarWidth,
    onListResizeStart,
    onSidebarResizeStart,
    onListResizeKeydown,
    onSidebarResizeKeydown,
    MIN_LIST_WIDTH,
    MAX_LIST_WIDTH,
    DEFAULT_LIST_WIDTH,
    MIN_SIDEBAR_WIDTH,
    MAX_SIDEBAR_WIDTH,
    DEFAULT_SIDEBAR_WIDTH,
  };
}

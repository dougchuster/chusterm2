<script setup>
import { computed, nextTick, ref, useId, useTemplateRef } from 'vue';
import { useWindowSize, useElementBounding } from '@vueuse/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  option: {
    type: Object,
    default: () => ({}),
  },
  subMenuAvailable: {
    type: Boolean,
    default: true,
  },
});

const menuRef = useTemplateRef('menuRef');
const submenuRef = useTemplateRef('submenuRef');
const triggerRef = useTemplateRef('triggerRef');
const { width: windowWidth, height: windowHeight } = useWindowSize();
const { bottom, right } = useElementBounding(menuRef);
const isOpen = ref(false);
const isPointerOpen = ref(false);
const submenuId = useId();

const ICON_MAP = {
  warning: 'i-lucide-triangle-alert',
  tag: 'i-lucide-tag',
  'person-add': 'i-lucide-user-plus',
  'people-team-add': 'i-lucide-users-round',
};

const icon = computed(() => {
  const iconName = props.option?.icon;
  if (!iconName) return '';
  if (iconName.startsWith('i-')) return iconName;
  return ICON_MAP[iconName] || 'i-lucide-circle';
});

const isCompactViewport = computed(() => windowWidth.value < 520);

// Vertical position
const verticalPosition = computed(() => {
  const SUBMENU_HEIGHT = 240; // 15rem in pixels
  const spaceBelow = windowHeight.value - bottom.value;
  return spaceBelow < SUBMENU_HEIGHT ? 'bottom-0' : 'top-0';
});

// Horizontal position
const horizontalPosition = computed(() => {
  const SUBMENU_WIDTH = 240;
  const spaceRight = windowWidth.value - right.value;
  return spaceRight < SUBMENU_WIDTH ? 'right-full' : 'left-full';
});

const submenuPosition = computed(() => [
  isCompactViewport.value
    ? [
        verticalPosition.value === 'bottom-0'
          ? 'bottom-full mb-1'
          : 'top-full mt-1',
        'left-0 right-auto w-full min-w-0',
      ]
    : [verticalPosition.value, horizontalPosition.value],
]);

const getSubmenuItems = () =>
  Array.from(
    submenuRef.value?.querySelectorAll('button:not([disabled])') || []
  );

const openSubmenu = async (focusIndex = null) => {
  if (!props.subMenuAvailable) return;
  isOpen.value = true;

  if (focusIndex === null) return;
  await nextTick();

  const items = getSubmenuItems();
  if (!items.length) return;
  const normalizedIndex = focusIndex < 0 ? items.length - 1 : focusIndex;
  items[normalizedIndex]?.focus();
};

const closeSubmenu = async ({ restoreFocus = false } = {}) => {
  isOpen.value = false;
  if (!restoreFocus) return;
  await nextTick();
  triggerRef.value?.focus();
};

const toggleSubmenu = () => {
  if (isPointerOpen.value) return;

  if (isOpen.value) {
    closeSubmenu();
  } else {
    openSubmenu();
  }
};

const handleTriggerKeydown = event => {
  if (!props.subMenuAvailable) return;

  if (['ArrowRight', 'ArrowDown'].includes(event.key)) {
    event.preventDefault();
    isPointerOpen.value = false;
    openSubmenu(0);
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    isPointerOpen.value = false;
    openSubmenu(-1);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    closeSubmenu({ restoreFocus: true });
  }
};

const handleSubmenuKeydown = event => {
  const items = getSubmenuItems();
  if (!items.length) return;

  const currentIndex = items.indexOf(document.activeElement);
  let nextIndex;

  if (event.key === 'ArrowDown') {
    nextIndex = (currentIndex + 1) % items.length;
  } else if (event.key === 'ArrowUp') {
    nextIndex = (currentIndex - 1 + items.length) % items.length;
  } else if (event.key === 'Home') {
    nextIndex = 0;
  } else if (event.key === 'End') {
    nextIndex = items.length - 1;
  } else if (['Escape', 'ArrowLeft'].includes(event.key)) {
    event.preventDefault();
    closeSubmenu({ restoreFocus: true });
    return;
  } else {
    return;
  }

  event.preventDefault();
  event.stopPropagation();
  items[nextIndex]?.focus();
};

const handlePointerEnter = event => {
  if (event.pointerType !== 'mouse') return;
  isPointerOpen.value = true;
  openSubmenu();
};

const handlePointerLeave = event => {
  const wasPointerOpen = isPointerOpen.value;
  isPointerOpen.value = false;
  if (wasPointerOpen || !event.currentTarget.contains(document.activeElement)) {
    closeSubmenu();
  }
};

const handleFocusOut = event => {
  if (!event.currentTarget.contains(event.relatedTarget)) {
    closeSubmenu();
  }
};
</script>

<template>
  <div
    ref="menuRef"
    class="relative w-full min-w-[12.5rem]"
    @pointerenter="handlePointerEnter"
    @pointerleave="handlePointerLeave"
    @focusout="handleFocusOut"
  >
    <button
      ref="triggerRef"
      type="button"
      role="menuitem"
      class="flex min-h-9 w-full items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-xs font-medium text-ds-fg-default outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:bg-ds-accent-soft focus-visible:text-ds-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
      :disabled="!subMenuAvailable"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      :aria-controls="subMenuAvailable ? submenuId : undefined"
      @click.stop="toggleSubmenu"
      @keydown="handleTriggerKeydown"
    >
      <Icon :icon="icon" class="size-3.5 shrink-0" aria-hidden="true" />
      <span class="min-w-0 flex-1 truncate">{{ option.label }}</span>
      <Icon
        icon="i-lucide-chevron-right"
        class="size-3.5 shrink-0 transition-transform"
        :class="isOpen ? 'rotate-90' : ''"
        aria-hidden="true"
      />
    </button>
    <div
      v-if="subMenuAvailable && isOpen"
      :id="submenuId"
      ref="submenuRef"
      role="menu"
      :aria-label="option.label"
      class="absolute z-50 max-h-60 min-w-[12.5rem] overflow-x-hidden overflow-y-auto rounded-xl bg-ds-bg-elevated p-1 shadow-lg ring-1 ring-ds-border-subtle"
      :class="submenuPosition"
      @keydown="handleSubmenuKeydown"
    >
      <slot />
    </div>
  </div>
</template>

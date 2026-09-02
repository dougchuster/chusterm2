<script setup>
import {
  computed,
  onMounted,
  nextTick,
  onUnmounted,
  useTemplateRef,
  inject,
} from 'vue';
import { useWindowSize, useElementBounding, useScrollLock } from '@vueuse/core';

import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  x: { type: Number, default: 0 },
  y: { type: Number, default: 0 },
});

const emit = defineEmits(['close']);

const elementToLock = inject('contextMenuElementTarget', null);

const menuRef = useTemplateRef('menuRef');

const scrollLockElement = computed(() => {
  if (!elementToLock?.value) return null;
  return elementToLock.value?.$el;
});

const isLocked = useScrollLock(scrollLockElement);

const { width: windowWidth, height: windowHeight } = useWindowSize();
const { width: menuWidth, height: menuHeight } = useElementBounding(menuRef);

const calculatePosition = (x, y, menuW, menuH, windowW, windowH) => {
  const PADDING = 16;
  // Initial position
  let left = x;
  let top = y;
  // Boundary checks
  const isOverflowingRight = left + menuW > windowW - PADDING;
  const isOverflowingBottom = top + menuH > windowH - PADDING;
  // Adjust position if overflowing
  if (isOverflowingRight) left = windowW - menuW - PADDING;
  if (isOverflowingBottom) top = windowH - menuH - PADDING;
  return {
    left: Math.max(PADDING, left),
    top: Math.max(PADDING, top),
  };
};

const position = computed(() => {
  if (!menuRef.value) return { top: `${props.y}px`, left: `${props.x}px` };

  const { left, top } = calculatePosition(
    props.x,
    props.y,
    menuWidth.value,
    menuHeight.value,
    windowWidth.value,
    windowHeight.value
  );

  return {
    top: `${top}px`,
    left: `${left}px`,
  };
});

onMounted(() => {
  isLocked.value = true;
  nextTick(() => {
    const firstMenuItem = menuRef.value?.querySelector(
      '[role="menuitem"]:not([disabled])'
    );
    (firstMenuItem || menuRef.value)?.focus();
  });
});

const handleClose = () => {
  isLocked.value = false;
  emit('close');
};

const handleFocusOut = event => {
  if (event.currentTarget.contains(event.relatedTarget)) return;
  handleClose();
};

const getMenuItems = () =>
  Array.from(
    menuRef.value?.querySelectorAll('[role="menuitem"]:not([disabled])') || []
  );

const handleMenuKeydown = event => {
  if (event.defaultPrevented) return;

  if (event.key === 'Escape') {
    event.preventDefault();
    handleClose();
    return;
  }

  const items = getMenuItems();
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
  } else {
    return;
  }

  event.preventDefault();
  items[nextIndex]?.focus();
};

onUnmounted(() => {
  isLocked.value = false;
});
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      ref="menuRef"
      class="fixed outline-none z-[9999] cursor-pointer"
      :style="position"
      role="menu"
      tabindex="-1"
      @focusout="handleFocusOut"
      @keydown="handleMenuKeydown"
    >
      <slot />
    </div>
  </TeleportWithDirection>
</template>

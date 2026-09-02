<script setup>
import { computed, nextTick, ref, useId, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useWindowSize } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import { useCaptain } from 'dashboard/composables/useCaptain';
import DropdownBody from 'next/dropdown-menu/base/DropdownBody.vue';

import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  hasSelection: {
    type: Boolean,
    default: false,
  },
  isEditorMenuPopover: {
    type: Boolean,
    default: false,
  },
  editorContent: {
    type: String,
    default: undefined,
  },
  conversationId: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['executeCopilotAction']);

const { t } = useI18n();

const { draftMessage } = useCaptain();

const replyMode = useMapGetter('draftMessages/getReplyEditorMode');

// When editorContent prop is passed, use it exclusively (even if empty)
// This ensures each editor instance shows menu items based on its own content
// Falls back to global draftMessage only when editorContent is not provided
const effectiveContent = computed(() =>
  props.editorContent !== undefined ? props.editorContent : draftMessage.value
);

// Selection-based menu items (when text is selected)
const menuItems = computed(() => {
  const items = [];
  // for now, we don't allow improving just  aprt of the selection
  // we will add this feature later. Once we do, we can revert the change
  const hasSelection = false;
  // const hasSelection = props.hasSelection

  if (hasSelection) {
    items.push({
      label: t(
        'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.IMPROVE_REPLY_SELECTION'
      ),
      key: 'improve_selection',
      icon: 'i-lucide-wand-sparkles',
    });
  } else if (
    props.conversationId &&
    replyMode.value === REPLY_EDITOR_MODES.REPLY &&
    effectiveContent.value
  ) {
    items.push({
      label: t('INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.IMPROVE_REPLY'),
      key: 'improve',
      icon: 'i-lucide-wand-sparkles',
    });
  }

  if (effectiveContent.value) {
    items.push(
      {
        label: t(
          'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.CHANGE_TONE.TITLE'
        ),
        key: 'change_tone',
        icon: 'i-lucide-audio-waveform',
        subMenuItems: [
          {
            label: t(
              'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.CHANGE_TONE.OPTIONS.PROFESSIONAL'
            ),
            key: 'professional',
          },
          {
            label: t(
              'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.CHANGE_TONE.OPTIONS.CASUAL'
            ),
            key: 'casual',
          },
          {
            label: t(
              'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.CHANGE_TONE.OPTIONS.STRAIGHTFORWARD'
            ),
            key: 'straightforward',
          },
          {
            label: t(
              'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.CHANGE_TONE.OPTIONS.CONFIDENT'
            ),
            key: 'confident',
          },
          {
            label: t(
              'INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.CHANGE_TONE.OPTIONS.FRIENDLY'
            ),
            key: 'friendly',
          },
        ],
      },
      {
        label: t('INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.GRAMMAR'),
        key: 'fix_spelling_grammar',
        icon: 'i-lucide-spell-check-2',
      }
    );
  }
  return items;
});

const generalMenuItems = computed(() => {
  const items = [];
  if (props.conversationId && replyMode.value === REPLY_EDITOR_MODES.REPLY) {
    items.push({
      label: t('INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.SUGGESTION'),
      key: 'reply_suggestion',
      icon: 'i-lucide-message-square-reply',
    });
  }

  if (
    props.conversationId &&
    (replyMode.value === REPLY_EDITOR_MODES.NOTE || true)
  ) {
    items.push({
      label: t('INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.SUMMARIZE'),
      key: 'summarize',
      icon: 'i-lucide-list-collapse',
    });
  }

  items.push({
    label: t('INTEGRATION_SETTINGS.OPEN_AI.REPLY_OPTIONS.ASK_COPILOT'),
    key: 'ask_copilot',
    icon: 'i-lucide-sparkles',
  });

  return items;
});

const menuRef = useTemplateRef('menuRef');
const { width: windowWidth } = useWindowSize();
const menuId = useId();
const openSubmenuKey = ref(null);
const isCompactViewport = computed(
  () => (windowWidth.value ?? window.innerWidth) < 520
);

// Smart submenu positioning based on available space
const submenuPosition = computed(() => {
  if (isCompactViewport.value) {
    return 'top-full mt-1 left-0 right-auto w-full min-w-0';
  }

  const el = menuRef.value?.$el;
  if (!el) return 'top-0 ltr:right-full rtl:left-full';

  const { left, right } = el.getBoundingClientRect();
  const SUBMENU_WIDTH = 200;
  const spaceRight = (windowWidth.value ?? window.innerWidth) - right;
  const spaceLeft = left;

  // Prefer right, fallback to side with more space
  const showRight = spaceRight >= SUBMENU_WIDTH || spaceRight >= spaceLeft;

  return showRight ? 'top-0 left-full' : 'top-0 right-full';
});

const selectionMenuClasses = computed(() =>
  props.hasSelection && props.isEditorMenuPopover
    ? '[left:var(--selection-left)] [top:var(--selection-top)] translate-y-[calc(-100%-0.625rem)] rtl:left-auto rtl:[right:var(--selection-right)]'
    : ''
);

const submenuId = key => `${menuId}-${key}-submenu`;
const submenuTriggerId = key => `${menuId}-${key}-trigger`;
const isSubmenuOpen = key => openSubmenuKey.value === key;

const getMenuRoot = () => menuRef.value?.$el ?? menuRef.value;

const getTopLevelItems = () =>
  Array.from(getMenuRoot()?.querySelectorAll('[data-copilot-top-level]') ?? []);

const getSubmenuItems = key =>
  Array.from(
    getMenuRoot()
      ?.querySelector(`[data-copilot-submenu="${key}"]`)
      ?.querySelectorAll('[role="menuitem"]') ?? []
  );

const openSubmenu = key => {
  openSubmenuKey.value = key;
};

const focusSubmenuItem = async (key, index = 0) => {
  openSubmenu(key);
  await nextTick();

  const items = getSubmenuItems(key);
  if (!items.length) return;

  const normalizedIndex = (index + items.length) % items.length;
  items[normalizedIndex].focus();
};

const closeSubmenu = async ({
  key = openSubmenuKey.value,
  restoreFocus,
} = {}) => {
  openSubmenuKey.value = null;
  if (!restoreFocus || !key) return;

  await nextTick();
  getMenuRoot()?.querySelector(`[data-copilot-key="${key}"]`)?.focus();
};

const focusTopLevelItem = (currentTarget, offset) => {
  const items = getTopLevelItems();
  const currentIndex = items.indexOf(currentTarget);
  if (currentIndex < 0 || !items.length) return;

  const nextIndex = (currentIndex + offset + items.length) % items.length;
  items[nextIndex].focus();
};

const handleMenuItemClick = item => {
  if (item.subMenuItems) {
    openSubmenu(item.key);
    return;
  }

  closeSubmenu();
  emit('executeCopilotAction', item.key);
};

const handleSubMenuItemClick = subItem => {
  closeSubmenu();
  emit('executeCopilotAction', subItem.key);
};

const handleTopLevelKeydown = (event, item) => {
  if (
    item.subMenuItems &&
    ['Enter', ' ', 'Spacebar', 'ArrowRight'].includes(event.key)
  ) {
    event.preventDefault();
    focusSubmenuItem(item.key);
    return;
  }

  if (event.key === 'ArrowDown') {
    event.preventDefault();
    focusTopLevelItem(event.currentTarget, 1);
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    focusTopLevelItem(event.currentTarget, -1);
  } else if (event.key === 'Home') {
    event.preventDefault();
    getTopLevelItems()[0]?.focus();
  } else if (event.key === 'End') {
    event.preventDefault();
    getTopLevelItems().at(-1)?.focus();
  } else if (event.key === 'Escape' && isSubmenuOpen(item.key)) {
    event.preventDefault();
    closeSubmenu();
  }
};

const handleSubmenuKeydown = (event, parentItem) => {
  const items = getSubmenuItems(parentItem.key);
  const currentIndex = items.indexOf(event.currentTarget);

  if (event.key === 'ArrowDown') {
    event.preventDefault();
    items[(currentIndex + 1) % items.length]?.focus();
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    items[(currentIndex - 1 + items.length) % items.length]?.focus();
  } else if (event.key === 'Home') {
    event.preventDefault();
    items[0]?.focus();
  } else if (event.key === 'End') {
    event.preventDefault();
    items.at(-1)?.focus();
  } else if (['Escape', 'ArrowLeft'].includes(event.key)) {
    event.preventDefault();
    closeSubmenu({ key: parentItem.key, restoreFocus: true });
  }
};

const handlePointerEnter = (event, key) => {
  if (event.pointerType === 'mouse') openSubmenu(key);
};

const handlePointerLeave = event => {
  if (!event.currentTarget.contains(document.activeElement)) closeSubmenu();
};

const handleFocusOut = event => {
  if (!event.currentTarget.contains(event.relatedTarget)) closeSubmenu();
};
</script>

<template>
  <DropdownBody
    ref="menuRef"
    role="menu"
    class="z-50 w-[min(14rem,calc(100vw-1rem))] min-w-0 font-sans text-ds-fg-default sm:min-w-56 [&>ul]:gap-1 [&>ul]:border-0 [&>ul]:bg-ds-bg-elevated [&>ul]:p-2 [&>ul]:shadow-xl [&>ul]:ring-1 [&>ul]:ring-ds-border-subtle"
    :class="selectionMenuClasses"
  >
    <template v-if="menuItems.length > 0">
      <li
        v-for="item in menuItems"
        :key="item.key"
        role="none"
        class="group/submenu relative w-full focus-within:z-20"
        @pointerenter="handlePointerEnter($event, item.key)"
        @pointerleave="handlePointerLeave"
        @focusout="handleFocusOut"
      >
        <button
          :id="submenuTriggerId(item.key)"
          type="button"
          role="menuitem"
          :data-copilot-key="item.key"
          data-copilot-top-level
          class="reset-base flex min-h-10 w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-sm font-medium text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:bg-ds-bg-hover focus-visible:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
          :aria-haspopup="item.subMenuItems ? 'menu' : undefined"
          :aria-expanded="
            item.subMenuItems ? isSubmenuOpen(item.key) : undefined
          "
          :aria-controls="item.subMenuItems ? submenuId(item.key) : undefined"
          @click="handleMenuItemClick(item)"
          @keydown="handleTopLevelKeydown($event, item)"
        >
          <Icon :icon="item.icon" class="size-4 shrink-0 text-ds-accent" />
          <span class="min-w-0 flex-1 truncate">{{ item.label }}</span>
          <Icon
            v-if="item.subMenuItems"
            icon="i-lucide-chevron-right"
            class="size-4 shrink-0 text-ds-fg-subtle transition-transform"
            :class="isSubmenuOpen(item.key) ? 'rotate-90' : 'rtl:rotate-180'"
          />
        </button>

        <DropdownBody
          v-if="item.subMenuItems && isSubmenuOpen(item.key)"
          :id="submenuId(item.key)"
          role="menu"
          :aria-labelledby="submenuTriggerId(item.key)"
          :data-copilot-submenu="item.key"
          strong
          class="z-20 max-h-60 min-w-48 [&>ul]:gap-1 [&>ul]:border-0 [&>ul]:bg-ds-bg-elevated [&>ul]:p-2 [&>ul]:shadow-xl [&>ul]:ring-1 [&>ul]:ring-ds-border-subtle"
          :class="submenuPosition"
        >
          <li
            v-for="subItem in item.subMenuItems"
            :key="subItem.key + subItem.label"
            role="none"
          >
            <button
              type="button"
              role="menuitem"
              class="reset-base flex min-h-10 w-full items-center rounded-lg px-2.5 py-2 text-left text-sm font-medium text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:bg-ds-bg-hover focus-visible:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
              @click="handleSubMenuItemClick(subItem)"
              @keydown="handleSubmenuKeydown($event, item)"
            >
              <span class="min-w-0 truncate">{{ subItem.label }}</span>
            </button>
          </li>
        </DropdownBody>
      </li>
    </template>

    <li
      v-if="menuItems.length > 0"
      role="separator"
      aria-orientation="horizontal"
      class="my-1 h-px w-full bg-ds-border-subtle"
    />

    <li v-for="item in generalMenuItems" :key="item.key" role="none">
      <button
        type="button"
        role="menuitem"
        :data-copilot-key="item.key"
        data-copilot-top-level
        class="reset-base flex min-h-10 w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-sm font-medium text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:bg-ds-bg-hover focus-visible:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
        @click="handleMenuItemClick(item)"
        @keydown="handleTopLevelKeydown($event, item)"
      >
        <Icon :icon="item.icon" class="size-4 shrink-0 text-ds-accent" />
        <span class="min-w-0 truncate">{{ item.label }}</span>
      </button>
    </li>
  </DropdownBody>
</template>

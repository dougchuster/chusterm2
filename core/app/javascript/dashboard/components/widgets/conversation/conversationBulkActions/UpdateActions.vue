<script setup>
import { useI18n } from 'vue-i18n';
import { nextTick, onMounted, ref } from 'vue';

const props = defineProps({
  showResolve: {
    type: Boolean,
    default: true,
  },
  showReopen: {
    type: Boolean,
    default: true,
  },
  showSnooze: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['update', 'close']);

const { t } = useI18n();

const menuRef = ref(null);
const actions = ref([
  { icon: 'i-lucide-check', key: 'resolved' },
  { icon: 'i-lucide-redo', key: 'open' },
  { icon: 'i-lucide-alarm-clock', key: 'snoozed' },
]);

const updateConversations = key => {
  if (key === 'snoozed') {
    // If the user clicks on the snooze option from the bulk action change status dropdown.
    // Open the snooze option for bulk action in the cmd bar.
    const ninja = document.querySelector('ninja-keys');
    ninja?.open({ parent: 'bulk_action_snooze_conversation' });
  } else {
    emit('update', key);
  }
};

const onClose = () => {
  emit('close');
};

const focusMenuItem = event => {
  const items = Array.from(
    menuRef.value?.querySelectorAll('[role="menuitem"]') || []
  );
  if (!items.length) return;

  const activeIndex = items.indexOf(document.activeElement);
  let nextIndex;

  if (event.key === 'Home') {
    nextIndex = 0;
  } else if (event.key === 'End') {
    nextIndex = items.length - 1;
  } else if (event.key === 'ArrowDown') {
    nextIndex = activeIndex < 0 ? 0 : (activeIndex + 1) % items.length;
  } else {
    nextIndex =
      activeIndex < 0
        ? items.length - 1
        : (activeIndex - 1 + items.length) % items.length;
  }

  event.preventDefault();
  items[nextIndex].focus();
};

const onMenuKeydown = event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    event.stopPropagation();
    onClose();
    return;
  }

  if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
    focusMenuItem(event);
  }
};

const showAction = key => {
  const actionsMap = {
    resolved: props.showResolve,
    open: props.showReopen,
    snoozed: props.showSnooze,
  };
  return actionsMap[key] || false;
};

const actionLabel = key => {
  const labelsMap = {
    resolved: t('CONVERSATION.HEADER.RESOLVE_ACTION'),
    open: t('CONVERSATION.HEADER.REOPEN_ACTION'),
    snoozed: t('BULK_ACTION.UPDATE.SNOOZE_UNTIL'),
  };
  return labelsMap[key] || '';
};

onMounted(() => {
  nextTick(() => {
    menuRef.value?.querySelector('[role="menuitem"]')?.focus();
  });
});
</script>

<template>
  <div
    ref="menuRef"
    v-on-clickaway="onClose"
    class="absolute top-12 z-20 w-[min(15rem,calc(100vw-1rem))] origin-top-right overflow-hidden rounded-xl bg-ds-bg-elevated/95 text-ds-fg-default shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle backdrop-blur-xl ltr:right-2 rtl:left-2"
    role="menu"
    :aria-label="$t('BULK_ACTION.UPDATE.CHANGE_STATUS')"
    @keydown="onMenuKeydown"
  >
    <span
      class="absolute -top-1.5 z-10 size-3 rotate-45 border-l border-t border-ds-border-subtle bg-ds-bg-elevated ltr:right-[var(--triangle-position)] rtl:left-[var(--triangle-position)]"
      aria-hidden="true"
    />
    <div
      class="flex min-h-11 items-center justify-between border-b border-ds-border-subtle px-3 py-2"
    >
      <span class="text-sm font-semibold text-ds-fg-default">
        {{ $t('BULK_ACTION.UPDATE.CHANGE_STATUS') }}
      </span>
      <button
        type="button"
        class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        :aria-label="$t('GENERAL.CLOSE')"
        @click="onClose"
      >
        <span class="i-lucide-x size-4" aria-hidden="true" />
      </button>
    </div>
    <ul class="m-0 list-none p-1.5">
      <template v-for="action in actions" :key="action.key">
        <li v-if="showAction(action.key)" role="none">
          <button
            type="button"
            role="menuitem"
            class="flex min-h-10 w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-sm text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
            @click="updateConversations(action.key)"
          >
            <span
              class="size-4 shrink-0 text-ds-fg-muted"
              :class="action.icon"
              aria-hidden="true"
            />
            <span class="min-w-0 truncate">
              {{ actionLabel(action.key) }}
            </span>
          </button>
        </li>
      </template>
    </ul>
  </div>
</template>

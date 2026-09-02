<script setup>
import { computed } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex >= 0 && selectedTabIndex < props.items.length) {
    const selectedItem = props.items[selectedTabIndex];
    if (selectedItem.key !== props.activeTab) {
      emit('chatTabChange', selectedItem.key);
    }
  }
};

const onTabKeydown = (event, index) => {
  let nextIndex;

  if (event.key === 'ArrowRight') {
    nextIndex = (index + 1) % props.items.length;
  } else if (event.key === 'ArrowLeft') {
    nextIndex = (index - 1 + props.items.length) % props.items.length;
  } else if (event.key === 'Home') {
    nextIndex = 0;
  } else if (event.key === 'End') {
    nextIndex = props.items.length - 1;
  }

  if (nextIndex === undefined) return;

  event.preventDefault();
  onTabChange(nextIndex);
  event.currentTarget.parentElement
    ?.querySelectorAll('[role="tab"]')
    [nextIndex]?.focus();
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (!props.items.length) return;
      if (props.activeTab === wootConstants.ASSIGNEE_TYPE.ALL) {
        onTabChange(0);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(nextIndex);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div
    class="flex w-full min-w-0 gap-1 bg-ds-bg-surface/80 px-2 pb-2 pt-1"
    role="tablist"
  >
    <button
      v-for="(item, index) in items"
      :key="item.key"
      type="button"
      class="group inline-flex min-h-10 min-w-0 flex-1 items-center justify-center gap-1.5 rounded-lg px-1.5 text-[13px] font-semibold leading-none text-ds-fg-muted outline-none transition-colors duration-150 hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus focus-visible:ring-offset-1 focus-visible:ring-offset-ds-bg-surface sm:text-sm"
      :class="{
        'bg-ds-accent-soft text-ds-accent': index === activeTabIndex,
      }"
      role="tab"
      :aria-selected="index === activeTabIndex"
      :aria-label="`${item.name}: ${item.count}`"
      :tabindex="index === activeTabIndex ? 0 : -1"
      :title="item.name"
      @click="onTabChange(index)"
      @keydown="onTabKeydown($event, index)"
    >
      <span class="whitespace-nowrap">{{ item.shortName || item.name }}</span>
      <span
        class="inline-flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-ds-bg-elevated px-1 text-[11px] font-bold leading-none text-ds-fg-muted transition-colors group-hover:text-ds-fg-default"
        :class="{
          'bg-ds-accent-soft text-ds-accent': index === activeTabIndex,
        }"
      >
        {{ item.count }}
      </span>
    </button>
  </div>
</template>

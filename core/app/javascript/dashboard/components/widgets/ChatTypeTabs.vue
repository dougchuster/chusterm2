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
  <div class="chat-type-tabs" role="tablist">
    <button
      v-for="(item, index) in items"
      :key="item.key"
      type="button"
      class="chat-type-tabs__item"
      :class="{ 'is-active': index === activeTabIndex }"
      role="tab"
      :aria-selected="index === activeTabIndex"
      @click="onTabChange(index)"
    >
      <span class="chat-type-tabs__label">{{ item.name }}</span>
      <span class="chat-type-tabs__count">{{ item.count }}</span>
    </button>
  </div>
</template>

<style scoped>
.chat-type-tabs {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(6.25rem, 1fr));
  gap: 0.375rem;
  width: 100%;
  min-width: 0;
  padding: 0.375rem 0.75rem 0.5rem;
  border-bottom: 1px solid rgb(var(--slate-4));
}

.chat-type-tabs__item {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 0;
  min-height: 2.375rem;
  gap: 0.375rem;
  border-radius: 0.5rem;
  color: rgb(var(--slate-11));
  font-size: 0.875rem;
  font-weight: 600;
  line-height: 1;
  outline: none;
  transition:
    background-color 0.15s ease,
    color 0.15s ease;
}

.chat-type-tabs__item:hover {
  background: rgb(var(--slate-3));
  color: rgb(var(--slate-12));
}

.chat-type-tabs__item:focus-visible {
  box-shadow: 0 0 0 2px rgb(var(--brand-7));
}

.chat-type-tabs__item::after {
  position: absolute;
  right: 0.25rem;
  bottom: -0.5rem;
  left: 0.25rem;
  height: 2px;
  border-radius: 999px;
  background: transparent;
  content: '';
}

.chat-type-tabs__item.is-active {
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-3));
}

.chat-type-tabs__item.is-active::after {
  background: rgb(var(--brand-9));
}

.chat-type-tabs__label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-type-tabs__count {
  display: inline-grid;
  flex: 0 0 auto;
  min-width: 1.25rem;
  height: 1.25rem;
  place-content: center;
  border-radius: 999px;
  background: rgb(var(--slate-4));
  color: rgb(var(--slate-11));
  font-size: 0.75rem;
  font-weight: 700;
}

.chat-type-tabs__item.is-active .chat-type-tabs__count {
  background: rgb(var(--brand-4));
  color: rgb(var(--brand-12));
}

@media (max-width: 420px) {
  .chat-type-tabs {
    padding-inline: 0.5rem;
    gap: 0.25rem;
  }

  .chat-type-tabs__item {
    font-size: 0.8125rem;
    gap: 0.25rem;
  }
}
</style>

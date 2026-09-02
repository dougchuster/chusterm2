<script setup>
import { computed, nextTick, ref } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: [String, Number], required: true },
  tabs: { type: Array, default: () => [] },
  label: { type: String, required: true },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'change']);
const tabRefs = ref([]);

const enabledTabs = computed(() =>
  props.tabs.filter(tab => !tab.disabled && !props.disabled)
);

const select = tab => {
  if (tab.disabled || props.disabled || props.loading) return;
  emit('update:modelValue', tab.value);
  emit('change', tab.value);
};

const focusTab = async value => {
  await nextTick();
  const index = props.tabs.findIndex(tab => tab.value === value);
  tabRefs.value[index]?.focus();
};

const handleKeydown = (event, tab) => {
  const currentIndex = enabledTabs.value.findIndex(
    item => item.value === tab.value
  );
  if (currentIndex < 0) return;

  let nextIndex = currentIndex;
  if (event.key === 'ArrowRight') nextIndex = currentIndex + 1;
  else if (event.key === 'ArrowLeft') nextIndex = currentIndex - 1;
  else if (event.key === 'Home') nextIndex = 0;
  else if (event.key === 'End') nextIndex = enabledTabs.value.length - 1;
  else return;

  event.preventDefault();
  const nextTab =
    enabledTabs.value[
      (nextIndex + enabledTabs.value.length) % enabledTabs.value.length
    ];
  select(nextTab);
  focusTab(nextTab.value);
};
</script>

<template>
  <div
    role="tablist"
    :aria-label="label"
    :aria-busy="loading || undefined"
    class="flex min-w-0 gap-1 overflow-x-auto"
  >
    <button
      v-for="(tab, index) in tabs"
      :key="tab.value"
      :ref="element => (tabRefs[index] = element)"
      type="button"
      role="tab"
      :aria-selected="modelValue === tab.value"
      :tabindex="modelValue === tab.value ? 0 : -1"
      :disabled="disabled || loading || tab.disabled"
      class="inline-flex h-8 shrink-0 items-center gap-2 rounded-ui-control px-3 text-ui-body-sm font-medium text-ui-text-muted transition-colors duration-ui-fast hover:enabled:bg-ui-hover hover:enabled:text-ui-text active:enabled:bg-ui-active focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus disabled:cursor-not-allowed disabled:text-ui-text-disabled max-sm:h-11"
      :class="{
        'bg-ui-active text-ui-text': modelValue === tab.value,
      }"
      @click="select(tab)"
      @keydown="handleKeydown($event, tab)"
    >
      <Icon
        v-if="tab.icon"
        :icon="tab.icon"
        class="size-4"
        aria-hidden="true"
      />
      <span>{{ tab.label }}</span>
      <span
        v-if="tab.count !== undefined"
        class="tabular-nums text-ui-caption text-ui-text-muted"
      >
        {{ tab.count }}
      </span>
    </button>
  </div>
</template>

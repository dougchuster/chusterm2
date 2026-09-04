<script setup>
import { computed, ref } from 'vue';
import Icon from 'next/icon/Icon.vue';
import SidebarGroupLeaf from './SidebarGroupLeaf.vue';
import SidebarGroupSeparator from './SidebarGroupSeparator.vue';

import { useSidebarContext } from './provider';
import { useEventListener } from '@vueuse/core';

const props = defineProps({
  isExpanded: { type: Boolean, default: false },
  label: { type: String, required: true },
  icon: { type: [Object, String], required: true },
  children: { type: Array, default: () => [] },
  activeChild: { type: Object, default: undefined },
});

const { isAllowed } = useSidebarContext();
const scrollableContainer = ref(null);

const accessibleItems = computed(() =>
  props.children.filter(child => {
    return child.to && isAllowed(child.to);
  })
);

const hasAccessibleItems = computed(() => {
  return accessibleItems.value.length > 0;
});

const isScrollable = computed(() => {
  return accessibleItems.value.length > 7;
});

const scrollEnd = ref(false);

useEventListener(scrollableContainer, 'scroll', () => {
  if (!scrollableContainer.value) return;
  const { scrollHeight, scrollTop, clientHeight } = scrollableContainer.value;
  scrollEnd.value = scrollHeight - scrollTop === clientHeight;
});
</script>

<template>
  <li class="relative min-w-0 list-none">
    <SidebarGroupSeparator
      v-if="hasAccessibleItems"
      v-show="isExpanded"
      :label="label"
      :icon="icon"
      class="my-1"
    />
    <div class="group reset-base relative min-w-0">
      <ul
        ref="scrollableContainer"
        class="m-0 min-w-0 list-none"
        :class="{
          'max-h-[calc(14rem+16px)] overflow-y-scroll no-scrollbar':
            isScrollable,
        }"
      >
        <SidebarGroupLeaf
          v-for="child in children"
          v-show="isExpanded || activeChild?.name === child.name"
          v-bind="child"
          :key="child.name"
          :active="activeChild?.name === child.name"
          is-nested
        />
      </ul>
      <div
        v-if="isScrollable && isExpanded"
        v-show="!scrollEnd"
        class="pointer-events-none absolute -bottom-1 flex h-12 w-full animate-fade-in-up items-end justify-end bg-gradient-to-t from-ds-shell-canvas to-transparent px-2"
      >
        <Icon
          icon="i-lucide-chevrons-down"
          class="size-4 text-ds-shell-subtle opacity-60 transition-opacity group-hover:opacity-100"
        />
      </div>
    </div>
  </li>
</template>

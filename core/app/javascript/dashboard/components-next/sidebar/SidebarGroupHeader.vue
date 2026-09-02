<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  to: { type: [Object, String], default: '' },
  label: { type: String, default: '' },
  icon: { type: [String, Object], default: '' },
  expandable: { type: Boolean, default: false },
  isExpanded: { type: Boolean, default: false },
  isActive: { type: Boolean, default: false },
  hasActiveChild: { type: Boolean, default: false },
  getterKeys: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['toggle']);

const showBadge = useMapGetter(props.getterKeys.badge);
const dynamicCount = useMapGetter(props.getterKeys.count);
const count = computed(() =>
  dynamicCount.value > 99 ? '99+' : dynamicCount.value
);
</script>

<template>
  <component
    :is="to ? 'router-link' : 'button'"
    class="group/sidebar-menu-item flex min-h-11 min-w-0 items-center gap-2.5 rounded-xl border-0 px-3 py-2 font-inter no-underline transition duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
    :type="to ? undefined : 'button'"
    draggable="false"
    :to="to"
    :title="label"
    :aria-current="isActive && !hasActiveChild ? 'page' : undefined"
    :aria-expanded="expandable ? isExpanded : undefined"
    :class="[
      isActive && !hasActiveChild
        ? 'bg-ds-shell-active text-ds-shell-fg shadow-sm shadow-ds-shell-accent/10'
        : '',
      hasActiveChild ? 'bg-ds-shell-panel-strong text-ds-shell-fg' : '',
      !isActive && !hasActiveChild
        ? 'text-ds-shell-muted hover:bg-ds-shell-hover hover:text-ds-shell-fg'
        : '',
    ]"
    @click.stop="emit('toggle')"
  >
    <div
      v-if="icon"
      class="relative grid size-5 flex-shrink-0 place-content-center"
    >
      <Icon :icon="icon" class="size-[18px]" aria-hidden="true" />
      <span
        v-if="showBadge"
        class="absolute -top-0.5 size-2 rounded-full bg-ds-shell-secondary ring-2 ring-ds-shell-canvas ltr:-right-0.5 rtl:-left-0.5"
        aria-hidden="true"
      />
    </div>
    <div class="flex min-w-0 flex-1 flex-grow items-center gap-1.5">
      <span class="truncate text-[0.875rem] font-medium leading-5">
        {{ label }}
      </span>
      <span
        v-if="dynamicCount && !expandable"
        class="min-w-5 flex-shrink-0 rounded-md bg-ds-shell-panel-strong px-1.5 py-0.5 text-center text-[0.6875rem] font-semibold leading-4"
        :class="isActive ? 'text-ds-shell-accent' : 'text-ds-shell-muted'"
      >
        {{ count }}
      </span>
    </div>
    <span
      v-if="expandable"
      class="size-4 flex-shrink-0 opacity-60 transition duration-150 group-hover/sidebar-menu-item:opacity-100"
      :class="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
      aria-hidden="true"
      @click.stop="emit('toggle')"
    />
  </component>
</template>

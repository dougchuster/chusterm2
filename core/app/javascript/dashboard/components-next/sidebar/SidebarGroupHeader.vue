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
    :is="to ? 'router-link' : 'div'"
    class="sidebar-group-header flex items-center gap-2.5 px-3 py-1.5 rounded-lg min-h-9 min-w-0 transition-colors duration-150 no-underline border-0"
    role="button"
    draggable="false"
    :to="to"
    :title="label"
    :class="{
      'is-current': isActive && !hasActiveChild,
      'has-current-child': hasActiveChild,
      'is-idle': !isActive && !hasActiveChild,
    }"
    @click.stop="emit('toggle')"
  >
    <div v-if="icon" class="relative flex items-center gap-2">
      <Icon v-if="icon" :icon="icon" class="size-[18px] flex-shrink-0" />
      <span
        v-if="showBadge"
        class="size-2 -top-px ltr:-right-px rtl:-left-px bg-n-brand absolute rounded-full border border-n-solid-2"
      />
    </div>
    <div class="flex items-center gap-1.5 flex-grow min-w-0 flex-1">
      <span class="truncate text-[0.875rem] leading-5 font-medium">
        {{ label }}
      </span>
      <span
        v-if="dynamicCount && !expandable"
        class="sidebar-group-header__count text-xs font-medium text-center flex-shrink-0"
        :class="{
          'text-n-slate-12': isActive,
          'text-n-slate-10': !isActive,
        }"
      >
        {{ count }}
      </span>
    </div>
    <span
      v-if="expandable"
      class="size-3.5 flex-shrink-0 opacity-60 transition-colors group-hover/sidebar-menu-item:opacity-100"
      :class="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
      @click.stop="emit('toggle')"
    />
  </component>
</template>

<style scoped>
.sidebar-group-header {
  color: rgb(var(--slate-11));
  text-decoration: none;
  border: none;
}

.sidebar-group-header.is-idle:hover {
  background: rgb(var(--surface-active));
  color: rgb(var(--slate-12));
}

.sidebar-group-header.has-current-child {
  color: rgb(var(--slate-12));
}

.sidebar-group-header.is-current {
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.dark .sidebar-group-header.is-current {
  background: rgb(var(--blue-2) / 0.42);
}

.sidebar-group-header__count {
  min-width: 1.25rem;
  padding: 0.1rem 0.4rem;
  border-radius: 6px;
  background: rgb(var(--slate-3) / 0.5);
  font-size: 0.7rem;
  line-height: 1rem;
}
</style>

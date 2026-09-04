<script setup>
import { computed, onMounted, onUnmounted, watch, nextTick, ref } from 'vue';
import { useSidebarContext, usePopoverState } from './provider';
import { useRoute, useRouter } from 'vue-router';
import Policy from 'dashboard/components/policy.vue';
import Icon from 'next/icon/Icon.vue';
import DsTooltip from 'dashboard/design-system/components/DsTooltip.vue';
import SidebarGroupHeader from './SidebarGroupHeader.vue';
import SidebarGroupLeaf from './SidebarGroupLeaf.vue';
import SidebarSubGroup from './SidebarSubGroup.vue';
import SidebarGroupEmptyLeaf from './SidebarGroupEmptyLeaf.vue';
import SidebarCollapsedPopover from './SidebarCollapsedPopover.vue';

const props = defineProps({
  name: { type: String, required: true },
  label: { type: String, required: true },
  icon: { type: [String, Object, Function], default: null },
  to: { type: Object, default: null },
  activeOn: { type: Array, default: () => [] },
  children: { type: Array, default: undefined },
  getterKeys: { type: Object, default: () => ({}) },
  canPin: { type: Boolean, default: true },
});

const {
  expandedItem,
  setExpandedItem,
  resolvePath,
  resolvePermissions,
  resolveFeatureFlag,
  isAllowed,
  isCollapsed,
  isResizing,
  isPinned,
  togglePin,
} = useSidebarContext();

const {
  activePopover,
  setActivePopover,
  closeActivePopover,
  scheduleClose,
  cancelClose,
} = usePopoverState();

const navigableChildren = computed(() => {
  return props.children?.flatMap(child => child.children || child) || [];
});

const route = useRoute();
const router = useRouter();
const isExpanded = computed(() => expandedItem.value === props.name);
const isExpandable = computed(() => props.children);
const hasChildren = computed(
  () => Array.isArray(props.children) && props.children.length > 0
);

const accessibleItems = computed(() => {
  if (!hasChildren.value) return [];
  return navigableChildren.value.filter(
    child => child.to && isAllowed(child.to)
  );
});

// Use shared popover state - only one popover can be open at a time
const isPopoverOpen = computed(() => activePopover.value === props.name);
const triggerRef = ref(null);
const collapsedPopoverRef = ref(null);
const triggerRect = ref({ top: 0, left: 0, bottom: 0, right: 0 });
const popoverId = computed(
  () =>
    `sidebar-collapsed-${String(props.name)
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, '-')}`
);

const isCurrentPinned = computed(() =>
  typeof isPinned === 'function' ? isPinned(props.name) : false
);

const handleTogglePin = () => {
  if (typeof togglePin === 'function') {
    // If props.to is present, pin it; otherwise find the first accessible child route
    const targetTo = props.to || accessibleItems.value[0]?.to;
    togglePin({
      id: props.name,
      name: props.name,
      label: props.label,
      icon: props.icon,
      to: targetTo,
      activeOn: props.activeOn,
    });
  }
};

const openPopover = async ({ focusFirst = false } = {}) => {
  if (triggerRef.value) {
    const rect = triggerRef.value.getBoundingClientRect();
    triggerRect.value = {
      top: rect.top,
      left: rect.left,
      bottom: rect.bottom,
      right: rect.right,
    };
  }
  setActivePopover(props.name);

  if (focusFirst) {
    await nextTick();
    collapsedPopoverRef.value?.focusFirstItem();
  }
};

const closePopover = async ({ restoreFocus = false } = {}) => {
  if (activePopover.value === props.name) {
    closeActivePopover();
  }

  if (restoreFocus) {
    await nextTick();
    triggerRef.value?.focus();
  }
};

const handleMouseEnter = () => {
  if (!hasChildren.value || isResizing.value) return;
  cancelClose();
  openPopover();
};

const handleMouseLeave = () => {
  if (!hasChildren.value) return;
  scheduleClose(200);
};

const handlePopoverMouseEnter = () => {
  cancelClose();
};

const handlePopoverMouseLeave = () => {
  scheduleClose(100);
};

// Close popover when mouse leaves the window
const handleWindowBlur = () => {
  closeActivePopover();
};

const hasTargetQuery = to => Object.keys(to?.query || {}).length > 0;

const targetQueryMatchesRoute = to => {
  const query = to?.query || {};
  return Object.entries(query).every(([key, value]) => {
    return String(route.query[key] ?? '') === String(value ?? '');
  });
};

const hasAccessibleChildren = computed(() => {
  return accessibleItems.value.length > 0;
});

const isActive = computed(() => {
  if (props.to) {
    if (route.path === resolvePath(props.to)) return true;

    return props.activeOn.includes(route.name);
  }

  return false;
});

const activeChild = computed(() => {
  const exactPathAndQuery = navigableChildren.value.find(child => {
    return (
      child.to &&
      route.path === resolvePath(child.to) &&
      hasTargetQuery(child.to) &&
      targetQueryMatchesRoute(child.to)
    );
  });
  if (exactPathAndQuery) return exactPathAndQuery;

  const pathSame = navigableChildren.value.find(
    child =>
      child.to &&
      route.path === resolvePath(child.to) &&
      (!hasTargetQuery(child.to) || targetQueryMatchesRoute(child.to))
  );
  if (pathSame) return pathSame;

  const activeOnPages = navigableChildren.value.filter(child =>
    child.activeOn?.includes(route.name)
  );

  if (activeOnPages.length > 0) {
    const rankedPage = activeOnPages.find(child => {
      return Object.keys(child.to?.params || {})
        .map(key => {
          return String(child.to.params[key]) === String(route.params[key]);
        })
        .every(match => match);
    });

    return rankedPage ?? activeOnPages[0];
  }

  return navigableChildren.value.find(
    child =>
      child.to &&
      route.path.startsWith(resolvePath(child.to)) &&
      (!hasTargetQuery(child.to) || targetQueryMatchesRoute(child.to))
  );
});

const hasActiveChild = computed(() => {
  return activeChild.value !== undefined;
});

const handleCollapsedClick = () => {
  if (!hasChildren.value || !hasAccessibleChildren.value) return;

  if (isPopoverOpen.value) {
    closePopover({ restoreFocus: true });
    return;
  }

  openPopover({ focusFirst: true });
};

const handleCollapsedKeydown = event => {
  if (!hasChildren.value || !hasAccessibleChildren.value) return;

  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault();
    event.stopPropagation();
    handleCollapsedClick();
    return;
  }

  if (event.key === 'ArrowRight') {
    event.preventDefault();
    event.stopPropagation();
    openPopover({ focusFirst: true });
    return;
  }

  if (event.key === 'Escape' && isPopoverOpen.value) {
    event.preventDefault();
    event.stopPropagation();
    closePopover({ restoreFocus: true });
  }
};

const toggleTrigger = () => {
  if (
    hasAccessibleChildren.value &&
    !isExpanded.value &&
    !hasActiveChild.value
  ) {
    const firstItem = accessibleItems.value[0];
    if (firstItem?.to) {
      router.push(firstItem.to);
    }
  }
  setExpandedItem(props.name);
};

onMounted(async () => {
  await nextTick();
  if (hasActiveChild.value) {
    setExpandedItem(props.name);
  }
  window.addEventListener('blur', handleWindowBlur);
  document.addEventListener('mouseleave', handleWindowBlur);
});

onUnmounted(() => {
  window.removeEventListener('blur', handleWindowBlur);
  document.removeEventListener('mouseleave', handleWindowBlur);
});

watch(
  hasActiveChild,
  hasNewActiveChild => {
    if (hasNewActiveChild && !isExpanded.value) {
      setExpandedItem(props.name);
    }
  },
  { once: true }
);
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Policy
    v-if="!hasChildren || hasAccessibleChildren"
    :permissions="resolvePermissions(to)"
    :feature-flag="resolveFeatureFlag(to)"
    as="li"
    class="grid gap-1.5 text-sm cursor-pointer select-none min-w-0"
  >
    <!-- Collapsed State -->
    <template v-if="isCollapsed">
      <div
        class="relative"
        @mouseenter="handleMouseEnter"
        @mouseleave="handleMouseLeave"
      >
        <DsTooltip :text="label" placement="right" :disabled="isPopoverOpen">
          <component
            :is="to && !hasChildren ? 'router-link' : 'button'"
            ref="triggerRef"
            :to="to && !hasChildren ? to : undefined"
            type="button"
            class="flex size-11 items-center justify-center rounded-xl text-ds-shell-muted transition-colors duration-150 hover:bg-ds-shell-hover hover:text-ds-shell-fg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
            :class="
              isActive || hasActiveChild
                ? 'bg-ds-shell-active text-ds-shell-fg'
                : ''
            "
            :title="label"
            :aria-label="label"
            :aria-current="isActive || hasActiveChild ? 'page' : undefined"
            :aria-haspopup="hasChildren ? 'menu' : undefined"
            :aria-expanded="hasChildren ? isPopoverOpen : undefined"
            :aria-controls="hasChildren ? popoverId : undefined"
            @click="hasChildren ? handleCollapsedClick() : undefined"
            @keydown="handleCollapsedKeydown"
          >
            <Icon v-if="icon" :icon="icon" class="size-5" aria-hidden="true" />
          </component>
        </DsTooltip>
        <SidebarCollapsedPopover
          v-if="hasChildren && isPopoverOpen"
          :id="popoverId"
          ref="collapsedPopoverRef"
          :label="label"
          :children="children"
          :active-child="activeChild"
          :trigger-rect="triggerRect"
          @close="closePopover"
          @mouseenter="handlePopoverMouseEnter"
          @mouseleave="handlePopoverMouseLeave"
        />
      </div>
    </template>
    <!-- Expanded State -->
    <template v-else>
      <SidebarGroupHeader
        :icon="icon"
        :label="label"
        :to="to"
        :getter-keys="getterKeys"
        :is-active="isActive"
        :has-active-child="hasActiveChild"
        :expandable="hasChildren"
        :is-expanded="isExpanded"
        :is-pinned="isCurrentPinned"
        :can-pin="canPin"
        @toggle="toggleTrigger"
        @toggle-pin="handleTogglePin"
      />
      <ul
        v-if="hasChildren"
        v-show="isExpanded || hasActiveChild"
        class="grid m-0 list-none sidebar-group-children min-w-0"
      >
        <template v-for="child in children" :key="child.name">
          <SidebarSubGroup
            v-if="child.children"
            :label="child.label"
            :icon="child.icon"
            :children="child.children"
            :is-expanded="isExpanded"
            :active-child="activeChild"
          />
          <SidebarGroupLeaf
            v-else-if="isAllowed(child.to)"
            v-show="isExpanded || activeChild?.name === child.name"
            v-bind="child"
            :active="activeChild?.name === child.name"
          />
        </template>
      </ul>
      <ul v-else-if="isExpandable && isExpanded">
        <SidebarGroupEmptyLeaf />
      </ul>
    </template>
  </Policy>
</template>

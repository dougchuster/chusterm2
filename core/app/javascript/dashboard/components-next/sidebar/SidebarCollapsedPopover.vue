<script setup>
import { computed, ref, onMounted, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useSidebarContext } from './provider';
import { useMapGetter } from 'dashboard/composables/store';
import Icon from 'next/icon/Icon.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  id: { type: String, required: true },
  label: { type: String, required: true },
  children: { type: Array, default: () => [] },
  activeChild: { type: Object, default: undefined },
  triggerRect: { type: Object, default: () => ({ top: 0, left: 0 }) },
});

const emit = defineEmits(['close', 'mouseenter', 'mouseleave']);

const router = useRouter();
const { isAllowed, sidebarWidth } = useSidebarContext();

const expandedSubGroup = ref(null);
const popoverRef = ref(null);
const topPosition = ref(0);
const isRTL = useMapGetter('accounts/isRTL');
const skipTransition = ref(true);

const toggleSubGroup = name => {
  expandedSubGroup.value = expandedSubGroup.value === name ? null : name;
};

const navigateAndClose = to => {
  router.push(to);
  emit('close');
};

const getMenuItems = () => {
  if (!popoverRef.value) return [];

  return Array.from(
    popoverRef.value.querySelectorAll('[role="menuitem"]:not([disabled])')
  );
};

const focusFirstItem = async () => {
  await nextTick();
  getMenuItems()[0]?.focus();
};

const focusSubGroupItem = async name => {
  await nextTick();
  const subGroupItem = getMenuItems().find(
    item => item.dataset.subgroupParent === name
  );
  subGroupItem?.focus();
};

const expandSubGroupAndFocus = async name => {
  expandedSubGroup.value = name;
  await focusSubGroupItem(name);
};

const collapseSubGroupAndFocus = async name => {
  expandedSubGroup.value = null;
  await nextTick();
  const subGroupTrigger = getMenuItems().find(
    item => item.dataset.subgroupTrigger === name
  );
  subGroupTrigger?.focus();
};

const handleMenuKeydown = event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    event.stopPropagation();
    emit('close', { restoreFocus: true });
    return;
  }

  const currentItem = event.target.closest?.('[role="menuitem"]');
  if (!currentItem) return;

  if (event.key === 'ArrowRight' && currentItem.dataset.subgroupTrigger) {
    event.preventDefault();
    expandSubGroupAndFocus(currentItem.dataset.subgroupTrigger);
    return;
  }

  if (event.key === 'ArrowLeft' && currentItem.dataset.subgroupParent) {
    event.preventDefault();
    collapseSubGroupAndFocus(currentItem.dataset.subgroupParent);
    return;
  }

  const items = getMenuItems();
  const currentIndex = items.indexOf(currentItem);
  const destinationByKey = {
    ArrowDown: (currentIndex + 1) % items.length,
    ArrowUp: (currentIndex - 1 + items.length) % items.length,
    Home: 0,
    End: items.length - 1,
  };
  const destinationIndex = destinationByKey[event.key];

  if (destinationIndex === undefined || destinationIndex < 0) return;

  event.preventDefault();
  items[destinationIndex]?.focus();
};

defineExpose({ focusFirstItem });

const isActive = child => props.activeChild?.name === child.name;

const getAccessibleSubChildren = children =>
  children.filter(c => isAllowed(c.to));

const renderIcon = icon => ({
  component: typeof icon === 'object' ? icon : Icon,
  props: typeof icon === 'string' ? { icon } : null,
});

const transition = computed(() =>
  skipTransition.value
    ? {}
    : {
        enterActiveClass: 'transition-all duration-200 ease-out',
        enterFromClass: 'opacity-0 -translate-y-2 max-h-0',
        enterToClass: 'opacity-100 translate-y-0 max-h-96',
        leaveActiveClass: 'transition-all duration-150 ease-in',
        leaveFromClass: 'opacity-100 translate-y-0 max-h-96',
        leaveToClass: 'opacity-0 -translate-y-2 max-h-0',
      }
);

const accessibleChildren = computed(() => {
  return props.children.filter(child => {
    if (child.children) {
      return child.children.some(subChild => isAllowed(subChild.to));
    }
    return child.to && isAllowed(child.to);
  });
});

onMounted(async () => {
  await nextTick();

  // Auto-expand subgroup if active child is inside it
  if (props.activeChild) {
    const parentGroup = props.children.find(child =>
      child.children?.some(subChild => subChild.name === props.activeChild.name)
    );
    if (parentGroup) {
      expandedSubGroup.value = parentGroup.name;
      // Wait for the subgroup expansion to render before measuring height
      await nextTick();
    }
  }

  if (!props.triggerRect) return;

  const viewportHeight = window.innerHeight;
  const popoverHeight = popoverRef.value?.offsetHeight || 300;
  const { top: triggerTop } = props.triggerRect;

  // Adjust position if popover would overflow viewport
  topPosition.value =
    triggerTop + popoverHeight > viewportHeight - 20
      ? Math.max(20, viewportHeight - popoverHeight - 20)
      : triggerTop;

  await nextTick();
  skipTransition.value = false;
});
</script>

<template>
  <TeleportWithDirection>
    <div
      :id="id"
      ref="popoverRef"
      class="fixed z-[100] min-w-[200px] max-w-[280px]"
      role="menu"
      :aria-label="label"
      :style="{
        [isRTL ? 'right' : 'left']: `${sidebarWidth + 8}px`,
        top: `${topPosition}px`,
      }"
      @mouseenter="emit('mouseenter')"
      @mouseleave="emit('mouseleave')"
      @keydown="handleMenuKeydown"
    >
      <div
        class="w-60 rounded-2xl bg-ds-shell-panel-strong px-3 py-3 text-ds-shell-fg shadow-2xl shadow-black/30 ring-1 ring-inset ring-ds-shell-border backdrop-blur-xl"
      >
        <div
          class="mb-2 border-b border-ds-shell-divider px-3 py-2 text-xs font-semibold uppercase tracking-wide text-ds-shell-muted"
          aria-hidden="true"
        >
          {{ label }}
        </div>
        <ul
          class="m-0 p-0 list-none max-h-[400px] overflow-y-auto no-scrollbar"
          role="none"
        >
          <template v-for="child in accessibleChildren" :key="child.name">
            <!-- SubGroup with children -->
            <li v-if="child.children" class="py-0.5" role="none">
              <button
                type="button"
                class="flex min-h-10 w-full items-center gap-3 rounded-xl px-3 py-2 text-left text-ds-shell-muted transition-colors hover:bg-ds-shell-hover hover:text-ds-shell-fg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus rtl:text-right"
                role="menuitem"
                aria-haspopup="true"
                :aria-expanded="expandedSubGroup === child.name"
                :data-subgroup-trigger="child.name"
                @click="toggleSubGroup(child.name)"
              >
                <Icon
                  v-if="child.icon"
                  :icon="child.icon"
                  class="size-5 flex-shrink-0"
                />
                <span class="flex-1 truncate text-[0.92rem] font-medium">{{
                  child.label
                }}</span>
                <span
                  class="size-4 transition-transform i-lucide-chevron-down"
                  :class="{
                    'rotate-180': expandedSubGroup === child.name,
                  }"
                />
              </button>
              <Transition v-bind="transition">
                <ul
                  v-if="expandedSubGroup === child.name"
                  class="m-0 p-0 list-none ltr:pl-4 rtl:pr-4 mt-1 overflow-hidden"
                  role="group"
                >
                  <li
                    v-for="subChild in getAccessibleSubChildren(child.children)"
                    :key="subChild.name"
                    class="py-0.5"
                    role="none"
                  >
                    <button
                      type="button"
                      class="flex min-h-10 w-full items-center gap-3 rounded-xl px-3 py-2 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus rtl:text-right"
                      role="menuitem"
                      :data-subgroup-parent="child.name"
                      :class="{
                        'bg-ds-shell-active text-ds-shell-fg':
                          isActive(subChild),
                        'text-ds-shell-muted hover:bg-ds-shell-hover hover:text-ds-shell-fg':
                          !isActive(subChild),
                      }"
                      @click="navigateAndClose(subChild.to)"
                    >
                      <component
                        :is="renderIcon(subChild.icon).component"
                        v-if="subChild.icon"
                        v-bind="renderIcon(subChild.icon).props"
                        class="size-5 flex-shrink-0"
                      />
                      <span class="flex-1 truncate">{{ subChild.label }}</span>
                    </button>
                  </li>
                </ul>
              </Transition>
            </li>
            <!-- Direct child item -->
            <li v-else class="py-0.5" role="none">
              <button
                type="button"
                class="flex min-h-10 w-full items-center gap-3 rounded-xl px-3 py-2 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus rtl:text-right"
                role="menuitem"
                :class="{
                  'bg-ds-shell-active text-ds-shell-fg': isActive(child),
                  'text-ds-shell-muted hover:bg-ds-shell-hover hover:text-ds-shell-fg':
                    !isActive(child),
                }"
                @click="navigateAndClose(child.to)"
              >
                <component
                  :is="renderIcon(child.icon).component"
                  v-if="child.icon"
                  v-bind="renderIcon(child.icon).props"
                  class="size-5 flex-shrink-0"
                />
                <span class="flex-1 truncate">{{ child.label }}</span>
              </button>
            </li>
          </template>
        </ul>
      </div>
    </div>
  </TeleportWithDirection>
</template>

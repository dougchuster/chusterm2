<script setup>
import { isVNode, computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import Policy from 'dashboard/components/policy.vue';
import { useSidebarContext } from './provider';

const props = defineProps({
  label: { type: String, required: true },
  to: { type: [String, Object], required: true },
  icon: { type: [String, Object], default: null },
  active: { type: Boolean, default: false },
  component: { type: Function, default: null },
  isNested: { type: Boolean, default: false },
});

const { resolvePermissions, resolveFeatureFlag } = useSidebarContext();

const shouldRenderComponent = computed(() => {
  return typeof props.component === 'function' || isVNode(props.component);
});
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Policy
    :permissions="resolvePermissions(to)"
    :feature-flag="resolveFeatureFlag(to)"
    as="li"
    class="child-item relative min-w-0"
    :class="isNested ? 'ltr:pl-3 rtl:pr-3' : 'ltr:pl-1 rtl:pr-1'"
  >
    <component
      :is="to ? 'router-link' : 'div'"
      :to="to"
      :title="label"
      :aria-current="active ? 'page' : undefined"
      class="group flex min-h-10 min-w-0 items-center border-0 font-inter no-underline transition duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
      :class="[
        isNested
          ? 'gap-2 rounded-lg px-2.5 py-1'
          : 'gap-2.5 rounded-xl px-3 py-1.5',
        active
          ? 'bg-ds-shell-active text-ds-shell-fg'
          : 'text-ds-shell-muted hover:bg-ds-shell-hover hover:text-ds-shell-fg',
      ]"
    >
      <component
        :is="component"
        v-if="shouldRenderComponent"
        :label
        :icon
        :active
      />
      <template v-else>
        <span
          v-if="icon"
          class="grid size-5 flex-shrink-0 place-content-center rounded-full leading-none transition-colors group-hover:text-ds-shell-accent"
          :class="{ 'text-ds-shell-accent': active }"
        >
          <Icon
            :icon="icon"
            :class="isNested ? 'size-3.5' : 'size-4'"
            aria-hidden="true"
          />
        </span>
        <div
          class="min-w-0 flex-1 truncate font-medium"
          :class="
            isNested ? 'text-[0.78rem] leading-5' : 'text-[0.84rem] leading-5'
          "
        >
          {{ label }}
        </div>
      </template>
    </component>
  </Policy>
</template>

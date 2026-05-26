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
    class="sidebar-group-leaf-container child-item relative min-w-0"
    :class="{ 'sidebar-group-leaf-container--nested': isNested }"
  >
    <component
      :is="to ? 'router-link' : 'div'"
      :to="to"
      :title="label"
      class="sidebar-group-leaf flex min-h-8 items-center gap-2.5 px-3 py-1 rounded-lg transition-colors duration-150 group min-w-0 no-underline border-0"
      :class="{
        'is-current': active,
        'is-idle': !active,
        'sidebar-group-leaf--nested': isNested,
      }"
    >
      <component
        :is="component"
        v-if="shouldRenderComponent"
        :label
        :icon
        :active
      />
      <template v-else>
        <span v-if="icon" class="sidebar-group-leaf__icon">
          <Icon :icon="icon" :class="isNested ? 'size-3.5' : 'size-4'" />
        </span>
        <div
          class="flex-1 truncate min-w-0"
          :class="
            isNested ? 'text-[0.78rem] leading-4' : 'text-[0.84rem] leading-5'
          "
        >
          {{ label }}
        </div>
      </template>
    </component>
  </Policy>
</template>

<style scoped>
.sidebar-group-leaf-container {
  padding-block: 0;
  margin-inline-start: 0;
  padding-inline-start: 0.25rem;
}

.sidebar-group-leaf-container--nested {
  padding-inline-start: 0.75rem;
}

.sidebar-group-leaf {
  color: rgb(var(--slate-11));
  text-decoration: none;
  border: none;
}

.sidebar-group-leaf--nested {
  min-height: 2rem;
  gap: 0.55rem;
  padding-block: 0.25rem;
  padding-inline: 0.5rem 0.625rem;
  border-radius: 0.5rem;
}

.sidebar-group-leaf.is-idle:hover {
  background: rgb(var(--surface-active));
  color: rgb(var(--slate-12));
}

.sidebar-group-leaf.is-current {
  color: rgb(var(--slate-12));
  background: rgb(var(--blue-2));
}

.dark .sidebar-group-leaf.is-idle:hover {
  background: rgb(var(--surface-active) / 0.72);
}

.dark .sidebar-group-leaf.is-current {
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2) / 0.42);
}

.sidebar-group-leaf__icon {
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 9999px;
  display: grid;
  place-content: center;
  flex-shrink: 0;
  line-height: 1;
}

.sidebar-group-leaf--nested .sidebar-group-leaf__icon {
  width: 1.15rem;
  height: 1.15rem;
}

.sidebar-group-leaf.is-current .sidebar-group-leaf__icon {
  color: rgb(var(--blue-9));
}

.sidebar-group-leaf.is-idle:hover .sidebar-group-leaf__icon {
  color: rgb(var(--blue-9));
}
</style>

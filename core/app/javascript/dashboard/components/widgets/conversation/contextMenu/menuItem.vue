<script setup>
import { computed } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  option: {
    type: Object,
    default: () => ({}),
  },
  variant: {
    type: String,
    default: 'default',
  },
});

const ICON_MAP = {
  mail: 'i-lucide-mail-open',
  'mail-unread': 'i-lucide-mail',
  checkmark: 'i-lucide-circle-check',
  'arrow-redo': 'i-lucide-rotate-ccw',
  'book-clock': 'i-lucide-circle-pause',
  snooze: 'i-lucide-clock-3',
  warning: 'i-lucide-triangle-alert',
  tag: 'i-lucide-tag',
  'person-add': 'i-lucide-user-plus',
  'people-team-add': 'i-lucide-users-round',
  delete: 'i-lucide-trash-2',
  open: 'i-lucide-external-link',
  copy: 'i-lucide-copy',
};

const icon = computed(() => {
  const iconName = props.option?.icon;
  if (!iconName) return '';
  if (iconName.startsWith('i-')) return iconName;
  return ICON_MAP[iconName] || 'i-lucide-circle';
});
</script>

<template>
  <button
    type="button"
    role="menuitem"
    class="group flex min-h-9 w-full min-w-[12.5rem] items-center gap-2 overflow-hidden rounded-lg px-2.5 py-1.5 text-left text-xs font-medium text-ds-fg-default outline-none transition-colors hover:bg-ds-accent hover:text-ds-fg-on-accent focus-visible:bg-ds-accent-soft focus-visible:text-ds-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
  >
    <Icon
      v-if="variant === 'icon' && icon"
      :icon="icon"
      class="size-3.5 shrink-0"
      aria-hidden="true"
    />
    <span
      v-if="
        (variant === 'label' || variant === 'label-assigned') && option.color
      "
      class="size-4 shrink-0 rounded-full border border-ds-border-strong"
      :style="{ backgroundColor: option.color }"
      aria-hidden="true"
    />
    <Avatar
      v-if="variant === 'agent'"
      :name="option.label"
      :src="option.thumbnail"
      :status="option.status === 'online' ? option.status : null"
      :size="20"
      class="shrink-0"
    />
    <span class="min-w-0 flex-1 truncate">
      {{ option.label }}
    </span>
    <Icon
      v-if="variant === 'label-assigned'"
      icon="i-lucide-check"
      class="mr-1 size-3.5 shrink-0"
      aria-hidden="true"
    />
  </button>
</template>

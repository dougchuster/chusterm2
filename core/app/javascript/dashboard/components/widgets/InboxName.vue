<script setup>
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';

defineProps({
  inbox: {
    type: Object,
    default: () => {},
  },
});
</script>

<template>
  <div :title="inbox.name" class="flex items-center gap-0.5 min-w-0">
    <ChannelIcon
      :inbox="inbox"
      class="size-4 flex-shrink-0 text-ds-fg-subtle"
    />
    <span class="truncate text-label-small text-ds-fg-muted">
      {{ inbox.name }}
    </span>
  </div>
</template>

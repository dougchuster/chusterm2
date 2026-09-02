<script setup>
import { format, fromUnixTime } from 'date-fns';

defineProps({
  label: {
    type: String,
    required: true,
  },
  items: {
    type: Array,
    required: true,
  },
});
const formatDate = timestamp =>
  format(fromUnixTime(timestamp), 'MMM dd, yyyy, hh:mm a');
</script>

<template>
  <div class="flex w-full justify-between gap-4">
    <span
      class="sticky top-0 h-fit min-w-[140px] truncate text-sm font-medium text-ds-fg-muted"
    >
      {{ label }}
    </span>
    <div class="flex w-full flex-col gap-2">
      <time
        v-for="item in items"
        :key="item.id"
        :datetime="new Date(item.created_at * 1000).toISOString()"
        class="text-right text-sm font-normal tabular-nums text-ds-fg-default"
      >
        {{ formatDate(item.created_at) }}
      </time>
      <slot name="showMore" />
    </div>
  </div>
</template>

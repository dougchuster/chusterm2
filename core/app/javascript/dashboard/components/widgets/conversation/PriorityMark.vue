<script>
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';

export default {
  name: 'PriorityMark',
  props: {
    priority: {
      type: String,
      default: '',
      validator: value =>
        [...Object.values(CONVERSATION_PRIORITY), ''].includes(value),
    },
  },
  data() {
    return {
      CONVERSATION_PRIORITY,
    };
  },
  computed: {
    tooltipText() {
      return this.$t(
        `CONVERSATION.PRIORITY.OPTIONS.${this.priority.toUpperCase()}`
      );
    },
    isUrgent() {
      return this.priority === CONVERSATION_PRIORITY.URGENT;
    },
    priorityIcon() {
      return {
        [CONVERSATION_PRIORITY.URGENT]: 'i-lucide-flame',
        [CONVERSATION_PRIORITY.HIGH]: 'i-lucide-signal-high',
        [CONVERSATION_PRIORITY.MEDIUM]: 'i-lucide-signal-medium',
        [CONVERSATION_PRIORITY.LOW]: 'i-lucide-signal-low',
      }[this.priority];
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <span
    v-if="priority"
    v-tooltip="{
      content: tooltipText,
      delay: { show: 1500, hide: 0 },
    }"
    :aria-label="tooltipText"
    class="inline-flex size-4 shrink-0 items-center justify-center rounded"
    :class="{
      'bg-ds-state-danger-soft text-ds-state-danger': isUrgent,
      'bg-ds-bg-active text-ds-fg-muted': !isUrgent,
    }"
  >
    <span class="size-3 shrink-0" :class="[priorityIcon]" aria-hidden="true" />
  </span>
</template>

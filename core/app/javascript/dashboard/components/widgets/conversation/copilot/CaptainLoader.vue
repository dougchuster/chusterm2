<script setup>
import Icon from 'next/icon/Icon.vue';
</script>

<template>
  <span
    role="status"
    :aria-label="$t('CONVERSATION.REPLYBOX.COPILOT_THINKING')"
    class="inline-flex text-ds-accent"
  >
    <Icon
      v-once
      aria-hidden="true"
      icon="i-woot-captain"
      class="animate-bounce motion-reduce:animate-none"
    />
  </span>
</template>

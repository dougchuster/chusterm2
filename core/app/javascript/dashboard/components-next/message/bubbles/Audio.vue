<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';
import { useMessageContext } from '../provider.js';

const { attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});
</script>

<template>
  <BaseBubble class="bg-transparent" data-bubble-name="audio">
    <AudioChip
      :attachment="attachment"
      class="p-2 text-ds-fg-default skip-context-menu"
    />
  </BaseBubble>
</template>

<script setup>
import MessagePreview from 'dashboard/components/widgets/conversation/MessagePreview.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  message: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['dismiss']);
</script>

<template>
  <div
    class="reply-editor mt-2 flex items-center gap-1.5 rounded-lg bg-ds-bg-active py-1 pl-2 pr-1 text-xs tracking-wide text-ds-fg-muted"
  >
    <span
      class="i-lucide-corner-up-left size-3.5 shrink-0"
      aria-hidden="true"
    />
    <div class="mt-px flex-grow truncate text-xs">
      {{ $t('CONVERSATION.REPLYBOX.REPLYING_TO') }}
      <MessagePreview
        :message="message"
        :show-message-type="false"
        :default-empty-message="$t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND')"
        class="inline"
      />
    </div>
    <Button
      v-tooltip="$t('CONVERSATION.REPLYBOX.DISMISS_REPLY')"
      :aria-label="$t('CONVERSATION.REPLYBOX.DISMISS_REPLY')"
      ghost
      xs
      slate
      icon="i-lucide-x"
      class="flex-shrink-0"
      @click.stop="emit('dismiss')"
    />
  </div>
</template>

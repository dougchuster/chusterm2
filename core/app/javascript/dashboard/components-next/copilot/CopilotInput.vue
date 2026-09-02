<script setup>
import { ref, nextTick, onMounted } from 'vue';

const emit = defineEmits(['send']);
const message = ref('');
const textareaRef = ref(null);

const adjustHeight = () => {
  if (!textareaRef.value) return;

  // Reset height to auto to get the correct scrollHeight
  textareaRef.value.style.height = 'auto';
  // Set the height to the scrollHeight
  textareaRef.value.style.height = `${textareaRef.value.scrollHeight}px`;
};

const sendMessage = () => {
  if (message.value.trim()) {
    emit('send', message.value);
    message.value = '';
    // Reset textarea height after sending
    nextTick(() => {
      adjustHeight();
    });
  }
};

const handleInput = () => {
  nextTick(adjustHeight);
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  sendMessage();
};

onMounted(() => {
  nextTick(adjustHeight);
});
</script>

<template>
  <form class="relative" @submit.prevent="sendMessage">
    <textarea
      ref="textareaRef"
      v-model="message"
      :placeholder="$t('CAPTAIN.COPILOT.SEND_MESSAGE')"
      class="reset-base mb-0 max-h-[200px] w-full resize-none overflow-hidden rounded-xl border border-ds-border-subtle bg-ds-bg-surface py-3 text-sm text-ds-fg-default outline-none placeholder:text-ds-fg-subtle focus:border-ds-border-focus focus:ring-2 focus:ring-ds-border-focus/30 ltr:pl-4 ltr:pr-12 rtl:pl-12 rtl:pr-4"
      rows="1"
      @input="handleInput"
      @keydown.enter.exact="handleEnterKey"
    />
    <button
      :aria-label="$t('CAPTAIN.COPILOT.SEND_MESSAGE')"
      :disabled="!message.trim()"
      class="absolute top-1/2 flex size-9 -translate-y-1/2 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-40 ltr:right-1 rtl:left-1"
      type="submit"
    >
      <i class="i-lucide-arrow-up size-4" aria-hidden="true" />
    </button>
  </form>
</template>

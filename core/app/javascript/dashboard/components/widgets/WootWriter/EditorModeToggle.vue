<script setup>
import { computed } from 'vue';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isReplyRestricted: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['setMode']);

/**
 * Computed boolean indicating if the editor is in private note mode
 * When isReplyRestricted is true, force switch to private note
 * Otherwise, respect the current mode prop
 * @type {ComputedRef<boolean>}
 */
const isPrivate = computed(() => {
  if (props.isReplyRestricted) {
    // Force switch to private note when replies are restricted
    return true;
  }
  // Otherwise respect the current mode
  return props.mode === REPLY_EDITOR_MODES.NOTE;
});

const setMode = mode => {
  if (props.disabled || mode === props.mode) return;
  if (mode === REPLY_EDITOR_MODES.REPLY && props.isReplyRestricted) return;
  emit('setMode', mode);
};
</script>

<template>
  <div
    role="group"
    :aria-label="$t('CONVERSATION.REPLYBOX.CHANGE_MODE')"
    class="relative z-0 inline-grid h-8 w-auto grid-cols-2 items-center rounded-lg bg-ds-bg-sunken p-1 text-xs font-semibold text-ds-fg-muted ring-1 ring-inset ring-ds-border-subtle transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-60"
  >
    <button
      type="button"
      class="z-10 inline-flex h-6 items-center justify-center whitespace-nowrap rounded-md px-2 transition-colors duration-150"
      :class="
        !isPrivate
          ? 'bg-ds-bg-surface text-ds-fg-default shadow-sm'
          : 'text-ds-fg-muted'
      "
      :disabled="disabled || isReplyRestricted"
      :aria-pressed="!isPrivate"
      @click="setMode(REPLY_EDITOR_MODES.REPLY)"
    >
      {{ $t('CONVERSATION.REPLYBOX.REPLY') }}
    </button>
    <button
      type="button"
      class="z-10 inline-flex h-6 items-center justify-center whitespace-nowrap rounded-md px-2 transition-colors duration-150"
      :class="
        isPrivate
          ? 'bg-ds-state-warning-soft text-ds-state-warning shadow-sm'
          : 'text-ds-fg-muted'
      "
      :disabled="disabled"
      :aria-pressed="isPrivate"
      @click="setMode(REPLY_EDITOR_MODES.NOTE)"
    >
      {{ $t('CONVERSATION.REPLYBOX.PRIVATE_NOTE') }}
    </button>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from './provider.js';
import { hasOneDayPassed } from 'shared/helpers/timeHelper';
import { ORIENTATION, MESSAGE_STATUS } from './constants';

defineProps({
  error: { type: String, required: true },
});

const emit = defineEmits(['retry']);

const { orientation, status, createdAt, content, attachments } =
  useMessageContext();

const { t } = useI18n();

const canRetry = computed(() => {
  const hasContent = content.value !== null;
  const hasAttachments = attachments.value && attachments.value.length > 0;
  return !hasOneDayPassed(createdAt.value) && (hasContent || hasAttachments);
});
</script>

<template>
  <div class="flex items-center gap-1.5 text-xs text-ds-state-danger">
    <span>{{ t('CHAT_LIST.FAILED_TO_SEND') }}</span>
    <div class="group relative">
      <button
        type="button"
        :aria-label="error"
        class="grid size-6 place-content-center rounded-md bg-ds-state-danger-soft outline-none transition-colors hover:bg-ds-state-danger-soft/70 focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      >
        <Icon
          icon="i-lucide-alert-triangle"
          class="size-3.5 text-ds-state-danger"
        />
      </button>
      <div
        role="tooltip"
        class="invisible absolute bottom-7 z-20 w-56 break-words rounded-xl bg-ds-bg-elevated px-4 py-3 text-xs text-ds-fg-default opacity-0 shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle transition-all group-hover:visible group-hover:opacity-100 group-focus-within:visible group-focus-within:opacity-100"
        :class="{
          'ltr:left-0 rtl:right-0': orientation === ORIENTATION.LEFT,
          'ltr:right-0 rtl:left-0': orientation === ORIENTATION.RIGHT,
        }"
      >
        {{ error }}
      </div>
    </div>
    <button
      v-if="canRetry"
      type="button"
      :aria-label="t('CHAT_LIST.SEARCH.RETRY')"
      :disabled="status !== MESSAGE_STATUS.FAILED"
      class="grid size-6 place-content-center rounded-md bg-ds-state-danger-soft outline-none transition-colors hover:bg-ds-state-danger-soft/70 focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
      @click="emit('retry')"
    >
      <Icon icon="i-lucide-refresh-ccw" class="size-3.5 text-ds-state-danger" />
    </button>
  </div>
</template>

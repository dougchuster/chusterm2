<script setup>
import { computed, ref } from 'vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  quotedEmailText: {
    type: String,
    required: true,
  },
  previewText: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['toggle']);

const { t } = useI18n();
const { formatMessage } = useMessageFormatter();

const isExpanded = ref(false);

const formattedQuotedEmailText = computed(() => {
  if (!props.quotedEmailText) {
    return '';
  }
  return formatMessage(props.quotedEmailText, false, false, true);
});

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value;
};

const expandLabel = computed(() =>
  isExpanded.value
    ? t('CONVERSATION.REPLYBOX.QUOTED_REPLY.COLLAPSE')
    : t('CONVERSATION.REPLYBOX.QUOTED_REPLY.EXPAND')
);
</script>

<template>
  <div class="mt-2">
    <div
      class="relative rounded-xl bg-ds-bg-sunken px-3 py-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-subtle"
    >
      <div
        class="absolute top-2 z-10 flex items-center gap-1 ltr:right-2 rtl:left-2"
      >
        <NextButton
          v-tooltip="expandLabel"
          type="button"
          :aria-label="expandLabel"
          :aria-expanded="isExpanded"
          color="primary"
          variant="ghost"
          xs
          :icon="isExpanded ? 'i-lucide-minimize' : 'i-lucide-maximize'"
          @click="toggleExpand"
        />
        <NextButton
          v-tooltip="t('CONVERSATION.REPLYBOX.QUOTED_REPLY.REMOVE_PREVIEW')"
          type="button"
          :aria-label="t('CONVERSATION.REPLYBOX.QUOTED_REPLY.REMOVE_PREVIEW')"
          color="primary"
          variant="ghost"
          xs
          icon="i-lucide-x"
          @click="emit('toggle')"
        />
      </div>
      <div
        v-dompurify-html="formattedQuotedEmailText"
        role="button"
        tabindex="0"
        :aria-label="expandLabel"
        :aria-expanded="isExpanded"
        class="prose prose-sm w-full max-w-none cursor-pointer break-words rounded-md outline-none ltr:pr-8 rtl:pl-8 [&_a]:text-ds-accent [&_p]:text-ds-fg-default [&_strong]:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        :class="{
          'line-clamp-1': !isExpanded,
          'max-h-60 overflow-y-auto': isExpanded,
        }"
        :title="previewText"
        @click="toggleExpand"
        @keydown.enter.prevent="toggleExpand"
        @keydown.space.prevent="toggleExpand"
      />
    </div>
  </div>
</template>

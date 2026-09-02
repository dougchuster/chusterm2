<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getFileInfo } from '@ChusteRM/utils';

import FileIcon from 'next/icon/FileIcon.vue';
import Icon from 'next/icon/Icon.vue';

const { attachment } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const fileDetails = computed(() => {
  return getFileInfo(attachment?.dataUrl || '');
});

const displayFileName = computed(() => {
  const { base, type } = fileDetails.value;
  const truncatedName = (str, maxLength, hasExt) =>
    str.length > maxLength
      ? `${str.substring(0, maxLength).trimEnd()}${hasExt ? '..' : '...'}`
      : str;

  return type
    ? `${truncatedName(base, 12, true)}.${type}`
    : truncatedName(base, 14, false);
});

const textColorClass = computed(() => {
  const colorMap = {
    csv: 'text-ds-state-warning',
    doc: 'text-ds-state-info',
    docx: 'text-ds-state-info',
    odt: 'text-ds-state-info',
    pdf: 'text-ds-state-danger',
    ppt: 'text-ds-state-warning',
    pptx: 'text-ds-state-warning',
    rtf: 'text-ds-state-info',
    xls: 'text-ds-state-success',
    xlsx: 'text-ds-state-success',
  };

  return colorMap[fileDetails.value.type] || 'text-ds-fg-default';
});
</script>

<template>
  <div
    class="flex h-10 items-center gap-2 overflow-hidden rounded-xl bg-ds-bg-elevated px-2 shadow-[var(--ds-shadow-xs)] ring-1 ring-inset ring-ds-border-subtle"
  >
    <FileIcon class="flex-shrink-0" :file-type="fileDetails.type" />
    <span
      class="min-w-0 max-w-36 flex-1 truncate text-sm font-medium"
      :title="fileDetails.name"
      :class="textColorClass"
    >
      {{ displayFileName }}
    </span>
    <a
      v-tooltip="t('CONVERSATION.DOWNLOAD')"
      :aria-label="t('CONVERSATION.DOWNLOAD')"
      class="grid size-8 flex-shrink-0 place-content-center rounded-lg text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      :href="attachment.dataUrl"
      rel="noreferrer noopener nofollow"
      target="_blank"
    >
      <Icon icon="i-lucide-download" />
    </a>
  </div>
</template>

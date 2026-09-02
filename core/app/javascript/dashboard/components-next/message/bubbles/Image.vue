<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import MediaUnderstandingStatus from 'next/message/MediaUnderstandingStatus.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import { downloadFile } from '@ChusteRM/utils';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const { t } = useI18n();

const { filteredCurrentChatAttachments, attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry();

const showGallery = ref(false);
const isDownloading = ref(false);

onMounted(() => {
  if (attachment.value?.dataUrl) {
    loadWithRetry(attachment.value.dataUrl);
  }
});

const downloadAttachment = async () => {
  const { fileType, dataUrl, extension } = attachment.value;
  try {
    isDownloading.value = true;
    await downloadFile({ url: dataUrl, type: fileType, extension });
  } catch (error) {
    useAlert(t('GALLERY_VIEW.ERROR_DOWNLOADING'));
  } finally {
    isDownloading.value = false;
  }
};

const handleImageError = () => {
  hasError.value = true;
};
</script>

<template>
  <BaseBubble class="overflow-hidden p-3" data-bubble-name="image">
    <div v-if="hasError" class="flex items-center gap-1 text-center rounded-lg">
      <Icon icon="i-lucide-circle-off" class="text-ds-fg-muted" />
      <p class="mb-0 text-ds-fg-muted">
        {{ $t('COMPONENTS.MEDIA.IMAGE_UNAVAILABLE') }}
      </p>
    </div>
    <div v-else-if="isLoaded" class="group relative overflow-hidden rounded-lg">
      <button
        type="button"
        :aria-label="$t('EMAIL_HEADER.EXPAND')"
        class="block rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="showGallery = true"
      >
        <img
          alt=""
          class="skip-context-menu"
          :src="attachment.dataUrl"
          :width="attachment.width"
          :height="attachment.height"
        />
      </button>
      <div
        class="pointer-events-none absolute inset-0 bg-gradient-to-tl from-ds-bg-canvas/55 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100 group-focus-within:opacity-100"
      />
      <MediaUnderstandingStatus
        :attachment="attachment"
        overlay
        class="absolute left-2 bottom-2 max-w-[calc(100%-5.5rem)]"
      />
      <div
        class="absolute bottom-2 right-2 flex gap-2 opacity-0 transition-opacity group-hover:opacity-100 group-focus-within:opacity-100"
      >
        <button
          type="button"
          :aria-label="$t('EMAIL_HEADER.EXPAND')"
          class="grid size-8 place-content-center rounded-lg bg-ds-bg-elevated/90 text-ds-fg-default shadow-[var(--ds-shadow-sm)] outline-none backdrop-blur transition-colors hover:bg-ds-bg-hover focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          @click="showGallery = true"
        >
          <Icon icon="i-lucide-expand" class="size-4" />
        </button>
        <button
          type="button"
          :aria-label="$t('CONVERSATION.DOWNLOAD')"
          class="grid size-8 place-content-center rounded-lg bg-ds-bg-elevated/90 text-ds-fg-default shadow-[var(--ds-shadow-sm)] outline-none backdrop-blur transition-colors hover:bg-ds-bg-hover focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isDownloading"
          @click="downloadAttachment"
        >
          <Icon
            :icon="
              isDownloading ? 'i-lucide-loader-circle' : 'i-lucide-download'
            "
            class="size-4"
            :class="{ 'animate-spin': isDownloading }"
          />
        </button>
      </div>
    </div>
  </BaseBubble>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleImageError"
    @close="() => (showGallery = false)"
  />
</template>

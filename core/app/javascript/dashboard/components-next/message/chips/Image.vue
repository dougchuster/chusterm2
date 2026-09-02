<script setup>
import { ref } from 'vue';
import Icon from 'next/icon/Icon.vue';
import MediaUnderstandingStatus from 'next/message/MediaUnderstandingStatus.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});
const hasError = ref(false);
const showGallery = ref(false);
const galleryAriaLabel = 'Abrir imagem';

const { filteredCurrentChatAttachments } = useMessageContext();

const handleError = () => {
  hasError.value = true;
};
</script>

<template>
  <button
    type="button"
    :aria-label="galleryAriaLabel"
    class="relative size-[72px] overflow-hidden rounded-xl outline-none ring-1 ring-inset ring-ds-border-subtle transition-shadow focus-visible:ring-2 focus-visible:ring-ds-border-focus"
    @click="showGallery = true"
  >
    <div
      v-if="hasError"
      class="flex size-full flex-col items-center justify-center gap-1 rounded-lg bg-ds-bg-sunken text-center text-xs text-ds-fg-muted"
    >
      <Icon icon="i-lucide-circle-off" class="text-ds-fg-muted" />
      {{ $t('COMPONENTS.MEDIA.LOADING_FAILED') }}
    </div>
    <img
      v-else
      alt=""
      class="size-full object-cover skip-context-menu"
      :src="attachment.dataUrl"
      @error="handleError"
    />
    <MediaUnderstandingStatus
      :attachment="attachment"
      overlay
      class="absolute inset-x-1 bottom-1 justify-center [&>span:last-child]:sr-only"
    />
  </button>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleError"
    @close="() => (showGallery = false)"
  />
</template>

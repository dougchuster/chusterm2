<script setup>
import { ref } from 'vue';
import Icon from 'next/icon/Icon.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});

const showGallery = ref(false);
const galleryAriaLabel = 'Abrir vídeo';

const { filteredCurrentChatAttachments } = useMessageContext();
</script>

<template>
  <button
    type="button"
    :aria-label="galleryAriaLabel"
    class="group relative size-[72px] overflow-hidden rounded-xl outline-none ring-1 ring-inset ring-ds-border-subtle transition-shadow focus-visible:ring-2 focus-visible:ring-ds-border-focus"
    @click="showGallery = true"
  >
    <video
      :src="attachment.dataUrl"
      class="size-full object-cover"
      muted
      playsInline
    />
    <div
      class="absolute w-full h-full inset-0 p-1 flex items-center justify-center"
    >
      <div
        class="grid size-8 place-content-center overflow-hidden rounded-full bg-ds-bg-canvas/75 text-ds-fg-default shadow-[var(--ds-shadow-md)] backdrop-blur-sm"
      >
        <Icon icon="i-lucide-play" class="size-4" />
      </div>
    </div>
  </button>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="onError"
    @close="() => (showGallery = false)"
  />
</template>

<script setup>
import { ref, computed, onMounted, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import { useStoreGetters } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useImageZoom } from 'dashboard/composables/useImageZoom';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import { downloadFile } from '@ChusteRM/utils';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  allAttachments: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['close']);
const show = defineModel('show', { type: Boolean, default: false });

const { t } = useI18n();
const getters = useStoreGetters();

const galleryActionLabels = {
  zoomIn: 'Ampliar imagem',
  zoomOut: 'Reduzir imagem',
  rotateLeft: 'Girar para a esquerda',
  rotateRight: 'Girar para a direita',
  previous: 'Anexo anterior',
  next: 'Próximo anexo',
  media: 'Mídia da conversa',
};

const ALLOWED_FILE_TYPES = {
  IMAGE: 'image',
  VIDEO: 'video',
  IG_REEL: 'ig_reel',
  AUDIO: 'audio',
};

const isDownloading = ref(false);
const activeAttachment = ref({});
const activeFileType = ref('');
const activeImageIndex = ref(
  props.allAttachments.findIndex(
    attachment => attachment.message_id === props.attachment.message_id
  ) || 0
);

const imageRef = useTemplateRef('imageRef');

const {
  imageWrapperStyle,
  imageStyle,
  onRotate,
  activeImageRotation,
  onZoom,
  onDoubleClickZoomImage,
  onWheelImageZoom,
  onMouseMove,
  onMouseLeave,
  resetZoomAndRotation,
} = useImageZoom(imageRef);

const currentUser = computed(() => getters.getCurrentUser.value);
const hasMoreThanOneAttachment = computed(
  () => props.allAttachments.length > 1
);

const readableTime = computed(() => {
  const { created_at: createdAt } = activeAttachment.value;
  if (!createdAt) return '';
  return messageTimestamp(createdAt, 'LLL d yyyy, h:mm a') || '';
});

const isImage = computed(
  () => activeFileType.value === ALLOWED_FILE_TYPES.IMAGE
);
const isVideo = computed(() =>
  [ALLOWED_FILE_TYPES.VIDEO, ALLOWED_FILE_TYPES.IG_REEL].includes(
    activeFileType.value
  )
);
const isAudio = computed(
  () => activeFileType.value === ALLOWED_FILE_TYPES.AUDIO
);

const senderDetails = computed(() => {
  const {
    name,
    available_name: availableName,
    avatar_url,
    thumbnail,
    id,
  } = activeAttachment.value?.sender || props.attachment?.sender || {};

  return {
    name: currentUser.value?.id === id ? 'You' : name || availableName || '',
    avatar: thumbnail || avatar_url || '',
  };
});

const fileNameFromDataUrl = computed(() => {
  const { data_url: dataUrl } = activeAttachment.value;
  if (!dataUrl) return '';

  const fileName = dataUrl.split('/').pop();
  return fileName ? decodeURIComponent(fileName) : '';
});

const onClose = () => emit('close');

const setImageAndVideoSrc = attachment => {
  const { file_type: type } = attachment;
  if (!Object.values(ALLOWED_FILE_TYPES).includes(type)) return;

  activeAttachment.value = attachment;
  activeFileType.value = type;
};

const onClickChangeAttachment = (attachment, index) => {
  if (!attachment) return;

  activeImageIndex.value = index;
  setImageAndVideoSrc(attachment);
  resetZoomAndRotation();
};

const onClickDownload = async () => {
  const { file_type: type, data_url: url, extension } = activeAttachment.value;
  if (!Object.values(ALLOWED_FILE_TYPES).includes(type)) return;

  try {
    isDownloading.value = true;
    await downloadFile({ url, type, extension });
  } catch (error) {
    useAlert(t('GALLERY_VIEW.ERROR_DOWNLOADING'));
  } finally {
    isDownloading.value = false;
  }
};

const keyboardEvents = {
  Escape: { action: onClose },
  ArrowLeft: {
    action: () => {
      onClickChangeAttachment(
        props.allAttachments[activeImageIndex.value - 1],
        activeImageIndex.value - 1
      );
    },
  },
  ArrowRight: {
    action: () => {
      onClickChangeAttachment(
        props.allAttachments[activeImageIndex.value + 1],
        activeImageIndex.value + 1
      );
    },
  },
};

useKeyboardEvents(keyboardEvents);

onMounted(() => {
  setImageAndVideoSrc(props.attachment);
});
</script>

<template>
  <TeleportWithDirection to="body">
    <woot-modal
      v-model:show="show"
      full-width
      :show-close-button="false"
      :on-close="onClose"
    >
      <div
        class="flex h-[inherit] w-[inherit] select-none flex-col overflow-hidden bg-ds-bg-canvas text-ds-fg-default"
        @click="onClose"
      >
        <header
          class="z-10 flex min-h-16 w-full items-center justify-end gap-2 bg-ds-bg-elevated/95 px-2 py-2 shadow-[var(--ds-shadow-xs)] backdrop-blur sm:justify-between sm:px-6"
          @click.stop
        >
          <div
            v-if="senderDetails"
            class="hidden min-w-0 items-center sm:flex sm:min-w-[15rem] sm:shrink-0"
          >
            <Avatar
              v-if="senderDetails.avatar"
              :name="senderDetails.name"
              :src="senderDetails.avatar"
              :size="40"
              rounded-full
              class="flex-shrink-0"
            />
            <div class="flex flex-col ml-2 rtl:ml-0 rtl:mr-2 overflow-hidden">
              <h3 class="text-base leading-5 m-0 font-medium">
                <span
                  class="overflow-hidden text-ellipsis whitespace-nowrap font-manrope text-ds-fg-default"
                >
                  {{ senderDetails.name }}
                </span>
              </h3>
              <span
                class="text-ellipsis whitespace-nowrap text-xs text-ds-fg-muted"
              >
                {{ readableTime }}
              </span>
            </div>
          </div>

          <div
            class="mx-2 hidden flex-1 truncate px-2 text-center text-sm font-medium text-ds-fg-default lg:block"
          >
            <span v-dompurify-html="fileNameFromDataUrl" class="truncate" />
          </div>

          <div class="ml-2 flex shrink-0 items-center gap-1">
            <NextButton
              v-if="isImage"
              type="button"
              :aria-label="galleryActionLabels.zoomIn"
              icon="i-lucide-zoom-in"
              color="primary"
              variant="ghost"
              size="sm"
              @click="onZoom(0.1)"
            />
            <NextButton
              v-if="isImage"
              type="button"
              :aria-label="galleryActionLabels.zoomOut"
              icon="i-lucide-zoom-out"
              color="primary"
              variant="ghost"
              size="sm"
              @click="onZoom(-0.1)"
            />
            <NextButton
              v-if="isImage"
              type="button"
              :aria-label="galleryActionLabels.rotateLeft"
              icon="i-lucide-rotate-ccw"
              color="primary"
              variant="ghost"
              size="sm"
              @click="onRotate('counter-clockwise')"
            />
            <NextButton
              v-if="isImage"
              type="button"
              :aria-label="galleryActionLabels.rotateRight"
              icon="i-lucide-rotate-cw"
              color="primary"
              variant="ghost"
              size="sm"
              @click="onRotate('clockwise')"
            />
            <NextButton
              type="button"
              :aria-label="t('CONVERSATION.DOWNLOAD')"
              icon="i-lucide-download"
              color="primary"
              variant="ghost"
              size="sm"
              :is-loading="isDownloading"
              :disabled="isDownloading"
              @click="onClickDownload"
            />
            <NextButton
              type="button"
              :aria-label="t('GENERAL.CLOSE')"
              icon="i-lucide-x"
              color="primary"
              variant="ghost"
              size="sm"
              @click="onClose"
            />
          </div>
        </header>

        <main class="flex items-stretch flex-1 h-full overflow-hidden">
          <div class="flex w-12 shrink-0 items-center justify-center sm:w-16">
            <NextButton
              v-if="hasMoreThanOneAttachment"
              type="button"
              :aria-label="galleryActionLabels.previous"
              icon="ltr:i-lucide-chevron-left rtl:i-lucide-chevron-right"
              class="z-10"
              color="primary"
              variant="faded"
              lg
              :disabled="activeImageIndex === 0"
              @click.stop="
                onClickChangeAttachment(
                  allAttachments[activeImageIndex - 1],
                  activeImageIndex - 1
                )
              "
            />
          </div>

          <div class="flex-1 flex items-center justify-center overflow-hidden">
            <div
              v-if="isImage"
              :style="imageWrapperStyle"
              class="flex items-center justify-center origin-center"
              :class="{
                // Adjust dimensions when rotated 90/270 degrees to maintain visibility
                // and prevent image from overflowing container in different aspect ratios
                'w-[calc(100dvh-8rem)] h-[calc(100dvw-7rem)]':
                  activeImageRotation % 180 !== 0,
                'size-full': activeImageRotation % 180 === 0,
              }"
            >
              <img
                ref="imageRef"
                :key="activeAttachment.message_id"
                :src="activeAttachment.data_url"
                :alt="fileNameFromDataUrl || galleryActionLabels.media"
                :style="imageStyle"
                class="max-h-full max-w-full object-contain duration-100 ease-in-out transform select-none"
                @click.stop
                @dblclick.stop="onDoubleClickZoomImage"
                @wheel.prevent.stop="onWheelImageZoom"
                @mousemove="onMouseMove"
                @mouseleave="onMouseLeave"
              />
            </div>

            <video
              v-if="isVideo"
              :key="activeAttachment.message_id"
              :src="activeAttachment.data_url"
              :aria-label="fileNameFromDataUrl || galleryActionLabels.media"
              controls
              playsInline
              class="max-h-full max-w-full object-contain"
              @click.stop
            />

            <audio
              v-if="isAudio"
              :key="activeAttachment.message_id"
              :aria-label="fileNameFromDataUrl || galleryActionLabels.media"
              controls
              class="w-full max-w-md"
              @click.stop
            >
              <source :src="`${activeAttachment.data_url}?t=${Date.now()}`" />
            </audio>
          </div>

          <div class="flex w-12 shrink-0 items-center justify-center sm:w-16">
            <NextButton
              v-if="hasMoreThanOneAttachment"
              type="button"
              :aria-label="galleryActionLabels.next"
              icon="ltr:i-lucide-chevron-right rtl:i-lucide-chevron-left"
              class="z-10"
              color="primary"
              variant="faded"
              lg
              :disabled="activeImageIndex === allAttachments.length - 1"
              @click.stop="
                onClickChangeAttachment(
                  allAttachments[activeImageIndex + 1],
                  activeImageIndex + 1
                )
              "
            />
          </div>
        </main>

        <footer
          class="z-10 flex h-12 items-center justify-center bg-ds-bg-elevated/90 shadow-[var(--ds-shadow-xs)]"
        >
          <div
            aria-live="polite"
            class="flex items-center justify-center rounded-full bg-ds-bg-sunken px-3 py-1 text-sm font-medium tabular-nums text-ds-fg-default ring-1 ring-inset ring-ds-border-subtle"
          >
            {{ `${activeImageIndex + 1} / ${allAttachments.length}` }}
          </div>
        </footer>
      </div>
    </woot-modal>
  </TeleportWithDirection>
</template>

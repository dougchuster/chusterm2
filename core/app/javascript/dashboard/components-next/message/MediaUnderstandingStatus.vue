<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  attachment: {
    type: Object,
    default: () => ({}),
  },
  overlay: {
    type: Boolean,
    default: false,
  },
});

const valueFor = (camelKey, snakeKey) =>
  props.attachment?.[camelKey] ?? props.attachment?.[snakeKey];

const fileType = computed(() => valueFor('fileType', 'file_type'));
const mediaStatus = computed(() =>
  valueFor('mediaUnderstandingStatus', 'media_understanding_status')
);
const transcribedText = computed(() =>
  valueFor('transcribedText', 'transcribed_text')
);
const imageDescription = computed(() =>
  valueFor('imageDescription', 'image_description')
);
const ocrText = computed(() => valueFor('ocrText', 'ocr_text'));
const documentGuess = computed(() =>
  valueFor('documentGuess', 'document_guess')
);

const statusConfig = computed(() => {
  if (fileType.value === 'audio') {
    if (transcribedText.value) {
      return {
        label: 'Áudio transcrito',
        icon: 'i-lucide-check-circle-2',
        className: 'bg-ds-state-success-soft text-ds-state-success',
      };
    }

    if (!mediaStatus.value) {
      return null;
    }

    if (mediaStatus.value === 'failed') {
      return {
        label: 'Falha na transcrição',
        icon: 'i-lucide-circle-alert',
        className: 'bg-ds-state-danger-soft text-ds-state-danger',
      };
    }

    if (mediaStatus.value === 'skipped') {
      return {
        label: 'Áudio não transcrito',
        icon: 'i-lucide-circle-minus',
        className: 'bg-ds-bg-sunken text-ds-fg-muted',
      };
    }

    if (mediaStatus.value !== 'processing') {
      return null;
    }

    return {
      label: 'Transcrevendo áudio',
      icon: 'i-lucide-loader-circle animate-spin',
      className: 'bg-ds-state-info-soft text-ds-state-info',
    };
  }

  if (!mediaStatus.value && !imageDescription.value && !ocrText.value) {
    return null;
  }

  if (mediaStatus.value === 'failed') {
    return {
      label: 'Falha na análise',
      icon: 'i-lucide-circle-alert',
      className: 'bg-ds-state-danger-soft text-ds-state-danger',
    };
  }

  if (mediaStatus.value === 'skipped') {
    return {
      label: 'Mídia não analisada',
      icon: 'i-lucide-circle-minus',
      className: 'bg-ds-bg-sunken text-ds-fg-muted',
    };
  }

  if (
    mediaStatus.value === 'processed' ||
    imageDescription.value ||
    ocrText.value
  ) {
    return {
      label: documentGuess.value
        ? `Documento: ${documentGuess.value}`
        : 'Imagem analisada',
      icon: 'i-lucide-sparkles',
      className: 'bg-ds-state-success-soft text-ds-state-success',
    };
  }

  return {
    label: 'Analisando mídia',
    icon: 'i-lucide-loader-circle animate-spin',
    className: 'bg-ds-state-info-soft text-ds-state-info',
  };
});
</script>

<template>
  <span
    v-show="statusConfig"
    role="status"
    aria-live="polite"
    class="inline-flex max-w-full items-center gap-1 rounded-lg px-2 py-1 text-xs font-medium ring-1 ring-inset ring-current/15"
    :class="[
      statusConfig?.className,
      overlay ? 'shadow-[var(--ds-shadow-xs)] backdrop-blur' : '',
    ]"
  >
    <span :class="statusConfig?.icon" class="size-3.5 shrink-0" />
    <span class="truncate">{{ statusConfig?.label }}</span>
  </span>
</template>

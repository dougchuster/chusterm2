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
        label: 'Audio transcrito',
        icon: 'i-lucide-check-circle-2',
        className:
          'bg-emerald-50 text-emerald-700 ring-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-300 dark:ring-emerald-900',
      };
    }

    if (!mediaStatus.value) {
      return null;
    }

    if (mediaStatus.value === 'failed') {
      return {
        label: 'Falha na transcricao',
        icon: 'i-lucide-circle-alert',
        className:
          'bg-ruby-50 text-ruby-700 ring-ruby-200 dark:bg-ruby-950/40 dark:text-ruby-300 dark:ring-ruby-900',
      };
    }

    if (mediaStatus.value === 'skipped') {
      return {
        label: 'Audio nao transcrito',
        icon: 'i-lucide-circle-minus',
        className: 'bg-n-alpha-2 text-n-slate-11 ring-n-weak',
      };
    }

    if (mediaStatus.value !== 'processing') {
      return null;
    }

    return {
      label: 'Transcrevendo audio',
      icon: 'i-lucide-loader-circle animate-spin',
      className:
        'bg-sky-50 text-sky-700 ring-sky-200 dark:bg-sky-950/40 dark:text-sky-300 dark:ring-sky-900',
    };
  }

  if (!mediaStatus.value && !imageDescription.value && !ocrText.value) {
    return null;
  }

  if (mediaStatus.value === 'failed') {
    return {
      label: 'Falha na analise',
      icon: 'i-lucide-circle-alert',
      className:
        'bg-ruby-50 text-ruby-700 ring-ruby-200 dark:bg-ruby-950/40 dark:text-ruby-300 dark:ring-ruby-900',
    };
  }

  if (mediaStatus.value === 'skipped') {
    return {
      label: 'Mídia não analisada',
      icon: 'i-lucide-circle-minus',
      className: 'bg-n-alpha-2 text-n-slate-11 ring-n-weak',
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
      className:
        'bg-emerald-50 text-emerald-700 ring-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-300 dark:ring-emerald-900',
    };
  }

  return {
    label: 'Analisando midia',
    icon: 'i-lucide-loader-circle animate-spin',
    className:
      'bg-sky-50 text-sky-700 ring-sky-200 dark:bg-sky-950/40 dark:text-sky-300 dark:ring-sky-900',
  };
});
</script>

<template>
  <span
    v-show="statusConfig"
    class="inline-flex max-w-full items-center gap-1 rounded px-2 py-1 text-xs font-medium ring-1"
    :class="[
      statusConfig?.className,
      overlay ? 'bg-opacity-95 shadow-sm backdrop-blur' : '',
    ]"
  >
    <span :class="statusConfig?.icon" class="size-3.5 shrink-0" />
    <span class="truncate">{{ statusConfig?.label }}</span>
  </span>
</template>

<script setup>
import { computed } from 'vue';

import { useDsTranslate } from '../useDsTranslate';
import DsButton from './DsButton.vue';

const props = defineProps({
  currentPage: { type: Number, required: true },
  totalItems: { type: Number, required: true },
  itemsPerPage: { type: Number, default: 50 },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['update:currentPage']);

const { translate } = useDsTranslate();

const navigationLabel = computed(() =>
  translate('PAGINATION.NAVIGATION', 'Pagination')
);
const previousPageLabel = computed(() =>
  translate('PAGINATION.PREVIOUS_PAGE', 'Previous page')
);
const nextPageLabel = computed(() =>
  translate('PAGINATION.NEXT_PAGE', 'Next page')
);

const totalPages = computed(() =>
  Math.max(1, Math.ceil(props.totalItems / props.itemsPerPage))
);
const firstItem = computed(() =>
  props.totalItems ? (props.currentPage - 1) * props.itemsPerPage + 1 : 0
);
const lastItem = computed(() =>
  Math.min(props.currentPage * props.itemsPerPage, props.totalItems)
);
const itemRangeLabel = computed(
  () => `${firstItem.value}–${lastItem.value} de ${props.totalItems}`
);
const currentPageLabel = computed(
  () => `${props.currentPage} de ${totalPages.value}`
);

const changePage = page => {
  if (props.disabled || props.loading || page < 1 || page > totalPages.value) {
    return;
  }
  emit('update:currentPage', page);
};
</script>

<template>
  <nav
    :aria-label="navigationLabel"
    :aria-busy="loading || undefined"
    class="flex flex-wrap items-center justify-between gap-3 border-t border-ui-border-subtle bg-ui-surface p-3"
  >
    <p class="m-0 text-ui-body-sm text-ui-text-muted">
      {{ itemRangeLabel }}
    </p>
    <div class="flex items-center gap-2">
      <DsButton
        icon="i-lucide-chevron-left"
        variant="ghost"
        size="sm"
        :aria-label="previousPageLabel"
        :disabled="disabled || currentPage <= 1"
        :loading="loading"
        @click="changePage(currentPage - 1)"
      />
      <span
        class="min-w-20 text-center text-ui-body-sm tabular-nums text-ui-text"
      >
        {{ currentPageLabel }}
      </span>
      <DsButton
        icon="i-lucide-chevron-right"
        variant="ghost"
        size="sm"
        :aria-label="nextPageLabel"
        :disabled="disabled || currentPage >= totalPages"
        :loading="loading"
        @click="changePage(currentPage + 1)"
      />
    </div>
  </nav>
</template>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import DsEmptyState from '../components/DsEmptyState.vue';
import DsSkeleton from '../components/DsSkeleton.vue';
import DsPageHeader from './DsPageHeader.vue';

defineProps({
  title: { type: String, required: true },
  breadcrumbs: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  empty: { type: Boolean, default: false },
  emptyTitle: { type: String, default: 'Nenhum registro encontrado.' },
  emptyActionLabel: { type: String, default: '' },
});

const emit = defineEmits(['empty-action']);
const LOADING_RECORDS_LABEL = 'Carregando registros';
</script>

<template>
  <section
    data-page-template="list"
    class="flex min-h-0 min-w-0 w-full flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader :title="title" :breadcrumbs="breadcrumbs" :loading="loading">
      <template v-if="$slots.actions" #actions>
        <slot name="actions" />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 p-4 sm:p-6">
      <div
        v-if="$slots.metrics"
        data-template-region="metrics"
        class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4"
      >
        <slot name="metrics" />
      </div>

      <div
        v-if="$slots.toolbar"
        data-template-region="toolbar"
        class="flex flex-wrap items-end gap-2"
      >
        <slot name="toolbar" />
      </div>

      <div
        v-if="$slots.selection"
        data-template-region="selection"
        class="flex min-h-10 flex-wrap items-center gap-2 rounded-ui-control border border-ui-border bg-ui-surface px-3 py-2"
      >
        <slot name="selection" />
      </div>

      <div
        data-template-region="content"
        class="min-h-0 flex-1 overflow-auto rounded-ui-surface border border-ui-border-subtle bg-ui-surface"
      >
        <div
          v-if="loading"
          class="grid gap-0"
          :aria-label="LOADING_RECORDS_LABEL"
        >
          <div
            v-for="row in 7"
            :key="row"
            class="grid min-h-[3.25rem] grid-cols-[2rem_minmax(10rem,2fr)_minmax(8rem,1fr)_7rem] items-center gap-3 border-b border-ui-border-subtle px-4 last:border-b-0"
          >
            <DsSkeleton class="size-4" />
            <DsSkeleton class="w-3/4" />
            <DsSkeleton class="w-2/3" />
            <DsSkeleton class="w-full" />
          </div>
        </div>
        <div v-else-if="empty" class="p-4">
          <DsEmptyState
            :title="emptyTitle"
            :action-label="emptyActionLabel"
            @action="emit('empty-action')"
          />
        </div>
        <slot v-else />
      </div>

      <div
        v-if="$slots.pagination && !loading && !empty"
        data-template-region="pagination"
        class="flex justify-end"
      >
        <slot name="pagination" />
      </div>
    </div>
  </section>
</template>

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
  emptyTitle: { type: String, default: 'Este registro não está disponível.' },
  emptyActionLabel: { type: String, default: '' },
});

const emit = defineEmits(['empty-action']);
const SUMMARY_LABEL = 'Resumo do registro';
const HISTORY_LABEL = 'Histórico do registro';
const CONTEXT_LABEL = 'Dados do registro';
</script>

<template>
  <section
    data-page-template="record"
    class="flex min-h-0 min-w-0 w-full flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader :title="title" :breadcrumbs="breadcrumbs" :loading="loading">
      <template v-if="$slots.actions" #actions>
        <slot name="actions" />
      </template>
    </DsPageHeader>

    <div
      v-if="loading"
      class="grid min-h-0 flex-1 gap-4 p-4 sm:p-6 lg:grid-cols-[minmax(0,1fr)_20rem]"
    >
      <div class="flex flex-col gap-4">
        <DsSkeleton shape="block" class="h-32" />
        <DsSkeleton shape="block" class="min-h-80 flex-1" />
      </div>
      <DsSkeleton shape="block" class="min-h-72" />
    </div>
    <div v-else-if="empty" class="p-4 sm:p-6">
      <DsEmptyState
        :title="emptyTitle"
        :action-label="emptyActionLabel"
        @action="emit('empty-action')"
      />
    </div>
    <div
      v-else
      class="grid min-h-0 flex-1 gap-4 overflow-y-auto p-4 sm:p-6 lg:grid-cols-[minmax(0,1fr)_20rem]"
    >
      <main class="flex min-w-0 flex-col gap-4">
        <section
          v-if="$slots.summary"
          data-template-region="summary"
          :aria-label="SUMMARY_LABEL"
        >
          <slot name="summary" />
        </section>
        <section
          data-template-region="timeline"
          :aria-label="HISTORY_LABEL"
          class="min-h-0"
        >
          <slot />
        </section>
      </main>

      <aside
        data-template-region="context"
        class="min-w-0"
        :aria-label="CONTEXT_LABEL"
      >
        <slot name="context" />
      </aside>
    </div>
  </section>
</template>

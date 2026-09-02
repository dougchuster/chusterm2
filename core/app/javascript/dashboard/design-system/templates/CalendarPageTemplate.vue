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
  emptyTitle: { type: String, default: 'Nenhum compromisso neste período.' },
  emptyActionLabel: { type: String, default: '' },
});

const emit = defineEmits(['empty-action']);
const CALENDAR_MAIN_LABEL = 'Calendário';
const AGENDA_MOBILE_LABEL = 'Agenda';
const AGENDA_ASIDE_LABEL = 'Compromissos do período';
</script>

<template>
  <section
    data-page-template="calendar"
    class="flex min-h-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader :title="title" :breadcrumbs="breadcrumbs" :loading="loading">
      <template v-if="$slots.actions" #actions>
        <slot name="actions" />
      </template>
    </DsPageHeader>

    <div
      v-if="$slots.toolbar"
      data-template-region="toolbar"
      class="flex shrink-0 flex-wrap items-end gap-2 border-b border-ui-border-subtle bg-ui-surface px-4 py-3 sm:px-6"
    >
      <slot name="toolbar" />
    </div>

    <div
      v-if="loading"
      class="grid min-h-0 flex-1 gap-4 p-4 sm:p-6 lg:grid-cols-[minmax(0,1fr)_18rem]"
    >
      <DsSkeleton shape="block" class="min-h-[32rem]" />
      <DsSkeleton shape="block" class="hidden min-h-80 lg:block" />
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
      class="grid min-h-0 flex-1 gap-4 overflow-y-auto p-4 sm:p-6 lg:grid-cols-[minmax(0,1fr)_18rem]"
    >
      <main
        data-template-region="calendar"
        class="hidden min-w-0 lg:block"
        :aria-label="CALENDAR_MAIN_LABEL"
      >
        <slot />
      </main>
      <main
        data-template-region="mobile-agenda"
        class="min-w-0 lg:hidden"
        :aria-label="AGENDA_MOBILE_LABEL"
      >
        <slot name="mobile" />
      </main>
      <aside
        data-template-region="agenda"
        class="hidden min-w-0 lg:block"
        :aria-label="AGENDA_ASIDE_LABEL"
      >
        <slot name="agenda" />
      </aside>
    </div>
  </section>
</template>

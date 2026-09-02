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
  emptyTitle: { type: String, default: 'Nenhuma configuração disponível.' },
});

const SETTINGS_NAV_LABEL = 'Seções de configuração';
</script>

<template>
  <section
    data-page-template="settings"
    class="flex min-h-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader :title="title" :breadcrumbs="breadcrumbs" :loading="loading">
      <template v-if="$slots.actions" #actions>
        <slot name="actions" />
      </template>
    </DsPageHeader>

    <div
      v-if="loading"
      class="grid min-h-0 flex-1 gap-6 p-4 sm:p-6 lg:grid-cols-[15rem_minmax(0,42rem)]"
    >
      <div class="hidden gap-2 lg:grid">
        <DsSkeleton v-for="item in 7" :key="item" class="h-8" />
      </div>
      <div class="flex flex-col gap-4">
        <DsSkeleton class="w-48" />
        <DsSkeleton shape="block" class="h-24" />
        <DsSkeleton shape="block" class="h-24" />
        <DsSkeleton shape="block" class="h-40" />
      </div>
    </div>
    <div v-else-if="empty" class="p-4 sm:p-6">
      <DsEmptyState :title="emptyTitle" />
    </div>
    <div
      v-else
      class="grid min-h-0 flex-1 overflow-y-auto p-4 sm:p-6 lg:grid-cols-[15rem_minmax(0,42rem)] lg:gap-6"
    >
      <nav
        data-template-region="settings-navigation"
        :aria-label="SETTINGS_NAV_LABEL"
        class="mb-4 min-w-0 overflow-x-auto border-b border-ui-border-subtle pb-3 lg:mb-0 lg:overflow-visible lg:border-b-0 lg:pb-0"
      >
        <slot name="navigation" />
      </nav>

      <main data-template-region="settings-form" class="min-w-0 pb-20">
        <slot />
      </main>
    </div>

    <footer
      v-if="$slots.footer && !loading && !empty"
      data-template-region="settings-footer"
      class="sticky bottom-0 z-ui-sticky flex min-h-16 shrink-0 flex-wrap items-center justify-end gap-2 border-t border-ui-border-subtle bg-ui-surface/95 py-3 pl-4 pr-20 sm:pl-6"
    >
      <slot name="footer" />
    </footer>
  </section>
</template>

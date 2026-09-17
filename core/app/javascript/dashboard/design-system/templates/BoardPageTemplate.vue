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
  emptyTitle: { type: String, default: 'Nenhum item neste quadro.' },
  emptyActionLabel: { type: String, default: '' },
});

const emit = defineEmits(['empty-action']);
const LOADING_BOARD_LABEL = 'Carregando quadro';
const DETAILS_ASIDE_LABEL = 'Detalhes do item';
</script>

<template>
  <section
    data-page-template="board"
    class="flex min-h-0 min-w-0 w-full flex-1 flex-col bg-ui-canvas text-ui-text"
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
      class="flex shrink-0 flex-wrap items-end gap-2.5 border-b border-ui-border-subtle/80 bg-ui-surface/60 px-4 py-3 backdrop-blur-md sm:px-6"
    >
      <slot name="toolbar" />
    </div>

    <div
      v-if="$slots.mobileNavigation"
      data-template-region="mobile-navigation"
      class="shrink-0 bg-ui-canvas px-4 pt-3 md:hidden"
    >
      <slot name="mobileNavigation" />
    </div>

    <div class="flex min-h-0 flex-1">
      <div
        data-template-region="board"
        class="min-w-0 flex-1 overflow-x-auto overflow-y-hidden p-4 sm:p-6"
      >
        <div
          v-if="loading"
          role="status"
          class="grid h-full min-w-[64rem] grid-cols-4 gap-4"
          :aria-label="LOADING_BOARD_LABEL"
        >
          <div
            v-for="column in 4"
            :key="column"
            class="flex min-h-96 flex-col gap-3 rounded-xl bg-ui-sunken p-3.5"
          >
            <DsSkeleton class="w-2/3" />
            <DsSkeleton
              v-for="card in 3"
              :key="card"
              shape="block"
              class="h-24 bg-ui-surface"
            />
          </div>
        </div>
        <DsEmptyState
          v-else-if="empty"
          :title="emptyTitle"
          :action-label="emptyActionLabel"
          @action="emit('empty-action')"
        />
        <div v-else class="flex h-full min-w-max gap-4 pb-2">
          <slot />
        </div>
      </div>

      <aside
        v-if="$slots.aside"
        data-template-region="aside"
        class="hidden w-80 shrink-0 overflow-y-auto border-l border-ui-border-subtle/80 bg-ui-surface/80 backdrop-blur-md xl:block"
        :aria-label="DETAILS_ASIDE_LABEL"
      >
        <slot name="aside" />
      </aside>
    </div>
  </section>
</template>

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
  emptyTitle: { type: String, default: 'Selecione uma conversa para começar.' },
  emptyActionLabel: { type: String, default: '' },
  mobilePanel: {
    type: String,
    default: 'conversation',
    validator: value => ['list', 'conversation', 'context'].includes(value),
  },
});

const emit = defineEmits(['empty-action']);
const CONVERSATION_LIST_LABEL = 'Lista de conversas';
const CONVERSATION_CONTEXT_LABEL = 'Contexto da conversa';
</script>

<template>
  <section
    data-page-template="conversation"
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
      class="grid min-h-0 flex-1 md:grid-cols-[18rem_minmax(0,1fr)] xl:grid-cols-[20rem_minmax(0,1fr)_22rem]"
    >
      <div
        class="hidden gap-3 border-r border-ui-border-subtle bg-ui-surface p-3 md:grid"
      >
        <DsSkeleton v-for="item in 8" :key="item" shape="block" class="h-16" />
      </div>
      <div class="flex min-h-0 flex-col gap-4 p-4">
        <DsSkeleton class="w-48" />
        <DsSkeleton shape="block" class="h-20 w-4/5" />
        <DsSkeleton shape="block" class="ml-auto h-16 w-3/5" />
        <DsSkeleton shape="block" class="mt-auto h-28 w-full" />
      </div>
      <div
        class="hidden gap-4 border-l border-ui-border-subtle bg-ui-surface p-4 xl:grid"
      >
        <DsSkeleton shape="block" class="h-28" />
        <DsSkeleton shape="block" class="h-40" />
      </div>
    </div>
    <div
      v-else
      class="grid min-h-0 flex-1 md:grid-cols-[18rem_minmax(0,1fr)] xl:grid-cols-[20rem_minmax(0,1fr)_22rem]"
    >
      <aside
        data-template-region="conversation-list"
        :aria-label="CONVERSATION_LIST_LABEL"
        class="min-h-0 overflow-y-auto border-r border-ui-border-subtle bg-ui-surface"
        :class="mobilePanel === 'list' ? 'block' : 'hidden md:block'"
      >
        <slot name="list" />
      </aside>

      <main
        data-template-region="conversation"
        class="min-h-0 min-w-0"
        :class="mobilePanel === 'conversation' ? 'block' : 'hidden md:block'"
      >
        <div v-if="empty" class="p-4">
          <DsEmptyState
            :title="emptyTitle"
            :action-label="emptyActionLabel"
            @action="emit('empty-action')"
          />
        </div>
        <slot v-else />
      </main>

      <aside
        data-template-region="conversation-context"
        :aria-label="CONVERSATION_CONTEXT_LABEL"
        class="min-h-0 overflow-y-auto border-l border-ui-border-subtle bg-ui-surface"
        :class="
          mobilePanel === 'context'
            ? 'block md:hidden xl:block'
            : 'hidden xl:block'
        "
      >
        <slot name="context" />
      </aside>
    </div>
  </section>
</template>

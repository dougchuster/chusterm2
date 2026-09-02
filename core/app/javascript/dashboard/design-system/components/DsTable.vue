<script setup>
import DsEmptyState from './DsEmptyState.vue';
import DsSkeleton from './DsSkeleton.vue';

defineProps({
  caption: { type: String, required: true },
  headers: { type: Array, default: () => [] },
  items: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  loadingRows: { type: Number, default: 6 },
  emptyTitle: { type: String, default: '' },
  minWidthClass: { type: String, default: 'min-w-[56rem]' },
});
</script>

<template>
  <div
    class="w-full overflow-hidden rounded-ui-surface border border-ui-border-subtle bg-ui-surface"
  >
    <div class="w-full overflow-x-auto overscroll-x-contain">
      <table class="w-full border-collapse" :class="minWidthClass">
        <caption class="sr-only">
          {{
            caption
          }}
        </caption>
        <thead class="bg-ui-sunken">
          <tr>
            <th
              v-for="header in headers"
              :key="header.key"
              scope="col"
              class="h-10 border-b border-ui-border-subtle px-3 text-left text-ui-caption font-semibold uppercase tracking-wide text-ui-text-muted"
              :class="header.class"
            >
              {{ header.label }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-ui-border-subtle">
          <template v-if="loading">
            <tr v-for="row in loadingRows" :key="row" aria-hidden="true">
              <td v-for="header in headers" :key="header.key" class="p-3">
                <DsSkeleton class="h-4 w-full" />
              </td>
            </tr>
          </template>
          <template v-else-if="items.length">
            <slot
              v-for="(item, index) in items"
              :key="item.id ?? index"
              name="row"
              :item="item"
              :index="index"
            />
          </template>
          <tr v-else>
            <td :colspan="headers.length || 1" class="p-4">
              <slot name="empty">
                <DsEmptyState
                  :title="emptyTitle || 'Nenhum registro encontrado.'"
                />
              </slot>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

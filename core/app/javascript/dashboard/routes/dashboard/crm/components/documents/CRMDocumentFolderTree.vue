<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { visibleRows } from './folderTree';

const props = defineProps({
  folders: { type: Array, default: () => [] },
  selectedId: { type: Number, default: null },
  clientName: { type: String, default: '' },
});

const emit = defineEmits(['select']);

const collapsed = ref(new Set());
const rows = computed(() => visibleRows(props.folders, collapsed.value));

const toggle = folderId => {
  const next = new Set(collapsed.value);
  if (next.has(folderId)) next.delete(folderId);
  else next.add(folderId);
  collapsed.value = next;
};

const focusRow = index => {
  const row = rows.value[index];
  if (!row) return;
  emit('select', row.folder.id);
  document.getElementById(`crm-folder-${row.folder.id}`)?.focus();
};

// Navegação de árvore (WAI-ARIA): setas sobem/descem, direita abre,
// esquerda fecha.
const onKeydown = (event, index, row) => {
  const actions = {
    ArrowDown: () => focusRow(index + 1),
    ArrowUp: () => focusRow(index - 1),
    ArrowRight: () =>
      row.hasChildren &&
      collapsed.value.has(row.folder.id) &&
      toggle(row.folder.id),
    ArrowLeft: () =>
      row.hasChildren &&
      !collapsed.value.has(row.folder.id) &&
      toggle(row.folder.id),
  };
  if (!actions[event.key]) return;
  event.preventDefault();
  actions[event.key]();
};
</script>

<template>
  <nav class="flex min-w-0 flex-col gap-1" aria-label="Pastas do cliente">
    <p
      class="m-0 truncate px-2 pb-1 font-mono text-ui-caption text-ui-text-muted"
      :title="clientName"
    >
      {{ clientName }}
    </p>
    <ul role="tree" class="m-0 flex list-none flex-col gap-px p-0">
      <li
        v-for="(row, index) in rows"
        :key="row.folder.id"
        role="treeitem"
        :aria-level="row.depth + 1"
        :aria-expanded="
          row.hasChildren ? !collapsed.has(row.folder.id) : undefined
        "
        :aria-selected="row.folder.id === selectedId"
      >
        <div
          class="group flex min-h-9 items-center rounded-ui-control text-ui-body-sm transition-colors"
          :class="
            row.folder.id === selectedId
              ? 'bg-ui-brand-soft text-ui-brand-foreground'
              : 'text-ui-text hover:bg-ui-hover'
          "
          :style="{ paddingLeft: `${row.depth * 14 + 4}px` }"
        >
          <button
            v-if="row.hasChildren"
            type="button"
            class="grid size-6 shrink-0 place-items-center rounded-ui-control text-ui-text-muted hover:text-ui-text"
            :aria-label="
              collapsed.has(row.folder.id)
                ? `Abrir ${row.folder.name}`
                : `Fechar ${row.folder.name}`
            "
            tabindex="-1"
            @click="toggle(row.folder.id)"
          >
            <Icon
              :icon="
                collapsed.has(row.folder.id)
                  ? 'i-lucide-chevron-right'
                  : 'i-lucide-chevron-down'
              "
              class="size-3.5"
            />
          </button>
          <span v-else class="size-6 shrink-0" />
          <button
            :id="`crm-folder-${row.folder.id}`"
            type="button"
            class="flex min-w-0 flex-1 items-center gap-2 py-1.5 pr-2 text-left outline-none focus-visible:ring-2 focus-visible:ring-ui-brand rounded-ui-control"
            :tabindex="row.folder.id === selectedId ? 0 : -1"
            @click="emit('select', row.folder.id)"
            @keydown="onKeydown($event, index, row)"
          >
            <Icon
              :icon="
                row.folder.id === selectedId
                  ? 'i-lucide-folder-open'
                  : 'i-lucide-folder'
              "
              class="size-4 shrink-0"
              :class="
                row.folder.slot === 'triagem' && row.folder.documents_count
                  ? 'text-ui-warning'
                  : 'text-ui-text-muted'
              "
            />
            <span class="min-w-0 flex-1 truncate" :title="row.folder.name">{{
              row.folder.name
            }}</span>
            <span
              v-if="row.folder.documents_count"
              class="shrink-0 font-mono text-ui-caption tabular-nums text-ui-text-muted"
            >
              {{ row.folder.documents_count }}
            </span>
          </button>
        </div>
      </li>
    </ul>
  </nav>
</template>

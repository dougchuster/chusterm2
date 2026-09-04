<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import {
  useVueTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
} from '@tanstack/vue-table';
import { useVirtualList } from '@vueuse/core';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useDsTranslate } from '../useDsTranslate';
import DsCheckbox from './DsCheckbox.vue';
import DsEmptyState from './DsEmptyState.vue';
import DsInput from './DsInput.vue';
import DsSelect from './DsSelect.vue';
import DsSkeleton from './DsSkeleton.vue';

const props = defineProps({
  columns: { type: Array, default: () => [] },
  data: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  loadingRows: { type: Number, default: 6 },
  emptyTitle: { type: String, default: '' },
  emptyDescription: { type: String, default: '' },
  rowKey: { type: String, default: 'id' },
  selectable: { type: Boolean, default: false },
  enableInlineEdit: { type: Boolean, default: false },
  selectedRows: { type: Array, default: () => [] },
  columnVisibility: { type: Object, default: () => ({}) },
  columnOrder: { type: Array, default: () => [] },
  columnSizing: { type: Object, default: () => ({}) },
  virtualThreshold: { type: Number, default: 100 },
  minWidthClass: { type: String, default: 'min-w-full' },
  caption: { type: String, default: '' },
});

const emit = defineEmits([
  'update:selectedRows',
  'update:columnVisibility',
  'update:columnOrder',
  'update:columnSizing',
  'cellUpdate',
  'rowClick',
]);

const { translate } = useDsTranslate();

const defaultEmptyTitle = computed(
  () =>
    props.emptyTitle || translate('DATA_GRID.EMPTY_TITLE', 'No records found')
);

const defaultEmptyDescription = computed(
  () =>
    props.emptyDescription ||
    translate(
      'DATA_GRID.EMPTY_DESCRIPTION',
      'There are no entries to display in this grid.'
    )
);

const selectAllAriaLabel = computed(() =>
  translate('DATA_GRID.SELECT_ALL', 'Select all rows')
);

const selectRowAriaLabel = computed(() =>
  translate('DATA_GRID.SELECT_ROW', 'Select row')
);

const gridRef = ref(null);
const sorting = ref([]);
const localColumnVisibility = ref({ ...props.columnVisibility });
const localColumnOrder = ref([...props.columnOrder]);
const localColumnSizing = ref({ ...props.columnSizing });
const editingCell = ref(null);

watch(
  () => props.columnVisibility,
  val => {
    localColumnVisibility.value = { ...val };
  },
  { deep: true }
);

watch(
  () => props.columnOrder,
  val => {
    localColumnOrder.value = [...val];
  },
  { deep: true }
);

watch(
  () => props.columnSizing,
  val => {
    localColumnSizing.value = { ...val };
  },
  { deep: true }
);

const getRowId = (item, index) => {
  if (!item) return String(index);
  return String(item[props.rowKey] ?? index);
};

const normalizedColumns = computed(() =>
  props.columns.map(col => {
    const id = String(col.id || col.key || col.accessorKey || '');
    const accessorKey = col.accessorKey || col.key || col.id;
    const header = col.header || col.label || col.title || col.name || id;
    const canSort = col.sortable !== false && col.enableSorting !== false;

    return {
      id,
      accessorKey,
      header,
      enableSorting: canSort,
      size: col.width || col.size || 150,
      minSize: col.minWidth || col.minSize || 60,
      maxSize: col.maxWidth || col.maxSize,
      meta: {
        editType: col.editType || 'text',
        editOptions: col.editOptions || col.options || [],
        editable: col.editable !== false,
        class: col.class || '',
      },
    };
  })
);

const table = useVueTable({
  get data() {
    return props.data;
  },
  get columns() {
    return normalizedColumns.value;
  },
  state: {
    get sorting() {
      return sorting.value;
    },
    get columnVisibility() {
      return localColumnVisibility.value;
    },
    get columnOrder() {
      return localColumnOrder.value;
    },
    get columnSizing() {
      return localColumnSizing.value;
    },
  },
  onSortingChange: updaterOrValue => {
    sorting.value =
      typeof updaterOrValue === 'function'
        ? updaterOrValue(sorting.value)
        : updaterOrValue;
  },
  onColumnVisibilityChange: updaterOrValue => {
    const next =
      typeof updaterOrValue === 'function'
        ? updaterOrValue(localColumnVisibility.value)
        : updaterOrValue;
    localColumnVisibility.value = next;
    emit('update:columnVisibility', next);
  },
  onColumnOrderChange: updaterOrValue => {
    const next =
      typeof updaterOrValue === 'function'
        ? updaterOrValue(localColumnOrder.value)
        : updaterOrValue;
    localColumnOrder.value = next;
    emit('update:columnOrder', next);
  },
  onColumnSizingChange: updaterOrValue => {
    const next =
      typeof updaterOrValue === 'function'
        ? updaterOrValue(localColumnSizing.value)
        : updaterOrValue;
    localColumnSizing.value = next;
    emit('update:columnSizing', next);
  },
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  enableMultiSort: true,
  columnResizeMode: 'onChange',
});

const tableHeaders = computed(() => {
  const headerGroups = table.getHeaderGroups();
  if (!headerGroups.length) return [];
  return headerGroups[0].headers;
});

const tableRows = computed(() => table.getRowModel().rows);

const isVirtual = computed(
  () => !props.loading && tableRows.value.length >= props.virtualThreshold
);

const {
  list: virtualListItems,
  containerProps,
  wrapperProps,
} = useVirtualList(tableRows, {
  itemHeight: 44,
  overscan: 10,
});

// Selection Helpers
const selectedKeysSet = computed(() => {
  const keys = new Set();
  props.selectedRows.forEach(item => {
    if (typeof item === 'object' && item !== null) {
      keys.add(getRowId(item));
    } else {
      keys.add(String(item));
    }
  });
  return keys;
});

const isRowSelected = row =>
  selectedKeysSet.value.has(getRowId(row.original, row.index));

const isAllSelected = computed(
  () =>
    props.data.length > 0 &&
    props.data.every((item, idx) =>
      selectedKeysSet.value.has(getRowId(item, idx))
    )
);

const isSomeSelected = computed(
  () =>
    props.data.length > 0 &&
    props.data.some((item, idx) =>
      selectedKeysSet.value.has(getRowId(item, idx))
    )
);

const isIndeterminate = computed(
  () => isSomeSelected.value && !isAllSelected.value
);

const toggleSelectAll = checked => {
  if (checked) {
    emit('update:selectedRows', [...props.data]);
  } else {
    emit('update:selectedRows', []);
  }
};

const toggleSelectRow = row => {
  const id = getRowId(row.original, row.index);
  const current = [...props.selectedRows];
  const idx = current.findIndex(item => {
    const itemId =
      typeof item === 'object' && item !== null ? getRowId(item) : String(item);
    return itemId === id;
  });

  if (idx >= 0) {
    current.splice(idx, 1);
  } else {
    current.push(row.original);
  }
  emit('update:selectedRows', current);
};

// Inline Editing
const isEditing = (row, cell) => {
  if (!editingCell.value) return false;
  const rowId = getRowId(row.original, row.index);
  return (
    editingCell.value.rowId === rowId &&
    editingCell.value.columnId === cell.column.id
  );
};

const startEditing = (row, cell, rowIndex, colIndex) => {
  if (!props.enableInlineEdit) return;
  if (cell.column.columnDef.meta?.editable === false) return;

  const rowId = getRowId(row.original, rowIndex);
  const columnId = cell.column.id;
  const val = cell.getValue();

  editingCell.value = {
    rowId,
    columnId,
    value: val ?? '',
    initialValue: val,
    editType: cell.column.columnDef.meta?.editType || 'text',
    editOptions: cell.column.columnDef.meta?.editOptions || [],
    rowIndex,
    colIndex,
  };
};

const saveEdit = () => {
  if (!editingCell.value) return;
  const { rowId, columnId, value, initialValue } = editingCell.value;
  emit('cellUpdate', {
    rowId,
    columnId,
    value,
    previousValue: initialValue,
  });
  editingCell.value = null;
};

const cancelEdit = () => {
  editingCell.value = null;
};

// Keyboard Navigation
const focusCell = (rowIndex, colIndex) => {
  nextTick(() => {
    if (!gridRef.value) return;
    const target = gridRef.value.querySelector(
      `[data-grid-cell="${rowIndex}-${colIndex}"]`
    );
    if (target) {
      target.focus();
    }
  });
};

const handleCellKeydown = (event, row, cell, rowIndex, colIndex) => {
  if (editingCell.value) {
    if (event.key === 'Escape') {
      event.preventDefault();
      cancelEdit();
      focusCell(rowIndex, colIndex);
    }
    return;
  }

  const maxRow = tableRows.value.length - 1;
  const visibleCells = row.getVisibleCells();
  const maxCol = visibleCells.length - 1;

  switch (event.key) {
    case 'ArrowUp':
      if (rowIndex > 0) {
        event.preventDefault();
        focusCell(rowIndex - 1, colIndex);
      }
      break;
    case 'ArrowDown':
      if (rowIndex < maxRow) {
        event.preventDefault();
        focusCell(rowIndex + 1, colIndex);
      }
      break;
    case 'ArrowLeft':
      if (colIndex > 0) {
        event.preventDefault();
        focusCell(rowIndex, colIndex - 1);
      }
      break;
    case 'ArrowRight':
      if (colIndex < maxCol) {
        event.preventDefault();
        focusCell(rowIndex, colIndex + 1);
      }
      break;
    case 'Tab':
      event.preventDefault();
      if (event.shiftKey) {
        if (colIndex > 0) {
          focusCell(rowIndex, colIndex - 1);
        } else if (rowIndex > 0) {
          focusCell(rowIndex - 1, maxCol);
        }
      } else if (colIndex < maxCol) {
        focusCell(rowIndex, colIndex + 1);
      } else if (rowIndex < maxRow) {
        focusCell(rowIndex + 1, 0);
      }
      break;
    case 'Enter':
    case 'F2':
      if (
        props.enableInlineEdit &&
        cell.column.columnDef.meta?.editable !== false
      ) {
        event.preventDefault();
        startEditing(row, cell, rowIndex, colIndex);
      }
      break;
    default:
      break;
  }
};

const handleRowClick = (row, event) => {
  // Prevent row click when interacting with inputs, checkboxes or buttons
  const tagName = event.target?.tagName?.toLowerCase();
  if (
    tagName === 'input' ||
    tagName === 'select' ||
    tagName === 'button' ||
    tagName === 'textarea' ||
    event.target?.closest('button') ||
    event.target?.closest('input') ||
    event.target?.closest('select') ||
    editingCell.value
  ) {
    return;
  }
  emit('rowClick', row.original);
};

const getSortAria = column => {
  if (!column.getCanSort()) return undefined;
  const isSorted = column.getIsSorted();
  if (isSorted === 'asc') return 'ascending';
  if (isSorted === 'desc') return 'descending';
  return 'none';
};
</script>

<template>
  <div
    ref="gridRef"
    class="w-full overflow-hidden rounded-ui-surface border border-ui-border-subtle bg-ui-surface"
  >
    <div
      class="w-full overflow-x-auto overscroll-x-contain"
      v-bind="isVirtual ? containerProps : {}"
    >
      <table
        role="grid"
        class="w-full border-collapse text-left text-ui-body text-ui-text"
        :class="minWidthClass"
      >
        <caption v-if="caption" class="sr-only">
          {{
            caption
          }}
        </caption>
        <thead class="sticky top-0 z-ui-sticky bg-ui-sunken">
          <tr role="row">
            <th
              v-if="selectable"
              scope="col"
              class="h-10 w-10 border-b border-ui-border-subtle px-3 py-2 text-center"
            >
              <DsCheckbox
                :model-value="isAllSelected"
                :indeterminate="isIndeterminate"
                :aria-label="selectAllAriaLabel"
                @update:model-value="toggleSelectAll"
              />
            </th>
            <th
              v-for="header in tableHeaders"
              :key="header.id"
              scope="col"
              role="columnheader"
              :aria-sort="getSortAria(header.column)"
              class="relative h-10 select-none border-b border-ui-border-subtle px-3 text-left text-ui-caption font-semibold uppercase tracking-wide text-ui-text-muted"
              :class="header.column.columnDef.meta?.class"
            >
              <div class="flex items-center justify-between gap-1.5">
                <button
                  v-if="header.column.getCanSort()"
                  type="button"
                  class="group inline-flex items-center gap-1.5 rounded-ui-control py-1 text-left text-ui-caption font-semibold uppercase tracking-wide text-ui-text-muted hover:text-ui-text focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ui-border-focus"
                  @click="header.column.toggleSorting()"
                >
                  <span>{{ header.column.columnDef.header }}</span>
                  <Icon
                    v-if="header.column.getIsSorted() === 'asc'"
                    icon="i-lucide-arrow-up"
                    class="size-3.5 shrink-0 text-ui-brand"
                    aria-hidden="true"
                  />
                  <Icon
                    v-else-if="header.column.getIsSorted() === 'desc'"
                    icon="i-lucide-arrow-down"
                    class="size-3.5 shrink-0 text-ui-brand"
                    aria-hidden="true"
                  />
                  <Icon
                    v-else
                    icon="i-lucide-arrow-up-down"
                    class="size-3.5 shrink-0 opacity-0 group-hover:opacity-60"
                    aria-hidden="true"
                  />
                </button>
                <span v-else>{{ header.column.columnDef.header }}</span>
              </div>

              <!-- Column Resizer -->
              <div
                v-if="header.column.getCanResize()"
                role="separator"
                :aria-label="
                  translate('DATA_GRID.RESIZE_COLUMN', 'Resize column')
                "
                class="absolute right-0 top-0 h-full w-1.5 cursor-col-resize select-none touch-none hover:bg-ui-brand"
                :class="{ 'bg-ui-brand': header.column.getIsResizing() }"
                @mousedown.stop="header.getResizeHandler()($event)"
                @touchstart.stop="header.getResizeHandler()($event)"
              />
            </th>
          </tr>
        </thead>

        <!-- Loading State -->
        <tbody v-if="loading" class="divide-y divide-ui-border-subtle">
          <tr v-for="r in loadingRows" :key="r" aria-hidden="true">
            <td v-if="selectable" class="p-3 text-center">
              <DsSkeleton shape="circle" class="mx-auto size-4" />
            </td>
            <td v-for="header in tableHeaders" :key="header.id" class="p-3">
              <DsSkeleton class="h-4 w-full" />
            </td>
          </tr>
        </tbody>

        <!-- Virtualized Rows -->
        <tbody
          v-else-if="isVirtual && tableRows.length"
          v-bind="wrapperProps"
          class="divide-y divide-ui-border-subtle"
        >
          <tr
            v-for="vItem in virtualListItems"
            :key="getRowId(vItem.data.original, vItem.index)"
            role="row"
            :aria-selected="isRowSelected(vItem.data)"
            class="group border-b border-ui-border-subtle transition-colors duration-ui-fast hover:bg-ui-hover"
            :class="{
              'bg-ui-brand-soft/50 hover:bg-ui-brand-soft/70': isRowSelected(
                vItem.data
              ),
              'cursor-pointer': $attrs.onRowClick || selectable,
            }"
            @click="handleRowClick(vItem.data, $event)"
          >
            <td
              v-if="selectable"
              class="w-10 px-3 py-2 text-center"
              @click.stop
            >
              <DsCheckbox
                :model-value="isRowSelected(vItem.data)"
                :aria-label="selectRowAriaLabel"
                @update:model-value="toggleSelectRow(vItem.data)"
              />
            </td>
            <td
              v-for="(cell, cIndex) in vItem.data.getVisibleCells()"
              :key="cell.id"
              role="gridcell"
              tabindex="0"
              :data-grid-cell="`${vItem.index}-${cIndex}`"
              class="relative h-11 px-3 py-2 text-ui-body text-ui-text outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
              :class="cell.column.columnDef.meta?.class"
              @dblclick="startEditing(vItem.data, cell, vItem.index, cIndex)"
              @keydown="
                handleCellKeydown($event, vItem.data, cell, vItem.index, cIndex)
              "
            >
              <template v-if="isEditing(vItem.data, cell)">
                <DsSelect
                  v-if="editingCell.editType === 'select'"
                  v-model="editingCell.value"
                  :options="editingCell.editOptions"
                  hide-label
                  autofocus
                  @keydown.enter.prevent="saveEdit"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit"
                />
                <DsInput
                  v-else-if="editingCell.editType === 'number'"
                  v-model="editingCell.value"
                  type="number"
                  hide-label
                  autofocus
                  @enter="saveEdit"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit"
                />
                <DsInput
                  v-else
                  v-model="editingCell.value"
                  type="text"
                  hide-label
                  autofocus
                  @enter="saveEdit"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit"
                />
              </template>
              <template v-else>
                <slot
                  :name="`cell-${cell.column.id}`"
                  :cell="cell"
                  :row="vItem.data.original"
                  :value="cell.getValue()"
                >
                  <slot
                    name="cell"
                    :cell="cell"
                    :row="vItem.data.original"
                    :value="cell.getValue()"
                  >
                    <span>{{ cell.getValue() }}</span>
                  </slot>
                </slot>
              </template>
            </td>
          </tr>
        </tbody>

        <!-- Standard Rows -->
        <tbody
          v-else-if="tableRows.length"
          class="divide-y divide-ui-border-subtle"
        >
          <tr
            v-for="(row, rIndex) in tableRows"
            :key="getRowId(row.original, rIndex)"
            role="row"
            :aria-selected="isRowSelected(row)"
            class="group border-b border-ui-border-subtle transition-colors duration-ui-fast hover:bg-ui-hover"
            :class="{
              'bg-ui-brand-soft/50 hover:bg-ui-brand-soft/70':
                isRowSelected(row),
              'cursor-pointer': $attrs.onRowClick || selectable,
            }"
            @click="handleRowClick(row, $event)"
          >
            <td
              v-if="selectable"
              class="w-10 px-3 py-2 text-center"
              @click.stop
            >
              <DsCheckbox
                :model-value="isRowSelected(row)"
                :aria-label="selectRowAriaLabel"
                @update:model-value="toggleSelectRow(row)"
              />
            </td>
            <td
              v-for="(cell, cIndex) in row.getVisibleCells()"
              :key="cell.id"
              role="gridcell"
              tabindex="0"
              :data-grid-cell="`${rIndex}-${cIndex}`"
              class="relative h-11 px-3 py-2 text-ui-body text-ui-text outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
              :class="cell.column.columnDef.meta?.class"
              @dblclick="startEditing(row, cell, rIndex, cIndex)"
              @keydown="handleCellKeydown($event, row, cell, rIndex, cIndex)"
            >
              <template v-if="isEditing(row, cell)">
                <DsSelect
                  v-if="editingCell.editType === 'select'"
                  v-model="editingCell.value"
                  :options="editingCell.editOptions"
                  hide-label
                  autofocus
                  @keydown.enter.prevent="saveEdit"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit"
                />
                <DsInput
                  v-else-if="editingCell.editType === 'number'"
                  v-model="editingCell.value"
                  type="number"
                  hide-label
                  autofocus
                  @enter="saveEdit"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit"
                />
                <DsInput
                  v-else
                  v-model="editingCell.value"
                  type="text"
                  hide-label
                  autofocus
                  @enter="saveEdit"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit"
                />
              </template>
              <template v-else>
                <slot
                  :name="`cell-${cell.column.id}`"
                  :cell="cell"
                  :row="row.original"
                  :value="cell.getValue()"
                >
                  <slot
                    name="cell"
                    :cell="cell"
                    :row="row.original"
                    :value="cell.getValue()"
                  >
                    <span>{{ cell.getValue() }}</span>
                  </slot>
                </slot>
              </template>
            </td>
          </tr>
        </tbody>

        <!-- Empty State -->
        <tbody v-else>
          <tr>
            <td
              :colspan="tableHeaders.length + (selectable ? 1 : 0)"
              class="p-6"
            >
              <slot name="empty">
                <DsEmptyState
                  :title="defaultEmptyTitle"
                  :description="defaultEmptyDescription"
                />
              </slot>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

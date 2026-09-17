<script setup>
import { ref } from 'vue';

import {
  DsButton,
  DsDropdown,
  DsInput,
  DsSelect,
} from 'dashboard/design-system/components';
import CRMFilterPills from 'dashboard/components/crm/CRMFilterPills.vue';
import CRMViewsMenu from 'dashboard/components/crm/CRMViewsMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

/**
 * A barra de ferramentas do quadro, extraída de `CrmIndexOperational.vue`
 * quando a página passou do teto de 800 linhas.
 *
 * É só apresentação: cada controle avisa o que o atendente fez e a página
 * decide o que recarregar. Os quatro campos de busca legados (busca, pipeline,
 * responsável, prioridade) convivem com as pílulas da F2.6 — a dívida B-16
 * (nem todo critério tem controle) segue registrada no plano.
 */
defineProps({
  views: { type: Array, default: () => [] },
  activeViewId: { type: [Number, String], default: null },
  filterPills: { type: Array, default: () => [] },
  filteredTotal: { type: Number, default: null },
  groupBy: { type: String, default: 'stage' },
  groupByOptions: { type: Array, default: () => [] },
  density: { type: String, default: 'normal' },
  densityOptions: { type: Array, default: () => [] },
  search: { type: String, default: '' },
  pipelineId: { type: String, default: '' },
  pipelineOptions: { type: Array, default: () => [] },
  ownerId: { type: String, default: '' },
  ownerOptions: { type: Array, default: () => [] },
  priority: { type: String, default: '' },
  priorityOptions: { type: Array, default: () => [] },
  hasFilters: { type: Boolean, default: false },
  totalVisible: { type: Number, default: 0 },
});

const emit = defineEmits([
  'update:search',
  'update:pipelineId',
  'update:ownerId',
  'update:priority',
  'update:groupBy',
  'update:density',
  'apply-filters',
  'change-pipeline',
  'clear-filters',
  'remove-filter',
  'clear-all-filters',
  'select-view',
  'save-view',
  'share-view',
  'delete-view',
]);

const advancedFiltersOpen = ref(false);
</script>

<template>
  <CRMFilterPills
    v-if="filterPills.length"
    :pills="filterPills"
    :result-count="filteredTotal"
    class="w-full"
    @remove="emit('remove-filter', $event)"
    @clear="emit('clear-all-filters')"
  />
  <div
    class="grid w-full grid-cols-[auto_minmax(0,1fr)] items-center gap-2.5 sm:grid-cols-[auto_minmax(12rem,1fr)_10rem] xl:flex xl:flex-wrap"
  >
    <DsDropdown
      :aria-label="$t('CRM.VIEWS.MENU')"
      class="col-start-1 row-start-2 sm:row-start-1 xl:col-auto xl:row-auto"
    >
      <CRMViewsMenu
        :views="views"
        :active-view-id="activeViewId"
        :has-active-filters="filterPills.length > 0"
        @select="emit('select-view', $event)"
        @save="emit('save-view')"
        @share="emit('share-view', $event)"
        @delete="emit('delete-view', $event)"
      />
    </DsDropdown>
    <DsSelect
      :model-value="pipelineId"
      :label="$t('CRM.TOOLBAR.PIPELINE')"
      hide-label
      :options="pipelineOptions"
      class="col-span-2 col-start-1 row-start-3 min-w-0 sm:col-span-1 sm:col-start-2 sm:row-start-1 xl:col-auto xl:row-auto xl:w-52 xl:shrink-0"
      @update:model-value="emit('update:pipelineId', $event)"
      @change="emit('change-pipeline')"
    />
    <DsSelect
      :model-value="groupBy"
      :label="$t('CRM.GROUP_BY.LABEL')"
      hide-label
      :options="groupByOptions"
      class="col-start-1 row-start-4 min-w-0 sm:col-start-3 sm:row-start-1 xl:col-auto xl:row-auto xl:w-40 xl:shrink-0"
      @update:model-value="emit('update:groupBy', $event)"
    />
    <DsInput
      id="crm-board-search"
      :model-value="search"
      :label="$t('CRM.TOOLBAR.SEARCH')"
      hide-label
      :placeholder="$t('CRM.TOOLBAR.SEARCH_PLACEHOLDER')"
      class="col-span-2 col-start-1 row-start-1 min-w-0 sm:row-start-2 xl:col-auto xl:row-auto xl:min-w-64 xl:flex-[1_1_20rem]"
      @update:model-value="emit('update:search', $event)"
      @enter="emit('apply-filters')"
      @keydown.escape="
        emit('update:search', '');
        emit('apply-filters');
      "
    >
      <template #prefix>
        <Icon icon="i-lucide-search" class="size-4" />
      </template>
    </DsInput>
    <DsButton
      data-testid="crm-toolbar-filter-toggle"
      :label="$t('FILTER.GROUPS.STANDARD_FILTERS')"
      icon="i-lucide-sliders-horizontal"
      :variant="advancedFiltersOpen || hasFilters ? 'secondary' : 'ghost'"
      class="col-start-2 row-start-4 justify-self-start sm:col-start-3 sm:row-start-2 xl:col-auto xl:row-auto"
      :aria-expanded="advancedFiltersOpen"
      aria-controls="crm-toolbar-advanced-filters"
      @click="advancedFiltersOpen = !advancedFiltersOpen"
    />
    <span
      class="col-span-2 col-start-1 row-start-5 self-center justify-self-end whitespace-nowrap rounded-full bg-ui-sunken px-2.5 py-1 text-ui-caption font-medium tabular-nums text-ui-text-muted sm:col-span-3 sm:row-start-3 xl:col-auto xl:row-auto xl:ml-auto"
    >
      {{ $t('CRM.TOOLBAR.TOTAL', { count: filteredTotal ?? totalVisible }) }}
    </span>
  </div>

  <div
    v-if="advancedFiltersOpen"
    id="crm-toolbar-advanced-filters"
    data-testid="crm-toolbar-advanced-filters"
    class="flex w-full flex-wrap items-center gap-2.5 rounded-xl bg-ui-sunken/70 p-2.5"
  >
    <DsSelect
      :model-value="ownerId"
      :label="$t('CRM.TOOLBAR.OWNER')"
      hide-label
      :options="ownerOptions"
      class="w-52 max-sm:flex-1"
      @update:model-value="emit('update:ownerId', $event)"
      @change="emit('apply-filters')"
    />
    <DsSelect
      :model-value="priority"
      :label="$t('CRM.TOOLBAR.PRIORITY')"
      hide-label
      :options="priorityOptions"
      class="w-48 max-sm:flex-1"
      @update:model-value="emit('update:priority', $event)"
      @change="emit('apply-filters')"
    />
    <DsSelect
      :model-value="density"
      :label="$t('CRM.DENSITY.LABEL')"
      hide-label
      :options="densityOptions"
      class="w-40 max-sm:flex-1"
      @update:model-value="emit('update:density', $event)"
    />
    <DsButton
      v-if="hasFilters"
      :label="$t('CRM.TOOLBAR.CLEAR')"
      variant="ghost"
      @click="emit('clear-filters')"
    />
  </div>
</template>

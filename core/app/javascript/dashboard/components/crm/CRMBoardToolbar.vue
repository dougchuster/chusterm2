<script setup>
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
</script>

<template>
  <DsDropdown :aria-label="$t('CRM.VIEWS.MENU')">
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
    :model-value="groupBy"
    :label="$t('CRM.GROUP_BY.LABEL')"
    hide-label
    :options="groupByOptions"
    class="w-44"
    @update:model-value="emit('update:groupBy', $event)"
  />
  <CRMFilterPills
    :pills="filterPills"
    :result-count="filterPills.length ? filteredTotal : null"
    class="w-full"
    @remove="emit('remove-filter', $event)"
    @clear="emit('clear-all-filters')"
  />
  <DsSelect
    :model-value="density"
    :label="$t('CRM.DENSITY.LABEL')"
    hide-label
    :options="densityOptions"
    class="w-40"
    @update:model-value="emit('update:density', $event)"
  />
  <DsInput
    :model-value="search"
    :label="$t('CRM.TOOLBAR.SEARCH')"
    hide-label
    :placeholder="$t('CRM.TOOLBAR.SEARCH_PLACEHOLDER')"
    class="min-w-64 flex-1"
    @update:model-value="emit('update:search', $event)"
    @enter="emit('apply-filters')"
  >
    <template #prefix>
      <Icon icon="i-lucide-search" class="size-4" />
    </template>
  </DsInput>
  <DsSelect
    :model-value="pipelineId"
    :label="$t('CRM.TOOLBAR.PIPELINE')"
    hide-label
    :options="pipelineOptions"
    class="min-w-44"
    @update:model-value="emit('update:pipelineId', $event)"
    @change="emit('change-pipeline')"
  />
  <DsSelect
    :model-value="ownerId"
    :label="$t('CRM.TOOLBAR.OWNER')"
    hide-label
    :options="ownerOptions"
    class="min-w-44"
    @update:model-value="emit('update:ownerId', $event)"
    @change="emit('apply-filters')"
  />
  <DsSelect
    :model-value="priority"
    :label="$t('CRM.TOOLBAR.PRIORITY')"
    hide-label
    :options="priorityOptions"
    class="min-w-44"
    @update:model-value="emit('update:priority', $event)"
    @change="emit('apply-filters')"
  />
  <DsButton
    v-if="hasFilters"
    :label="$t('CRM.TOOLBAR.CLEAR')"
    variant="ghost"
    @click="emit('clear-filters')"
  />
  <span
    class="ml-auto self-center text-ui-body-sm tabular-nums text-ui-text-muted"
  >
    {{ $t('CRM.TOOLBAR.TOTAL', { count: totalVisible }) }}
  </span>
</template>

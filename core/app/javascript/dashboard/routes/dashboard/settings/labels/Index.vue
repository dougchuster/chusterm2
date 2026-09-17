<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';

import AddLabel from './AddLabel.vue';
import EditLabel from './EditLabel.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedLabel = ref({});
const searchQuery = ref('');
const categoryFilter = ref('');
const filterText = {
  all: 'Todas',
};

const records = computed(() => getters['labels/getLabels'].value);
const categoryLabels = {
  area: 'Setor jurídico',
  temperature: 'Temperatura',
  relationship: 'Relacionamento',
  status: 'Status',
  document: 'Documento',
  origin: 'Origem',
  risk: 'Risco',
  service: 'Atendimento',
};
const categoryOptions = computed(() => {
  const categories = records.value
    .map(label => label.category)
    .filter(Boolean)
    .filter((value, index, list) => list.indexOf(value) === index)
    .sort();

  return categories.map(value => ({
    value,
    label: categoryLabels[value] || value,
  }));
});

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  const categoryScoped = categoryFilter.value
    ? records.value.filter(label => label.category === categoryFilter.value)
    : records.value;
  if (!query) return categoryScoped;
  return picoSearch(categoryScoped, query, [
    { name: 'display_title', weight: 5 },
    { name: 'title', weight: 4 },
    { name: 'slug', weight: 3 },
    'category',
    'description',
  ]);
});
const uiFlags = computed(() => getters['labels/getUIFlags'].value);

const deleteMessage = computed(
  () => ` ${selectedLabel.value.display_title || selectedLabel.value.title}?`
);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = response => {
  showEditPopup.value = true;
  selectedLabel.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  selectedLabel.value = response;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteLabel = async id => {
  try {
    await store.dispatch('labels/delete', id);
    useAlert(t('LABEL_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('LABEL_MGMT.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedLabel.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedLabel.value.id] = true;
  closeDeletePopup();
  deleteLabel(selectedLabel.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('LABEL_MGMT.LIST.TABLE_HEADER.NAME'),
    'Categoria',
    'Slug',
    'Escopo',
    t('LABEL_MGMT.LIST.TABLE_HEADER.DESCRIPTION'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.COLOR'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.ACTION'),
  ];
});

const readableCategory = category =>
  categoryLabels[category] || category || '-';
const readableScope = scope =>
  ({
    contact: 'Contato',
    conversation: 'Conversa',
    both: 'Ambos',
  })[scope] || '-';

onBeforeMount(() => {
  store.dispatch('labels/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('LABEL_MGMT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('LABEL_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('LABEL_MGMT.HEADER')"
        :description="$t('LABEL_MGMT.DESCRIPTION')"
        :link-text="$t('LABEL_MGMT.LEARN_MORE')"
        :search-placeholder="$t('LABEL_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="labels"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('LABEL_MGMT.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('LABEL_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div
        v-if="categoryOptions.length"
        class="flex flex-wrap items-center gap-2 mb-4"
      >
        <button
          type="button"
          class="px-3 py-1.5 text-sm rounded-md border border-ui-border-subtle text-n-slate-11 hover:bg-n-slate-2"
          :class="{ 'bg-n-slate-3 text-n-slate-12': !categoryFilter }"
          @click="categoryFilter = ''"
        >
          {{ filterText.all }}
        </button>
        <button
          v-for="option in categoryOptions"
          :key="option.value"
          type="button"
          class="px-3 py-1.5 text-sm rounded-md border border-ui-border-subtle text-n-slate-11 hover:bg-n-slate-2"
          :class="{
            'bg-n-slate-3 text-n-slate-12': categoryFilter === option.value,
          }"
          @click="categoryFilter = option.value"
        >
          {{ option.label }}
        </button>
      </div>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery ? $t('LABEL_MGMT.NO_RESULTS') : $t('LABEL_MGMT.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="label in items" :key="label.title" :item="label">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ label.display_title || label.title }}
                </span>
                <span
                  v-if="
                    label.display_title && label.display_title !== label.title
                  "
                  class="block text-xs text-n-slate-10"
                >
                  {{ label.title }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ readableCategory(label.category) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ label.slug || '-' }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ readableScope(label.scope) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ label.description }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <div class="flex items-center">
                  <span
                    class="w-4 h-4 ltr:mr-2 rtl:ml-2 border border-solid rounded border-ui-border-subtle"
                    :style="{ backgroundColor: label.color }"
                  />
                  <span class="text-body-main text-n-slate-12">
                    {{ label.color }}
                  </span>
                </div>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('LABEL_MGMT.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[label.id]"
                    @click="openEditPopup(label)"
                  />
                  <Button
                    v-tooltip.top="$t('LABEL_MGMT.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[label.id]"
                    @click="openDeletePopup(label)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddLabel @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditLabel :selected-response="selectedLabel" @close="hideEditPopup" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('LABEL_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('LABEL_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="$t('LABEL_MGMT.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>

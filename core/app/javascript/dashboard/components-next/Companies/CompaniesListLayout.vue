<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompaniesStore } from 'dashboard/stores/companies';
import { useAlert } from 'dashboard/composables';
import CompanyAPI from 'dashboard/api/companies';
import {
  DsDataGrid,
  DsRecordDrawer,
  DsAvatar,
  DsEmptyState,
  DsSkeleton,
} from 'dashboard/design-system/components';
import CompanyHeader from './CompaniesHeader/CompanyHeader.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

const props = defineProps({
  companies: { type: Array, default: () => [] },
  searchValue: { type: String, default: '' },
  headerTitle: { type: String, default: '' },
  currentPage: { type: Number, default: 1 },
  totalItems: { type: Number, default: 0 },
  activeSort: { type: String, default: 'name' },
  activeOrdering: { type: String, default: '' },
  isFetchingList: { type: Boolean, default: false },
  showPaginationFooter: { type: Boolean, default: true },
});

const emit = defineEmits([
  'update:currentPage',
  'update:sort',
  'search',
  'cellUpdate',
  'rowClick',
]);

const { t } = useI18n();
const companiesStore = useCompaniesStore();

const selectedCompany = ref(null);
const isDrawerOpen = ref(false);
const drawerActiveTab = ref('overview');
const linkedContacts = ref([]);
const isLoadingContacts = ref(false);

const columns = computed(() => [
  {
    id: 'name',
    header: t('COMPANIES.DATA_GRID.COLUMNS.NAME'),
    accessorKey: 'name',
    editType: 'text',
    width: 220,
  },
  {
    id: 'domain',
    header: t('COMPANIES.DATA_GRID.COLUMNS.DOMAIN'),
    accessorKey: 'domain',
    editType: 'text',
    width: 200,
  },
  {
    id: 'description',
    header: t('COMPANIES.DATA_GRID.COLUMNS.DESCRIPTION'),
    accessorKey: 'description',
    editType: 'text',
    width: 300,
  },
  {
    id: 'contacts_count',
    header: t('COMPANIES.DATA_GRID.COLUMNS.CONTACTS_COUNT'),
    accessorKey: 'contactsCount',
    editable: false,
    width: 130,
  },
  {
    id: 'updated_at',
    header: t('COMPANIES.DATA_GRID.COLUMNS.UPDATED_AT'),
    accessorKey: 'updatedAt',
    editable: false,
    width: 160,
  },
]);

const gridData = computed(() => {
  return (props.companies || []).map(company => ({
    ...company,
    contactsCount: company.contactsCount ?? company.contacts_count ?? 0,
    updatedAt: company.updatedAt || company.updated_at || '',
  }));
});

const drawerTabs = computed(() => [
  {
    id: 'overview',
    value: 'overview',
    label: t('COMPANIES.DRAWER.TABS.OVERVIEW'),
    icon: 'i-lucide-file-text',
  },
  {
    id: 'contacts',
    value: 'contacts',
    label: t('COMPANIES.DRAWER.TABS.CONTACTS'),
    icon: 'i-lucide-users',
  },
  {
    id: 'timeline',
    value: 'timeline',
    label: t('COMPANIES.DRAWER.TABS.TIMELINE'),
    icon: 'i-lucide-history',
  },
  {
    id: 'notes',
    value: 'notes',
    label: t('COMPANIES.DRAWER.TABS.NOTES'),
    icon: 'i-lucide-notebook-pen',
  },
]);

const drawerFields = computed(() => {
  if (!selectedCompany.value) return [];
  const comp = selectedCompany.value;
  return [
    {
      id: 'name',
      label: t('COMPANIES.FIELDS.NAME'),
      value: comp.name || '',
      editable: true,
      editType: 'text',
    },
    {
      id: 'domain',
      label: t('COMPANIES.FIELDS.DOMAIN'),
      value: comp.domain || '',
      editable: true,
      editType: 'text',
    },
    {
      id: 'description',
      label: t('COMPANIES.FIELDS.DESCRIPTION'),
      value: comp.description || '',
      editable: true,
      editType: 'text',
    },
    {
      id: 'contactsCount',
      label: t('COMPANIES.FIELDS.CONTACTS_COUNT'),
      value: comp.contactsCount ?? comp.contacts_count ?? 0,
      editable: false,
      editType: 'number',
    },
  ];
});

const fetchLinkedContacts = async companyId => {
  if (!companyId) return;
  isLoadingContacts.value = true;
  try {
    const { data } = await CompanyAPI.listContacts(companyId);
    linkedContacts.value = data?.payload || [];
  } catch (error) {
    linkedContacts.value = [];
  } finally {
    isLoadingContacts.value = false;
  }
};

const handleRowClick = row => {
  selectedCompany.value = row;
  isDrawerOpen.value = true;
  drawerActiveTab.value = 'overview';
  fetchLinkedContacts(row.id);
  emit('rowClick', row);
};

const handleCellUpdate = async ({ rowId, columnId, value, previousValue }) => {
  emit('cellUpdate', { rowId, columnId, value, previousValue });

  try {
    await companiesStore.update({
      id: rowId,
      [columnId]: value,
    });
    useAlert(t('COMPANIES.UPDATE_SUCCESS'));
  } catch (error) {
    // Rollback on store/state if needed
    await companiesStore.update({
      id: rowId,
      [columnId]: previousValue,
    });
    useAlert(t('COMPANIES.UPDATE_ERROR'));
  }
};

const handleDrawerFieldUpdate = ({ fieldId, value, previousValue }) => {
  if (!selectedCompany.value) return;
  const rowId = selectedCompany.value.id;
  selectedCompany.value = {
    ...selectedCompany.value,
    [fieldId]: value,
  };
  handleCellUpdate({ rowId, columnId: fieldId, value, previousValue });
};

const handleCloseDrawer = () => {
  isDrawerOpen.value = false;
  selectedCompany.value = null;
  linkedContacts.value = [];
};

const updateCurrentPage = page => {
  emit('update:currentPage', page);
};

watch(
  () => drawerActiveTab.value,
  newTab => {
    if (
      newTab === 'contacts' &&
      selectedCompany.value?.id &&
      !linkedContacts.value.length
    ) {
      fetchLinkedContacts(selectedCompany.value.id);
    }
  }
);
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-hidden bg-ui-surface">
    <div class="flex h-full w-full flex-col">
      <!-- Company Header -->
      <CompanyHeader
        :search-value="searchValue"
        :header-title="headerTitle"
        :active-sort="activeSort"
        :active-ordering="activeOrdering"
        @search="emit('search', $event)"
        @update:sort="emit('update:sort', $event)"
      />

      <!-- Main Data Grid View -->
      <main class="flex-1 overflow-auto p-6">
        <DsDataGrid
          :columns="columns"
          :data="gridData"
          :loading="isFetchingList"
          enable-inline-edit
          row-key="id"
          @cell-update="handleCellUpdate"
          @row-click="handleRowClick"
        >
          <!-- Optional Slot Passthrough for Custom Renderers if provided -->
          <template #default>
            <slot name="default" />
          </template>
        </DsDataGrid>
      </main>

      <!-- Pagination Footer -->
      <footer
        v-if="showPaginationFooter"
        class="sticky bottom-0 z-0 border-t border-ui-border-subtle bg-ui-surface"
      >
        <PaginationFooter
          current-page-info="COMPANIES_LAYOUT.PAGINATION_FOOTER.SHOWING"
          :current-page="currentPage"
          :total-items="totalItems"
          :items-per-page="25"
          class="max-w-[67rem]"
          @update:current-page="updateCurrentPage"
        />
      </footer>
    </div>

    <!-- 360 Company Record Drawer -->
    <DsRecordDrawer
      :open="isDrawerOpen"
      :title="selectedCompany?.name || t('COMPANIES.UNNAMED')"
      :subtitle="selectedCompany?.domain || ''"
      :avatar-url="
        selectedCompany?.avatarUrl || selectedCompany?.avatar_url || ''
      "
      :avatar-name="selectedCompany?.name || ''"
      :tabs="drawerTabs"
      :active-tab="drawerActiveTab"
      :fields="drawerFields"
      @close="handleCloseDrawer"
      @update:active-tab="drawerActiveTab = $event"
      @field-update="handleDrawerFieldUpdate"
    >
      <!-- Contacts Tab Slot -->
      <template #contacts>
        <div v-if="isLoadingContacts" class="space-y-3 p-4">
          <div
            v-for="idx in 3"
            :key="idx"
            class="flex items-center gap-3 rounded-ui-surface border border-ui-border-subtle bg-ui-surface p-3"
          >
            <DsSkeleton shape="circle" class="size-9" />
            <div class="flex-1 space-y-1.5">
              <DsSkeleton class="h-4 w-32" />
              <DsSkeleton class="h-3 w-48" />
            </div>
          </div>
        </div>
        <div v-else-if="linkedContacts.length > 0" class="space-y-2 p-1">
          <div
            v-for="contact in linkedContacts"
            :key="contact.id"
            class="flex items-center justify-between gap-3 rounded-ui-surface border border-ui-border-subtle bg-ui-surface p-3 transition-colors duration-ui-fast hover:bg-ui-hover"
          >
            <div class="flex items-center gap-3">
              <DsAvatar
                :src="contact.thumbnail || contact.avatar_url"
                :name="contact.name || contact.email || 'Contact'"
                size="md"
              />
              <div class="min-w-0">
                <p class="m-0 truncate text-ui-body font-medium text-ui-text">
                  {{ contact.name || contact.email }}
                </p>
                <p
                  v-if="contact.email && contact.name"
                  class="m-0 truncate text-ui-caption text-ui-text-muted"
                >
                  {{ contact.email }}
                </p>
              </div>
            </div>
            <span
              v-if="contact.phone_number || contact.phoneNumber"
              class="text-ui-caption text-ui-text-muted"
            >
              {{ contact.phone_number || contact.phoneNumber }}
            </span>
          </div>
        </div>
        <DsEmptyState
          v-else
          icon="i-lucide-users"
          :title="t('COMPANIES.DRAWER.CONTACTS.EMPTY_TITLE')"
          :description="t('COMPANIES.DRAWER.CONTACTS.EMPTY_DESCRIPTION')"
        />
      </template>

      <!-- Timeline Slot -->
      <template #timeline>
        <DsEmptyState
          icon="i-lucide-history"
          :title="t('RECORD_DRAWER.TIMELINE.EMPTY_TITLE')"
          :description="t('RECORD_DRAWER.TIMELINE.EMPTY_DESCRIPTION')"
        />
      </template>

      <!-- Notes Slot -->
      <template #notes>
        <DsEmptyState
          icon="i-lucide-notebook-pen"
          :title="t('RECORD_DRAWER.NOTES.EMPTY_TITLE')"
          :description="t('RECORD_DRAWER.NOTES.EMPTY_DESCRIPTION')"
        />
      </template>
    </DsRecordDrawer>
  </section>
</template>

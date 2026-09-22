<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import CRMDocumentVault from 'dashboard/routes/dashboard/crm/components/documents/CRMDocumentVault.vue';
import BulkActionsAPI from 'dashboard/api/bulkActions';
import {
  DsDataGrid,
  DsBulkActionBar,
  DsRecordDrawer,
  DsInput,
  DsButton,
} from 'dashboard/design-system/components';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const contactsList = useMapGetter('contacts/getContactsList');
const contactByIdGetter = useMapGetter('contacts/getContactById');
const uiFlags = useMapGetter('contacts/getUIFlags');

const isFetching = computed(() =>
  Boolean(uiFlags.value?.isFetching || uiFlags.value?.isFetchingItem)
);
const selectedRows = ref([]);
const activeContactId = ref(route.params.contactId || null);
const isDrawerOpen = ref(Boolean(route.params.contactId));
const drawerActiveTab = ref('overview');

// Cofre de documentos (PROJETO-COFRE-DOCUMENTOS.md §8.1): a gaveta completa do
// cliente, como aba do drawer. Só aparece com o módulo ligado na conta.
const { currentAccount } = useAccount();
const documentVaultEnabled = ref(true);
const crmDocumentsEnabled = computed(
  () =>
    documentVaultEnabled.value &&
    currentAccount.value?.settings?.crm_documents === true
);
const drawerTabs = computed(() => {
  const tabs = [
    {
      value: 'overview',
      label: t('RECORD_DRAWER.TABS.OVERVIEW'),
      icon: 'i-lucide-file-text',
    },
    {
      value: 'timeline',
      label: t('RECORD_DRAWER.TABS.TIMELINE'),
      icon: 'i-lucide-history',
    },
    {
      value: 'notes',
      label: t('RECORD_DRAWER.TABS.NOTES'),
      icon: 'i-lucide-notebook-pen',
    },
  ];
  if (!crmDocumentsEnabled.value) return tabs;
  return [
    ...tabs,
    {
      value: 'documents',
      label: t('RECORD_DRAWER.TABS.DOCUMENTS'),
      icon: 'i-lucide-folder',
    },
  ];
});
const onDocumentVaultUnavailable = () => {
  documentVaultEnabled.value = false;
  drawerActiveTab.value = 'overview';
};
const searchQuery = ref(route.query?.search || '');

const getCompanyName = contact =>
  contact?.additionalAttributes?.companyName ||
  contact?.additionalAttributes?.company_name ||
  contact?.additional_attributes?.company_name ||
  contact?.additional_attributes?.companyName ||
  contact?.company_name ||
  '';

const relationshipOptions = computed(() => [
  { value: 'lead', label: t('CONTACTS_DATA_GRID.RELATIONSHIPS.LEAD') },
  { value: 'customer', label: t('CONTACTS_DATA_GRID.RELATIONSHIPS.CUSTOMER') },
]);

const lifecycleOptions = computed(() => [
  { value: 'visitor', label: t('CONTACTS_DATA_GRID.STAGES.VISITOR') },
  { value: 'lead', label: t('CONTACTS_DATA_GRID.STAGES.LEAD') },
  {
    value: 'qualified_lead',
    label: t('CONTACTS_DATA_GRID.STAGES.QUALIFIED_LEAD'),
  },
  { value: 'triage', label: t('CONTACTS_DATA_GRID.STAGES.TRIAGE') },
  {
    value: 'consultation_scheduled',
    label: t('CONTACTS_DATA_GRID.STAGES.CONSULTATION_SCHEDULED'),
  },
  { value: 'customer', label: t('CONTACTS_DATA_GRID.STAGES.CUSTOMER') },
  {
    value: 'active_customer',
    label: t('CONTACTS_DATA_GRID.STAGES.ACTIVE_CUSTOMER'),
  },
  {
    value: 'recurring_customer',
    label: t('CONTACTS_DATA_GRID.STAGES.RECURRING_CUSTOMER'),
  },
  { value: 'ex_customer', label: t('CONTACTS_DATA_GRID.STAGES.EX_CUSTOMER') },
  { value: 'lost', label: t('CONTACTS_DATA_GRID.STAGES.LOST') },
]);

const columns = computed(() => [
  {
    id: 'name',
    header: t('CONTACTS_DATA_GRID.COLUMNS.NAME'),
    accessorKey: 'name',
    editType: 'text',
    width: 200,
  },
  {
    id: 'email',
    header: t('CONTACTS_DATA_GRID.COLUMNS.EMAIL'),
    accessorKey: 'email',
    editType: 'text',
    width: 220,
  },
  {
    id: 'phone_number',
    header: t('CONTACTS_DATA_GRID.COLUMNS.PHONE'),
    accessorKey: 'phone_number',
    editType: 'text',
    width: 160,
  },
  {
    id: 'company_name',
    header: t('CONTACTS_DATA_GRID.COLUMNS.COMPANY'),
    accessorKey: 'company_name',
    editType: 'text',
    width: 180,
  },
  {
    id: 'relationship_status',
    header: t('CONTACTS_DATA_GRID.COLUMNS.RELATIONSHIP'),
    accessorKey: 'relationship_status',
    editType: 'select',
    editOptions: relationshipOptions.value,
    width: 150,
  },
  {
    id: 'lifecycle_stage',
    header: t('CONTACTS_DATA_GRID.COLUMNS.LIFECYCLE_STAGE'),
    accessorKey: 'lifecycle_stage',
    editType: 'select',
    editOptions: lifecycleOptions.value,
    width: 180,
  },
  {
    id: 'location',
    header: t('CONTACTS_DATA_GRID.COLUMNS.LOCATION'),
    accessorKey: 'location',
    editType: 'text',
    width: 160,
  },
]);

const gridData = computed(() => {
  return (contactsList.value || []).map(contact => ({
    ...contact,
    company_name: getCompanyName(contact),
    phone_number: contact.phoneNumber || contact.phone_number || '',
    relationship_status:
      contact.relationshipStatus || contact.relationship_status || '',
    lifecycle_stage: contact.lifecycleStage || contact.lifecycle_stage || '',
    location: contact.location || '',
  }));
});

const activeContact = computed(() => {
  if (!activeContactId.value) return null;
  const found = (contactsList.value || []).find(
    c => String(c.id) === String(activeContactId.value)
  );
  if (found) return found;
  if (typeof contactByIdGetter.value === 'function') {
    return contactByIdGetter.value(activeContactId.value) || null;
  }
  return null;
});

const drawerFields = computed(() => {
  if (!activeContact.value) return [];
  const c = activeContact.value;
  return [
    {
      id: 'name',
      label: t('CONTACTS_DATA_GRID.FIELDS.NAME'),
      value: c.name || '',
      editable: true,
      editType: 'text',
    },
    {
      id: 'email',
      label: t('CONTACTS_DATA_GRID.FIELDS.EMAIL'),
      value: c.email || '',
      editable: true,
      editType: 'text',
    },
    {
      id: 'phone_number',
      label: t('CONTACTS_DATA_GRID.FIELDS.PHONE'),
      value: c.phoneNumber || c.phone_number || '',
      editable: true,
      editType: 'text',
    },
    {
      id: 'company_name',
      label: t('CONTACTS_DATA_GRID.FIELDS.COMPANY'),
      value: getCompanyName(c),
      editable: true,
      editType: 'text',
    },
    {
      id: 'relationship_status',
      label: t('CONTACTS_DATA_GRID.FIELDS.RELATIONSHIP'),
      value: c.relationshipStatus || c.relationship_status || '',
      editable: true,
      editType: 'select',
      options: relationshipOptions.value,
    },
    {
      id: 'lifecycle_stage',
      label: t('CONTACTS_DATA_GRID.FIELDS.LIFECYCLE_STAGE'),
      value: c.lifecycleStage || c.lifecycle_stage || '',
      editable: true,
      editType: 'select',
      options: lifecycleOptions.value,
    },
    {
      id: 'location',
      label: t('CONTACTS_DATA_GRID.FIELDS.LOCATION'),
      value: c.location || '',
      editable: true,
      editType: 'text',
    },
  ];
});

const drawerQuickActions = computed(() => {
  if (!activeContact.value) return [];
  return [
    {
      id: 'toggle_block',
      label: activeContact.value.blocked
        ? t('CONTACTS_DATA_GRID.DRAWER.UNBLOCK_CONTACT')
        : t('CONTACTS_DATA_GRID.DRAWER.BLOCK_CONTACT'),
      icon: activeContact.value.blocked
        ? 'i-lucide-shield-check'
        : 'i-lucide-shield-ban',
      variant: 'secondary',
    },
  ];
});

const bulkActions = computed(() => [
  {
    id: 'delete',
    label: t('CONTACTS_BULK_ACTIONS.DELETE_CONTACTS'),
    icon: 'i-lucide-trash-2',
    variant: 'danger',
  },
]);

const columnVisibility = computed(
  () => uiSettings.value?.contacts_grid_visibility || {}
);
const columnOrder = computed(() => uiSettings.value?.contacts_grid_order || []);
const columnSizing = computed(
  () => uiSettings.value?.contacts_grid_sizing || {}
);

const onColumnVisibilityChange = next => {
  updateUISettings({ contacts_grid_visibility: next });
};

const onColumnOrderChange = next => {
  updateUISettings({ contacts_grid_order: next });
};

const onColumnSizingChange = next => {
  updateUISettings({ contacts_grid_sizing: next });
};

const fetchContacts = async () => {
  const page = Number(route.query?.page) || 1;
  const sort = route.query?.sort || '-last_activity_at';
  const query = searchQuery.value;

  if (query) {
    await store.dispatch('contacts/search', {
      search: query,
      page,
      sortAttr: sort,
    });
  } else {
    await store.dispatch('contacts/get', {
      page,
      sortAttr: sort,
    });
  }
};

const handleCellUpdate = async ({ rowId, columnId, value, previousValue }) => {
  const existing = (contactsList.value || []).find(
    c => String(c.id) === String(rowId)
  );

  // Optimistic update
  if (columnId === 'company_name') {
    const prevAddAttr =
      existing?.additional_attributes || existing?.additionalAttributes || {};
    store.commit('contacts/EDIT_CONTACT', {
      id: Number(rowId),
      additional_attributes: { ...prevAddAttr, company_name: value },
    });
  } else {
    store.commit('contacts/EDIT_CONTACT', {
      id: Number(rowId),
      [columnId]: value,
    });
  }

  try {
    let payload = { id: rowId };
    if (columnId === 'company_name') {
      const prevAddAttr =
        existing?.additional_attributes || existing?.additionalAttributes || {};
      payload.additional_attributes = {
        ...prevAddAttr,
        company_name: value,
      };
    } else {
      payload[columnId] = value;
    }
    await store.dispatch('contacts/update', payload);
    useAlert(t('CONTACTS_DATA_GRID.UPDATE_SUCCESS'));
  } catch (error) {
    // Rollback
    if (columnId === 'company_name') {
      const prevAddAttr =
        existing?.additional_attributes || existing?.additionalAttributes || {};
      store.commit('contacts/EDIT_CONTACT', {
        id: Number(rowId),
        additional_attributes: { ...prevAddAttr, company_name: previousValue },
      });
    } else {
      store.commit('contacts/EDIT_CONTACT', {
        id: Number(rowId),
        [columnId]: previousValue,
      });
    }
    useAlert(t('CONTACTS_DATA_GRID.UPDATE_ERROR'));
  }
};

const handleDrawerFieldUpdate = ({ fieldId, value, previousValue }) => {
  if (!activeContactId.value) return;
  handleCellUpdate({
    rowId: activeContactId.value,
    columnId: fieldId,
    value,
    previousValue,
  });
};

const handleRowClick = row => {
  activeContactId.value = row.id;
  isDrawerOpen.value = true;
};

const handleCloseDrawer = () => {
  isDrawerOpen.value = false;
  if (route.params.contactId) {
    router.push({ name: 'contacts_dashboard_index', query: route.query });
  }
};

const handleQuickAction = async actionId => {
  if (actionId === 'toggle_block' && activeContact.value) {
    const nextBlocked = !activeContact.value.blocked;
    try {
      await store.dispatch('contacts/update', {
        ...activeContact.value,
        blocked: nextBlocked,
      });
      useAlert(
        nextBlocked
          ? t('CONTACT_PANEL.MUTED_SUCCESS')
          : t('CONTACT_PANEL.UNMUTED_SUCCESS')
      );
    } catch (error) {
      useAlert(t('CONTACTS_DATA_GRID.UPDATE_ERROR'));
    }
  }
};

const handleBulkAction = async actionId => {
  if (actionId === 'delete' && selectedRows.value.length) {
    const ids = selectedRows.value.map(item => item.id);
    try {
      await BulkActionsAPI.create({
        type: 'Contact',
        ids,
        action_name: 'delete',
      });
      useAlert(t('CONTACTS_BULK_ACTIONS.DELETE_SUCCESS'));
      selectedRows.value = [];
      await fetchContacts();
    } catch (error) {
      useAlert(t('CONTACTS_BULK_ACTIONS.DELETE_FAILED'));
    }
  }
};

const handleSearch = () => {
  router.replace({
    query: {
      ...route.query,
      search: searchQuery.value || undefined,
      page: 1,
    },
  });
  fetchContacts();
};

watch(
  () => route.params.contactId,
  newId => {
    if (newId) {
      activeContactId.value = newId;
      isDrawerOpen.value = true;
      store.dispatch('contacts/show', { id: newId });
    }
  }
);

onMounted(async () => {
  await fetchContacts();
  if (route.params.contactId) {
    activeContactId.value = route.params.contactId;
    isDrawerOpen.value = true;
    await store.dispatch('contacts/show', { id: route.params.contactId });
  }
});
</script>

<template>
  <div class="flex h-full w-full flex-col overflow-hidden bg-ui-surface">
    <!-- Header -->
    <header
      class="flex shrink-0 items-center justify-between border-b border-ui-border-subtle bg-ui-surface px-6 py-4"
    >
      <div class="flex min-w-0 flex-col">
        <h1 class="m-0 text-ui-title font-semibold text-ui-text">
          {{ t('CONTACTS_DATA_GRID.TITLE') }}
        </h1>
        <p class="m-0 text-ui-body-sm text-ui-text-muted">
          {{ t('CONTACTS_DATA_GRID.SUBTITLE') }}
        </p>
      </div>
      <div class="flex items-center gap-3">
        <DsInput
          v-model="searchQuery"
          :placeholder="t('CONTACTS_DATA_GRID.SEARCH_PLACEHOLDER')"
          prefix-icon="i-lucide-search"
          hide-label
          class="w-64"
          @enter="handleSearch"
        />
        <DsButton
          variant="secondary"
          size="sm"
          icon="i-lucide-search"
          @click="handleSearch"
        />
      </div>
    </header>

    <!-- Main Grid Content -->
    <main class="flex-1 overflow-auto p-6">
      <DsDataGrid
        :columns="columns"
        :data="gridData"
        :loading="isFetching"
        selectable
        enable-inline-edit
        :selected-rows="selectedRows"
        :column-visibility="columnVisibility"
        :column-order="columnOrder"
        :column-sizing="columnSizing"
        row-key="id"
        @update:selected-rows="selectedRows = $event"
        @update:column-visibility="onColumnVisibilityChange"
        @update:column-order="onColumnOrderChange"
        @update:column-sizing="onColumnSizingChange"
        @cell-update="handleCellUpdate"
        @row-click="handleRowClick"
      />
    </main>

    <!-- Floating Bulk Actions Bar -->
    <DsBulkActionBar
      :count="selectedRows.length"
      :actions="bulkActions"
      @action="handleBulkAction"
      @clear="selectedRows = []"
    />

    <!-- Peek Record Drawer 360 -->
    <DsRecordDrawer
      :open="isDrawerOpen"
      :title="
        activeContact?.name ||
        activeContact?.email ||
        t('CONTACT_PANEL.NOT_AVAILABLE')
      "
      :subtitle="activeContact?.email || activeContact?.phone_number || ''"
      :avatar-url="activeContact?.thumbnail || activeContact?.avatar_url || ''"
      :avatar-name="activeContact?.name || ''"
      :active-tab="drawerActiveTab"
      :tabs="drawerTabs"
      :fields="drawerFields"
      :quick-actions="drawerQuickActions"
      @close="handleCloseDrawer"
      @update:active-tab="drawerActiveTab = $event"
      @field-update="handleDrawerFieldUpdate"
      @quick-action="handleQuickAction"
    >
      <template v-if="crmDocumentsEnabled && activeContact?.id" #documents>
        <CRMDocumentVault
          :contact-id="Number(activeContact.id)"
          :contact-name="activeContact.name || ''"
          @unavailable="onDocumentVaultUnavailable"
        />
      </template>
    </DsRecordDrawer>
  </div>
</template>

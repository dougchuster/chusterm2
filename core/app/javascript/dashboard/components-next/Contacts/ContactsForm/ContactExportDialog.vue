<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import ContactAPI from 'dashboard/api/contacts';
import { useAlert } from 'dashboard/composables';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['export']);

const { t } = useI18n();
const route = useRoute();

const dialogRef = ref(null);
const isDownloadingCsv = ref(false);
const isSyncingGoogleSheet = ref(false);
const isConnectingGoogle = ref(false);
const googleSheetText = {
  description:
    'Enviar os contatos filtrados para uma nova planilha no Google Sheets.',
  sync: 'Criar Google Sheet',
  connect: 'Conectar Google',
  success: 'Planilha criada no Google Sheets.',
  error: 'Não foi possível criar a planilha no Google Sheets.',
};

const segments = useMapGetter('customViews/getContactCustomViews');
const appliedFilters = useMapGetter('contacts/getAppliedContactFilters');
const uiFlags = useMapGetter('contacts/getUIFlags');
const isExportingContact = computed(() => uiFlags.value.isExporting);
const isBusy = computed(
  () =>
    isExportingContact.value ||
    isDownloadingCsv.value ||
    isSyncingGoogleSheet.value ||
    isConnectingGoogle.value
);

const activeSegmentId = computed(() => route.params.segmentId);
const activeSegment = computed(() =>
  activeSegmentId.value
    ? segments.value.find(view => view.id === Number(activeSegmentId.value))
    : undefined
);

const normalizePayload = payload =>
  payload.map((filter, index) => ({
    ...filter,
    query_operator: index === payload.length - 1 ? null : 'and',
  }));

const quickFilterPayload = () => {
  const query = route.query || {};
  const payload = [];
  const addFilter = ({
    attributeKey,
    value,
    attributeModel = 'standard',
    filterOperator = 'equal_to',
  }) => {
    if (!value) return;
    payload.push({
      attribute_key: attributeKey,
      filter_operator: filterOperator,
      values: Array.isArray(value) ? value : [value],
      query_operator: 'and',
      attribute_model: attributeModel,
    });
  };

  addFilter({
    attributeKey: 'relationship_status',
    value: query.relationship_status,
  });
  addFilter({ attributeKey: 'lifecycle_stage', value: query.lifecycle_stage });
  addFilter({ attributeKey: 'crm_owner_id', value: query.crm_owner_id });
  addFilter({
    attributeKey: 'source_list',
    value: query.source_list,
    attributeModel: 'additional_attributes',
  });
  addFilter({
    attributeKey: 'legal_area',
    value: query.legal_area,
    attributeModel: 'additional_attributes',
    filterOperator: 'contains',
  });

  if (query.without_crm_owner === 'true') {
    payload.push({
      attribute_key: 'crm_owner_id',
      filter_operator: 'is_not_present',
      values: [],
      query_operator: 'and',
      attribute_model: 'standard',
    });
  }

  const labelValues = [
    ...new Set([route.params.label, query.label].filter(Boolean)),
  ];
  addFilter({ attributeKey: 'labels', value: labelValues });

  return payload;
};

const buildExportQuery = () => {
  let query = { payload: [] };

  if (activeSegmentId.value && activeSegment.value) {
    query = activeSegment.value.query;
  } else if (Object.keys(appliedFilters.value).length > 0) {
    query = filterQueryGenerator(appliedFilters.value);
  }

  const payload = [...(query.payload || []), ...quickFilterPayload()];

  return {
    ...query,
    payload: normalizePayload(payload),
    label: route.params.label || '',
  };
};

const exportContacts = async () => {
  emit('export', buildExportQuery());
};

const downloadBlob = blob => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `contatos-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
};

const downloadContactsCsv = async () => {
  isDownloadingCsv.value = true;
  try {
    const response = await ContactAPI.exportContactsCsv(buildExportQuery());
    downloadBlob(response.data);
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CSV_SUCCESS'));
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CSV_ERROR'));
  } finally {
    isDownloadingCsv.value = false;
  }
};

const connectGoogleWorkspace = async () => {
  isConnectingGoogle.value = true;
  try {
    const response = await ContactAPI.authorizeGoogleWorkspace();
    if (response.data?.url) window.location.href = response.data.url;
  } catch (error) {
    useAlert(googleSheetText.error);
  } finally {
    isConnectingGoogle.value = false;
  }
};

const exportContactsGoogleSheet = async () => {
  isSyncingGoogleSheet.value = true;
  try {
    const response =
      await ContactAPI.exportContactsGoogleSheet(buildExportQuery());
    if (response.data?.url) window.open(response.data.url, '_blank');
    useAlert(googleSheetText.success);
  } catch (error) {
    if (error?.response?.data?.authorization_required) {
      await connectGoogleWorkspace();
      return;
    }
    useAlert(googleSheetText.error);
  } finally {
    isSyncingGoogleSheet.value = false;
  }
};

const handleDialogConfirm = async () => {
  await exportContacts();
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.TITLE')"
    :description="
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.DESCRIPTION')
    "
    :confirm-button-label="
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CONFIRM')
    "
    :is-loading="isExportingContact"
    :disable-confirm-button="isBusy"
    @confirm="handleDialogConfirm"
  >
    <div class="rounded-lg border border-n-weak bg-n-alpha-2 p-4">
      <p class="mb-3 text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CSV_DESCRIPTION') }}
      </p>
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="sm"
        icon="i-lucide-download"
        :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CSV_CONFIRM')"
        :is-loading="isDownloadingCsv"
        :disabled="isBusy"
        @click="downloadContactsCsv"
      />
    </div>
    <div class="mt-3 rounded-lg border border-n-weak bg-n-alpha-2 p-4">
      <p class="mb-3 text-sm text-n-slate-11">
        {{ googleSheetText.description }}
      </p>
      <div class="flex flex-wrap gap-2">
        <Button
          type="button"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-table-2"
          :label="googleSheetText.sync"
          :is-loading="isSyncingGoogleSheet"
          :disabled="isBusy"
          @click="exportContactsGoogleSheet"
        />
        <Button
          type="button"
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-key-round"
          :label="googleSheetText.connect"
          :is-loading="isConnectingGoogle"
          :disabled="isBusy"
          @click="connectGoogleWorkspace"
        />
      </div>
    </div>
  </Dialog>
</template>

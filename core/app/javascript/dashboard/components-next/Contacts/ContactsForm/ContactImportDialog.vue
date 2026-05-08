<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const emit = defineEmits(['import']);
const { t } = useI18n();

const uiFlags = useMapGetter('contacts/getUIFlags');
const isImportingContact = computed(() => uiFlags.value.isImporting);

const dialogRef = ref(null);
const fileInput = ref(null);

const hasSelectedFile = ref(null);
const selectedFileName = ref('');
const previewHeaders = ref([]);
const previewRows = ref([]);
const columnMapping = ref({});
const importOptions = ref({
  sourceList: '',
  labels: '',
  relationshipStatus: 'lead',
  lifecycleStage: 'lead',
  legalArea: '',
  crmOwnerEmail: '',
  duplicateStrategy: 'update',
});

const fieldText = {
  sourceList: 'Nome da lista',
  sourceListPlaceholder: 'Ex: Leads INSS Maio',
  labels: 'Categorias adicionais',
  labelsPlaceholder: 'Ex: DF, Previdenciario, Re-marketing',
  relationship: 'Relacionamento',
  lifecycle: 'Etapa',
  legalArea: 'Setor jurídico',
  legalAreaPlaceholder: 'Ex: Previdenciario',
  owner: 'Responsável',
  ownerPlaceholder: 'email do responsável',
  duplicateStrategy: 'Duplicados',
  columnMapping: 'Mapeamento de colunas',
  columnMappingHint:
    'Confirme como cada coluna da planilha deve entrar no CRM antes da importacao.',
  columnHeader: 'Coluna',
  sampleHeader: 'Exemplo',
  crmFieldHeader: 'Campo no CRM',
  preview: 'Preview da planilha',
};

const relationshipOptions = [
  { value: 'lead', label: 'Lead' },
  { value: 'customer', label: 'Cliente' },
];

const lifecycleOptions = [
  { value: 'lead', label: 'Lead' },
  { value: 'qualified_lead', label: 'Lead qualificado' },
  { value: 'triage', label: 'Triagem' },
  { value: 'consultation_scheduled', label: 'Consulta agendada' },
  { value: 'customer', label: 'Cliente' },
];

const duplicateStrategyOptions = [
  { value: 'update', label: 'Atualizar contato existente' },
  { value: 'ignore', label: 'Ignorar duplicados' },
  { value: 'create_new', label: 'Criar novo contato' },
];

const csvUrl = '/downloads/import-contacts-sample.csv';
const previewDisplayHeaders = computed(() => previewHeaders.value.slice(0, 8));
const previewDisplayRows = computed(() =>
  previewRows.value.map(row => row.slice(0, 8))
);

const mappingOptions = [
  { value: '__ignore__', label: 'Ignorar coluna' },
  { value: 'name', label: 'Nome' },
  { value: 'email', label: 'Email' },
  { value: 'phone_number', label: 'Telefone / WhatsApp' },
  { value: 'identifier', label: 'Identificador / CPF' },
  { value: 'company', label: 'Empresa' },
  { value: 'city', label: 'Cidade' },
  { value: 'categories', label: 'Categorias' },
  { value: 'labels', label: 'Etiquetas antigas' },
  { value: 'source_list', label: 'Lista de origem' },
  { value: 'relationship_status', label: 'Lead ou cliente' },
  { value: 'lifecycle_stage', label: 'Etapa do contato' },
  { value: 'legal_area', label: 'Setor jurídico' },
  { value: 'crm_owner_email', label: 'Responsável por email' },
  { value: '__custom__', label: 'Atributo customizado' },
];

const relationshipSelectOptions = relationshipOptions.map(option => ({
  value: option.value,
  label: option.label,
}));

const lifecycleSelectOptions = lifecycleOptions.map(option => ({
  value: option.value,
  label: option.label,
}));

const duplicateStrategySelectOptions = duplicateStrategyOptions.map(option => ({
  value: option.value,
  label: option.label,
}));

const handleFileClick = () => fileInput.value?.click();

const processFileName = fileName => {
  const lastDotIndex = fileName.lastIndexOf('.');
  const extension = fileName.slice(lastDotIndex);
  const baseName = fileName.slice(0, lastDotIndex);

  return baseName.length > 20
    ? `${baseName.slice(0, 20)}...${extension}`
    : fileName;
};

const parsePreviewLine = line =>
  line.split(',').map(value => value.trim().replace(/^"|"$/g, ''));

const normalizeHeader = header =>
  header
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');

const guessMappingForHeader = header => {
  const normalizedHeader = normalizeHeader(header);

  if (
    ['nome', 'nome_completo', 'name', 'cliente', 'contato'].includes(
      normalizedHeader
    )
  )
    return 'name';
  if (['email', 'e_mail', 'mail'].includes(normalizedHeader)) return 'email';
  if (
    ['telefone', 'celular', 'whatsapp', 'phone', 'phone_number'].includes(
      normalizedHeader
    )
  )
    return 'phone_number';
  if (
    ['cpf', 'documento', 'identificador', 'identifier'].includes(
      normalizedHeader
    )
  )
    return 'identifier';
  if (['empresa', 'company'].includes(normalizedHeader)) return 'company';
  if (['cidade', 'city'].includes(normalizedHeader)) return 'city';
  if (['categoria', 'categorias', 'lista', 'listas'].includes(normalizedHeader))
    return 'categories';
  if (
    ['etiqueta', 'etiquetas', 'tag', 'tags', 'labels'].includes(
      normalizedHeader
    )
  )
    return 'labels';
  if (
    ['lista', 'lista_origem', 'source_list', 'origem'].includes(
      normalizedHeader
    )
  )
    return 'source_list';
  if (
    ['relacionamento', 'lead_cliente', 'relationship_status'].includes(
      normalizedHeader
    )
  ) {
    return 'relationship_status';
  }
  if (
    ['etapa', 'lifecycle_stage', 'funil', 'status'].includes(normalizedHeader)
  )
    return 'lifecycle_stage';
  if (['área', 'área_jurídica', 'legal_area'].includes(normalizedHeader))
    return 'legal_area';
  if (['responsável', 'owner', 'crm_owner_email'].includes(normalizedHeader))
    return 'crm_owner_email';

  return '__custom__';
};

const buildDefaultColumnMapping = () => {
  columnMapping.value = previewHeaders.value.reduce((mapping, header) => {
    mapping[header] = guessMappingForHeader(header);
    return mapping;
  }, {});
};

const sampleValueForHeader = headerIndex =>
  previewRows.value.find(row => row[headerIndex])?.[headerIndex] || '-';

const buildPreview = file => {
  const reader = new FileReader();
  reader.onload = event => {
    const lines = String(event.target?.result || '')
      .split(/\r?\n/)
      .filter(Boolean)
      .slice(0, 4);
    previewHeaders.value = parsePreviewLine(lines[0] || '');
    previewRows.value = lines.slice(1).map(parsePreviewLine);
    buildDefaultColumnMapping();
  };
  reader.readAsText(file);
};

const handleFileChange = () => {
  const file = fileInput.value?.files[0];
  hasSelectedFile.value = file;
  selectedFileName.value = file ? processFileName(file.name) : '';
  previewHeaders.value = [];
  previewRows.value = [];
  columnMapping.value = {};
  if (file) buildPreview(file);
};

const handleRemoveFile = () => {
  hasSelectedFile.value = null;
  if (fileInput.value) {
    fileInput.value.value = null;
  }
  selectedFileName.value = '';
  previewHeaders.value = [];
  previewRows.value = [];
  columnMapping.value = {};
};

const mappedColumnPayload = () =>
  Object.entries(columnMapping.value).reduce((mapping, [header, target]) => {
    if (target) mapping[header] = target;
    return mapping;
  }, {});

const uploadFile = async () => {
  if (!hasSelectedFile.value) return;
  emit('import', {
    file: hasSelectedFile.value,
    options: {
      source_list: importOptions.value.sourceList,
      labels: importOptions.value.labels
        .split(/[,;|]/)
        .map(label => label.trim())
        .filter(Boolean),
      categories: importOptions.value.labels
        .split(/[,;|]/)
        .map(label => label.trim())
        .filter(Boolean),
      relationship_status: importOptions.value.relationshipStatus,
      lifecycle_stage: importOptions.value.lifecycleStage,
      legal_area: importOptions.value.legalArea,
      crm_owner_email: importOptions.value.crmOwnerEmail,
      duplicate_strategy: importOptions.value.duplicateStrategy,
      column_mapping: mappedColumnPayload(),
    },
  });
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TITLE')"
    :confirm-button-label="
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT')
    "
    :is-loading="isImportingContact"
    :disable-confirm-button="isImportingContact || !hasSelectedFile"
    @confirm="uploadFile"
  >
    <template #description>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DESCRIPTION') }}
        <a
          :href="csvUrl"
          target="_blank"
          rel="noopener noreferrer"
          download="import-contacts-sample.csv"
          class="text-n-blue-11"
        >
          {{
            t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DOWNLOAD_LABEL')
          }}
        </a>
      </p>
    </template>

    <div class="flex flex-col gap-3">
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        <span class="font-medium">{{ fieldText.sourceList }}</span>
        <input
          v-model="importOptions.sourceList"
          type="text"
          :placeholder="fieldText.sourceListPlaceholder"
          class="h-9 rounded border border-n-weak bg-n-surface-1 px-3 outline-none"
        />
      </label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        <span class="font-medium">{{ fieldText.labels }}</span>
        <input
          v-model="importOptions.labels"
          type="text"
          :placeholder="fieldText.labelsPlaceholder"
          class="h-9 rounded border border-n-weak bg-n-surface-1 px-3 outline-none"
        />
      </label>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          <span class="font-medium">{{ fieldText.relationship }}</span>
          <Select
            v-model="importOptions.relationshipStatus"
            :options="relationshipSelectOptions"
            block
          />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          <span class="font-medium">{{ fieldText.lifecycle }}</span>
          <Select
            v-model="importOptions.lifecycleStage"
            :options="lifecycleSelectOptions"
            block
          />
        </label>
      </div>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          <span class="font-medium">{{ fieldText.legalArea }}</span>
          <input
            v-model="importOptions.legalArea"
            type="text"
            :placeholder="fieldText.legalAreaPlaceholder"
            class="h-9 rounded border border-n-weak bg-n-surface-1 px-3 outline-none"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          <span class="font-medium">{{ fieldText.owner }}</span>
          <input
            v-model="importOptions.crmOwnerEmail"
            type="email"
            :placeholder="fieldText.ownerPlaceholder"
            class="h-9 rounded border border-n-weak bg-n-surface-1 px-3 outline-none"
          />
        </label>
      </div>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        <span class="font-medium">{{ fieldText.duplicateStrategy }}</span>
        <Select
          v-model="importOptions.duplicateStrategy"
          :options="duplicateStrategySelectOptions"
          block
        />
      </label>
      <div class="flex items-center gap-2">
        <label class="text-sm text-n-slate-12 whitespace-nowrap">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.LABEL') }}
        </label>
        <div class="flex items-center justify-between w-full gap-2">
          <span v-if="hasSelectedFile" class="text-sm text-n-slate-12">
            {{ selectedFileName }}
          </span>
          <Button
            v-if="!hasSelectedFile"
            :label="
              t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHOOSE_FILE')
            "
            icon="i-lucide-upload"
            color="slate"
            variant="ghost"
            size="sm"
            class="!w-fit"
            @click="handleFileClick"
          />
          <div v-else class="flex items-center gap-1">
            <Button
              :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANGE')"
              color="slate"
              variant="ghost"
              size="sm"
              @click="handleFileClick"
            />
            <div class="w-px h-3 bg-n-strong" />
            <Button
              icon="i-lucide-trash"
              color="slate"
              variant="ghost"
              size="sm"
              @click="handleRemoveFile"
            />
          </div>
        </div>
      </div>
      <div
        v-if="previewHeaders.length"
        class="rounded border border-n-weak bg-n-slate-1 p-3 text-xs"
      >
        <div class="mb-3">
          <div class="font-medium text-n-slate-12">
            {{ fieldText.columnMapping }}
          </div>
          <p class="mt-1 text-n-slate-11">
            {{ fieldText.columnMappingHint }}
          </p>
          <div class="mt-2 max-h-56 overflow-y-auto">
            <table class="min-w-full text-left">
              <thead>
                <tr>
                  <th
                    class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-11"
                  >
                    {{ fieldText.columnHeader }}
                  </th>
                  <th
                    class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-11"
                  >
                    {{ fieldText.sampleHeader }}
                  </th>
                  <th
                    class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-11"
                  >
                    {{ fieldText.crmFieldHeader }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(header, headerIndex) in previewHeaders"
                  :key="header"
                >
                  <td
                    class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-12"
                  >
                    {{ header }}
                  </td>
                  <td
                    class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-11"
                  >
                    {{ sampleValueForHeader(headerIndex) }}
                  </td>
                  <td class="border-b border-n-weak px-2 py-1">
                    <Select
                      v-model="columnMapping[header]"
                      :options="mappingOptions"
                      class="min-w-44"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <div class="mb-2 font-medium text-n-slate-12">
          {{ fieldText.preview }}
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full text-left">
            <thead>
              <tr>
                <th
                  v-for="header in previewDisplayHeaders"
                  :key="header"
                  class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-11"
                >
                  {{ header }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, rowIndex) in previewDisplayRows" :key="rowIndex">
                <td
                  v-for="(value, valueIndex) in row"
                  :key="`${rowIndex}-${valueIndex}`"
                  class="whitespace-nowrap border-b border-n-weak px-2 py-1 text-n-slate-12"
                >
                  {{ value }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    <input
      ref="fileInput"
      type="file"
      accept="text/csv"
      class="hidden"
      @change="handleFileChange"
    />
  </Dialog>
</template>

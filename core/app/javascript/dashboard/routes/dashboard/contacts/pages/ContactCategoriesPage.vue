<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';

import ContactAPI from 'dashboard/api/contacts';
import ContactCategoriesAPI from 'dashboard/api/contactCategories';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const router = useRouter();

const CATEGORY_COLORS = [
  '#2563eb',
  '#059669',
  '#7c3aed',
  '#ea580c',
  '#0891b2',
  '#dc2626',
  '#475569',
];

const FOLDERS = [
  {
    key: 'area',
    title: 'Setor jurídico',
    description: 'Áreas do caso, como INSS, Trabalhista e Família.',
    icon: 'i-lucide-scale',
  },
  {
    key: 'location',
    title: 'Localidade',
    description: 'Estados, cidades e regiões para segmentação local.',
    icon: 'i-lucide-globe',
  },
  {
    key: 'campaign',
    title: 'Campanhas e listas',
    description: 'Audiências de remarketing e ações comerciais.',
    icon: 'i-lucide-megaphone',
  },
  {
    key: 'origin',
    title: 'Origem',
    description: 'Canais, listas importadas e fontes de entrada.',
    icon: 'i-lucide-route',
  },
  {
    key: 'restriction',
    title: 'Restrições',
    description: 'Opt-out, não chamar e regras de cuidado.',
    icon: 'i-lucide-shield-alert',
  },
  {
    key: 'custom',
    title: 'Outras categorias',
    description: 'Pastas livres criadas pela operação.',
    icon: 'i-lucide-tags',
  },
];
const FOLDER_KEYS = FOLDERS.map(folder => folder.key);

const CATEGORY_KIND_OPTIONS = FOLDERS.map(folder => ({
  value: folder.key,
  label: folder.title,
}));

const pageText = {
  title: 'Categorias',
  subtitle:
    'Organize suas listas em pastas, importe contatos, exporte audiências e acompanhe duplicados.',
  allFolders: 'Pastas',
  backToFolders: 'Voltar para pastas',
  backToFolder: 'Voltar para pasta',
  createCategory: 'Criar lista',
  newCategory: 'Nova lista',
  name: 'Nome',
  type: 'Tipo',
  color: 'Cor',
  description: 'Descrição',
  contacts: 'contatos',
  open: 'Abrir',
  edit: 'Editar',
  delete: 'Excluir',
  import: 'Importar',
  exportCsv: 'Exportar CSV',
  exportSheet: 'Google Sheets',
  latestImport: 'Última importação',
  noLatestImport: 'Sem importações',
  importHistory: 'Histórico de importações',
  contactsListTitle: 'Contatos da lista',
  listActions: 'Ações da lista',
  lists: 'listas',
  separator: '-',
  processed: 'processados',
  newRecords: 'novos',
  duplicates: 'duplicados',
  rejected: 'rejeitados',
  downloadFailures: 'Baixar falhas',
  tableName: 'Nome',
  tablePhone: 'Telefone',
  tableEmail: 'E-mail',
  tableType: 'Tipo',
  folderEmpty: 'Nenhuma lista criada nesta pasta.',
  detailEmpty: 'Nenhum contato nesta lista.',
  duplicateHint:
    'Duplicados por CPF/identificador, e-mail ou telefone serão atualizados e sinalizados.',
  createSuccess: 'Lista criada.',
  updateSuccess: 'Lista atualizada.',
  deleteSuccess: 'Lista excluída.',
  importSuccess: 'Importação enviada. Os duplicados serão atualizados.',
  exportSuccess: 'Exportação iniciada.',
  exportError: 'Não foi possível exportar a lista.',
  genericError: 'Não foi possível concluir a ação.',
};

const categories = ref([]);
const imports = ref([]);
const contacts = ref([]);
const contactsMeta = ref({});
const isLoading = ref(false);
const isLoadingContacts = ref(false);
const isSavingCategory = ref(false);
const isDeletingCategory = ref(false);
const isImporting = ref(false);
const isExportingCsv = ref(false);
const isExportingSheet = ref(false);
const showCreateForm = ref(false);
const fileInputRef = ref(null);
const importTarget = ref(null);
const editDialogRef = ref(null);
const deleteDialogRef = ref(null);
const categoryToEdit = ref(null);
const categoryToDelete = ref(null);
const categoryForm = reactive({
  name: '',
  kind: 'custom',
  color: CATEGORY_COLORS[0],
  description: '',
});

const selectedKind = computed(() => route.params.kind?.toString() || '');
const selectedCategoryId = computed(() =>
  route.params.categoryId ? Number(route.params.categoryId) : null
);
const selectedFolder = computed(
  () => FOLDERS.find(folder => folder.key === selectedKind.value) || null
);
const selectedCategory = computed(() =>
  categories.value.find(category => category.id === selectedCategoryId.value)
);
const isFolderOverview = computed(() => !selectedKind.value);
const isFolderView = computed(
  () => !!selectedKind.value && !selectedCategoryId.value
);
const isCategoryDetail = computed(() => !!selectedCategoryId.value);

const categoryKind = category =>
  category?.kind || category?.category || 'custom';
const categoryFolderKind = category => {
  const kind = categoryKind(category);
  return FOLDER_KEYS.includes(kind) ? kind : 'custom';
};
const categoryDisplayName = category => {
  const title = category?.title || category?.display_title || '';

  return title
    .toString()
    .replace(
      /^(area|origin|location|campaign|custom|status|restriction|rel|temp|risk|doc)[._]/,
      ''
    )
    .replace(/_/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase());
};
const categoryContactCount = category => category?.contacts_count || 0;
const folderCategories = kind =>
  categories.value.filter(category => categoryFolderKind(category) === kind);
const selectedFolderCategories = computed(() =>
  selectedKind.value ? folderCategories(selectedKind.value) : []
);
const totalContactsInFolder = folder =>
  folderCategories(folder.key).reduce(
    (total, category) => total + categoryContactCount(category),
    0
  );

const resetCategoryForm = (kind = selectedKind.value || 'custom') => {
  categoryForm.name = '';
  categoryForm.kind = kind;
  categoryForm.color =
    CATEGORY_COLORS[categories.value.length % CATEGORY_COLORS.length];
  categoryForm.description = '';
};

const sanitizeCategoryTitle = value =>
  value
    .toString()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');

const importCategories = item => [
  ...new Set([
    ...(Array.isArray(item.metadata?.categories)
      ? item.metadata.categories
      : []),
    ...(Array.isArray(item.metadata?.labels) ? item.metadata.labels : []),
  ]),
];

const importsForCategory = category => {
  if (!category) return [];

  return imports.value.filter(item => {
    const metadataCategories = importCategories(item);
    return (
      metadataCategories.includes(category.title) ||
      item.metadata?.source_list === category.title ||
      item.metadata?.source_list === categoryDisplayName(category)
    );
  });
};

const latestImportForCategory = category => importsForCategory(category)[0];
const importSummary = item => item?.metadata?.import_summary || {};
const duplicateCount = item =>
  importSummary(item).duplicate_records ||
  importSummary(item).updated_records ||
  0;
const createdCount = item => importSummary(item).created_records || 0;
const rejectedCount = item => item?.rejected_records || 0;
const importStatusLabel = status =>
  ({
    pending: 'Pendente',
    processing: 'Processando',
    completed: 'Concluida',
    failed: 'Falhou',
  })[status] || status;

const loadCategories = async () => {
  const response = await ContactCategoriesAPI.get();
  categories.value = response.data?.payload || [];
};

const loadImports = async () => {
  const response = await ContactAPI.getImports();
  imports.value = response.data || [];
};

const loadPageData = async () => {
  isLoading.value = true;
  try {
    await Promise.all([loadCategories(), loadImports()]);
  } catch (error) {
    useAlert(pageText.genericError);
  } finally {
    isLoading.value = false;
  }
};

const loadCategoryContacts = async (page = 1) => {
  if (!selectedCategory.value) return;

  isLoadingContacts.value = true;
  try {
    const response = await ContactAPI.get(
      page,
      'name',
      selectedCategory.value.title
    );
    contacts.value = response.data?.payload || [];
    contactsMeta.value = response.data?.meta || {};
  } catch (error) {
    contacts.value = [];
    contactsMeta.value = {};
  } finally {
    isLoadingContacts.value = false;
  }
};

const openFolder = folder => {
  router.push({
    name: 'contacts_dashboard_category_kind',
    params: { ...route.params, kind: folder.key },
    query: {},
  });
};

const openCategory = category => {
  router.push({
    name: 'contacts_dashboard_category_detail',
    params: {
      ...route.params,
      kind: categoryFolderKind(category),
      categoryId: category.id,
    },
    query: {},
  });
};

const backToFolders = () => {
  router.push({
    name: 'contacts_dashboard_categories',
    params: route.params,
    query: {},
  });
};

const backToFolder = () => {
  router.push({
    name: 'contacts_dashboard_category_kind',
    params: { ...route.params, kind: selectedKind.value },
    query: {},
  });
};

const createCategory = async () => {
  const title = sanitizeCategoryTitle(categoryForm.name);
  if (!title || isSavingCategory.value) return;

  isSavingCategory.value = true;
  try {
    await ContactCategoriesAPI.create({
      category: {
        title,
        kind: categoryForm.kind,
        color: categoryForm.color,
        description: categoryForm.description,
      },
    });
    useAlert(pageText.createSuccess);
    showCreateForm.value = false;
    resetCategoryForm();
    await loadCategories();
  } catch (error) {
    useAlert(pageText.genericError);
  } finally {
    isSavingCategory.value = false;
  }
};

const openEditCategory = category => {
  categoryToEdit.value = category;
  categoryForm.name = categoryDisplayName(category);
  categoryForm.kind = categoryFolderKind(category);
  categoryForm.color = category.color || CATEGORY_COLORS[0];
  categoryForm.description = category.description || '';
  editDialogRef.value?.open?.();
};

const updateCategory = async () => {
  const category = categoryToEdit.value;
  const title = sanitizeCategoryTitle(categoryForm.name);
  if (!category || !title || isSavingCategory.value) return;

  isSavingCategory.value = true;
  try {
    const response = await ContactCategoriesAPI.update(category.id, {
      category: {
        title,
        kind: categoryForm.kind,
        color: categoryForm.color,
        description: categoryForm.description,
      },
    });
    const updated = response.data;
    useAlert(pageText.updateSuccess);
    editDialogRef.value?.close?.();
    await loadCategories();
    if (selectedCategoryId.value === category.id) {
      router.replace({
        name: 'contacts_dashboard_category_detail',
        params: {
          ...route.params,
          kind: categoryFolderKind(updated),
          categoryId: updated.id,
        },
        query: {},
      });
    }
  } catch (error) {
    useAlert(pageText.genericError);
  } finally {
    isSavingCategory.value = false;
  }
};

const openDeleteCategory = category => {
  categoryToDelete.value = category;
  deleteDialogRef.value?.open?.();
};

const deleteCategory = async () => {
  const category = categoryToDelete.value;
  if (!category || isDeletingCategory.value) return;

  isDeletingCategory.value = true;
  try {
    await ContactCategoriesAPI.delete(category.id);
    useAlert(pageText.deleteSuccess);
    deleteDialogRef.value?.close?.();
    if (selectedCategoryId.value === category.id) {
      await backToFolder();
    }
    await loadCategories();
  } catch (error) {
    useAlert(pageText.genericError);
  } finally {
    isDeletingCategory.value = false;
  }
};

const openImportFile = category => {
  importTarget.value = category;
  fileInputRef.value?.click();
};

const handleImportFile = async event => {
  const file = event.target.files?.[0];
  const category = importTarget.value;
  if (!file || !category) return;

  isImporting.value = true;
  try {
    await ContactAPI.importContacts(file, {
      source_list: categoryDisplayName(category),
      labels: [category.title],
      categories: [category.title],
      relationship_status: 'lead',
      lifecycle_stage: 'lead',
      legal_area:
        categoryKind(category) === 'area' ? categoryDisplayName(category) : '',
      duplicate_strategy: 'update',
    });
    useAlert(pageText.importSuccess);
    await Promise.all([loadImports(), loadCategories()]);
    await loadCategoryContacts(1);
  } catch (error) {
    useAlert(pageText.genericError);
  } finally {
    isImporting.value = false;
    importTarget.value = null;
    if (fileInputRef.value) fileInputRef.value.value = null;
  }
};

const downloadBlob = (blob, category) => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${category.title}-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
};

const exportCategoryCsv = async category => {
  if (!category || isExportingCsv.value) return;

  isExportingCsv.value = true;
  try {
    const response = await ContactAPI.exportContactsCsv({
      label: category.title,
    });
    downloadBlob(response.data, category);
    useAlert(pageText.exportSuccess);
  } catch (error) {
    useAlert(pageText.exportError);
  } finally {
    isExportingCsv.value = false;
  }
};

const exportCategoryGoogleSheet = async category => {
  if (!category || isExportingSheet.value) return;

  isExportingSheet.value = true;
  try {
    const response = await ContactAPI.exportContactsGoogleSheet({
      label: category.title,
    });
    if (response.data?.url) window.open(response.data.url, '_blank');
    useAlert(pageText.exportSuccess);
  } catch (error) {
    if (error?.response?.data?.authorization_required) {
      const response = await ContactAPI.authorizeGoogleWorkspace();
      if (response.data?.url) window.location.href = response.data.url;
      return;
    }
    useAlert(pageText.exportError);
  } finally {
    isExportingSheet.value = false;
  }
};

watch(
  () => [route.params.kind, route.params.categoryId, categories.value.length],
  () => {
    if (isCategoryDetail.value) loadCategoryContacts(1);
  }
);

onMounted(async () => {
  resetCategoryForm();
  await loadPageData();
  if (isCategoryDetail.value) await loadCategoryContacts(1);
});
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-auto bg-n-surface-1">
    <input
      ref="fileInputRef"
      type="file"
      accept=".csv"
      class="hidden"
      @change="handleImportFile"
    />

    <main
      class="mx-auto flex w-full max-w-7xl flex-1 flex-col gap-4 px-4 py-6 sm:px-6"
    >
      <header class="rounded-lg bg-ui-surface shadow-ui-raised p-4 sm:p-5">
        <div
          class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
        >
          <div class="min-w-0">
            <button
              v-if="!isFolderOverview"
              type="button"
              class="mb-3 inline-flex h-8 items-center gap-2 rounded border border-ui-border-subtle px-3 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
              @click="isCategoryDetail ? backToFolder() : backToFolders()"
            >
              <span class="i-lucide-arrow-left size-4" />
              {{
                isCategoryDetail
                  ? pageText.backToFolder
                  : pageText.backToFolders
              }}
            </button>
            <p
              class="text-[11px] font-semibold uppercase tracking-normal text-n-slate-10"
            >
              {{
                isFolderOverview ? pageText.allFolders : selectedFolder?.title
              }}
            </p>
            <h1 class="m-0 mt-1 text-2xl font-semibold text-n-slate-12">
              {{
                isCategoryDetail
                  ? categoryDisplayName(selectedCategory)
                  : pageText.title
              }}
            </h1>
            <p class="mt-1 max-w-3xl text-sm text-n-slate-11">
              {{
                isCategoryDetail
                  ? pageText.duplicateHint
                  : selectedFolder?.description || pageText.subtitle
              }}
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-if="isFolderView"
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded bg-n-blue-9 px-3 text-sm font-semibold text-white hover:bg-n-blue-10"
              @click="
                showCreateForm = !showCreateForm;
                resetCategoryForm(selectedKind);
              "
            >
              <span class="i-lucide-plus size-4" />
              {{ pageText.newCategory }}
            </button>
            <template v-if="isCategoryDetail && selectedCategory">
              <button
                type="button"
                class="inline-flex h-9 items-center gap-2 rounded border border-ui-border-subtle px-3 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                :disabled="isImporting"
                @click="openImportFile(selectedCategory)"
              >
                <span class="i-lucide-upload size-4" />
                {{ pageText.import }}
              </button>
              <button
                type="button"
                class="inline-flex h-9 items-center gap-2 rounded border border-ui-border-subtle px-3 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                :disabled="isExportingCsv"
                @click="exportCategoryCsv(selectedCategory)"
              >
                <span class="i-lucide-download size-4" />
                {{ pageText.exportCsv }}
              </button>
              <button
                type="button"
                class="inline-flex h-9 items-center gap-2 rounded border border-ui-border-subtle px-3 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                :disabled="isExportingSheet"
                @click="exportCategoryGoogleSheet(selectedCategory)"
              >
                <span class="i-lucide-table-2 size-4" />
                {{ pageText.exportSheet }}
              </button>
            </template>
          </div>
        </div>
      </header>

      <div v-if="isLoading" class="flex justify-center py-12 text-n-slate-11">
        <Spinner />
      </div>

      <template v-else>
        <section
          v-if="isFolderOverview"
          class="grid gap-3 md:grid-cols-2 xl:grid-cols-3"
        >
          <button
            v-for="folder in FOLDERS"
            :key="folder.key"
            type="button"
            class="flex min-h-40 flex-col rounded-lg bg-ui-surface shadow-ui-raised p-4 text-left transition hover:border-n-blue-7 hover:bg-n-blue-2"
            @click="openFolder(folder)"
          >
            <svg
              v-if="folder.key === 'location'"
              class="mb-4 size-6 text-n-blue-10"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M20 10c0 4.5-8 11-8 11s-8-6.5-8-11a8 8 0 1 1 16 0Z" />
              <circle cx="12" cy="10" r="3" />
            </svg>
            <span
              v-else
              :class="folder.icon"
              class="mb-4 size-6 text-n-blue-10"
            />
            <span class="text-lg font-semibold text-n-slate-12">
              {{ folder.title }}
            </span>
            <span class="mt-1 text-sm leading-5 text-n-slate-11">
              {{ folder.description }}
            </span>
            <span class="mt-auto pt-4 text-sm font-medium text-n-slate-12">
              {{ folderCategories(folder.key).length }} {{ pageText.lists }}
              {{ pageText.separator }}
              {{ totalContactsInFolder(folder) }} {{ pageText.contacts }}
            </span>
          </button>
        </section>

        <section v-else-if="isFolderView" class="flex flex-col gap-4">
          <form
            v-if="showCreateForm"
            class="grid gap-3 rounded-lg bg-ui-surface shadow-ui-raised p-4 md:grid-cols-[minmax(0,1fr)_180px_130px_auto]"
            @submit.prevent="createCategory"
          >
            <label class="flex flex-col gap-1 text-sm text-n-slate-12">
              <span class="font-medium">{{ pageText.name }}</span>
              <input
                v-model="categoryForm.name"
                type="text"
                class="h-9 rounded border border-ui-border-subtle bg-n-surface-1 px-3 outline-none"
              />
            </label>
            <label class="flex flex-col gap-1 text-sm text-n-slate-12">
              <span class="font-medium">{{ pageText.type }}</span>
              <select
                v-model="categoryForm.kind"
                class="h-9 rounded border border-ui-border-subtle bg-n-surface-1 px-3 outline-none"
              >
                <option
                  v-for="option in CATEGORY_KIND_OPTIONS"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
            <label class="flex flex-col gap-1 text-sm text-n-slate-12">
              <span class="font-medium">{{ pageText.color }}</span>
              <input
                v-model="categoryForm.color"
                type="color"
                class="h-9 rounded border border-ui-border-subtle bg-n-surface-1 px-2"
              />
            </label>
            <label
              class="flex flex-col gap-1 text-sm text-n-slate-12 md:col-span-3"
            >
              <span class="font-medium">{{ pageText.description }}</span>
              <textarea
                v-model="categoryForm.description"
                rows="2"
                class="resize-none rounded border border-ui-border-subtle bg-n-surface-1 px-3 py-2 outline-none"
              />
            </label>
            <button
              type="submit"
              class="inline-flex h-9 items-center justify-center rounded bg-n-blue-9 px-3 text-sm font-semibold text-white disabled:opacity-60 md:mt-auto"
              :disabled="isSavingCategory || !categoryForm.name"
            >
              {{ pageText.createCategory }}
            </button>
          </form>

          <div
            v-if="!selectedFolderCategories.length"
            class="rounded-lg border border-dashed border-ui-border-subtle bg-ui-sunken/50 p-8 text-center text-sm text-n-slate-11"
          >
            {{ pageText.folderEmpty }}
          </div>

          <div class="grid gap-3 lg:grid-cols-2">
            <article
              v-for="category in selectedFolderCategories"
              :key="category.id"
              class="rounded-lg bg-ui-surface shadow-ui-raised p-4"
            >
              <div class="flex items-start justify-between gap-3">
                <button
                  type="button"
                  class="flex min-w-0 items-start gap-3 text-left"
                  @click="openCategory(category)"
                >
                  <span
                    class="mt-1 size-4 shrink-0 rounded"
                    :style="{ backgroundColor: category.color || '#2563eb' }"
                  />
                  <span class="min-w-0">
                    <span
                      class="block truncate text-base font-semibold text-n-slate-12"
                    >
                      {{ categoryDisplayName(category) }}
                    </span>
                    <span class="mt-1 block text-sm text-n-slate-11">
                      {{ categoryContactCount(category) }}
                      {{ pageText.contacts }}
                    </span>
                  </span>
                </button>
                <button
                  type="button"
                  class="inline-flex h-8 shrink-0 items-center gap-1 rounded border border-ui-border-subtle px-2 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                  @click="openCategory(category)"
                >
                  <span class="i-lucide-folder-open size-4" />
                  {{ pageText.open }}
                </button>
              </div>

              <div
                class="mt-4 rounded border border-ui-border-subtle bg-n-surface-1 p-3 text-xs text-n-slate-11"
              >
                <span class="font-medium text-n-slate-12">
                  {{ `${pageText.latestImport}:` }}
                </span>
                <template v-if="latestImportForCategory(category)">
                  {{
                    importStatusLabel(latestImportForCategory(category).status)
                  }}
                  {{ pageText.separator }}
                  {{ latestImportForCategory(category).processed_records || 0 }}
                  {{ pageText.processed }} {{ pageText.separator }}
                  {{ duplicateCount(latestImportForCategory(category)) }}
                  {{ pageText.duplicates }}
                </template>
                <template v-else>
                  {{ pageText.noLatestImport }}
                </template>
              </div>

              <div class="mt-4 flex flex-wrap gap-2">
                <button
                  type="button"
                  class="inline-flex h-8 items-center gap-1 rounded border border-ui-border-subtle px-2 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                  @click="openImportFile(category)"
                >
                  <span class="i-lucide-upload size-4" />
                  {{ pageText.import }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-8 items-center gap-1 rounded border border-ui-border-subtle px-2 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                  @click="exportCategoryCsv(category)"
                >
                  <span class="i-lucide-download size-4" />
                  {{ pageText.exportCsv }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-8 items-center gap-1 rounded border border-ui-border-subtle px-2 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                  @click="openEditCategory(category)"
                >
                  <span class="i-lucide-pencil size-4" />
                  {{ pageText.edit }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-8 items-center gap-1 rounded border border-n-ruby-6 px-2 text-sm font-medium text-n-ruby-11 hover:bg-n-ruby-3"
                  @click="openDeleteCategory(category)"
                >
                  <span class="i-lucide-trash-2 size-4" />
                  {{ pageText.delete }}
                </button>
              </div>
            </article>
          </div>
        </section>

        <section
          v-else-if="isCategoryDetail && selectedCategory"
          class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]"
        >
          <div class="rounded-lg bg-ui-surface shadow-ui-raised p-4">
            <div class="mb-3 flex items-center justify-between gap-2">
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ pageText.contactsListTitle }}
              </h2>
              <span class="text-sm text-n-slate-11">
                {{
                  contactsMeta.count || categoryContactCount(selectedCategory)
                }}
                {{ pageText.contacts }}
              </span>
            </div>
            <div v-if="isLoadingContacts" class="flex justify-center py-10">
              <Spinner />
            </div>
            <div
              v-else-if="!contacts.length"
              class="rounded border border-dashed border-ui-border-subtle p-8 text-center text-sm text-n-slate-11"
            >
              {{ pageText.detailEmpty }}
            </div>
            <div
              v-else
              class="overflow-hidden rounded border border-ui-border-subtle"
            >
              <table class="min-w-full text-sm">
                <thead
                  class="bg-n-slate-2 text-[11px] uppercase text-n-slate-10"
                >
                  <tr>
                    <th class="px-3 py-3 text-left">
                      {{ pageText.tableName }}
                    </th>
                    <th class="px-3 py-3 text-left">
                      {{ pageText.tablePhone }}
                    </th>
                    <th class="px-3 py-3 text-left">
                      {{ pageText.tableEmail }}
                    </th>
                    <th class="px-3 py-3 text-left">
                      {{ pageText.tableType }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="contact in contacts"
                    :key="contact.id"
                    class="border-t border-ui-border-subtle/60 text-n-slate-11"
                  >
                    <td class="px-3 py-3 font-medium text-n-slate-12">
                      {{ contact.name || '-' }}
                    </td>
                    <td class="px-3 py-3">
                      {{ contact.phoneNumber || contact.phone_number || '-' }}
                    </td>
                    <td class="px-3 py-3">{{ contact.email || '-' }}</td>
                    <td class="px-3 py-3">
                      {{
                        contact.relationshipStatus ||
                        contact.relationship_status ||
                        '-'
                      }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <aside class="flex flex-col gap-4">
            <div class="rounded-lg bg-ui-surface shadow-ui-raised p-4">
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ pageText.importHistory }}
              </h2>
              <div class="mt-3 grid gap-2">
                <div
                  v-for="item in importsForCategory(selectedCategory)"
                  :key="item.id"
                  class="rounded border border-ui-border-subtle bg-n-surface-1 p-3 text-sm"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="font-medium text-n-slate-12">
                      {{ item.filename || `Importação #${item.id}` }}
                    </span>
                    <span class="text-xs text-n-slate-10">
                      {{ importStatusLabel(item.status) }}
                    </span>
                  </div>
                  <div
                    class="mt-2 grid grid-cols-2 gap-2 text-xs text-n-slate-11"
                  >
                    <span>
                      {{ item.processed_records || 0 }} {{ pageText.processed }}
                    </span>
                    <span>
                      {{ createdCount(item) }} {{ pageText.newRecords }}
                    </span>
                    <span>
                      {{ duplicateCount(item) }} {{ pageText.duplicates }}
                    </span>
                    <span>
                      {{ rejectedCount(item) }} {{ pageText.rejected }}
                    </span>
                  </div>
                  <a
                    v-if="item.failed_records_url"
                    :href="item.failed_records_url"
                    class="mt-2 inline-flex text-xs font-medium text-n-blue-11 hover:underline"
                  >
                    {{ pageText.downloadFailures }}
                  </a>
                </div>
                <div
                  v-if="!importsForCategory(selectedCategory).length"
                  class="rounded border border-dashed border-ui-border-subtle p-4 text-sm text-n-slate-11"
                >
                  {{ pageText.noLatestImport }}
                </div>
              </div>
            </div>
            <div class="rounded-lg bg-ui-surface shadow-ui-raised p-4">
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ pageText.listActions }}
              </h2>
              <div class="mt-3 grid gap-2">
                <button
                  type="button"
                  class="inline-flex h-9 items-center justify-center gap-2 rounded border border-ui-border-subtle px-3 text-sm font-medium text-n-slate-11 hover:bg-n-slate-2"
                  @click="openEditCategory(selectedCategory)"
                >
                  <span class="i-lucide-pencil size-4" />
                  {{ pageText.edit }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-9 items-center justify-center gap-2 rounded border border-n-ruby-6 px-3 text-sm font-medium text-n-ruby-11 hover:bg-n-ruby-3"
                  @click="openDeleteCategory(selectedCategory)"
                >
                  <span class="i-lucide-trash-2 size-4" />
                  {{ pageText.delete }}
                </button>
              </div>
            </div>
          </aside>
        </section>
      </template>
    </main>

    <Dialog
      ref="editDialogRef"
      width="md"
      :title="pageText.edit"
      :confirm-button-label="pageText.edit"
      :is-loading="isSavingCategory"
      :disable-confirm-button="!categoryForm.name || isSavingCategory"
      @confirm="updateCategory"
    >
      <div class="grid gap-3 text-sm">
        <label class="flex flex-col gap-1 text-n-slate-12">
          <span class="font-medium">{{ pageText.name }}</span>
          <input
            v-model="categoryForm.name"
            type="text"
            class="h-10 rounded border border-ui-border-subtle bg-n-surface-1 px-3 outline-none"
          />
        </label>
        <label class="flex flex-col gap-1 text-n-slate-12">
          <span class="font-medium">{{ pageText.type }}</span>
          <select
            v-model="categoryForm.kind"
            class="h-10 rounded border border-ui-border-subtle bg-n-surface-1 px-3 outline-none"
          >
            <option
              v-for="option in CATEGORY_KIND_OPTIONS"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1 text-n-slate-12">
          <span class="font-medium">{{ pageText.color }}</span>
          <input
            v-model="categoryForm.color"
            type="color"
            class="h-10 rounded border border-ui-border-subtle bg-n-surface-1 px-2"
          />
        </label>
        <label class="flex flex-col gap-1 text-n-slate-12">
          <span class="font-medium">{{ pageText.description }}</span>
          <textarea
            v-model="categoryForm.description"
            rows="3"
            class="resize-none rounded border border-ui-border-subtle bg-n-surface-1 px-3 py-2 outline-none"
          />
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="pageText.delete"
      description="A lista será removida dos contatos antes de ser excluída."
      :confirm-button-label="pageText.delete"
      :is-loading="isDeletingCategory"
      @confirm="deleteCategory"
    />
  </section>
</template>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsEmptyState,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import CRMDocumentEditModal from './CRMDocumentEditModal.vue';
import CRMDocumentFolderTree from './CRMDocumentFolderTree.vue';
import CRMDocumentList from './CRMDocumentList.vue';
import { initialFolderId, lineage, visibleRows } from './folderTree';

// Gaveta de documentos do cliente (PROJETO-COFRE-DOCUMENTOS.md §8.4). Emite
// `unavailable` quando o módulo está desligado na conta (404), para quem
// renderiza cair no conteúdo antigo sem mostrar erro.
const props = defineProps({
  contactId: { type: Number, required: true },
  dealId: { type: Number, default: null },
});

const emit = defineEmits(['unavailable', 'count']);

const folders = ref([]);
const types = ref([]);
const clientName = ref('');
const selectedFolderId = ref(null);
const documents = ref([]);
const loading = ref(true);
const loadingDocuments = ref(false);
const uploads = ref([]);
const dragging = ref(false);
const editing = ref({ mode: '', document: null });
const saving = ref(false);
const fileInput = ref(null);

const breadcrumb = computed(() =>
  lineage(folders.value, selectedFolderId.value).map(folder => folder.name)
);
const selectedFolder = computed(() =>
  folders.value.find(folder => folder.id === selectedFolderId.value)
);
const folderOptions = computed(() =>
  visibleRows(folders.value).map(({ folder, depth }) => ({
    value: folder.id,
    label: `${'— '.repeat(depth)}${folder.name}`,
  }))
);
const totalDocuments = computed(() =>
  folders.value.reduce((sum, folder) => sum + (folder.documents_count || 0), 0)
);

const UPLOAD_FEEDBACK_MS = 6000;

const errorMessage = (err, fallback) => err?.response?.data?.error || fallback;

const loadFolders = async () => {
  const { data } = await CrmDocumentsAPI.getFolders({
    contactId: props.contactId,
    dealId: props.dealId,
  });
  folders.value = data.folders;
  clientName.value = data.client_folder_name;
  if (!folders.value.some(folder => folder.id === selectedFolderId.value)) {
    selectedFolderId.value = initialFolderId(data.folders, data.case_folder_id);
  }
  emit('count', totalDocuments.value);
};

const loadDocuments = async () => {
  if (!selectedFolderId.value) return;
  loadingDocuments.value = true;
  try {
    const { data } = await CrmDocumentsAPI.getDocuments({
      contactId: props.contactId,
      folderId: selectedFolderId.value,
    });
    documents.value = data.payload;
  } catch (err) {
    useAlert(
      errorMessage(err, 'Não foi possível carregar os documentos da pasta.')
    );
  } finally {
    loadingDocuments.value = false;
  }
};

const load = async () => {
  loading.value = true;
  try {
    const [, typesResponse] = await Promise.all([
      loadFolders(),
      CrmDocumentsAPI.getTypes(),
    ]);
    types.value = typesResponse.data;
    await loadDocuments();
  } catch (err) {
    if (err?.response?.status === 404) emit('unavailable');
    else
      useAlert(
        errorMessage(err, 'Não foi possível abrir os documentos do cliente.')
      );
  } finally {
    loading.value = false;
  }
};

const refresh = async () => {
  await loadFolders();
  await loadDocuments();
};

const uploadOne = async entry => {
  try {
    const { data } = await CrmDocumentsAPI.upload({
      contactId: props.contactId,
      folderId: selectedFolderId.value,
      dealId: props.dealId,
      file: entry.file,
      onProgress: progress => {
        entry.progress = progress;
      },
    });
    entry.status = data.duplicate ? 'duplicate' : 'done';
  } catch (err) {
    entry.status = 'error';
    entry.error = errorMessage(err, 'Falha no envio.');
  }
};

const uploadFiles = async fileList => {
  const entries = Array.from(fileList || []).map(file => ({
    key: `${file.name}-${file.size}-${Date.now()}`,
    name: file.name,
    file,
    progress: 0,
    status: 'uploading',
    error: '',
  }));
  if (!entries.length) return;
  uploads.value = [...entries, ...uploads.value].slice(0, 20);
  // Os itens reativos (proxies) são os que a tela observa: o progresso precisa
  // ser gravado neles, não nos objetos originais.
  const tracked = uploads.value.slice(0, entries.length);
  // Um por vez: celular em 3G não aguenta vários uploads em paralelo.
  await tracked.reduce(
    (chain, entry) => chain.then(() => uploadOne(entry)),
    Promise.resolve()
  );
  const duplicates = tracked.filter(
    entry => entry.status === 'duplicate'
  ).length;
  if (duplicates)
    useAlert(
      `${duplicates} arquivo(s) já estavam guardados. Nada foi duplicado.`
    );
  // Envio concluído some sozinho; erro fica até a pessoa limpar.
  setTimeout(() => {
    uploads.value = uploads.value.filter(entry =>
      ['error', 'uploading'].includes(entry.status)
    );
  }, UPLOAD_FEEDBACK_MS);
  await refresh();
};

const onDrop = event => {
  dragging.value = false;
  uploadFiles(event.dataTransfer?.files);
};

const openDocument = async (document, inline = true) => {
  try {
    const { data } = await CrmDocumentsAPI.getDownloadUrl(document.id, {
      inline,
    });
    window.open(data.url, '_blank', 'noopener,noreferrer');
  } catch (err) {
    useAlert(errorMessage(err, 'Não foi possível abrir o arquivo.'));
  }
};

const archiveDocument = async document => {
  try {
    await CrmDocumentsAPI.archiveDocument(document.id);
    useAlert(`${document.file_name} foi arquivado.`);
    await refresh();
  } catch (err) {
    useAlert(errorMessage(err, 'Não foi possível arquivar.'));
  }
};

const startEdit = (mode, document = null) => {
  editing.value = { mode, document };
};

const saveEdit = async payload => {
  saving.value = true;
  try {
    if (editing.value.mode === 'folder') {
      await CrmDocumentsAPI.createFolder({
        contactId: props.contactId,
        parentId: selectedFolderId.value,
        ...payload,
      });
    } else {
      await CrmDocumentsAPI.updateDocument(editing.value.document.id, payload);
    }
    editing.value = { mode: '', document: null };
    await refresh();
  } catch (err) {
    useAlert(errorMessage(err, 'Não foi possível salvar.'));
  } finally {
    saving.value = false;
  }
};

watch(selectedFolderId, (value, previous) => {
  if (previous !== null && value !== previous) loadDocuments();
});
watch(() => [props.contactId, props.dealId], load);
onMounted(load);
</script>

<template>
  <section class="flex flex-col" aria-label="Documentos do cliente">
    <header
      class="flex flex-wrap items-center gap-3 border-b border-ui-border-subtle p-3"
    >
      <p
        class="m-0 hidden min-w-0 flex-1 truncate text-ui-body-sm text-ui-text-muted sm:block"
        :title="breadcrumb.join(' / ')"
      >
        <Icon
          icon="i-lucide-folder-tree"
          class="mr-1 inline size-4 align-text-bottom"
        />
        <span v-for="(part, index) in breadcrumb" :key="index">
          <span v-if="index" class="px-1 text-ui-text-subtle">/</span>
          <span
            :class="
              index === breadcrumb.length - 1 ? 'font-medium text-ui-text' : ''
            "
            >{{ part }}</span
          >
        </span>
      </p>
      <DsButton
        size="sm"
        variant="ghost"
        icon="i-lucide-folder-plus"
        label="Nova pasta"
        @click="startEdit('folder')"
      />
      <DsButton
        size="sm"
        variant="primary"
        icon="i-lucide-upload"
        label="Enviar arquivos"
        @click="fileInput?.click()"
      />
      <input
        ref="fileInput"
        type="file"
        multiple
        class="hidden"
        @change="
          uploadFiles($event.target.files);
          $event.target.value = '';
        "
      />
    </header>

    <div v-if="loading" class="flex flex-col gap-2 p-4">
      <DsSkeleton v-for="n in 4" :key="n" class="h-10" />
    </div>

    <div
      v-else
      class="grid content-start md:min-h-80 md:grid-cols-[17rem_minmax(0,1fr)]"
    >
      <aside class="hidden border-r border-ui-border-subtle p-2 md:block">
        <CRMDocumentFolderTree
          :folders="folders"
          :selected-id="selectedFolderId"
          :client-name="clientName"
          @select="selectedFolderId = $event"
        />
      </aside>
      <div class="border-b border-ui-border-subtle p-3 md:hidden">
        <DsSelect
          id="crm-doc-folder-mobile"
          :model-value="selectedFolderId"
          label="Pasta"
          :options="folderOptions"
          @update:model-value="selectedFolderId = Number($event)"
        />
      </div>

      <div
        class="relative flex min-w-0 flex-col"
        @dragover.prevent="dragging = true"
        @dragleave.self="dragging = false"
        @drop.prevent="onDrop"
      >
        <ul
          v-if="uploads.length"
          class="m-0 flex list-none flex-col gap-1 border-b border-ui-border-subtle p-3"
          aria-live="polite"
        >
          <li class="flex justify-end">
            <button
              type="button"
              class="text-ui-caption text-ui-text-muted underline-offset-2 hover:text-ui-text hover:underline"
              @click="
                uploads = uploads.filter(entry => entry.status === 'uploading')
              "
            >
              Limpar lista
            </button>
          </li>
          <li
            v-for="entry in uploads"
            :key="entry.key"
            class="flex items-center gap-2 text-ui-caption"
          >
            <Icon
              :icon="
                {
                  uploading: 'i-lucide-loader-circle',
                  done: 'i-lucide-circle-check',
                  duplicate: 'i-lucide-copy-check',
                  error: 'i-lucide-circle-alert',
                }[entry.status]
              "
              class="size-4 shrink-0"
              :class="{
                'animate-spin text-ui-text-muted': entry.status === 'uploading',
                'text-ui-success': entry.status === 'done',
                'text-ui-text-muted': entry.status === 'duplicate',
                'text-ui-danger-foreground': entry.status === 'error',
              }"
            />
            <span class="min-w-0 flex-1 truncate font-mono">{{
              entry.name
            }}</span>
            <span
              v-if="entry.status === 'uploading'"
              class="tabular-nums text-ui-text-muted"
              >{{ entry.progress }}%</span
            >
            <span
              v-else-if="entry.status === 'duplicate'"
              class="text-ui-text-muted"
              >já estava guardado</span
            >
            <span
              v-else-if="entry.status === 'error'"
              class="text-ui-danger-foreground"
              >{{ entry.error }}</span
            >
          </li>
        </ul>

        <div v-if="loadingDocuments" class="flex flex-col gap-2 p-4">
          <DsSkeleton v-for="n in 3" :key="n" class="h-10" />
        </div>
        <DsEmptyState
          v-else-if="!documents.length"
          icon="i-lucide-folder-open"
          :title="
            selectedFolder?.slot === 'triagem'
              ? 'Nada para classificar'
              : 'Esta pasta está vazia'
          "
          description="Arraste arquivos para cá ou use Enviar arquivos. O nome padrão é dado pelo sistema."
          action-label="Enviar arquivos"
          action-icon="i-lucide-upload"
          class="m-auto py-10"
          @action="fileInput?.click()"
        />
        <CRMDocumentList
          v-else
          :documents="documents"
          @open="openDocument($event, true)"
          @download="openDocument($event, false)"
          @edit="startEdit"
          @archive="archiveDocument"
        />

        <div
          v-if="dragging"
          class="pointer-events-none absolute inset-2 grid place-items-center rounded-ui-card border-2 border-dashed border-ui-brand bg-ui-brand-soft/80 text-ui-body-sm font-medium text-ui-brand-foreground"
        >
          Solte para guardar em {{ selectedFolder?.name }}
        </div>
      </div>
    </div>

    <CRMDocumentEditModal
      :mode="editing.mode"
      :document="editing.document"
      :folders="folders"
      :types="types"
      :loading="saving"
      @close="editing = { mode: '', document: null }"
      @confirm="saveEdit"
    />
  </section>
</template>

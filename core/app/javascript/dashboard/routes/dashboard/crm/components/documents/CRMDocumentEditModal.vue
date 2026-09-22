<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';

import { DsInput, DsModal, DsSelect } from 'dashboard/design-system/components';
import { visibleRows } from './folderTree';

// Uma edição por vez: classificar, mover, renomear ou criar pasta. O modal
// mostra a consequência antes de confirmar (para onde vai, qual o nome).
const props = defineProps({
  mode: { type: String, default: '' },
  document: { type: Object, default: null },
  folders: { type: Array, default: () => [] },
  types: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'confirm']);

const typeSlug = ref('');
const description = ref('');
const folderId = ref('');
const name = ref('');

const TITLES = {
  classify: 'Classificar documento',
  move: 'Mover documento',
  rename: 'Renomear documento',
  folder: 'Nova pasta',
};

watch(
  () => [props.mode, props.document],
  () => {
    // Sugestão da captura automática já vem marcada; a equipe só confirma.
    typeSlug.value =
      props.document?.doc_type || props.document?.suggested_doc_type || '';
    description.value = props.document?.description || '';
    folderId.value = props.document?.folder_id || '';
    name.value = props.mode === 'rename' ? props.document?.file_name || '' : '';
  },
  { immediate: true }
);

const typeOptions = computed(() =>
  props.types.map(type => ({ value: type.slug, label: type.label }))
);

const folderOptions = computed(() =>
  visibleRows(props.folders).map(({ folder, depth }) => ({
    value: folder.id,
    label: `${'  '.repeat(depth)}${folder.name}`,
  }))
);

const willMove = computed(
  () => props.mode === 'classify' && props.document?.in_triage && typeSlug.value
);

const canConfirm = computed(() => {
  if (props.mode === 'classify') return Boolean(typeSlug.value);
  if (props.mode === 'move')
    return (
      Boolean(folderId.value) &&
      Number(folderId.value) !== props.document?.folder_id
    );
  if (props.mode === 'rename')
    return Boolean(name.value.trim()) || Boolean(props.document?.name_locked);
  return Boolean(name.value.trim());
});

const confirm = () => {
  if (!canConfirm.value) return;
  const payloads = {
    classify: { doc_type: typeSlug.value, description: description.value },
    move: { crm_document_folder_id: Number(folderId.value) },
    rename: { file_name: name.value.trim() },
    folder: { name: name.value.trim() },
  };
  emit('confirm', payloads[props.mode]);
};
</script>

<template>
  <DsModal
    :open="Boolean(mode)"
    :title="TITLES[mode] || ''"
    :description="document?.file_name || ''"
    confirm-label="Salvar"
    :disabled="!canConfirm"
    :loading="loading"
    @close="emit('close')"
    @confirm="confirm"
  >
    <form class="flex flex-col gap-3" @submit.prevent="confirm">
      <template v-if="mode === 'classify'">
        <DsSelect
          id="crm-doc-type"
          v-model="typeSlug"
          label="Tipo do documento"
          placeholder="Escolha o tipo"
          :options="typeOptions"
        />
        <DsInput
          id="crm-doc-description"
          v-model="description"
          label="Descrição (opcional)"
          placeholder="Ex.: Frente e verso"
        />
        <p
          v-if="willMove"
          class="m-0 rounded-ui-control bg-ui-success-soft px-3 py-2 text-ui-caption text-ui-success-foreground"
        >
          Sai da Triagem e vai para a pasta do tipo escolhido, com o nome
          padrão.
        </p>
      </template>
      <DsSelect
        v-else-if="mode === 'move'"
        id="crm-doc-folder"
        v-model="folderId"
        label="Pasta de destino"
        :options="folderOptions"
      />
      <DsInput
        v-else
        id="crm-doc-name"
        v-model="name"
        :label="mode === 'folder' ? 'Nome da pasta' : 'Nome do arquivo'"
        :description="
          mode === 'rename'
            ? 'O nome dado à mão não é mais recalculado pelo sistema. Deixe em branco para voltar ao nome padrão.'
            : ''
        "
      />
    </form>
  </DsModal>
</template>

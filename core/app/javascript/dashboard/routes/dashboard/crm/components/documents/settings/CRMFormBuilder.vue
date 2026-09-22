<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsCheckbox,
  DsInput,
  DsTextarea,
} from 'dashboard/design-system/components';
import CRMFormEntryEditor from './CRMFormEntryEditor.vue';
import {
  conditionSources,
  keyFromLabel,
  localWarnings,
  move,
} from './formBuilder';

// Construtor de formulário (PROJETO-COFRE-DOCUMENTOS.md §8.7): a conta monta
// as perguntas, os documentos pedidos e os textos. Salva de uma vez; o
// servidor valida a estrutura e devolve a mensagem se algo estiver errado.
const props = defineProps({
  form: { type: Object, required: true },
  documentTypes: { type: Array, default: () => [] },
});

const emit = defineEmits(['saved', 'archived']);

const draft = ref(null);
const saving = ref(false);
const serverError = ref('');
const newestField = ref(null);
const newestItem = ref(null);

const reset = () => {
  draft.value = JSON.parse(JSON.stringify(props.form));
  serverError.value = '';
};
watch(() => props.form, reset, { immediate: true });

const warnings = computed(() => localWarnings(draft.value.fields));
const dirty = computed(
  () => JSON.stringify(draft.value) !== JSON.stringify(props.form)
);

const setSetting = (key, value) => {
  draft.value.settings = { ...draft.value.settings, [key]: value };
};

const updateEntry = (list, index, entry) => {
  const copy = [...draft.value[list]];
  copy[index] = entry;
  draft.value[list] = copy;
};

const addField = () => {
  const keys = draft.value.fields.map(field => field.key);
  const key = keyFromLabel('Nova pergunta', keys);
  draft.value.fields = [
    ...draft.value.fields,
    { key, label: 'Nova pergunta', type: 'text' },
  ];
  newestField.value = key;
};

const addItem = () => {
  const keys = draft.value.document_items.map(item => item.key);
  const key = keyFromLabel('Novo documento', keys);
  draft.value.document_items = [
    ...draft.value.document_items,
    { key, label: 'Novo documento' },
  ];
  newestItem.value = key;
};

const remove = (list, index) => {
  draft.value[list] = draft.value[list].filter(
    (_, position) => position !== index
  );
};

const copy = async text => {
  try {
    await navigator.clipboard.writeText(text);
    useAlert('Link copiado.');
  } catch {
    useAlert(text);
  }
};

const save = async () => {
  saving.value = true;
  serverError.value = '';
  try {
    const {
      name,
      active,
      fields,
      document_items: items,
      settings,
    } = draft.value;
    const { data } = await CrmDocumentsAPI.updateForm(draft.value.id, {
      name,
      active,
      fields,
      document_items: items,
      settings,
    });
    useAlert('Formulário salvo.');
    emit('saved', data);
  } catch (err) {
    serverError.value =
      err?.response?.data?.error || 'Não foi possível salvar.';
  } finally {
    saving.value = false;
  }
};

const archive = async () => {
  try {
    await CrmDocumentsAPI.archiveForm(draft.value.id);
    useAlert('Formulário arquivado. O link deixou de funcionar.');
    emit('archived', draft.value.id);
  } catch {
    useAlert('Não foi possível arquivar.');
  }
};
</script>

<template>
  <section
    v-if="draft"
    class="flex flex-col gap-5"
    aria-label="Construtor de formulário"
  >
    <div class="flex flex-wrap items-end gap-3">
      <DsInput
        id="form-name"
        v-model="draft.name"
        label="Nome do formulário"
        class="min-w-0 flex-1 basis-64"
      />
      <DsCheckbox
        id="form-active"
        v-model="draft.active"
        label="Publicado"
        description="Desligado, o link mostra “não disponível”."
      />
    </div>

    <div
      class="flex flex-wrap items-center gap-2 rounded-ui-control bg-ui-sunken px-3 py-2 text-ui-body-sm"
    >
      <Icon icon="i-lucide-link" class="size-4 text-ui-text-muted" />
      <span
        class="min-w-0 flex-1 truncate font-mono text-ui-caption"
        :title="form.public_url"
        >{{ form.public_url }}</span
      >
      <DsButton
        size="sm"
        variant="ghost"
        icon="i-lucide-copy"
        label="Copiar"
        @click="copy(form.public_url)"
      />
      <a
        :href="form.public_url"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-1 text-ui-caption text-ui-brand-foreground hover:underline"
      >
        <Icon icon="i-lucide-external-link" class="size-3.5" /> Abrir
      </a>
    </div>

    <details class="rounded-ui-control border border-ui-border p-3">
      <summary class="cursor-pointer text-ui-body-sm font-medium text-ui-text">
        Textos da página
      </summary>
      <div class="mt-3 grid gap-3">
        <DsTextarea
          id="form-intro"
          :model-value="draft.settings.intro || ''"
          label="Apresentação (aparece no topo)"
          @update:model-value="setSetting('intro', $event)"
        />
        <DsTextarea
          id="form-success"
          :model-value="draft.settings.success_message || ''"
          label="Mensagem depois do envio"
          @update:model-value="setSetting('success_message', $event)"
        />
        <DsTextarea
          id="form-consent"
          :model-value="draft.settings.consent_text || ''"
          label="Texto de autorização (LGPD)"
          @update:model-value="setSetting('consent_text', $event)"
        />
        <DsInput
          id="form-submit"
          :model-value="draft.settings.submit_label || ''"
          label="Texto do botão"
          @update:model-value="setSetting('submit_label', $event)"
        />
      </div>
    </details>

    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-2">
        <h3 class="m-0 text-ui-body font-semibold text-ui-text">
          Perguntas ({{ draft.fields.length }})
        </h3>
        <DsButton
          size="sm"
          variant="secondary"
          icon="i-lucide-plus"
          label="Pergunta"
          @click="addField"
        />
      </div>
      <ul class="m-0 flex list-none flex-col gap-2 p-0">
        <CRMFormEntryEditor
          v-for="(field, index) in draft.fields"
          :key="field.key"
          kind="field"
          :entry="field"
          :index="index"
          :total="draft.fields.length"
          :condition-fields="conditionSources(draft.fields, index)"
          :start-open="field.key === newestField"
          @update="updateEntry('fields', index, $event)"
          @move="draft.fields = move(draft.fields, index, $event)"
          @remove="remove('fields', index)"
        />
      </ul>
    </div>

    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-2">
        <h3 class="m-0 text-ui-body font-semibold text-ui-text">
          Documentos pedidos ({{ draft.document_items.length }})
        </h3>
        <DsButton
          size="sm"
          variant="secondary"
          icon="i-lucide-plus"
          label="Documento"
          @click="addItem"
        />
      </div>
      <ul class="m-0 flex list-none flex-col gap-2 p-0">
        <CRMFormEntryEditor
          v-for="(item, index) in draft.document_items"
          :key="item.key"
          kind="item"
          :entry="item"
          :index="index"
          :total="draft.document_items.length"
          :condition-fields="conditionSources(draft.fields)"
          :document-types="documentTypes"
          :start-open="item.key === newestItem"
          @update="updateEntry('document_items', index, $event)"
          @move="
            draft.document_items = move(draft.document_items, index, $event)
          "
          @remove="remove('document_items', index)"
        />
      </ul>
    </div>

    <ul
      v-if="warnings.length"
      class="m-0 list-none rounded-ui-control bg-ui-warning-soft p-3 text-ui-caption text-ui-warning-foreground"
    >
      <li v-for="warning in warnings" :key="warning">{{ warning }}</li>
    </ul>
    <p
      v-if="serverError"
      class="m-0 rounded-ui-control bg-ui-danger-soft p-3 text-ui-body-sm text-ui-danger-foreground"
      role="alert"
    >
      {{ serverError }}
    </p>

    <div class="flex flex-wrap items-center gap-2">
      <DsButton
        variant="primary"
        icon="i-lucide-save"
        label="Salvar formulário"
        :loading="saving"
        :disabled="!dirty"
        @click="save"
      />
      <DsButton
        variant="ghost"
        icon="i-lucide-undo-2"
        label="Descartar mudanças"
        :disabled="!dirty"
        @click="reset"
      />
      <span class="flex-1" />
      <DsButton
        variant="danger"
        icon="i-lucide-archive"
        label="Arquivar formulário"
        @click="archive"
      />
    </div>
  </section>
</template>

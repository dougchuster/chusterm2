<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DsButton,
  DsInput,
  DsSelect,
} from 'dashboard/design-system/components';
import { previewFileName } from './documentNaming';

// Painel da Caixa de Triagem (PROJETO-COFRE-DOCUMENTOS.md §8.3): vê o arquivo,
// escolhe o tipo com um toque (ou tecla 1–9) e confirma com Enter. Mostra o
// destino e o nome final ANTES de confirmar.
const props = defineProps({
  document: { type: Object, required: true },
  types: { type: Array, default: () => [] },
  saving: { type: Boolean, default: false },
});

const emit = defineEmits(['classify', 'discard', 'next', 'previous']);

const QUICK_TYPES = [
  'rg',
  'cpf',
  'cnh',
  'comprovante_residencia',
  'cnis',
  'ctps',
  'laudo_medico',
  'procuracao',
  'holerite',
];

const typeSlug = ref('');
const description = ref('');
const dealId = ref('');
const previewUrl = ref('');

const typesBySlug = computed(() =>
  Object.fromEntries(props.types.map(type => [type.slug, type]))
);
const quickTypes = computed(() => {
  const slugs = [props.document.suggested_doc_type, ...QUICK_TYPES].filter(
    Boolean
  );
  return [...new Set(slugs)]
    .map(slug => typesBySlug.value[slug])
    .filter(Boolean)
    .slice(0, 9);
});
const typeOptions = computed(() =>
  props.types.map(type => ({ value: type.slug, label: type.label }))
);
const selectedType = computed(() => typesBySlug.value[typeSlug.value]);
const needsDeal = computed(() =>
  selectedType.value?.target_slot?.startsWith('processo_')
);
const deals = computed(() => props.document.contact_deals || []);
const dealOptions = computed(() =>
  deals.value.map(deal => ({ value: deal.id, label: deal.title }))
);

const destination = computed(() => {
  if (!selectedType.value) return '';
  if (selectedType.value.target_slot === 'current')
    return 'Fica na pasta atual (00 Triagem). Mova depois, se quiser.';
  if (!needsDeal.value)
    return `Vai para ${selectedType.value.target_folder_label}`;
  const deal = deals.value.find(item => item.id === Number(dealId.value));
  if (!deals.value.length)
    return 'Este cliente não tem processo aberto: o documento fica classificado na Triagem.';
  if (!deal) return 'Escolha o processo para saber a pasta.';
  return `Vai para o processo “${deal.title}” / ${selectedType.value.target_folder_label}`;
});
const fileName = computed(() =>
  selectedType.value
    ? previewFileName({
        document: props.document,
        typeSlug: typeSlug.value,
        typeLabel: selectedType.value.label,
        description: description.value,
      })
    : ''
);
const canClassify = computed(
  () =>
    Boolean(typeSlug.value) &&
    (!needsDeal.value || !deals.value.length || Boolean(dealId.value))
);
const isImage = computed(() =>
  props.document.content_type?.startsWith('image/')
);
const isPdf = computed(() => props.document.content_type === 'application/pdf');

const loadPreview = async () => {
  previewUrl.value = '';
  if (!isImage.value && !isPdf.value) return;
  try {
    const { data } = await CrmDocumentsAPI.getDownloadUrl(props.document.id, {
      inline: true,
    });
    previewUrl.value = data.url;
  } catch {
    previewUrl.value = '';
  }
};

const openFile = async () => {
  const { data } = await CrmDocumentsAPI.getDownloadUrl(props.document.id, {
    inline: true,
  });
  window.open(data.url, '_blank', 'noopener,noreferrer');
};

const classify = () => {
  if (!canClassify.value || props.saving) return;
  const payload = { doc_type: typeSlug.value, description: description.value };
  if (needsDeal.value && dealId.value)
    payload.crm_deal_id = Number(dealId.value);
  emit('classify', payload);
};

const typing = event =>
  ['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target?.tagName);

const onKeydown = event => {
  if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey)
    return;
  if (event.key === 'Enter' && !(event.target?.tagName === 'BUTTON')) {
    event.preventDefault();
    classify();
    return;
  }
  if (typing(event)) return;
  const actions = {
    j: () => emit('next'),
    ArrowDown: () => emit('next'),
    k: () => emit('previous'),
    ArrowUp: () => emit('previous'),
    Delete: () => emit('discard'),
    Backspace: () => emit('discard'),
  };
  const index = Number(event.key) - 1;
  if (index >= 0 && index < quickTypes.value.length)
    actions[event.key] = () => {
      typeSlug.value = quickTypes.value[index].slug;
    };
  if (!actions[event.key]) return;
  event.preventDefault();
  actions[event.key]();
};

watch(
  () => props.document.id,
  () => {
    typeSlug.value = props.document.suggested_doc_type || '';
    description.value = '';
    dealId.value = deals.value.length === 1 ? deals.value[0].id : '';
    loadPreview();
  },
  { immediate: true }
);

onMounted(() => window.addEventListener('keydown', onKeydown));
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown));
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-4 p-4"
    aria-label="Classificar documento"
  >
    <div
      class="grid aspect-[4/3] max-w-full place-items-center overflow-hidden rounded-ui-control border border-ui-border-subtle bg-ui-sunken"
    >
      <img
        v-if="isImage && previewUrl"
        :src="previewUrl"
        :alt="document.file_name"
        class="max-h-full max-w-full object-contain"
      />
      <iframe
        v-else-if="isPdf && previewUrl"
        :src="previewUrl"
        :title="document.file_name"
        class="size-full"
      />
      <div
        v-else
        class="flex flex-col items-center gap-2 p-6 text-center text-ui-text-muted"
      >
        <Icon icon="i-lucide-file" class="size-8" />
        <span class="text-ui-caption"
          >Sem pré-visualização para este tipo de arquivo.</span
        >
      </div>
    </div>

    <div
      class="flex flex-wrap items-center gap-x-3 gap-y-1 text-ui-caption text-ui-text-muted"
    >
      <span
v-if="document.caption"
class="italic text-ui-text"
        >“{{ document.caption }}”</span
      >
      <a
        v-if="document.conversation_path"
        :href="document.conversation_path"
        class="inline-flex items-center gap-1 text-ui-brand-foreground hover:underline"
      >
        <Icon icon="i-lucide-message-square" class="size-3.5" /> Ver na conversa
      </a>
      <button
        type="button"
        class="inline-flex items-center gap-1 hover:text-ui-text"
        @click="openFile"
      >
        <Icon icon="i-lucide-external-link" class="size-3.5" /> Abrir arquivo
      </button>
    </div>

    <fieldset class="m-0 flex flex-col gap-2 border-0 p-0">
      <legend class="mb-1 text-ui-body-sm font-medium text-ui-text">
        Tipo do documento
      </legend>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="(type, index) in quickTypes"
          :key="type.slug"
          type="button"
          class="inline-flex min-h-9 items-center gap-1.5 rounded-ui-control border px-3 text-ui-body-sm transition-colors"
          :class="
            typeSlug === type.slug
              ? 'border-ui-brand bg-ui-brand-soft font-medium text-ui-brand-foreground'
              : 'border-ui-border bg-ui-surface text-ui-text hover:bg-ui-hover'
          "
          :aria-pressed="typeSlug === type.slug"
          @click="typeSlug = type.slug"
        >
          <kbd class="font-mono text-ui-caption opacity-70">{{
            index + 1
          }}</kbd>
          {{ type.label }}
          <Icon
            v-if="type.slug === document.suggested_doc_type"
            icon="i-lucide-sparkles"
            class="size-3.5"
          />
        </button>
      </div>
      <DsSelect
        id="crm-triage-type"
        v-model="typeSlug"
        label="Outros tipos"
        hide-label
        placeholder="Todos os tipos…"
        :options="typeOptions"
      />
    </fieldset>

    <DsInput
      id="crm-triage-description"
      v-model="description"
      label="Descrição (opcional)"
      placeholder="Ex.: Frente e verso"
    />
    <DsSelect
      v-if="needsDeal && deals.length > 1"
      id="crm-triage-deal"
      v-model="dealId"
      label="Processo"
      placeholder="Escolha o processo"
      :options="dealOptions"
    />

    <div
      v-if="selectedType"
      class="flex flex-col gap-1 rounded-ui-control bg-ui-success-soft px-3 py-2 text-ui-caption text-ui-success-foreground"
      aria-live="polite"
    >
      <span>{{ destination }}</span>
      <span class="font-mono text-ui-text [overflow-wrap:anywhere]">{{
        fileName
      }}</span>
    </div>

    <div class="flex flex-wrap gap-2">
      <DsButton
        variant="primary"
        icon="i-lucide-check"
        label="Classificar (Enter)"
        :disabled="!canClassify"
        :loading="saving"
        @click="classify"
      />
      <DsButton
        variant="secondary"
        icon="i-lucide-archive"
        label="Descartar"
        :disabled="saving"
        @click="emit('discard')"
      />
      <DsButton
        variant="ghost"
        icon="i-lucide-skip-forward"
        label="Pular"
        @click="emit('next')"
      />
    </div>
    <p class="m-0 text-ui-caption text-ui-text-muted">
      Atalhos: <kbd>J</kbd>/<kbd>K</kbd> navegam, <kbd>1</kbd>–<kbd>9</kbd>
      escolhem o tipo, <kbd>Enter</kbd> classifica, <kbd>Delete</kbd> descarta
      para 99 Arquivo.
    </p>
  </section>
</template>

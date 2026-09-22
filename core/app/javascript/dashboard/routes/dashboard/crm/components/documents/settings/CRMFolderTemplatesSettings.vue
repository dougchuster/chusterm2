<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsInput,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { move } from './formBuilder';

// Estrutura das pastas: a gaveta de cada cliente e as subpastas de cada
// negócio (por área). Vale para gavetas criadas depois de salvar.
const SYSTEM_SLOTS = ['triagem', 'processos', 'arquivo'];

const templates = ref(null);
const selectedId = ref(null);
const draft = ref([]);
const saving = ref(false);

const templateOptions = computed(() =>
  (templates.value || []).map(template => ({
    value: template.id,
    label:
      template.scope === 'client'
        ? `Gaveta do cliente — ${template.name}`
        : `Subpastas de negócio — ${template.name}`,
  }))
);
const selected = computed(() =>
  templates.value?.find(template => template.id === Number(selectedId.value))
);
const dirty = computed(
  () =>
    JSON.stringify(draft.value) !== JSON.stringify(selected.value?.tree || [])
);

watch(selected, template => {
  draft.value = JSON.parse(JSON.stringify(template?.tree || []));
});

const load = async () => {
  const { data } = await CrmDocumentsAPI.getFolderTemplates();
  templates.value = data;
  selectedId.value =
    selectedId.value ||
    data.find(template => template.scope === 'client')?.id ||
    data[0]?.id;
};

const rename = (index, name) => {
  draft.value = draft.value.map((node, position) =>
    position === index ? { ...node, name } : node
  );
};

const isSystem = node =>
  selected.value?.scope === 'client' && SYSTEM_SLOTS.includes(node.slot);

const save = async () => {
  saving.value = true;
  try {
    await CrmDocumentsAPI.updateFolderTemplate(selected.value.id, {
      tree: draft.value,
    });
    await load();
    useAlert('Estrutura salva. Vale para as próximas gavetas.');
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível salvar.');
  } finally {
    saving.value = false;
  }
};

onMounted(() =>
  load().catch(() => useAlert('Não foi possível carregar as pastas.'))
);
</script>

<template>
  <div v-if="!templates" class="flex flex-col gap-2">
    <DsSkeleton v-for="n in 5" :key="n" class="h-10" />
  </div>
  <div v-else class="flex max-w-2xl flex-col gap-4">
    <DsSelect
      id="folder-template"
      v-model="selectedId"
      label="Estrutura"
      :options="templateOptions"
    />
    <p class="m-0 text-ui-caption text-ui-text-muted">
      Os números na frente mantêm a mesma ordem no sistema, no Windows e no
      Drive. Mudanças valem para gavetas criadas depois; as existentes não
      mudam.
    </p>
    <ul class="m-0 flex list-none flex-col gap-2 p-0">
      <li
        v-for="(node, index) in draft"
        :key="`${node.slot}-${index}`"
        class="flex items-center gap-2"
      >
        <Icon
          icon="i-lucide-folder"
          class="size-4 shrink-0 text-ui-text-muted"
        />
        <DsInput
          :id="`folder-${index}`"
          :model-value="node.name"
          label="Nome da pasta"
          hide-label
          class="min-w-0 flex-1"
          @update:model-value="rename(index, $event)"
        />
        <span
          v-if="isSystem(node)"
          class="text-ui-caption text-ui-text-muted"
          title="O sistema depende desta pasta"
          >do sistema</span
        >
        <button
          type="button"
          class="grid size-8 place-items-center rounded-ui-control hover:bg-ui-hover disabled:opacity-40"
          :disabled="index === 0"
          :aria-label="`Subir ${node.name}`"
          @click="draft = move(draft, index, -1)"
        >
          <Icon icon="i-lucide-arrow-up" class="size-4" />
        </button>
        <button
          type="button"
          class="grid size-8 place-items-center rounded-ui-control hover:bg-ui-hover disabled:opacity-40"
          :disabled="index === draft.length - 1"
          :aria-label="`Descer ${node.name}`"
          @click="draft = move(draft, index, 1)"
        >
          <Icon icon="i-lucide-arrow-down" class="size-4" />
        </button>
        <button
          type="button"
          class="grid size-8 place-items-center rounded-ui-control text-ui-danger-foreground hover:bg-ui-hover disabled:opacity-40"
          :disabled="isSystem(node)"
          :aria-label="`Remover ${node.name}`"
          @click="draft = draft.filter((_, position) => position !== index)"
        >
          <Icon icon="i-lucide-trash-2" class="size-4" />
        </button>
      </li>
    </ul>
    <div class="flex flex-wrap gap-2">
      <DsButton
        variant="secondary"
        icon="i-lucide-folder-plus"
        label="Pasta"
        @click="draft = [...draft, { name: 'Nova pasta' }]"
      />
      <DsButton
        variant="primary"
        icon="i-lucide-save"
        label="Salvar estrutura"
        :loading="saving"
        :disabled="!dirty"
        @click="save"
      />
    </div>
  </div>
</template>

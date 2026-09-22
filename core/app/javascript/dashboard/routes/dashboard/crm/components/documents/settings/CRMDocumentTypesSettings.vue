<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import { useAlert } from 'dashboard/composables';
import {
  DsBadge,
  DsButton,
  DsInput,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { keyFromLabel } from './formBuilder';

// Catálogo de tipos de documento: nome, pasta de destino e validade. Os tipos
// alimentam a classificação, o checklist e os formulários.
const types = ref(null);
const folders = ref([]);
const editing = ref({});
const newLabel = ref('');
const saving = ref(false);

const folderOptions = computed(() => [
  { value: 'current', label: 'Fica na pasta atual' },
  ...folders.value.map(node => ({ value: node.slot, label: node.label })),
]);

const load = async () => {
  const [typeList, templates] = await Promise.all([
    CrmDocumentsAPI.getAllTypes(),
    CrmDocumentsAPI.getFolderTemplates(),
  ]);
  types.value = typeList.data;
  const client = templates.data.find(template => template.scope === 'client');
  const generic = templates.data.find(
    template => template.scope === 'case' && template.legal_area === 'geral'
  );
  folders.value = [
    ...(client?.tree || []).map(node => ({
      slot: node.slot,
      label: node.name,
    })),
    ...(generic?.tree || []).map(node => ({
      slot: node.slot,
      label: `Negócio › ${node.name}`,
    })),
  ];
};

const draftFor = type =>
  editing.value[type.id] || {
    label: type.label,
    target_slot: type.target_slot,
    validity_days: type.validity_days ?? '',
  };

const edit = (type, key, value) => {
  editing.value = {
    ...editing.value,
    [type.id]: { ...draftFor(type), [key]: value },
  };
};

const saveType = async type => {
  const draft = draftFor(type);
  try {
    await CrmDocumentsAPI.updateType(type.id, {
      ...draft,
      validity_days: draft.validity_days || null,
    });
    const { [type.id]: _, ...rest } = editing.value;
    editing.value = rest;
    await load();
    useAlert('Tipo salvo.');
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível salvar.');
  }
};

const toggleActive = async type => {
  try {
    if (type.active) await CrmDocumentsAPI.deactivateType(type.id);
    else await CrmDocumentsAPI.updateType(type.id, { active: true });
    await load();
  } catch {
    useAlert('Não foi possível alterar o tipo.');
  }
};

const addType = async () => {
  const label = newLabel.value.trim();
  if (!label) return;
  saving.value = true;
  try {
    const slug = keyFromLabel(
      label,
      types.value.map(type => type.slug)
    );
    await CrmDocumentsAPI.createType({ slug, label, target_slot: 'current' });
    newLabel.value = '';
    await load();
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível criar o tipo.');
  } finally {
    saving.value = false;
  }
};

onMounted(() =>
  load().catch(() => useAlert('Não foi possível carregar os tipos.'))
);
</script>

<template>
  <div v-if="!types" class="flex flex-col gap-2">
    <DsSkeleton v-for="n in 5" :key="n" class="h-10" />
  </div>
  <div v-else class="flex flex-col gap-4">
    <form class="flex flex-wrap items-end gap-2" @submit.prevent="addType">
      <DsInput
        id="new-doc-type"
        v-model="newLabel"
        label="Novo tipo de documento"
        placeholder="Ex.: Alvará de funcionamento"
        class="min-w-0 flex-1 basis-64"
      />
      <DsButton
        type="submit"
        variant="secondary"
        icon="i-lucide-plus"
        label="Adicionar"
        :loading="saving"
      />
    </form>
    <div class="overflow-x-auto">
      <table class="w-full min-w-[40rem] border-collapse text-ui-body-sm">
        <thead>
          <tr class="text-left text-ui-caption text-ui-text-muted">
            <th class="px-2 py-2 font-medium">Tipo</th>
            <th class="px-2 py-2 font-medium">Vai para</th>
            <th class="px-2 py-2 font-medium">Validade (dias)</th>
            <th class="px-2 py-2 font-medium">Situação</th>
            <th class="px-2 py-2" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="type in types"
            :key="type.id"
            class="border-t border-ui-border-subtle align-top"
            :class="{ 'opacity-60': !type.active }"
          >
            <td class="px-2 py-2">
              <DsInput
                :id="`type-label-${type.id}`"
                :model-value="draftFor(type).label"
                label="Nome"
                hide-label
                @update:model-value="edit(type, 'label', $event)"
              />
            </td>
            <td class="px-2 py-2">
              <DsSelect
                :id="`type-slot-${type.id}`"
                :model-value="draftFor(type).target_slot"
                label="Pasta"
                hide-label
                :options="folderOptions"
                @update:model-value="edit(type, 'target_slot', $event)"
              />
            </td>
            <td class="px-2 py-2">
              <DsInput
                :id="`type-validity-${type.id}`"
                :model-value="draftFor(type).validity_days"
                type="number"
                label="Validade"
                hide-label
                placeholder="Sem prazo"
                @update:model-value="edit(type, 'validity_days', $event)"
              />
            </td>
            <td class="px-2 py-2">
              <DsBadge
                :variant="type.active ? 'success' : 'neutral'"
                :label="type.active ? 'Ativo' : 'Desativado'"
              />
            </td>
            <td class="whitespace-nowrap px-2 py-2 text-right">
              <DsButton
                v-if="editing[type.id]"
                size="sm"
                variant="primary"
                label="Salvar"
                @click="saveType(type)"
              />
              <DsButton
                size="sm"
                variant="ghost"
                :label="type.active ? 'Desativar' : 'Reativar'"
                @click="toggleActive(type)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

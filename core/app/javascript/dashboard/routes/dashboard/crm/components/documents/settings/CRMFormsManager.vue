<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import { useAlert } from 'dashboard/composables';
import {
  DsBadge,
  DsButton,
  DsEmptyState,
  DsSkeleton,
} from 'dashboard/design-system/components';
import CRMFormBuilder from './CRMFormBuilder.vue';

// Formulários de envio da conta: lista à esquerda, construtor à direita.
// Novo formulário nasce do modelo da área (o administrador ajusta depois).
const forms = ref([]);
const types = ref([]);
const selectedId = ref(null);
const loading = ref(true);
const creating = ref(false);

const selected = computed(() =>
  forms.value.find(form => form.id === selectedId.value)
);

const load = async () => {
  loading.value = true;
  try {
    const [formList, typeList] = await Promise.all([
      CrmDocumentsAPI.getForms(),
      CrmDocumentsAPI.getTypes(),
    ]);
    forms.value = formList.data;
    types.value = typeList.data;
    selectedId.value = selectedId.value || forms.value[0]?.id || null;
  } catch {
    useAlert('Não foi possível carregar os formulários.');
  } finally {
    loading.value = false;
  }
};

const create = async () => {
  creating.value = true;
  try {
    const { data } = await CrmDocumentsAPI.createForm({
      name: `Envio de documentos ${forms.value.length + 1}`,
    });
    forms.value = [...forms.value, data];
    selectedId.value = data.id;
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Não foi possível criar o formulário.'
    );
  } finally {
    creating.value = false;
  }
};

const onSaved = form => {
  forms.value = forms.value.map(item => (item.id === form.id ? form : item));
};

const onArchived = id => {
  forms.value = forms.value.filter(form => form.id !== id);
  selectedId.value = forms.value[0]?.id || null;
};

onMounted(load);
</script>

<template>
  <div v-if="loading" class="flex flex-col gap-2">
    <DsSkeleton v-for="n in 3" :key="n" class="h-12" />
  </div>
  <DsEmptyState
    v-else-if="!forms.length"
    icon="i-lucide-clipboard-list"
    title="Nenhum formulário ainda"
    description="Crie um formulário para o cliente enviar dados e documentos por um link, sem cadastro. Ele já vem pronto para a sua área; ajuste como quiser."
    action-label="Criar formulário"
    action-icon="i-lucide-plus"
    :loading="creating"
    @action="create"
  />
  <div v-else class="grid gap-4 lg:grid-cols-[16rem_minmax(0,1fr)]">
    <nav class="flex flex-col gap-1" aria-label="Formulários">
      <button
        v-for="form in forms"
        :key="form.id"
        type="button"
        class="flex flex-col items-start gap-1 rounded-ui-control px-3 py-2 text-left"
        :class="
          form.id === selectedId
            ? 'bg-ui-brand-soft text-ui-brand-foreground'
            : 'text-ui-text hover:bg-ui-hover'
        "
        :aria-current="form.id === selectedId ? 'true' : undefined"
        @click="selectedId = form.id"
      >
        <span class="text-ui-body-sm font-medium">{{ form.name }}</span>
        <span
          class="flex items-center gap-2 text-ui-caption text-ui-text-muted"
        >
          <DsBadge
            :variant="form.active ? 'success' : 'neutral'"
            :label="form.active ? 'Publicado' : 'Desligado'"
          />
          {{ form.submissions_count }} envio(s)
        </span>
      </button>
      <DsButton
        size="sm"
        variant="secondary"
        icon="i-lucide-plus"
        label="Novo formulário"
        :loading="creating"
        class="mt-2"
        @click="create"
      />
    </nav>
    <CRMFormBuilder
      v-if="selected"
      :key="selected.id"
      :form="selected"
      :document-types="types"
      @saved="onSaved"
      @archived="onArchived"
    />
  </div>
</template>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsEmptyState,
  DsSkeleton,
} from 'dashboard/design-system/components';
import CRMTriagePanel from '../components/documents/CRMTriagePanel.vue';

// Caixa de Triagem do escritório (PROJETO-COFRE-DOCUMENTOS.md §8.3): tudo que
// chegou pelas conversas e ainda não foi classificado, agrupado por cliente.
// Substitui o "reenviar para o grupo".
const documents = ref([]);
const types = ref([]);
const count = ref(0);
const selectedId = ref(null);
const loading = ref(true);
const saving = ref(false);
const unavailable = ref(false);

const selected = computed(() =>
  documents.value.find(document => document.id === selectedId.value)
);
const groups = computed(() => {
  const byContact = new Map();
  documents.value.forEach(document => {
    if (!byContact.has(document.contact_id)) {
      byContact.set(document.contact_id, {
        contactId: document.contact_id,
        name: document.contact_name,
        items: [],
      });
    }
    byContact.get(document.contact_id).items.push(document);
  });
  return [...byContact.values()];
});

const formatTime = value => {
  const date = new Date(value);
  const today = new Date().toDateString() === date.toDateString();
  return today
    ? date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
    : date.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });
};

const originalName = document =>
  document.original_filename || document.file_name;

const load = async () => {
  loading.value = true;
  try {
    const [triage, typeList] = await Promise.all([
      CrmDocumentsAPI.getTriage(),
      CrmDocumentsAPI.getTypes(),
    ]);
    documents.value = triage.data.payload;
    count.value = triage.data.meta.count;
    types.value = typeList.data;
    selectedId.value = documents.value[0]?.id ?? null;
  } catch (err) {
    if (err?.response?.status === 404) unavailable.value = true;
    else useAlert('Não foi possível carregar a triagem.');
  } finally {
    loading.value = false;
  }
};

const move = step => {
  const index = documents.value.findIndex(
    document => document.id === selectedId.value
  );
  const next = documents.value[index + step];
  if (next) selectedId.value = next.id;
};

// Tira da lista e segue para o próximo — o ritmo da triagem é um por vez.
const removeCurrent = () => {
  const index = documents.value.findIndex(
    document => document.id === selectedId.value
  );
  documents.value = documents.value.filter(
    document => document.id !== selectedId.value
  );
  count.value = Math.max(0, count.value - 1);
  selectedId.value =
    documents.value[Math.min(index, documents.value.length - 1)]?.id ?? null;
};

const folderOf = path => (path || '').split('/').slice(-2, -1)[0] || '';

const update = async (payload, message) => {
  saving.value = true;
  try {
    const { data } = await CrmDocumentsAPI.updateDocument(
      selectedId.value,
      payload
    );
    removeCurrent();
    useAlert(message(data));
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível salvar.');
  } finally {
    saving.value = false;
  }
};

const classify = payload =>
  update(
    payload,
    data => `${data.file_name} guardado em ${folderOf(data.path)}.`
  );

const discard = () => {
  if (!selected.value?.discard_folder_id) return;
  update(
    { crm_document_folder_id: selected.value.discard_folder_id },
    () => 'Descartado para 99 Arquivo (continua guardado).'
  );
};

onMounted(load);
</script>

<template>
  <div class="flex h-full min-h-0 flex-col gap-4 overflow-y-auto p-4 md:p-6">
    <header class="flex flex-wrap items-center gap-3">
      <Icon icon="i-lucide-inbox" class="size-6 text-ui-text-muted" />
      <div class="min-w-0 flex-1">
        <h1 class="m-0 text-ui-title text-ui-text">Triagem de documentos</h1>
        <p class="m-0 text-ui-body-sm text-ui-text-muted">
          O que os clientes mandaram pelas conversas e ainda não foi
          classificado.
        </p>
      </div>
      <span
        v-if="count"
        class="rounded-full bg-ui-warning-soft px-3 py-1 text-ui-caption font-medium text-ui-warning-foreground"
      >
        {{ count }} para classificar
      </span>
      <DsButton
        size="sm"
        variant="ghost"
        icon="i-lucide-refresh-cw"
        label="Atualizar"
        :loading="loading"
        @click="load"
      />
    </header>

    <div v-if="loading" class="flex flex-col gap-2">
      <DsSkeleton v-for="n in 5" :key="n" class="h-12" />
    </div>
    <DsEmptyState
      v-else-if="unavailable"
      icon="i-lucide-folder-lock"
      title="O módulo de arquivos não está ligado nesta conta"
      description="Fale com o administrador para ativar o cofre de documentos."
    />
    <DsEmptyState
      v-else-if="!documents.length"
      icon="i-lucide-check-check"
      title="Tudo classificado"
      description="Os novos arquivos aparecem aqui assim que chegam pelas conversas."
    />

    <div
      v-else
      class="grid min-h-0 gap-4 rounded-ui-card border border-ui-border bg-ui-surface lg:grid-cols-[minmax(0,1fr)_minmax(0,1.25fr)]"
    >
      <nav
        class="min-w-0 border-b border-ui-border-subtle p-2 lg:border-b-0 lg:border-r"
        aria-label="Documentos para classificar"
      >
        <section v-for="group in groups" :key="group.contactId" class="py-1">
          <h2
            class="m-0 flex items-center gap-2 px-2 py-1.5 text-ui-body-sm font-medium text-ui-text"
          >
            {{ group.name || 'Contato sem nome' }}
            <span class="font-mono text-ui-caption text-ui-text-muted">{{
              group.items.length
            }}</span>
          </h2>
          <ul class="m-0 flex list-none flex-col gap-px p-0">
            <li v-for="document in group.items" :key="document.id">
              <button
                type="button"
                class="grid w-full grid-cols-[3.5rem_minmax(0,1fr)_auto] items-center gap-2 rounded-ui-control px-2 py-2 text-left text-ui-caption"
                :class="
                  document.id === selectedId
                    ? 'bg-ui-brand-soft text-ui-brand-foreground'
                    : 'text-ui-text hover:bg-ui-hover'
                "
                :aria-current="document.id === selectedId ? 'true' : undefined"
                @click="selectedId = document.id"
              >
                <span class="font-mono tabular-nums text-ui-text-muted">{{
                  formatTime(document.created_at)
                }}</span>
                <span
                  class="truncate font-mono"
                  :title="originalName(document)"
                  >{{ originalName(document) }}</span
                >
                <span
                  v-if="document.suggested_doc_type_label"
                  class="rounded-ui-control bg-ui-sunken px-1.5 py-0.5 text-ui-caption text-ui-text-muted"
                >
                  {{ document.suggested_doc_type_label }}
                </span>
                <span
                  v-else-if="document.likely_irrelevant"
                  class="text-ui-text-muted"
                  >figurinha?</span
                >
              </button>
            </li>
          </ul>
        </section>
      </nav>

      <CRMTriagePanel
        v-if="selected"
        :document="selected"
        :types="types"
        :saving="saving"
        @classify="classify"
        @discard="discard"
        @next="move(1)"
        @previous="move(-1)"
      />
    </div>
  </div>
</template>

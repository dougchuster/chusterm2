<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { onMounted, ref } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsEmptyState,
  DsSkeleton,
} from 'dashboard/design-system/components';
import CRMDocumentEditModal from './CRMDocumentEditModal.vue';

// Filas do escritório (PROJETO-COFRE-DOCUMENTOS.md §8.5): "Para análise"
// (aprovar ou rejeitar) e "Vencendo" (validade em até 30 dias).
const props = defineProps({
  queue: {
    type: String,
    required: true,
    validator: value => ['review', 'expiring'].includes(value),
  },
});

const emit = defineEmits(['count']);

const documents = ref([]);
const loading = ref(true);
const rejecting = ref(null);
const saving = ref(false);

const EMPTY = {
  review: {
    title: 'Nada esperando análise',
    description:
      'Os documentos classificados aparecem aqui até serem aprovados ou rejeitados.',
  },
  expiring: {
    title: 'Nenhum documento vencendo',
    description:
      'Certidões, comprovantes e CNIS aparecem aqui 30 dias antes de vencer.',
  },
};

const formatDate = value =>
  value
    ? new Date(`${value}`.slice(0, 10) + 'T12:00:00').toLocaleDateString(
        'pt-BR'
      )
    : '';

const daysLeft = value =>
  Math.round((new Date(`${value}T12:00:00`) - new Date()) / 86400000);

const expiryLabel = document => {
  const days = daysLeft(document.expires_on);
  if (days < 0) return `Venceu em ${formatDate(document.expires_on)}`;
  if (days === 0) return 'Vence hoje';
  return `Vence em ${days} dia(s) · ${formatDate(document.expires_on)}`;
};

const load = async () => {
  loading.value = true;
  try {
    const { data } = await CrmDocumentsAPI.getQueue(props.queue);
    documents.value = data.payload;
    emit('count', data.meta.count);
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível carregar a fila.');
  } finally {
    loading.value = false;
  }
};

const open = async document => {
  try {
    const { data } = await CrmDocumentsAPI.getDownloadUrl(document.id, {
      inline: true,
    });
    window.open(data.url, '_blank', 'noopener,noreferrer');
  } catch {
    useAlert('Não foi possível abrir o arquivo.');
  }
};

const update = async (document, payload, message) => {
  saving.value = true;
  try {
    await CrmDocumentsAPI.updateDocument(document.id, payload);
    useAlert(message);
    rejecting.value = null;
    await load();
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível salvar.');
  } finally {
    saving.value = false;
  }
};

const approve = document =>
  update(document, { status: 'approved' }, `${document.file_name} aprovado.`);
const reject = payload =>
  update(
    rejecting.value,
    payload,
    'Documento rejeitado. O motivo ficou registrado.'
  );

onMounted(load);
</script>

<template>
  <div class="flex flex-col">
    <div v-if="loading" class="flex flex-col gap-2 p-3">
      <DsSkeleton v-for="n in 4" :key="n" class="h-12" />
    </div>
    <DsEmptyState
      v-else-if="!documents.length"
      :icon="
        queue === 'review' ? 'i-lucide-check-check' : 'i-lucide-calendar-check'
      "
      :title="EMPTY[queue].title"
      :description="EMPTY[queue].description"
      class="py-10"
    />
    <ul v-else class="m-0 flex list-none flex-col p-0">
      <li
        v-for="document in documents"
        :key="document.id"
        class="flex flex-wrap items-center gap-3 border-b border-ui-border-subtle px-3 py-2.5 last:border-b-0"
      >
        <div class="min-w-0 flex-1 basis-64">
          <p class="m-0 text-ui-caption font-medium text-ui-text-muted">
            {{ document.contact_name || 'Contato sem nome' }}
          </p>
          <button
            type="button"
            class="block max-w-full truncate text-left font-mono text-ui-body-sm text-ui-text hover:underline"
            :title="document.path"
            @click="open(document)"
          >
            {{ document.file_name }}
          </button>
          <p class="m-0 text-ui-caption text-ui-text-muted">
            {{ document.doc_type_label }}
            <template v-if="queue === 'expiring'">
              ·
              <span
                :class="
                  daysLeft(document.expires_on) < 0
                    ? 'font-medium text-ui-danger-foreground'
                    : 'text-ui-warning-foreground'
                "
              >
                {{ expiryLabel(document) }}
              </span>
            </template>
          </p>
        </div>
        <a
          v-if="document.conversation_path"
          :href="document.conversation_path"
          class="inline-flex items-center gap-1 text-ui-caption text-ui-brand-foreground hover:underline"
        >
          <Icon icon="i-lucide-message-square" class="size-3.5" /> Conversa
        </a>
        <template v-if="queue === 'review'">
          <DsButton
            size="sm"
            variant="secondary"
            icon="i-lucide-circle-x"
            label="Rejeitar"
            :disabled="saving"
            @click="rejecting = document"
          />
          <DsButton
            size="sm"
            variant="primary"
            icon="i-lucide-circle-check"
            label="Aprovar"
            :disabled="saving"
            @click="approve(document)"
          />
        </template>
        <DsButton
          v-else
          size="sm"
          variant="ghost"
          icon="i-lucide-eye"
          label="Ver"
          @click="open(document)"
        />
      </li>
    </ul>

    <CRMDocumentEditModal
      :mode="rejecting ? 'reject' : ''"
      :document="rejecting"
      :loading="saving"
      @close="rejecting = null"
      @confirm="reject"
    />
  </div>
</template>

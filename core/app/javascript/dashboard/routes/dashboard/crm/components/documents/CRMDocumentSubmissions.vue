<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { onMounted, ref } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import { useAlert } from 'dashboard/composables';
import {
  DsBadge,
  DsButton,
  DsEmptyState,
  DsSkeleton,
} from 'dashboard/design-system/components';

// Fila "Novos envios" (PROJETO-COFRE-DOCUMENTOS.md §8.7.2): o que chegou pelos
// formulários, com as respostas e a identificação do contato. Os arquivos
// estão na Triagem do cliente, com o tipo já sugerido.
const emit = defineEmits(['count']);

const submissions = ref([]);
const loading = ref(true);
const busyId = ref(null);

const MATCH = {
  link: { label: 'Link do cliente', variant: 'success' },
  matched_phone: { label: 'Cliente encontrado pelo telefone', variant: 'info' },
  matched_email: { label: 'Cliente encontrado pelo e-mail', variant: 'info' },
  new_contact: { label: 'Contato novo criado', variant: 'brand' },
};

const formatAnswer = answer => {
  if (answer.value === true) return 'Sim';
  if (Array.isArray(answer.value)) return answer.value.join(', ');
  if (answer.type === 'date')
    return new Date(`${answer.value}T12:00:00`).toLocaleDateString('pt-BR');
  return answer.value;
};

const formatDate = value =>
  new Date(value).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

const load = async () => {
  loading.value = true;
  try {
    const { data } = await CrmDocumentsAPI.getSubmissions();
    submissions.value = data.payload;
    emit('count', data.meta.count);
  } catch {
    useAlert('Não foi possível carregar os envios.');
  } finally {
    loading.value = false;
  }
};

const review = async (submission, payload, message) => {
  busyId.value = submission.id;
  try {
    await CrmDocumentsAPI.reviewSubmission(submission.id, payload);
    useAlert(message);
    await load();
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Não foi possível atualizar o envio.'
    );
  } finally {
    busyId.value = null;
  }
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col">
    <div v-if="loading" class="flex flex-col gap-2 p-3">
      <DsSkeleton v-for="n in 3" :key="n" class="h-24" />
    </div>
    <DsEmptyState
      v-else-if="!submissions.length"
      icon="i-lucide-mailbox"
      title="Nenhum envio novo"
      description="O que os clientes enviarem pelos formulários aparece aqui, com as respostas e o protocolo."
      class="py-10"
    />
    <ul v-else class="m-0 flex list-none flex-col gap-3 p-3">
      <li
        v-for="submission in submissions"
        :key="submission.id"
        class="rounded-ui-control border border-ui-border p-3"
      >
        <div class="flex flex-wrap items-center gap-2">
          <span class="font-mono text-ui-body-sm font-semibold text-ui-text">{{
            submission.protocol
          }}</span>
          <DsBadge
            :variant="MATCH[submission.match_status]?.variant || 'neutral'"
            :label="
              MATCH[submission.match_status]?.label || submission.match_status
            "
          />
          <DsBadge
            v-if="!submission.verified"
            variant="warning"
            icon="i-lucide-shield-alert"
            label="Não verificado"
          />
          <span class="ml-auto text-ui-caption text-ui-text-muted"
            >{{ submission.form_name }} ·
            {{ formatDate(submission.created_at) }}</span
          >
        </div>
        <p class="m-0 mt-2 text-ui-body-sm font-medium text-ui-text">
          {{ submission.contact_name || 'Contato sem nome' }} ·
          {{ submission.documents_count }} arquivo(s) na Triagem
        </p>
        <dl
          class="m-0 mt-2 grid gap-x-4 gap-y-1 text-ui-caption sm:grid-cols-[minmax(0,12rem)_minmax(0,1fr)]"
        >
          <template v-for="answer in submission.answers" :key="answer.key">
            <dt class="text-ui-text-muted">{{ answer.label }}</dt>
            <dd class="m-0 text-ui-text [overflow-wrap:anywhere]">
              {{ formatAnswer(answer) }}
            </dd>
          </template>
        </dl>
        <p
          v-if="!submission.verified"
          class="m-0 mt-2 text-ui-caption text-ui-text-muted"
        >
          Confira se é mesmo este cliente antes de usar os documentos: qualquer
          pessoa pode digitar um telefone.
        </p>
        <div class="mt-3 flex flex-wrap gap-2">
          <DsButton
            v-if="!submission.verified"
            size="sm"
            variant="secondary"
            icon="i-lucide-shield-check"
            label="É este cliente"
            :disabled="busyId === submission.id"
            @click="review(submission, { verified: true }, 'Envio verificado.')"
          />
          <DsButton
            size="sm"
            variant="primary"
            icon="i-lucide-check"
            label="Concluir"
            :disabled="busyId === submission.id"
            @click="
              review(submission, { review_status: 'done' }, 'Envio concluído.')
            "
          />
          <DsButton
            size="sm"
            variant="ghost"
            icon="i-lucide-ban"
            label="Spam"
            :disabled="busyId === submission.id"
            @click="
              review(
                submission,
                { review_status: 'spam' },
                'Marcado como spam; arquivos arquivados.'
              )
            "
          />
        </div>
      </li>
    </ul>
  </div>
</template>

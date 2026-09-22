<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsModal,
  DsSelect,
  DsTextarea,
} from 'dashboard/design-system/components';

// "Pedir documentos" (PROJETO-COFRE-DOCUMENTOS.md §8.7, modo B): gera um link
// do formulário escolhido só para este cliente. O cliente não precisa se
// identificar e o envio entra verificado. A equipe copia a mensagem pronta.
const props = defineProps({
  open: { type: Boolean, default: false },
  contactId: { type: Number, required: true },
  contactName: { type: String, default: '' },
  dealId: { type: Number, default: null },
});

const emit = defineEmits(['close']);

const forms = ref([]);
const formId = ref('');
const ttlDays = ref('7');
const link = ref(null);
const loading = ref(false);

const formOptions = computed(() =>
  forms.value
    .filter(form => form.active)
    .map(form => ({ value: form.id, label: form.name }))
);
const ttlOptions = [
  { value: '3', label: '3 dias' },
  { value: '7', label: '7 dias' },
  { value: '15', label: '15 dias' },
  { value: '30', label: '30 dias' },
];
const message = computed(() => {
  if (!link.value) return '';
  const firstName = (props.contactName || '').split(' ')[0];
  return `Olá${firstName ? `, ${firstName}` : ''}! Para seguirmos, envie seus documentos por este link (vale até ${new Date(link.value.expires_at).toLocaleDateString('pt-BR')}): ${link.value.url}`;
});

watch(
  () => props.open,
  async isOpen => {
    if (!isOpen) return;
    link.value = null;
    try {
      const { data } = await CrmDocumentsAPI.getForms();
      forms.value = data;
      formId.value = formOptions.value[0]?.value || '';
    } catch {
      forms.value = [];
    }
  }
);

const generate = async () => {
  if (!formId.value) return;
  loading.value = true;
  try {
    const { data } = await CrmDocumentsAPI.issueFormLink(Number(formId.value), {
      contactId: props.contactId,
      dealId: props.dealId,
      ttlDays: Number(ttlDays.value),
    });
    link.value = data;
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Não foi possível gerar o link.');
  } finally {
    loading.value = false;
  }
};

const copyMessage = async () => {
  try {
    await navigator.clipboard.writeText(message.value);
    useAlert('Mensagem copiada. Cole na conversa do WhatsApp.');
  } catch {
    useAlert('Selecione e copie a mensagem manualmente.');
  }
};
</script>

<template>
  <DsModal
    :open="open"
    title="Pedir documentos"
    description="Gera um link só para este cliente, sem precisar se identificar."
    :confirm-label="link ? 'Copiar mensagem' : 'Gerar link'"
    :disabled="!link && !formId"
    :loading="loading"
    @close="emit('close')"
    @confirm="link ? copyMessage() : generate()"
  >
    <div class="flex flex-col gap-3">
      <template v-if="!link">
        <p
          v-if="!formOptions.length"
          class="m-0 text-ui-body-sm text-ui-text-muted"
        >
          Nenhum formulário publicado. Um administrador cria em Configurar
          documentos → Formulários.
        </p>
        <template v-else>
          <DsSelect
            id="request-form"
            v-model="formId"
            label="Formulário"
            :options="formOptions"
          />
          <DsSelect
            id="request-ttl"
            v-model="ttlDays"
            label="O link vale por"
            :options="ttlOptions"
          />
        </template>
      </template>
      <template v-else>
        <DsTextarea
          id="request-message"
          :model-value="message"
          label="Mensagem pronta para enviar"
          readonly
        />
        <DsButton
          size="sm"
          variant="ghost"
          icon="i-lucide-refresh-cw"
          label="Gerar outro link"
          @click="link = null"
        />
      </template>
    </div>
  </DsModal>
</template>

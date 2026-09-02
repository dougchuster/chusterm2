<script setup>
// UX-03: substituto do window.confirm nas telas CRM — mesmo uso imperativo,
// mas com o Dialog do design system. Uso:
//   const confirmDialog = ref(null);
//   const ok = await confirmDialog.value.confirm({ title, description });
import { ref } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const dialogRef = ref(null);
const title = ref('');
const description = ref('');
const confirmLabel = ref('');
const cancelLabel = ref('');
const dialogType = ref('alert');

let resolver = null;

const settle = value => {
  if (!resolver) return;
  resolver(value);
  resolver = null;
};

const confirm = (options = {}) => {
  title.value = options.title || 'Confirmar ação';
  description.value = options.description || '';
  confirmLabel.value = options.confirmLabel || 'Confirmar';
  cancelLabel.value = options.cancelLabel || 'Cancelar';
  // 'alert' = botão vermelho (ações destrutivas); 'edit' = azul
  dialogType.value = options.type || 'alert';

  settle(false);
  dialogRef.value?.open();

  return new Promise(resolve => {
    resolver = resolve;
  });
};

const onConfirm = () => {
  settle(true);
  dialogRef.value?.close();
};

const onClose = () => settle(false);

defineExpose({ confirm });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :type="dialogType"
    :title="title"
    :description="description"
    :confirm-button-label="confirmLabel"
    :cancel-button-label="cancelLabel"
    width="sm"
    @confirm="onConfirm"
    @close="onClose"
  />
</template>

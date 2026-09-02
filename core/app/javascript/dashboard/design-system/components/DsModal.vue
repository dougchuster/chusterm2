<script setup>
import { nextTick, ref, watch } from 'vue';

import DsButton from './DsButton.vue';

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  confirmLabel: { type: String, default: 'Confirmar' },
  cancelLabel: { type: String, default: 'Cancelar' },
  dangerous: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'confirm']);
const dialogRef = ref(null);
const CLOSE_LABEL = 'Fechar';

const syncDialogState = async open => {
  await nextTick();
  const dialog = dialogRef.value;
  if (!dialog) return;
  if (open && !dialog.open) dialog.showModal();
  if (!open && dialog.open) dialog.close();
};

const requestClose = () => {
  if (!props.loading) emit('close');
};

const handleBackdrop = event => {
  if (event.target === dialogRef.value) requestClose();
};

watch(() => props.open, syncDialogState, { immediate: true });
</script>

<template>
  <dialog
    ref="dialogRef"
    :aria-labelledby="`${$attrs.id || 'ds-modal'}-title`"
    :aria-describedby="
      description ? `${$attrs.id || 'ds-modal'}-description` : undefined
    "
    class="m-auto w-[calc(100%-2rem)] max-w-md rounded-ui-surface border border-ui-border bg-ui-elevated p-0 text-ui-text shadow-ui-overlay backdrop:bg-black/40"
    @cancel.prevent="requestClose"
    @click="handleBackdrop"
  >
    <section class="flex flex-col" @click.stop>
      <header
        class="flex items-start justify-between gap-4 border-b border-ui-border-subtle p-4"
      >
        <div class="min-w-0">
          <h2
            :id="`${$attrs.id || 'ds-modal'}-title`"
            class="m-0 text-ui-heading font-semibold text-ui-text"
          >
            {{ title }}
          </h2>
          <p
            v-if="description"
            :id="`${$attrs.id || 'ds-modal'}-description`"
            class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted"
          >
            {{ description }}
          </p>
        </div>
        <DsButton
          icon="i-lucide-x"
          size="sm"
          variant="ghost"
          :aria-label="CLOSE_LABEL"
          :disabled="loading"
          @click="requestClose"
        />
      </header>
      <div v-if="$slots.default" class="p-4">
        <slot />
      </div>
      <footer
        class="flex flex-wrap justify-end gap-2 border-t border-ui-border-subtle p-4"
      >
        <slot name="footer">
          <DsButton
            :label="cancelLabel"
            variant="secondary"
            :disabled="loading"
            @click="requestClose"
          />
          <DsButton
            :label="confirmLabel"
            :variant="dangerous ? 'danger' : 'primary'"
            :disabled="disabled"
            :loading="loading"
            @click="emit('confirm')"
          />
        </slot>
      </footer>
    </section>
  </dialog>
</template>

<script setup>
import { computed, nextTick, ref, watch } from 'vue';

import { useDsTranslate } from '../useDsTranslate';
import DsButton from './DsButton.vue';

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  description: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg', 'xl', '2xl'].includes(value),
  },
  widthClass: { type: String, default: '' },
});

const emit = defineEmits(['close']);
const dialogRef = ref(null);

const { translate } = useDsTranslate();

const closeLabel = computed(() => translate('DRAWER.CLOSE', 'Close panel'));

const sizeClasses = computed(() => {
  if (props.widthClass) return props.widthClass;
  return (
    {
      sm: 'max-w-sm',
      md: 'max-w-md',
      lg: 'max-w-lg',
      xl: 'max-w-xl',
      '2xl': 'max-w-2xl',
    }[props.size] || 'max-w-md'
  );
});

const syncDialogState = async open => {
  await nextTick();
  const dialog = dialogRef.value;
  if (!dialog) return;
  if (open && !dialog.open) dialog.showModal();
  if (!open && dialog.open) dialog.close();
};

const requestClose = () => {
  if (!props.disabled && !props.loading) emit('close');
};

const handleBackdrop = event => {
  if (event.target === dialogRef.value) requestClose();
};

watch(() => props.open, syncDialogState, { immediate: true });
</script>

<template>
  <dialog
    ref="dialogRef"
    :aria-labelledby="`${$attrs.id || 'ds-drawer'}-title`"
    :aria-describedby="
      description ? `${$attrs.id || 'ds-drawer'}-description` : undefined
    "
    class="fixed inset-y-0 left-auto right-0 m-0 h-full max-h-none w-full rounded-none border-0 border-l border-ui-border bg-ui-elevated p-0 text-ui-text shadow-ui-overlay backdrop:bg-black/40"
    :class="sizeClasses"
    @cancel.prevent="requestClose"
    @click="handleBackdrop"
  >
    <section class="flex h-full flex-col" @click.stop>
      <slot name="header">
        <header
          class="flex shrink-0 items-start justify-between gap-4 border-b border-ui-border-subtle p-4"
        >
          <div class="min-w-0">
            <h2
              :id="`${$attrs.id || 'ds-drawer'}-title`"
              class="m-0 text-ui-heading font-semibold text-ui-text"
            >
              {{ title }}
            </h2>
            <p
              v-if="description"
              :id="`${$attrs.id || 'ds-drawer'}-description`"
              class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted"
            >
              {{ description }}
            </p>
          </div>
          <DsButton
            icon="i-lucide-x"
            size="sm"
            variant="ghost"
            :aria-label="closeLabel"
            :disabled="disabled || loading"
            @click="requestClose"
          />
        </header>
      </slot>
      <div class="min-h-0 flex-1 overflow-y-auto p-4">
        <slot />
      </div>
      <footer
        v-if="$slots.footer"
        class="shrink-0 border-t border-ui-border-subtle p-4"
      >
        <slot name="footer" />
      </footer>
    </section>
  </dialog>
</template>

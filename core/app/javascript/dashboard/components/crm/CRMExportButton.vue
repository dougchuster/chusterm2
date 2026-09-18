<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<script setup>
import { ref } from 'vue';
import CrmAPI from 'dashboard/api/crm';
import DsButton from 'dashboard/design-system/components/DsButton.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  filters: {
    type: Object,
    default: () => ({}),
  },
  label: {
    type: String,
    default: 'Exportar CSV',
  },
});

const exporting = ref(false);
const error = ref('');
const successMessage = ref('');

// PERF-04: o export roda em background no servidor; o CSV chega por email.
const triggerExport = async () => {
  exporting.value = true;
  error.value = '';
  successMessage.value = '';

  try {
    const response = await CrmAPI.exportDeals(props.filters);
    successMessage.value =
      response?.data?.message ||
      'Exportação em processamento. Você receberá um email com o link.';
  } catch (err) {
    if (err?.response?.status === 403) {
      error.value =
        'Sem permissão para exportar. Apenas administradores podem exportar dados.';
    } else {
      error.value =
        err?.response?.data?.error || 'Falha ao exportar. Tente novamente.';
    }
  } finally {
    exporting.value = false;
  }
};
</script>

<template>
  <div class="inline-flex min-w-0 flex-col gap-1.5">
    <DsButton
      :label="exporting ? 'Exportando...' : label"
      icon="i-lucide-download"
      variant="secondary"
      size="sm"
      :loading="exporting"
      :title="label"
      @click="triggerExport"
    />

    <p
      v-if="error"
      role="alert"
      class="m-0 flex max-w-[22rem] items-center gap-1.5 text-xs text-ui-danger-foreground"
    >
      <Icon
        icon="i-lucide-triangle-alert"
        class="size-3.5 shrink-0"
        aria-hidden="true"
      />
      {{ error }}
    </p>

    <p
      v-if="successMessage"
      class="m-0 flex max-w-[22rem] items-center gap-1.5 text-xs text-ui-success-foreground"
    >
      <Icon
        icon="i-lucide-mail-check"
        class="size-3.5 shrink-0"
        aria-hidden="true"
      />
      {{ successMessage }}
    </p>
  </div>
</template>

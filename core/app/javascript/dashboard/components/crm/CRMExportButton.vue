<!-- eslint-disable vue/no-static-inline-styles, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { ref } from 'vue';
import CrmAPI from 'dashboard/api/crm';

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

const triggerExport = async () => {
  exporting.value = true;
  error.value = '';

  try {
    const response = await CrmAPI.exportDeals(props.filters);

    // Cria link de download com Blob
    const blob = new Blob([response.data], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `crm_deals_${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
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
  <div class="crm-export-btn-wrapper">
    <button
      type="button"
      class="crm-export-btn"
      :disabled="exporting"
      :title="label"
      @click="triggerExport"
    >
      <span
        v-if="exporting"
        class="i-lucide-loader-2 crm-export-btn__icon crm-export-btn__icon--spin"
      />
      <span v-else class="i-lucide-download crm-export-btn__icon" />
      {{ exporting ? 'Exportando...' : label }}
    </button>

    <p v-if="error" class="crm-export-btn__error">
      <span
        class="i-lucide-alert-triangle"
        style="width: 0.875rem; height: 0.875rem; flex-shrink: 0"
      />
      {{ error }}
    </p>
  </div>
</template>

<style scoped>
.crm-export-btn-wrapper {
  display: inline-flex;
  flex-direction: column;
  gap: 0.375rem;
}

.crm-export-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  height: 2.25rem;
  padding: 0 0.875rem;
  border-radius: 0.5rem;
  border: 1px solid rgb(var(--slate-6));
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-11));
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition:
    background 0.15s,
    border-color 0.15s,
    color 0.15s;
  white-space: nowrap;
}

.crm-export-btn:hover:not(:disabled) {
  background: rgb(var(--slate-3));
  border-color: rgb(var(--brand-8));
  color: rgb(var(--brand-11));
}

.crm-export-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.crm-export-btn__icon {
  width: 0.875rem;
  height: 0.875rem;
  flex-shrink: 0;
}

.crm-export-btn__icon--spin {
  animation: crm-spin 1s linear infinite;
}

@keyframes crm-spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.crm-export-btn__error {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  margin: 0;
  font-size: 0.75rem;
  color: rgb(var(--ruby-11));
  max-width: 22rem;
}
</style>

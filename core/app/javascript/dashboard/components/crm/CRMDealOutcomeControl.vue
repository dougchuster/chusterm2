<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';

const props = defineProps({
  status: {
    type: String,
    default: 'open',
  },
  lossReasons: {
    type: Array,
    default: () => [],
  },
  lossReasonId: {
    type: [Number, String],
    default: '',
  },
  lossReasonName: {
    type: String,
    default: '',
  },
  lossNote: {
    type: String,
    default: '',
  },
  busy: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['markWon', 'markLost', 'reopen']);

const showLossForm = ref(false);
const selectedLossReasonId = ref('');
const lossNoteDraft = ref('');

const statusMeta = computed(() => {
  const statuses = {
    open: {
      label: 'Em aberto',
      classes: 'bg-ui-brand/10 text-ui-brand',
    },
    won: {
      label: 'Ganho',
      classes: 'bg-ui-success-soft text-ui-success-foreground',
    },
    lost: {
      label: 'Perdido',
      classes: 'bg-ui-danger-soft text-ui-danger-foreground',
    },
    archived: {
      label: 'Arquivado',
      classes: 'bg-ui-sunken text-ui-text-muted',
    },
  };

  return (
    statuses[props.status] || {
      label: props.status,
      classes: 'bg-ui-sunken text-ui-text-muted',
    }
  );
});

const resolvedLossReasonName = computed(() => {
  if (props.lossReasonName) return props.lossReasonName;
  return (
    props.lossReasons.find(
      reason => String(reason.id) === String(props.lossReasonId)
    )?.name || ''
  );
});

const canSubmitLoss = computed(
  () => !!selectedLossReasonId.value && !props.busy
);

const openLossForm = () => {
  selectedLossReasonId.value = '';
  lossNoteDraft.value = '';
  showLossForm.value = true;
};

const cancelLoss = () => {
  showLossForm.value = false;
  selectedLossReasonId.value = '';
  lossNoteDraft.value = '';
};

const submitLoss = () => {
  if (!canSubmitLoss.value) return;

  emit('markLost', {
    lossReasonId: Number(selectedLossReasonId.value),
    note: lossNoteDraft.value.trim(),
  });
};

watch(
  () => props.status,
  status => {
    if (status !== 'open') cancelLoss();
  }
);
</script>

<template>
  <div class="flex min-w-0 flex-wrap items-center gap-2">
    <span
      class="inline-flex h-7 items-center rounded-full px-2.5 text-xs font-semibold"
      :class="statusMeta.classes"
      data-testid="deal-outcome-status"
    >
      {{ statusMeta.label }}
    </span>

    <template v-if="status === 'open'">
      <button
        type="button"
        class="inline-flex h-8 items-center gap-1 rounded-lg border border-ui-success bg-ui-success-soft px-2.5 text-xs font-semibold text-ui-success-foreground hover:bg-ui-success-soft disabled:opacity-50"
        :disabled="busy"
        @click="emit('markWon')"
      >
        <span class="i-lucide-trophy size-3.5" />
        Marcar ganho
      </button>
      <button
        type="button"
        class="inline-flex h-8 items-center gap-1 rounded-lg border border-ui-danger bg-ui-danger-soft px-2.5 text-xs font-semibold text-ui-danger-foreground hover:bg-ui-danger-soft disabled:opacity-50"
        :disabled="busy"
        @click="openLossForm"
      >
        <span class="i-lucide-circle-x size-3.5" />
        Marcar perdido
      </button>
    </template>

    <button
      v-else-if="status === 'won' || status === 'lost'"
      type="button"
      class="inline-flex h-8 items-center gap-1 rounded-lg border border-ui-border-subtle bg-ui-surface px-2.5 text-xs font-semibold text-ui-text-muted hover:bg-ui-sunken disabled:opacity-50"
      :disabled="busy"
      @click="emit('reopen')"
    >
      <span class="i-lucide-rotate-ccw size-3.5" />
      Reabrir negócio
    </button>

    <p
      v-if="status === 'lost' && (resolvedLossReasonName || lossNote)"
      class="m-0 basis-full text-xs text-ui-text-subtle"
      data-testid="deal-loss-detail"
    >
      <strong v-if="resolvedLossReasonName" class="text-ui-text-muted">
        {{ resolvedLossReasonName }}
      </strong>
      <span v-if="resolvedLossReasonName && lossNote"> · </span>
      <span v-if="lossNote">{{ lossNote }}</span>
    </p>

    <form
      v-if="status === 'open' && showLossForm"
      class="grid basis-full gap-2 rounded-lg border border-ui-danger bg-ui-danger-soft p-3 sm:grid-cols-2"
      data-testid="deal-loss-form"
      @submit.prevent="submitLoss"
    >
      <label class="grid gap-1 text-xs font-semibold text-ui-text-muted">
        Motivo da perda
        <select
          v-model="selectedLossReasonId"
          class="h-9 min-w-0 rounded-lg border border-ui-border-subtle bg-ui-surface px-2 text-sm text-ui-text outline-none focus:border-ui-brand"
          required
        >
          <option value="" disabled>Selecione um motivo</option>
          <option
            v-for="reason in lossReasons"
            :key="reason.id"
            :value="reason.id"
          >
            {{ reason.name }}
          </option>
        </select>
      </label>
      <label class="grid gap-1 text-xs font-semibold text-ui-text-muted">
        Nota (opcional)
        <input
          v-model="lossNoteDraft"
          class="h-9 min-w-0 rounded-lg border border-ui-border-subtle bg-ui-surface px-2 text-sm text-ui-text outline-none focus:border-ui-brand"
          type="text"
          placeholder="Contexto do encerramento"
        />
      </label>
      <p
        v-if="!lossReasons.length"
        class="m-0 text-xs text-ui-danger-foreground sm:col-span-2"
      >
        Cadastre ao menos um motivo de perda antes de encerrar o negócio.
      </p>
      <div class="flex justify-end gap-2 sm:col-span-2">
        <button
          type="button"
          class="h-8 rounded-lg border border-ui-border-subtle px-3 text-xs font-semibold text-ui-text-muted hover:bg-ui-sunken"
          :disabled="busy"
          @click="cancelLoss"
        >
          Cancelar
        </button>
        <button
          type="submit"
          class="h-8 rounded-lg bg-ui-danger-solid px-3 text-xs font-semibold text-white hover:bg-ui-danger-solid disabled:opacity-50"
          :disabled="!canSubmitLoss"
        >
          {{ busy ? 'Salvando...' : 'Confirmar perda' }}
        </button>
      </div>
    </form>
  </div>
</template>

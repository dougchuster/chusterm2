<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';
import CrmAPI from '../../api/crm';

const props = defineProps({
  dealId: { type: [Number, String], required: true },
});

const emit = defineEmits(['updated']);

const activities = ref([]);
const loading = ref(false);
const error = ref('');
const completingId = ref(null);
const snoozingId = ref(null);

const pendingActivities = computed(() =>
  activities.value.filter(activity => !activity.completed_at)
);

const completedActivities = computed(() =>
  activities.value.filter(activity => activity.completed_at).slice(0, 4)
);

function formatDate(value) {
  if (!value) return 'Sem prazo';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function kindLabel(kind) {
  const labels = {
    ligacao: 'Ligação',
    reuniao: 'Reunião',
    analise_documental: 'Analise documental',
    solicitacao_documentos: 'Solicitar documentos',
    follow_up: 'Follow-up',
    envio_contrato: 'Envio de contrato',
    envio_proposta: 'Envio de proposta',
    revisao_juridica: 'Revisão jurídica',
    retorno_cliente: 'Retorno ao cliente',
    arquivamento: 'Arquivamento',
  };
  return labels[kind] || kind || 'Atividade';
}

async function loadActivities() {
  if (!props.dealId) return;
  loading.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.getActivities({ deal_id: props.dealId });
    activities.value = Array.isArray(data) ? data : [];
  } catch {
    error.value = 'Não foi possível carregar as atividades.';
  } finally {
    loading.value = false;
  }
}

async function completeActivity(activity) {
  completingId.value = activity.id;
  error.value = '';
  try {
    const { data } = await CrmAPI.completeActivity(
      activity.id,
      'Concluída pelo painel CRM'
    );
    const index = activities.value.findIndex(item => item.id === activity.id);
    if (index >= 0) activities.value.splice(index, 1, data);
    emit('updated');
  } catch {
    error.value = 'Não foi possível concluir a atividade.';
  } finally {
    completingId.value = null;
  }
}

async function snoozeActivity(activity, hours = 24) {
  snoozingId.value = activity.id;
  error.value = '';
  try {
    const { data } = await CrmAPI.snoozeActivity(activity.id, hours);
    const index = activities.value.findIndex(item => item.id === activity.id);
    if (index >= 0) activities.value.splice(index, 1, data);
    emit('updated');
  } catch {
    error.value = 'Não foi possível adiar a atividade.';
  } finally {
    snoozingId.value = null;
  }
}

watch(() => props.dealId, loadActivities, { immediate: true });
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <section class="space-y-3">
    <div class="flex items-center justify-between">
      <h4 class="m-0 text-sm font-semibold text-n-slate-12">Atividades</h4>
      <button
        type="button"
        class="text-xs font-medium text-n-brand hover:underline"
        @click="loadActivities"
      >
        Atualizar
      </button>
    </div>

    <div v-if="loading" class="text-sm text-n-slate-11">Carregando...</div>
    <div v-else-if="error" class="text-sm text-red-500">{{ error }}</div>
    <div
      v-else-if="!activities.length"
      class="rounded-lg bg-n-slate-2 p-3 text-sm text-n-slate-11"
    >
      Nenhuma atividade vinculada a esta oportunidade.
    </div>

    <div v-else class="space-y-2">
      <article
        v-for="activity in pendingActivities"
        :key="activity.id"
        class="rounded-lg border border-ui-border-subtle bg-n-slate-1 p-3"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <span class="text-xs font-medium uppercase text-n-slate-10">
                {{ kindLabel(activity.kind) }}
              </span>
              <span
                class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs text-n-slate-11"
              >
                {{ activity.priority || 'normal' }}
              </span>
            </div>
            <p class="m-0 mt-1 text-sm font-medium text-n-slate-12">
              {{ activity.title }}
            </p>
            <p
              v-if="activity.description"
              class="m-0 mt-1 text-xs text-n-slate-11"
            >
              {{ activity.description }}
            </p>
            <p class="m-0 mt-2 text-xs text-n-slate-10">
              Prazo: {{ formatDate(activity.due_at) }}
            </p>
          </div>
          <div class="flex shrink-0 items-center gap-1">
            <button
              type="button"
              class="inline-flex h-8 items-center gap-1 rounded-lg border border-ui-border-subtle px-2 text-xs font-medium text-n-slate-12 hover:bg-n-slate-3 disabled:opacity-50"
              :disabled="snoozingId === activity.id"
              @click="snoozeActivity(activity, 24)"
            >
              <span class="i-lucide-clock-3 size-4" />
              Adiar
            </button>
            <button
              type="button"
              class="inline-flex h-8 items-center gap-1 rounded-lg border border-ui-border-subtle px-2 text-xs font-medium text-n-slate-12 hover:bg-n-slate-3 disabled:opacity-50"
              :disabled="completingId === activity.id"
              @click="completeActivity(activity)"
            >
              <span class="i-lucide-check size-4" />
              Concluir
            </button>
          </div>
        </div>
      </article>

      <div v-if="completedActivities.length" class="space-y-2 pt-2">
        <p class="m-0 text-xs font-medium uppercase text-n-slate-10">
          Concluídas recentemente
        </p>
        <article
          v-for="activity in completedActivities"
          :key="activity.id"
          class="rounded-lg border border-ui-border-subtle bg-n-slate-2 p-3 opacity-80"
        >
          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ activity.title }}
          </p>
          <p class="m-0 mt-1 text-xs text-n-slate-10">
            {{ kindLabel(activity.kind) }} -
            {{ formatDate(activity.completed_at) }}
          </p>
        </article>
      </div>
    </div>
  </section>
</template>

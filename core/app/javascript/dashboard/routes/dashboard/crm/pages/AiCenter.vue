<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
// UX-04 (fatia 2): Central de IA — estado da IA por conversa, motivo
// estruturado da pausa, quem/quando, botão retomar (auditado via
// resume_source) e saúde de mídia/transcrição.
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import axios from 'axios';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import { AI_HANDOFF_REASON_LABELS } from 'dashboard/helper/crmOptions';
import { useAlert } from 'dashboard/composables';

const route = useRoute();
const router = useRouter();

const loading = ref(true);
const error = ref('');
const summary = ref(null);
const metrics = ref(null);
const media = ref(null);
const pausedConversations = ref([]);
const resumingId = ref(null);

const accountId = computed(() => route.params.accountId);

const AI_MODE_LABELS = {
  auto: 'IA ativa',
  supervised: 'Supervisionada',
  paused: 'Pausada',
  human_only: 'Humano no controle',
};

function formatDuration(seconds) {
  if (!seconds) return '—';
  if (seconds < 3600) return `${Math.round(seconds / 60)} min`;
  return `${(seconds / 3600).toFixed(1)} h`;
}

// Benchmark BR 2026: IA resolve 62-78% das conversas; abaixo de 60% = atenção
function deflectionTone(rate) {
  if (rate == null) return 'ok';
  return rate >= 60 ? 'ok' : 'warn';
}

const summaryCards = computed(() => {
  if (!summary.value) return [];
  return [
    {
      key: 'deflection',
      label: 'Deflection (resolvidas pela IA)',
      value:
        metrics.value?.deflection_rate != null
          ? `${metrics.value.deflection_rate}%`
          : '—',
      tone: deflectionTone(metrics.value?.deflection_rate),
      icon: 'i-lucide-target',
    },
    {
      key: 'time_to_handoff',
      label: 'Tempo médio até handoff',
      value: formatDuration(metrics.value?.avg_seconds_to_handoff),
      tone: 'ok',
      icon: 'i-lucide-timer',
    },
    {
      key: 'auto',
      label: 'IA respondendo',
      value: summary.value.auto,
      tone: 'ok',
      icon: 'i-lucide-bot',
    },
    {
      key: 'human',
      label: 'Humano no controle',
      value: (summary.value.human_only || 0) + (summary.value.paused || 0),
      tone: 'warn',
      icon: 'i-lucide-user-round',
    },
    {
      key: 'media_failed',
      label: 'Falhas de mídia',
      value:
        (media.value?.audio_failed || 0) + (media.value?.media_failed || 0),
      tone:
        (media.value?.audio_failed || 0) + (media.value?.media_failed || 0) > 0
          ? 'danger'
          : 'ok',
      icon: 'i-lucide-file-warning',
    },
    {
      key: 'stale_media',
      label: 'Mídia processando (parada)',
      value: media.value?.stale_processing || 0,
      tone: (media.value?.stale_processing || 0) > 0 ? 'danger' : 'ok',
      icon: 'i-lucide-loader',
    },
  ];
});

const reasonBreakdown = computed(() => {
  const byCode = summary.value?.by_reason_code || {};
  return Object.entries(byCode)
    .map(([code, count]) => ({
      code,
      count,
      label: AI_HANDOFF_REASON_LABELS[code] || code,
    }))
    .sort((a, b) => b.count - a.count);
});

function reasonLabel(state) {
  return (
    AI_HANDOFF_REASON_LABELS[state.handoff_reason_code] ||
    state.handoff_reason ||
    'Motivo não registrado'
  );
}

function formatDateTime(value) {
  if (!value) return '';
  return new Date(value).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

async function loadAiCenter() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId.value}/captain/ai_center`
    );
    summary.value = data.summary;
    metrics.value = data.metrics;
    media.value = data.media;
    pausedConversations.value = data.paused_conversations || [];
  } catch (err) {
    error.value =
      err?.response?.data?.error || 'Não foi possível carregar a Central de IA.';
  } finally {
    loading.value = false;
  }
}

async function resumeAi(state) {
  const conversationDisplayId = state.conversation_display_id;
  if (!conversationDisplayId) {
    useAlert('Esta conversa não possui um identificador público válido.');
    return;
  }

  resumingId.value = state.id;
  try {
    await CaptainConversationStateAPI.update(
      conversationDisplayId,
      { ai_mode: 'auto' }
    );
    useAlert('IA retomada para a conversa.');
    await loadAiCenter();
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Não foi possível retomar a IA.'
    );
  } finally {
    resumingId.value = null;
  }
}

function openConversation(state) {
  if (!state.conversation_display_id) return;
  router.push(
    `/app/accounts/${accountId.value}/conversations/${state.conversation_display_id}`
  );
}

onMounted(loadAiCenter);
</script>

<template>
  <main class="crm-ai-center flex h-full w-full min-w-0 flex-col gap-4 overflow-y-auto bg-n-slate-2 p-4 text-n-slate-12 dark:bg-n-background sm:p-5">
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div class="flex min-w-0 items-start gap-3">
        <span
          class="grid size-11 flex-shrink-0 place-content-center rounded-xl bg-n-brand/10 text-n-brand"
        >
          <span class="i-lucide-bot size-5" />
        </span>
        <div>
          <p class="m-0 text-xs font-extrabold uppercase text-n-brand">
            Captain
          </p>
          <h1 class="m-0 text-xl font-extrabold">Central de IA</h1>
          <p class="m-0 mt-0.5 text-sm text-n-slate-10">
            Estado da IA por conversa, motivos de pausa e saúde de mídia.
          </p>
        </div>
      </div>
      <button
        type="button"
        class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-slate-3 dark:bg-n-slate-2"
        :disabled="loading"
        @click="loadAiCenter"
      >
        <span
          class="size-4"
          :class="loading ? 'i-lucide-loader-2 animate-spin' : 'i-lucide-refresh-cw'"
        />
        Atualizar
      </button>
    </header>

    <p
      v-if="error"
      class="m-0 rounded-lg border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
    >
      {{ error }}
    </p>

    <!-- Cards de resumo -->
    <section class="grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-6">
      <article
        v-for="card in summaryCards"
        :key="card.key"
        class="rounded-xl border border-n-weak bg-n-slate-1 p-3 dark:bg-n-slate-2"
      >
        <span
          class="mb-2 grid size-8 place-content-center rounded-lg"
          :class="{
            'bg-n-teal-3 text-n-teal-11': card.tone === 'ok',
            'bg-n-amber-3 text-n-amber-11': card.tone === 'warn',
            'bg-n-ruby-3 text-n-ruby-11': card.tone === 'danger',
          }"
        >
          <span class="size-4" :class="card.icon" />
        </span>
        <p class="m-0 text-2xl font-extrabold">{{ card.value }}</p>
        <p class="m-0 text-xs text-n-slate-10">{{ card.label }}</p>
      </article>
    </section>

    <!-- Motivos de pausa -->
    <section
      v-if="reasonBreakdown.length"
      class="rounded-xl border border-n-weak bg-n-slate-1 p-4 dark:bg-n-slate-2"
    >
      <h2 class="m-0 mb-3 text-sm font-semibold">Pausas por motivo</h2>
      <ul class="m-0 flex list-none flex-wrap gap-2 p-0">
        <li
          v-for="item in reasonBreakdown"
          :key="item.code"
          class="inline-flex items-center gap-2 rounded-full bg-n-slate-3 px-3 py-1 text-xs"
        >
          <span class="font-semibold">{{ item.count }}</span>
          {{ item.label }}
        </li>
      </ul>
    </section>

    <!-- Conversas pausadas -->
    <section
      class="flex-1 rounded-xl border border-n-weak bg-n-slate-1 dark:bg-n-slate-2"
    >
      <header class="border-b border-n-weak px-4 py-3">
        <h2 class="m-0 text-sm font-semibold">
          Conversas com IA pausada
          <span class="ml-1 text-n-slate-10">
            ({{ pausedConversations.length }})
          </span>
        </h2>
      </header>

      <div v-if="loading" class="grid min-h-32 place-content-center p-6 text-sm text-n-slate-10">
        <span class="i-lucide-loader-2 mx-auto mb-1 size-5 animate-spin" />
        Carregando...
      </div>

      <div
        v-else-if="!pausedConversations.length"
        class="grid min-h-32 place-content-center p-6 text-center text-sm text-n-slate-10"
      >
        <span class="i-lucide-check-circle-2 mx-auto mb-1 size-5 text-n-teal-11" />
        Nenhuma conversa pausada — a IA está respondendo tudo.
      </div>

      <ul v-else class="m-0 list-none divide-y divide-n-weak p-0">
        <li
          v-for="state in pausedConversations"
          :key="state.id"
          class="flex flex-wrap items-center gap-3 px-4 py-3"
        >
          <div class="min-w-0 flex-1">
            <p class="m-0 truncate text-sm font-semibold">
              {{ state.contact_name || `Conversa #${state.conversation_display_id}` }}
              <span class="ml-1 font-normal text-n-slate-10">
                #{{ state.conversation_display_id }}
              </span>
            </p>
            <p class="m-0 mt-0.5 flex flex-wrap items-center gap-x-2 text-xs text-n-slate-10">
              <span
                class="inline-flex items-center gap-1 rounded-full bg-n-ruby-3 px-1.5 py-0.5 font-semibold text-n-ruby-11"
              >
                <span class="i-lucide-pause-circle size-3" />
                {{ AI_MODE_LABELS[state.ai_mode] || state.ai_mode }}
              </span>
              {{ reasonLabel(state) }}
              <span v-if="state.handoff_by_name">
                · por {{ state.handoff_by_name }}
              </span>
              <span v-if="state.handoff_at">
                · {{ formatDateTime(state.handoff_at) }}
              </span>
            </p>
          </div>
          <div class="flex flex-shrink-0 items-center gap-2">
            <button
              type="button"
              class="inline-flex h-8 items-center gap-1.5 rounded-lg border border-n-weak bg-n-background px-2.5 text-xs font-medium hover:bg-n-slate-3 dark:bg-n-slate-1"
              @click="openConversation(state)"
            >
              <span class="i-lucide-message-square size-3.5" />
              Abrir
            </button>
            <button
              type="button"
              class="inline-flex h-8 items-center gap-1.5 rounded-lg bg-n-teal-9 px-2.5 text-xs font-semibold text-white hover:bg-n-teal-10 disabled:opacity-60"
              :disabled="
                !state.conversation_display_id || resumingId === state.id
              "
              @click="resumeAi(state)"
            >
              <span
                class="size-3.5"
                :class="
                  resumingId === state.id
                    ? 'i-lucide-loader-2 animate-spin'
                    : 'i-lucide-play-circle'
                "
              />
              Retomar IA
            </button>
          </div>
        </li>
      </ul>
    </section>
  </main>
</template>

<script setup>
// UX-04 (fatia 2): Central de IA — estado da IA por conversa, motivo
// estruturado da pausa, quem/quando, botão retomar (auditado via
// resume_source) e saúde de mídia/transcrição.
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import CaptainAiCenterAPI from 'dashboard/api/captain/aiCenter';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import CrmAPI from 'dashboard/api/crm';
import { AI_HANDOFF_REASON_LABELS } from 'dashboard/helper/crmOptions';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import CRMPackAiCard from 'dashboard/components/crm/CRMPackAiCard.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsEmptyState,
  DsSelect,
  DsSkeleton,
  DsTabs,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const loading = ref(true);
const error = ref('');
const summary = ref(null);
const metrics = ref(null);
const media = ref(null);
const pausedConversations = ref([]);
const resumingId = ref(null);

// 3.4: tela única de IA — aba Operação (métricas/handoffs) + aba Assistente
// (identidade do pack, prompt override e atalhos para as telas profundas do
// Captain, que continuam upstream).
const activeTab = ref('operation');
const packs = ref([]);
const promptOverride = ref('');

const accountId = computed(() => route.params.accountId);
const assistants = useMapGetter('captainAssistants/getRecords');
const isFeatureEnabled = useMapGetter('accounts/isFeatureEnabledonAccount');
const currentAccountId = useMapGetter('getCurrentAccountId');

const isUniversal = computed(() =>
  isFeatureEnabled.value?.(currentAccountId.value, FEATURE_FLAGS.CRM_UNIVERSAL)
);

const selectedAssistantId = ref(null);

const assistantOptions = computed(() =>
  assistants.value.map(assistant => ({
    value: assistant.id,
    label: assistant.name,
  }))
);

const tabs = computed(() => [
  {
    value: 'operation',
    label: t('CRM.AI_CENTER.TABS.OPERATION'),
    icon: 'i-lucide-activity',
  },
  {
    value: 'assistant',
    label: t('CRM.AI_CENTER.TABS.ASSISTANT'),
    icon: 'i-lucide-bot',
  },
]);

const assistantLinks = computed(() => {
  if (!selectedAssistantId.value) return [];
  const params = {
    accountId: accountId.value,
    assistantId: selectedAssistantId.value,
  };
  return [
    {
      key: 'config',
      icon: 'i-lucide-settings-2',
      label: t('CRM.AI_CENTER.ASSISTANT_LINKS.CONFIG'),
      description: t('CRM.AI_CENTER.ASSISTANT_LINKS.CONFIG_DESC'),
      to: { name: 'captain_agent_configs_index', params },
    },
    {
      key: 'guardrails',
      icon: 'i-lucide-shield-check',
      label: t('CRM.AI_CENTER.ASSISTANT_LINKS.GUARDRAILS'),
      description: t('CRM.AI_CENTER.ASSISTANT_LINKS.GUARDRAILS_DESC'),
      to: { name: 'captain_assistants_guardrails_index', params },
    },
    {
      key: 'guidelines',
      icon: 'i-lucide-list-checks',
      label: t('CRM.AI_CENTER.ASSISTANT_LINKS.GUIDELINES'),
      description: t('CRM.AI_CENTER.ASSISTANT_LINKS.GUIDELINES_DESC'),
      to: { name: 'captain_assistants_guidelines_index', params },
    },
    {
      key: 'tools',
      icon: 'i-lucide-wrench',
      label: t('CRM.AI_CENTER.ASSISTANT_LINKS.TOOLS'),
      description: t('CRM.AI_CENTER.ASSISTANT_LINKS.TOOLS_DESC'),
      to: { name: 'captain_tools_index', params },
    },
    {
      key: 'inboxes',
      icon: 'i-lucide-inbox',
      label: t('CRM.AI_CENTER.ASSISTANT_LINKS.INBOXES'),
      description: t('CRM.AI_CENTER.ASSISTANT_LINKS.INBOXES_DESC'),
      to: { name: 'captain_assistants_inboxes_index', params },
    },
    {
      key: 'playground',
      icon: 'i-lucide-flask-conical',
      label: t('CRM.AI_CENTER.ASSISTANT_LINKS.PLAYGROUND'),
      description: t('CRM.AI_CENTER.ASSISTANT_LINKS.PLAYGROUND_DESC'),
      to: { name: 'captain_assistants_playground_index', params },
    },
  ];
});

const aiModeLabels = computed(() => ({
  auto: t('CRM.AI_CENTER.MODE.AUTO'),
  supervised: t('CRM.AI_CENTER.MODE.SUPERVISED'),
  paused: t('CRM.AI_CENTER.MODE.PAUSED'),
  human_only: t('CRM.AI_CENTER.MODE.HUMAN_ONLY'),
}));

function formatDuration(seconds) {
  if (!seconds || seconds < 0) return '—';
  if (seconds < 3600) {
    return t('CRM.AI_CENTER.DURATION_MINUTES', {
      count: Math.round(seconds / 60),
    });
  }
  return t('CRM.AI_CENTER.DURATION_HOURS', { count: (seconds / 3600).toFixed(1) });
}

// Benchmark BR 2026: IA resolve 62-78% das conversas; abaixo de 60% = atenção
function deflectionTone(rate) {
  if (rate == null) return 'ok';
  return rate >= 60 ? 'ok' : 'warn';
}

const summaryCards = computed(() => {
  if (!summary.value) return [];
  const failedMedia =
    (media.value?.audio_failed || 0) + (media.value?.media_failed || 0);
  return [
    {
      key: 'deflection',
      label: t('CRM.AI_CENTER.METRICS.DEFLECTION'),
      value:
        metrics.value?.deflection_rate != null
          ? `${metrics.value.deflection_rate}%`
          : '—',
      tone: deflectionTone(metrics.value?.deflection_rate),
      icon: 'i-lucide-target',
    },
    {
      key: 'time_to_handoff',
      label: t('CRM.AI_CENTER.METRICS.TIME_TO_HANDOFF'),
      value: formatDuration(metrics.value?.avg_seconds_to_handoff),
      tone: 'ok',
      icon: 'i-lucide-timer',
    },
    {
      key: 'auto',
      label: t('CRM.AI_CENTER.METRICS.AUTO'),
      value: summary.value.auto,
      tone: 'ok',
      icon: 'i-lucide-bot',
    },
    {
      key: 'human',
      label: t('CRM.AI_CENTER.METRICS.HUMAN'),
      value: (summary.value.human_only || 0) + (summary.value.paused || 0),
      tone: 'warn',
      icon: 'i-lucide-user-round',
    },
    {
      key: 'media_failed',
      label: t('CRM.AI_CENTER.METRICS.MEDIA_FAILED'),
      value: failedMedia,
      tone: failedMedia > 0 ? 'danger' : 'ok',
      icon: 'i-lucide-file-warning',
    },
    {
      key: 'stale_media',
      label: t('CRM.AI_CENTER.METRICS.STALE_MEDIA'),
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

const toneIconClasses = {
  ok: 'bg-ui-success-soft text-ui-success-foreground',
  warn: 'bg-ui-warning-soft text-ui-warning-foreground',
  danger: 'bg-ui-danger-soft text-ui-danger-foreground',
};

function reasonLabel(state) {
  return (
    AI_HANDOFF_REASON_LABELS[state.handoff_reason_code] ||
    state.handoff_reason ||
    t('CRM.AI_CENTER.NO_REASON')
  );
}

function formatDateTime(value) {
  if (!value) return '';
  return new Date(value).toLocaleString(undefined, {
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
    const { data } = await CaptainAiCenterAPI.get();
    summary.value = data.summary;
    metrics.value = data.metrics;
    media.value = data.media;
    pausedConversations.value = data.paused_conversations || [];
  } catch (err) {
    error.value =
      err?.response?.data?.error || t('CRM.AI_CENTER.ERROR_GENERIC');
  } finally {
    loading.value = false;
  }
}

async function resumeAi(state) {
  const conversationDisplayId = state.conversation_display_id;
  if (!conversationDisplayId) {
    useAlert(t('CRM.AI_CENTER.NO_DISPLAY_ID'));
    return;
  }

  resumingId.value = state.id;
  try {
    await CaptainConversationStateAPI.update(conversationDisplayId, {
      ai_mode: 'auto',
    });
    useAlert(t('CRM.AI_CENTER.RESUMED'));
    await loadAiCenter();
  } catch (err) {
    useAlert(err?.response?.data?.error || t('CRM.AI_CENTER.RESUME_ERROR'));
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

function onAiSaved(value) {
  promptOverride.value = value;
}

function onAiError(message) {
  error.value = message;
}

async function loadAssistantTab() {
  await store.dispatch('captainAssistants/get');
  if (!selectedAssistantId.value && assistants.value.length) {
    selectedAssistantId.value = assistants.value[0].id;
  }
  if (!isUniversal.value) return;
  try {
    const { data } = await CrmAPI.getPacks();
    packs.value = data?.packs || [];
    promptOverride.value = data?.ai_settings?.prompt_override || '';
  } catch {
    packs.value = [];
  }
}

onMounted(() => {
  loadAiCenter();
  loadAssistantTab();
});
</script>

<template>
  <section
    class="crm-ai-center flex h-full min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="t('CRM.AI_CENTER.TITLE')"
      :breadcrumbs="[
        { label: t('CRM.AI_CENTER.BREADCRUMB') },
        { label: t('CRM.AI_CENTER.TITLE') },
      ]"
    >
      <template #actions>
        <DsButton
          icon="i-lucide-refresh-cw"
          variant="secondary"
          :loading="loading"
          :label="t('CRM.AI_CENTER.REFRESH')"
          @click="loadAiCenter"
        />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <p class="m-0 -mt-2 text-ui-body-sm text-ui-text-muted">
        {{ t('CRM.AI_CENTER.SUBTITLE') }}
      </p>

      <DsTabs
        v-model="activeTab"
        :tabs="tabs"
        :label="t('CRM.AI_CENTER.TABS_LABEL')"
      />

      <template v-if="activeTab === 'assistant'">
        <DsCard
          v-if="assistants.length"
          as="section"
          aria-labelledby="ai-assistant-title"
        >
          <h2
            id="ai-assistant-title"
            class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
          >
            {{ t('CRM.AI_CENTER.ASSISTANT_TITLE') }}
          </h2>
          <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
            {{ t('CRM.AI_CENTER.ASSISTANT_SUBTITLE') }}
          </p>
          <DsSelect
            v-model="selectedAssistantId"
            class="mt-3 max-w-md"
            :label="t('CRM.AI_CENTER.ASSISTANT_SELECT')"
            :options="assistantOptions"
          />
        </DsCard>

        <CRMPackAiCard
          v-if="isUniversal"
          :packs="packs"
          :prompt-override="promptOverride"
          @saved="onAiSaved"
          @error="onAiError"
        />

        <section
          v-if="assistantLinks.length"
          class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3"
          :aria-label="t('CRM.AI_CENTER.ASSISTANT_LINKS_LABEL')"
        >
          <DsCard
            v-for="link in assistantLinks"
            :key="link.key"
            as="article"
            padding="sm"
          >
            <router-link
              :to="link.to"
              class="group flex items-start gap-3 no-underline"
            >
              <span
                class="grid size-9 shrink-0 place-content-center rounded-ui-surface bg-ui-brand-soft text-ui-brand-foreground"
              >
                <span class="size-4" :class="link.icon" />
              </span>
              <span class="min-w-0">
                <span
                  class="block text-ui-body-sm font-semibold text-ui-text group-hover:text-ui-brand"
                >
                  {{ link.label }}
                </span>
                <span class="block text-ui-caption text-ui-text-muted">
                  {{ link.description }}
                </span>
              </span>
            </router-link>
          </DsCard>
        </section>

        <DsEmptyState
          v-if="!assistants.length && !isUniversal"
          icon="i-lucide-bot"
          :title="t('CRM.AI_CENTER.NO_ASSISTANT_TITLE')"
          :description="t('CRM.AI_CENTER.NO_ASSISTANT_DESC')"
        />
      </template>

      <template v-else>
        <DsCard
          v-if="error"
          as="section"
          padding="sm"
          role="alert"
          class="border-ui-danger/30 bg-ui-danger-soft text-ui-danger-foreground"
        >
          <p class="m-0 text-ui-body-sm">{{ error }}</p>
        </DsCard>

        <section
          class="grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-6"
          :aria-label="t('CRM.AI_CENTER.METRICS_LABEL')"
        >
          <DsCard
            v-for="card in summaryCards"
            :key="card.key"
            as="article"
            padding="sm"
          >
            <span
              class="mb-2 grid size-8 place-content-center rounded-ui-surface"
              :class="toneIconClasses[card.tone]"
            >
              <span class="size-4" :class="card.icon" />
            </span>
            <p class="m-0 text-ui-title font-semibold">{{ card.value }}</p>
            <p class="m-0 text-ui-caption text-ui-text-muted">
              {{ card.label }}
            </p>
          </DsCard>
        </section>

        <DsCard v-if="reasonBreakdown.length" as="section" padding="md">
          <h2 class="m-0 mb-3 text-ui-label font-semibold text-ui-text">
            {{ t('CRM.AI_CENTER.PAUSE_REASONS') }}
          </h2>
          <ul class="m-0 flex list-none flex-wrap gap-2 p-0">
            <li
              v-for="item in reasonBreakdown"
              :key="item.code"
              class="inline-flex items-center gap-2 rounded-full bg-ui-sunken px-3 py-1 text-ui-caption text-ui-text"
            >
              <span class="font-semibold">{{ item.count }}</span>
              {{ item.label }}
            </li>
          </ul>
        </DsCard>

        <DsCard as="section" padding="none" class="min-h-0 flex-1">
          <header class="border-b border-ui-border-subtle px-4 py-3">
            <h2 class="m-0 text-ui-label font-semibold text-ui-text">
              {{ t('CRM.AI_CENTER.PAUSED_TITLE') }}
              <span class="ml-1 text-ui-text-muted">
                ({{ pausedConversations.length }})
              </span>
            </h2>
          </header>

          <div v-if="loading" class="flex flex-col gap-2 p-4">
            <DsSkeleton v-for="n in 3" :key="n" class="h-12 w-full" />
          </div>

          <DsEmptyState
            v-else-if="!pausedConversations.length"
            :title="t('CRM.AI_CENTER.EMPTY_TITLE')"
            :description="t('CRM.AI_CENTER.EMPTY_DESCRIPTION')"
            icon="i-lucide-check-circle-2"
          />

          <ul v-else class="m-0 list-none divide-y divide-ui-border-subtle p-0">
            <li
              v-for="state in pausedConversations"
              :key="state.id"
              class="flex flex-wrap items-center gap-3 px-4 py-3"
            >
              <div class="min-w-0 flex-1">
                <p class="m-0 truncate text-ui-body font-semibold text-ui-text">
                  {{
                    state.contact_name ||
                      t('CRM.AI_CENTER.CONVERSATION_FALLBACK', {
                        id: state.conversation_display_id,
                      })
                  }}
                  <span class="ml-1 font-normal text-ui-text-muted">
                    #{{ state.conversation_display_id }}
                  </span>
                </p>
                <p
                  class="m-0 mt-0.5 flex flex-wrap items-center gap-x-2 text-ui-caption text-ui-text-muted"
                >
                  <DsBadge
                    :label="aiModeLabels[state.ai_mode] || state.ai_mode"
                    icon="i-lucide-pause-circle"
                    variant="danger"
                  />
                  {{ reasonLabel(state) }}
                  <span v-if="state.handoff_by_name">
                    ·
                    {{
                      t('CRM.AI_CENTER.PAUSED_BY', {
                        name: state.handoff_by_name,
                      })
                    }}
                  </span>
                  <span v-if="state.handoff_at">
                    · {{ formatDateTime(state.handoff_at) }}
                  </span>
                </p>
              </div>
              <div class="flex flex-shrink-0 items-center gap-2">
                <DsButton
                  size="sm"
                  variant="secondary"
                  icon="i-lucide-message-square"
                  :label="t('CRM.AI_CENTER.OPEN')"
                  @click="openConversation(state)"
                />
                <DsButton
                  size="sm"
                  variant="primary"
                  icon="i-lucide-play-circle"
                  :label="t('CRM.AI_CENTER.RESUME')"
                  :loading="resumingId === state.id"
                  :disabled="!state.conversation_display_id"
                  @click="resumeAi(state)"
                />
              </div>
            </li>
          </ul>
        </DsCard>
      </template>
    </div>
  </section>
</template>

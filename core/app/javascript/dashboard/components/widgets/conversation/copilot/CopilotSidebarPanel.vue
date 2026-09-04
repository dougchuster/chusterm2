<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import Copilot from 'dashboard/components-next/copilot/Copilot.vue';
import {
  DsButton,
  DsCard,
  DsBadge,
  DsSkeleton,
} from 'dashboard/design-system/components';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const { updateUISettings, uiSettings } = useUISettings();
const {
  captainEnabled,
  captainTasksEnabled,
  summarizeConversation,
  getReplySuggestion,
  rewriteContent,
} = useCaptain();

const activeTab = ref('assistant');
const summary = ref('');
const isSummarizing = ref(false);
const summaryError = ref('');

const suggestedReply = ref('');
const isSuggestingReply = ref(false);
const isRefiningReply = ref(false);
const replyError = ref('');

const selectedCopilotThreadId = ref(null);
const selectedAssistantId = ref(null);

const currentUser = useMapGetter('getCurrentUser');
const assistants = useMapGetter('captainAssistants/getRecords');
const inboxAssistant = useMapGetter('getCopilotAssistant');
const currentChat = useMapGetter('getSelectedChat');

const messages = computed(() =>
  store.getters['copilotMessages/getMessagesByThreadId'](
    selectedCopilotThreadId.value
  )
);

const activeAssistant = computed(() => {
  const preferredId = uiSettings.value?.preferred_captain_assistant_id;
  if (preferredId) {
    const preferredAssistant = assistants.value?.find(
      a => a.id === preferredId
    );
    if (preferredAssistant) return preferredAssistant;
  }
  if (inboxAssistant.value) {
    const inboxMatchedAssistant = assistants.value?.find(
      a => a.id === inboxAssistant.value.id
    );
    if (inboxMatchedAssistant) return inboxMatchedAssistant;
  }
  return assistants.value?.[0] || {};
});

const tabs = computed(() => {
  const items = [
    {
      value: 'assistant',
      label: t('COPILOT.TABS.ASSISTANT'),
      icon: 'i-lucide-sparkles',
    },
  ];
  if (assistants.value?.length > 0) {
    items.push({
      value: 'chat',
      label: t('COPILOT.TABS.CHAT'),
      icon: 'i-lucide-message-square',
    });
  }
  return items;
});

const closeCopilotPanel = () => {
  updateUISettings({
    is_copilot_panel_open: false,
    is_contact_sidebar_open: false,
  });
};

const handleGenerateSummary = async () => {
  isSummarizing.value = true;
  summaryError.value = '';
  try {
    const result = await summarizeConversation();
    if (result?.message) {
      summary.value = result.message;
    } else if (result?.errorType) {
      summaryError.value = t('COPILOT.SMART_SUMMARY.ERROR');
    }
  } catch (error) {
    summaryError.value = t('COPILOT.SMART_SUMMARY.ERROR');
    useAlert(t('COPILOT.SMART_SUMMARY.ERROR'));
  } finally {
    isSummarizing.value = false;
  }
};

const copySummary = async () => {
  if (!summary.value) return;
  try {
    await navigator.clipboard.writeText(summary.value);
    useAlert(t('COPILOT.SMART_SUMMARY.COPIED'));
  } catch {
    useAlert(t('COPILOT.SMART_SUMMARY.COPIED'));
  }
};

const insertSummaryIntoEditor = () => {
  if (!summary.value) return;
  emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, summary.value);
};

const handleGenerateReplySuggestion = async () => {
  isSuggestingReply.value = true;
  replyError.value = '';
  try {
    const result = await getReplySuggestion();
    if (result?.message) {
      suggestedReply.value = result.message;
    } else if (result?.errorType) {
      replyError.value = t('COPILOT.REPLY_ASSISTANT.ERROR');
    }
  } catch (error) {
    replyError.value = t('COPILOT.REPLY_ASSISTANT.ERROR');
    useAlert(t('COPILOT.REPLY_ASSISTANT.ERROR'));
  } finally {
    isSuggestingReply.value = false;
  }
};

const handleRefineReply = async operation => {
  if (!suggestedReply.value || isRefiningReply.value) return;
  isRefiningReply.value = true;
  try {
    const result = await rewriteContent(suggestedReply.value, operation);
    if (result?.message) {
      suggestedReply.value = result.message;
    }
  } catch (error) {
    useAlert(t('COPILOT.REPLY_ASSISTANT.ERROR'));
  } finally {
    isRefiningReply.value = false;
  }
};

const copyReply = async () => {
  if (!suggestedReply.value) return;
  try {
    await navigator.clipboard.writeText(suggestedReply.value);
    useAlert(t('COPILOT.REPLY_ASSISTANT.COPIED'));
  } catch {
    useAlert(t('COPILOT.REPLY_ASSISTANT.COPIED'));
  }
};

const insertReplyIntoEditor = () => {
  if (!suggestedReply.value) return;
  emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, suggestedReply.value);
};

const sendChatMessage = async message => {
  try {
    if (selectedCopilotThreadId.value) {
      await store.dispatch('copilotMessages/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: props.conversationId || currentChat.value?.id,
        threadId: selectedCopilotThreadId.value,
        message,
      });
    } else {
      const response = await store.dispatch('copilotThreads/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: props.conversationId || currentChat.value?.id,
        message,
      });
      const threadData = response.thread || response;
      selectedCopilotThreadId.value = threadData.id;
    }
  } catch (error) {
    useAlert(error.message || t('CAPTAIN.COPILOT.EMPTY_MESSAGE'));
  }
};

const handleResetChat = () => {
  selectedCopilotThreadId.value = null;
};

const handleSetAssistant = async assistant => {
  selectedAssistantId.value = assistant.id;
  await updateUISettings({
    preferred_captain_assistant_id: assistant.id,
  });
};

onMounted(() => {
  if (captainEnabled.value) {
    store.dispatch('captainAssistants/get');
  }
});
</script>

<template>
  <section
    data-testid="copilot-sidebar-panel"
    class="flex h-full w-full min-w-0 flex-col overflow-hidden bg-ds-bg-canvas text-ds-fg-default"
  >
    <SidebarActionsHeader
      :title="$t('COPILOT.SIDEBAR_TITLE')"
      @close="closeCopilotPanel"
    />

    <!-- Navigation Switcher if assistants exist -->
    <div
      v-if="tabs.length > 1"
      class="border-b border-ds-border-subtle bg-ds-bg-elevated px-4 py-2"
    >
      <div class="flex items-center gap-1 rounded-ui-surface bg-ui-sunken p-1">
        <button
          v-for="tab in tabs"
          :key="tab.value"
          type="button"
          class="flex flex-1 items-center justify-center gap-1.5 rounded-ui-control px-2.5 py-1.5 text-ui-caption font-medium transition-colors"
          :class="[
            activeTab === tab.value
              ? 'bg-ui-surface text-ui-text shadow-sm'
              : 'text-ui-text-muted hover:text-ui-text',
          ]"
          @click="activeTab = tab.value"
        >
          <Icon :icon="tab.icon" class="size-3.5" />
          <span>{{ tab.label }}</span>
        </button>
      </div>
    </div>

    <!-- Tab 1: Smart Contextual Assistant -->
    <div
      v-if="activeTab === 'assistant'"
      class="flex-1 space-y-4 overflow-y-auto p-4"
    >
      <!-- Smart Summary Card -->
      <DsCard padding="md" class="space-y-3">
        <div class="flex items-start justify-between gap-2">
          <div class="flex items-center gap-2">
            <span
              class="flex size-7 items-center justify-center rounded-lg bg-ds-accent-soft text-ds-accent"
            >
              <Icon icon="i-lucide-file-text" class="size-4" />
            </span>
            <div>
              <h3 class="m-0 text-ui-body-sm font-semibold text-ui-text">
                {{ $t('COPILOT.SMART_SUMMARY.TITLE') }}
              </h3>
              <p class="m-0 text-ui-caption text-ui-text-muted">
                {{ $t('COPILOT.SMART_SUMMARY.DESCRIPTION') }}
              </p>
            </div>
          </div>
          <DsBadge
            v-if="captainTasksEnabled"
            :label="$t('COPILOT.HEADER_BADGE')"
            variant="brand"
          />
        </div>

        <div
          v-if="isSummarizing"
          class="space-y-2 py-2"
          data-testid="summary-loading"
        >
          <DsSkeleton class="h-3.5 w-3/4" />
          <DsSkeleton class="h-3.5 w-full" />
          <DsSkeleton class="h-3.5 w-5/6" />
        </div>

        <div
          v-else-if="summary"
          data-testid="summary-content"
          class="rounded-ui-control border border-ui-border-subtle bg-ui-sunken p-3 text-ui-body-sm text-ui-text whitespace-pre-wrap"
        >
          {{ summary }}
        </div>

        <p
          v-else
          class="m-0 rounded-ui-control border border-dashed border-ui-border-subtle p-3 text-center text-ui-caption text-ui-text-muted"
        >
          {{ $t('COPILOT.SMART_SUMMARY.EMPTY') }}
        </p>

        <div class="flex flex-wrap items-center gap-2 pt-1">
          <DsButton
            :label="
              summary
                ? $t('COPILOT.SMART_SUMMARY.REFRESH_BUTTON')
                : $t('COPILOT.SMART_SUMMARY.GENERATE_BUTTON')
            "
            icon="i-lucide-sparkles"
            variant="secondary"
            size="sm"
            :loading="isSummarizing"
            @click="handleGenerateSummary"
          />
          <DsButton
            v-if="summary"
            icon="i-lucide-copy"
            variant="ghost"
            size="sm"
            :aria-label="$t('COPILOT.SMART_SUMMARY.COPY')"
            @click="copySummary"
          />
          <DsButton
            v-if="summary"
            :label="$t('COPILOT.SMART_SUMMARY.INSERT')"
            icon="i-lucide-arrow-down-left"
            variant="ghost"
            size="sm"
            @click="insertSummaryIntoEditor"
          />
        </div>
      </DsCard>

      <!-- Reply Assistant Card -->
      <DsCard padding="md" class="space-y-3">
        <div class="flex items-start justify-between gap-2">
          <div class="flex items-center gap-2">
            <span
              class="flex size-7 items-center justify-center rounded-lg bg-ds-accent-soft text-ds-accent"
            >
              <Icon icon="i-lucide-message-square-plus" class="size-4" />
            </span>
            <div>
              <h3 class="m-0 text-ui-body-sm font-semibold text-ui-text">
                {{ $t('COPILOT.REPLY_ASSISTANT.TITLE') }}
              </h3>
              <p class="m-0 text-ui-caption text-ui-text-muted">
                {{ $t('COPILOT.REPLY_ASSISTANT.DESCRIPTION') }}
              </p>
            </div>
          </div>
        </div>

        <div
          v-if="isSuggestingReply || isRefiningReply"
          class="space-y-2 py-2"
          data-testid="reply-loading"
        >
          <DsSkeleton class="h-3.5 w-4/5" />
          <DsSkeleton class="h-3.5 w-full" />
          <DsSkeleton class="h-3.5 w-2/3" />
        </div>

        <div
          v-else-if="suggestedReply"
          data-testid="reply-content"
          class="rounded-ui-control border border-ui-border-subtle bg-ui-sunken p-3 text-ui-body-sm text-ui-text whitespace-pre-wrap"
        >
          {{ suggestedReply }}
        </div>

        <p
          v-else
          class="m-0 rounded-ui-control border border-dashed border-ui-border-subtle p-3 text-center text-ui-caption text-ui-text-muted"
        >
          {{ $t('COPILOT.REPLY_ASSISTANT.EMPTY') }}
        </p>

        <!-- Refine Pills when a suggestion exists -->
        <div v-if="suggestedReply" class="space-y-1.5 pt-1">
          <span class="block text-[11px] font-medium text-ui-text-muted">
            {{ $t('COPILOT.REPLY_ASSISTANT.REFINE_LABEL') }}
          </span>
          <div class="flex flex-wrap gap-1.5">
            <button
              type="button"
              :disabled="isRefiningReply"
              class="rounded-ui-control border border-ui-border-subtle bg-ui-surface px-2 py-1 text-ui-caption text-ui-text hover:bg-ui-hover active:bg-ui-active disabled:opacity-50"
              @click="handleRefineReply('professional')"
            >
              {{ $t('COPILOT.REPLY_ASSISTANT.TONE_PROFESSIONAL') }}
            </button>
            <button
              type="button"
              :disabled="isRefiningReply"
              class="rounded-ui-control border border-ui-border-subtle bg-ui-surface px-2 py-1 text-ui-caption text-ui-text hover:bg-ui-hover active:bg-ui-active disabled:opacity-50"
              @click="handleRefineReply('casual')"
            >
              {{ $t('COPILOT.REPLY_ASSISTANT.TONE_CASUAL') }}
            </button>
            <button
              type="button"
              :disabled="isRefiningReply"
              class="rounded-ui-control border border-ui-border-subtle bg-ui-surface px-2 py-1 text-ui-caption text-ui-text hover:bg-ui-hover active:bg-ui-active disabled:opacity-50"
              @click="handleRefineReply('shorten')"
            >
              {{ $t('COPILOT.REPLY_ASSISTANT.TONE_SHORTEN') }}
            </button>
            <button
              type="button"
              :disabled="isRefiningReply"
              class="rounded-ui-control border border-ui-border-subtle bg-ui-surface px-2 py-1 text-ui-caption text-ui-text hover:bg-ui-hover active:bg-ui-active disabled:opacity-50"
              @click="handleRefineReply('expand')"
            >
              {{ $t('COPILOT.REPLY_ASSISTANT.TONE_EXPAND') }}
            </button>
            <button
              type="button"
              :disabled="isRefiningReply"
              class="rounded-ui-control border border-ui-border-subtle bg-ui-surface px-2 py-1 text-ui-caption text-ui-text hover:bg-ui-hover active:bg-ui-active disabled:opacity-50"
              @click="handleRefineReply('fix_spelling_grammar')"
            >
              {{ $t('COPILOT.REPLY_ASSISTANT.TONE_GRAMMAR') }}
            </button>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-2 pt-1">
          <DsButton
            :label="
              suggestedReply
                ? $t('COPILOT.REPLY_ASSISTANT.REFRESH_BUTTON')
                : $t('COPILOT.REPLY_ASSISTANT.GENERATE_BUTTON')
            "
            icon="i-lucide-sparkles"
            variant="secondary"
            size="sm"
            :loading="isSuggestingReply"
            @click="handleGenerateReplySuggestion"
          />
          <DsButton
            v-if="suggestedReply"
            icon="i-lucide-copy"
            variant="ghost"
            size="sm"
            :aria-label="$t('COPILOT.REPLY_ASSISTANT.COPY')"
            @click="copyReply"
          />
          <DsButton
            v-if="suggestedReply"
            :label="$t('COPILOT.REPLY_ASSISTANT.INSERT')"
            icon="i-lucide-arrow-down-left"
            variant="ghost"
            size="sm"
            @click="insertReplyIntoEditor"
          />
        </div>
      </DsCard>
    </div>

    <!-- Tab 2: Interactive Chat -->
    <div v-else-if="activeTab === 'chat'" class="flex-1 overflow-hidden">
      <Copilot
        :messages="messages"
        :support-agent="currentUser"
        :conversation-inbox-type="currentChat?.inbox_id ? 'channel' : 'default'"
        :assistants="assistants"
        :active-assistant="activeAssistant"
        @send-message="sendChatMessage"
        @reset="handleResetChat"
        @set-assistant="handleSetAssistant"
      />
    </div>
  </section>
</template>

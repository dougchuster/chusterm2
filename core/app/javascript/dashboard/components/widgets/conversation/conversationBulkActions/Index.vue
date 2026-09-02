<script>
import { getUnixTime } from 'date-fns';
import { findSnoozeTime } from 'dashboard/helper/snoozeHelpers';
import { emitter } from 'shared/helpers/mitt';
import wootConstants from 'dashboard/constants/globals';
import {
  CMD_BULK_ACTION_SNOOZE_CONVERSATION,
  CMD_BULK_ACTION_REOPEN_CONVERSATION,
  CMD_BULK_ACTION_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import AgentSelector from './AgentSelector.vue';
import UpdateActions from './UpdateActions.vue';
import LabelActions from './LabelActions.vue';
import TeamActions from './TeamActions.vue';
import CustomSnoozeModal from 'dashboard/components/CustomSnoozeModal.vue';

let bulkActionInstanceId = 0;

export default {
  components: {
    AgentSelector,
    UpdateActions,
    LabelActions,
    TeamActions,
    CustomSnoozeModal,
  },
  props: {
    conversations: {
      type: Array,
      default: () => [],
    },
    allConversationsSelected: {
      type: Boolean,
      default: false,
    },
    selectedInboxes: {
      type: Array,
      default: () => [],
    },
    showOpenAction: {
      type: Boolean,
      default: false,
    },
    showResolvedAction: {
      type: Boolean,
      default: false,
    },
    showSnoozedAction: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'selectAllConversations',
    'assignAgent',
    'updateConversations',
    'assignLabels',
    'assignTeam',
    'resolveConversations',
  ],
  data() {
    bulkActionInstanceId += 1;
    const instanceId = bulkActionInstanceId;

    return {
      showAgentsList: false,
      showUpdateActions: false,
      showLabelActions: false,
      showTeamsList: false,
      showCustomTimeSnoozeModal: false,
      activeTriggerElement: null,
      menuIds: {
        labels: `bulk-actions-labels-${instanceId}`,
        update: `bulk-actions-update-${instanceId}`,
        agents: `bulk-actions-agents-${instanceId}`,
        teams: `bulk-actions-teams-${instanceId}`,
      },
    };
  },
  mounted() {
    emitter.on(
      CMD_BULK_ACTION_SNOOZE_CONVERSATION,
      this.onCmdSnoozeConversation
    );
    emitter.on(
      CMD_BULK_ACTION_REOPEN_CONVERSATION,
      this.onCmdReopenConversation
    );
    emitter.on(
      CMD_BULK_ACTION_RESOLVE_CONVERSATION,
      this.onCmdResolveConversation
    );
  },
  unmounted() {
    emitter.off(
      CMD_BULK_ACTION_SNOOZE_CONVERSATION,
      this.onCmdSnoozeConversation
    );
    emitter.off(
      CMD_BULK_ACTION_REOPEN_CONVERSATION,
      this.onCmdReopenConversation
    );
    emitter.off(
      CMD_BULK_ACTION_RESOLVE_CONVERSATION,
      this.onCmdResolveConversation
    );
  },
  methods: {
    onCmdSnoozeConversation(snoozeType) {
      if (snoozeType === wootConstants.SNOOZE_OPTIONS.UNTIL_CUSTOM_TIME) {
        this.showCustomTimeSnoozeModal = true;
      } else if (typeof snoozeType === 'number') {
        this.updateConversations('snoozed', snoozeType);
      } else {
        this.updateConversations('snoozed', findSnoozeTime(snoozeType) || null);
      }
    },
    onCmdReopenConversation() {
      this.updateConversations('open', null);
    },
    onCmdResolveConversation() {
      this.updateConversations('resolved', null);
    },
    customSnoozeTime(customSnoozedTime) {
      this.showCustomTimeSnoozeModal = false;
      if (customSnoozedTime) {
        this.updateConversations('snoozed', getUnixTime(customSnoozedTime));
      }
    },
    hideCustomSnoozeModal() {
      this.showCustomTimeSnoozeModal = false;
    },
    selectAll(e) {
      this.$emit('selectAllConversations', e.target.checked);
    },
    submit(agent) {
      this.$emit('assignAgent', agent);
    },
    updateConversations(status, snoozedUntil) {
      this.$emit('updateConversations', status, snoozedUntil);
    },
    assignLabels(labels) {
      this.$emit('assignLabels', labels);
    },
    assignTeam(team) {
      this.$emit('assignTeam', team);
    },
    resolveConversations() {
      this.$emit('resolveConversations');
    },
    setAllMenusClosed() {
      this.showLabelActions = false;
      this.showUpdateActions = false;
      this.showAgentsList = false;
      this.showTeamsList = false;
    },
    toggleActionMenu(menu, event) {
      const stateKeys = {
        labels: 'showLabelActions',
        update: 'showUpdateActions',
        agents: 'showAgentsList',
        teams: 'showTeamsList',
      };
      const stateKey = stateKeys[menu];
      const shouldOpen = stateKey ? !this[stateKey] : false;

      this.setAllMenusClosed();

      if (shouldOpen) {
        this[stateKey] = true;
        this.activeTriggerElement = event.currentTarget;
      } else {
        this.activeTriggerElement = null;
      }
    },
    closeActionMenus({ restoreFocus = true } = {}) {
      const trigger = this.activeTriggerElement;

      this.setAllMenusClosed();
      this.activeTriggerElement = null;

      if (restoreFocus && trigger) {
        this.$nextTick(() => trigger.focus());
      }
    },
  },
};
</script>

<template>
  <div
    class="relative border-b border-ds-border-subtle bg-ds-bg-surface p-3 text-ds-fg-default"
  >
    <div class="flex items-center justify-between gap-2">
      <label class="flex min-w-0 cursor-pointer items-center gap-2">
        <input
          type="checkbox"
          class="checkbox m-0 shrink-0 cursor-pointer accent-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          :checked="allConversationsSelected"
          :indeterminate.prop="!allConversationsSelected"
          @change="selectAll($event)"
        />
        <span class="truncate text-xs font-medium text-ds-fg-muted">
          {{
            $t('BULK_ACTION.CONVERSATIONS_SELECTED', {
              conversationCount: conversations.length,
            })
          }}
        </span>
      </label>
      <div class="flex shrink-0 items-center gap-1">
        <button
          v-tooltip="$t('BULK_ACTION.LABELS.ASSIGN_LABELS')"
          type="button"
          class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          :aria-label="$t('BULK_ACTION.LABELS.ASSIGN_LABELS')"
          aria-haspopup="dialog"
          :aria-expanded="showLabelActions"
          :aria-controls="menuIds.labels"
          @click="toggleActionMenu('labels', $event)"
        >
          <span class="i-lucide-tags size-4" aria-hidden="true" />
        </button>
        <button
          v-tooltip="$t('BULK_ACTION.UPDATE.CHANGE_STATUS')"
          type="button"
          class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          :aria-label="$t('BULK_ACTION.UPDATE.CHANGE_STATUS')"
          aria-haspopup="menu"
          :aria-expanded="showUpdateActions"
          :aria-controls="menuIds.update"
          @click="toggleActionMenu('update', $event)"
        >
          <span class="i-lucide-repeat-2 size-4" aria-hidden="true" />
        </button>
        <button
          v-tooltip="$t('BULK_ACTION.ASSIGN_AGENT_TOOLTIP')"
          type="button"
          class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          :aria-label="$t('BULK_ACTION.ASSIGN_AGENT_TOOLTIP')"
          aria-haspopup="dialog"
          :aria-expanded="showAgentsList"
          :aria-controls="menuIds.agents"
          @click="toggleActionMenu('agents', $event)"
        >
          <span class="i-lucide-user-round-plus size-4" aria-hidden="true" />
        </button>
        <button
          v-tooltip="$t('BULK_ACTION.ASSIGN_TEAM_TOOLTIP')"
          type="button"
          class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          :aria-label="$t('BULK_ACTION.ASSIGN_TEAM_TOOLTIP')"
          aria-haspopup="dialog"
          :aria-expanded="showTeamsList"
          :aria-controls="menuIds.teams"
          @click="toggleActionMenu('teams', $event)"
        >
          <span class="i-lucide-users-round size-4" aria-hidden="true" />
        </button>
      </div>
      <transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="scale-95 opacity-0"
        enter-to-class="scale-100 opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="scale-100 opacity-100"
        leave-to-class="scale-95 opacity-0"
      >
        <LabelActions
          v-if="showLabelActions"
          :id="menuIds.labels"
          class="[--triangle-position:5.3125rem]"
          context-scope="conversation"
          @assign="assignLabels"
          @close="closeActionMenus"
        />
      </transition>
      <transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="scale-95 opacity-0"
        enter-to-class="scale-100 opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="scale-100 opacity-100"
        leave-to-class="scale-95 opacity-0"
      >
        <UpdateActions
          v-if="showUpdateActions"
          :id="menuIds.update"
          class="[--triangle-position:3.5rem]"
          :show-resolve="!showResolvedAction"
          :show-reopen="!showOpenAction"
          :show-snooze="!showSnoozedAction"
          @update="updateConversations"
          @close="closeActionMenus"
        />
      </transition>
      <transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="scale-95 opacity-0"
        enter-to-class="scale-100 opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="scale-100 opacity-100"
        leave-to-class="scale-95 opacity-0"
      >
        <AgentSelector
          v-if="showAgentsList"
          :id="menuIds.agents"
          class="[--triangle-position:1.75rem]"
          :selected-inboxes="selectedInboxes"
          :conversation-count="conversations.length"
          @select="submit"
          @close="closeActionMenus"
        />
      </transition>
      <transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="scale-95 opacity-0"
        enter-to-class="scale-100 opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="scale-100 opacity-100"
        leave-to-class="scale-95 opacity-0"
      >
        <TeamActions
          v-if="showTeamsList"
          :id="menuIds.teams"
          class="[--triangle-position:0.125rem]"
          @assign-team="assignTeam"
          @close="closeActionMenus"
        />
      </transition>
    </div>
    <div
      v-if="allConversationsSelected"
      class="mt-2 rounded-lg border border-ds-state-warning/25 bg-ds-state-warning-soft px-2 py-1.5 text-xs text-ds-state-warning"
      role="status"
    >
      {{ $t('BULK_ACTION.ALL_CONVERSATIONS_SELECTED_ALERT') }}
    </div>
    <woot-modal
      v-model:show="showCustomTimeSnoozeModal"
      :on-close="hideCustomSnoozeModal"
    >
      <CustomSnoozeModal
        @close="hideCustomSnoozeModal"
        @choose-time="customSnoozeTime"
      />
    </woot-modal>
  </div>
</template>

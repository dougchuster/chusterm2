<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import Avatar from 'next/avatar/Avatar.vue';
import MessagePreview from './MessagePreview.vue';
import InboxName from '../InboxName.vue';
import ConversationContextMenu from './contextMenu/Index.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import CardLabels from './conversationCardComponents/CardLabels.vue';
import PriorityMark from './PriorityMark.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  activeLabel: { type: String, default: '' },
  chat: { type: Object, default: () => ({}) },
  hideInboxName: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  teamId: { type: [String, Number], default: 0 },
  foldersId: { type: [String, Number], default: 0 },
  showAssignee: { type: Boolean, default: false },
  conversationType: { type: String, default: '' },
  selected: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
  enableContextMenu: { type: Boolean, default: false },
  allowedContextMenuOptions: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'contextMenuToggle',
  'assignAgent',
  'assignLabel',
  'removeLabel',
  'assignTeam',
  'markAsUnread',
  'markAsRead',
  'assignPriority',
  'updateConversationStatus',
  'deleteConversation',
  'selectConversation',
  'deSelectConversation',
]);

const router = useRouter();
const store = useStore();

const hovered = ref(false);
const showContextMenu = ref(false);
const contextMenu = ref({ x: null, y: null });

// Reset UI state when conversation changes at same index (no :key, instance reused on reorder)
// This prevents context menu/hover state from leaking to a different conversation
// Emit contextMenuToggle(false) to sync parent state if menu was open during recycling
const resetState = () => {
  if (showContextMenu.value) {
    emit('contextMenuToggle', false);
  }
  hovered.value = false;
  showContextMenu.value = false;
  contextMenu.value = { x: null, y: null };
};

watch(() => props.chat.id, resetState);

const currentChat = useMapGetter('getSelectedChat');
const inboxesList = useMapGetter('inboxes/getInboxes');
const activeInbox = useMapGetter('getSelectedInbox');
const accountId = useMapGetter('getCurrentAccountId');

const chatMetadata = computed(() => props.chat.meta || {});

const assignee = computed(() => chatMetadata.value.assignee || {});

const senderId = computed(() => chatMetadata.value.sender?.id);

const currentContact = computed(() => {
  return senderId.value
    ? store.getters['contacts/getContact'](senderId.value)
    : {};
});

const cardAriaLabel = computed(
  () => currentContact.value.name || String(props.chat.id)
);

const isActiveChat = computed(() => {
  return currentChat.value.id === props.chat.id;
});

const unreadCount = computed(() => props.chat.unread_count);

const hasUnread = computed(() => unreadCount.value > 0);
const formattedUnreadCount = computed(() =>
  unreadCount.value > 9 ? `${9}+` : unreadCount.value
);

const isInboxNameVisible = computed(() => !activeInbox.value);

const lastMessageInChat = computed(() => getLastMessage(props.chat));

const voiceCallData = computed(() => ({
  status: props.chat.additional_attributes?.call_status,
  direction: props.chat.additional_attributes?.call_direction,
}));

const inboxId = computed(() => props.chat.inbox_id);

const inbox = computed(() => {
  return inboxId.value ? store.getters['inboxes/getInbox'](inboxId.value) : {};
});

const showInboxName = computed(() => {
  return (
    !props.hideInboxName &&
    isInboxNameVisible.value &&
    inboxesList.value.length > 1
  );
});

const showMetaSection = computed(() => {
  return (
    showInboxName.value ||
    (props.showAssignee && assignee.value.name) ||
    props.chat.priority
  );
});

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

const showLabelsSection = computed(() => {
  return props.chat.labels?.length > 0 || hasSlaPolicyId.value;
});

const messagePreviewClass = computed(() => {
  return hasUnread.value
    ? 'font-medium text-ds-fg-default'
    : 'text-ds-fg-muted';
});

const conversationPath = computed(() => {
  return frontendURL(
    conversationUrl({
      accountId: accountId.value,
      activeInbox: activeInbox.value,
      id: props.chat.id,
      label: props.activeLabel,
      teamId: props.teamId,
      conversationType: props.conversationType,
      foldersId: props.foldersId,
    })
  );
});

const onCardClick = e => {
  const path = conversationPath.value;
  if (!path) return;

  // Handle Ctrl/Cmd + Click for new tab
  if (e.metaKey || e.ctrlKey) {
    e.preventDefault();
    window.open(
      `${window.chustermConfig.hostURL}${path}`,
      '_blank',
      'noopener,noreferrer'
    );
    return;
  }

  // Skip if already active
  if (isActiveChat.value) return;

  router.push({ path });
};

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, inbox.value.id);
  } else {
    emit('deSelectConversation', props.chat.id, inbox.value.id);
  }
};

const openContextMenu = e => {
  if (!props.enableContextMenu) return;
  e.preventDefault();
  emit('contextMenuToggle', true);

  if (e.type === 'keydown') {
    const { left, top } = e.currentTarget.getBoundingClientRect();
    contextMenu.value.x = left + 24;
    contextMenu.value.y = top + 24;
  } else {
    contextMenu.value.x = e.clientX;
    contextMenu.value.y = e.clientY;
  }

  showContextMenu.value = true;
};

const onCardKeydown = e => {
  if (e.key === 'ContextMenu' || (e.shiftKey && e.key === 'F10')) {
    openContextMenu(e);
  }
};

const closeContextMenu = () => {
  emit('contextMenuToggle', false);
  showContextMenu.value = false;
  contextMenu.value.x = null;
  contextMenu.value.y = null;
};

const onUpdateConversation = (status, snoozedUntil) => {
  closeContextMenu();
  emit('updateConversationStatus', props.chat.id, status, snoozedUntil);
};

const onAssignAgent = agent => {
  emit('assignAgent', agent, [props.chat.id]);
  closeContextMenu();
};

const onAssignLabel = label => {
  emit('assignLabel', [label.title], [props.chat.id]);
};

const onRemoveLabel = label => {
  emit('removeLabel', [label.title], [props.chat.id]);
};

const onAssignTeam = team => {
  emit('assignTeam', team, props.chat.id);
  closeContextMenu();
};

const markAsUnread = () => {
  emit('markAsUnread', props.chat.id);
  closeContextMenu();
};

const markAsRead = () => {
  emit('markAsRead', props.chat.id);
  closeContextMenu();
};

const assignPriority = priority => {
  emit('assignPriority', priority, props.chat.id);
  closeContextMenu();
};

const deleteConversation = () => {
  emit('deleteConversation', props.chat.id);
  closeContextMenu();
};
</script>

<template>
  <div
    class="conversation-card conversation group relative mx-1.5 my-0.5 flex w-auto max-w-full flex-none items-start gap-2 rounded-xl bg-transparent transition-[background-color,box-shadow] duration-150"
    :class="{
      'active is-active bg-ds-accent-soft shadow-sm shadow-ds-accent/10':
        isActiveChat,
      'is-selected bg-ds-bg-active hover:bg-ds-bg-active':
        selected && !isActiveChat,
      'hover:bg-ds-bg-hover': !isActiveChat && !selected,
      'px-2 py-2': compact,
      'px-3 py-2.5': !compact,
    }"
  >
    <button
      type="button"
      class="absolute inset-0 z-0 cursor-pointer rounded-xl border-0 bg-transparent outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus focus-visible:ring-offset-1 focus-visible:ring-offset-ds-bg-surface"
      :aria-label="cardAriaLabel"
      :aria-current="isActiveChat ? 'page' : undefined"
      @click="onCardClick"
      @contextmenu="openContextMenu($event)"
      @keydown="onCardKeydown"
    />
    <div
      class="pointer-events-none relative z-10 mt-1 shrink-0"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <Avatar
        v-if="!hideThumbnail"
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="32"
        :status="currentContact.availability_status"
        class="ring-2 ring-ds-accent-soft transition-shadow group-hover:ring-ds-accent/30"
        hide-offline-status
        rounded-full
      >
        <template #overlay>
          <label
            class="pointer-events-auto absolute inset-0 z-10 flex size-full cursor-pointer items-center justify-center rounded-full bg-ds-bg-sunken/70 opacity-0 backdrop-blur-sm transition-opacity group-hover:opacity-100 group-focus-within:opacity-100"
            :class="{ 'opacity-100': selected }"
            :title="
              $t('BULK_ACTION.SELECT_CONVERSATION', {
                name: currentContact.name,
              })
            "
            @click.stop
          >
            <input
              :value="selected"
              :checked="selected"
              :aria-label="
                $t('BULK_ACTION.SELECT_CONVERSATION', {
                  name: currentContact.name,
                })
              "
              class="!m-0 size-4 cursor-pointer rounded border-ds-border-strong bg-ds-bg-sunken text-ds-accent focus:ring-2 focus:ring-ds-border-focus focus:ring-offset-0"
              type="checkbox"
              @change="onSelectConversation($event.target.checked)"
              @keydown.stop
            />
          </label>
        </template>
      </Avatar>
    </div>
    <div class="pointer-events-none relative z-10 min-w-0 flex-1">
      <div
        v-if="showMetaSection"
        class="mb-0.5 flex min-h-4 min-w-0 items-center gap-1.5"
      >
        <InboxName v-if="showInboxName" :inbox="inbox" class="flex-1 min-w-0" />
        <div
          class="flex min-w-0 shrink-0 items-center gap-1.5"
          :class="{
            'flex-1 justify-between': !showInboxName,
          }"
        >
          <span
            v-if="showAssignee && assignee.name"
            class="inline-flex min-w-0 items-center gap-1 truncate text-xs font-medium leading-4 text-ds-fg-muted"
          >
            <Icon
              icon="i-lucide-user-round"
              class="size-3.5 shrink-0 text-ds-fg-subtle"
            />
            <span class="truncate">{{ assignee.name }}</span>
          </span>
          <PriorityMark :priority="chat.priority" class="shrink-0" />
        </div>
      </div>
      <div class="flex min-w-0 items-baseline gap-2">
        <h4
          class="conversation--user my-0 min-w-0 flex-1 truncate text-sm text-ds-fg-default"
          :class="hasUnread ? 'font-semibold' : 'font-medium'"
        >
          {{ currentContact.name }}
        </h4>
        <span
          class="shrink-0 whitespace-nowrap text-xs font-normal leading-4 text-ds-fg-subtle"
        >
          <TimeAgo
            :last-activity-timestamp="chat.timestamp"
            :created-at-timestamp="chat.created_at"
            :conversation-id="chat.id"
          />
        </span>
      </div>
      <div class="mt-0.5 flex h-5 min-w-0 items-center gap-2">
        <VoiceCallStatus
          v-if="voiceCallData.status"
          key="voice-status-row"
          class="!mx-0 !h-5 !leading-5"
          :status="voiceCallData.status"
          :direction="voiceCallData.direction"
          :message-preview-class="messagePreviewClass"
        />
        <MessagePreview
          v-else-if="lastMessageInChat"
          key="message-preview"
          :message="lastMessageInChat"
          class="min-w-0 flex-1 text-sm leading-5"
          :class="messagePreviewClass"
        />
        <p
          v-else
          key="no-messages"
          class="my-0 flex min-w-0 flex-1 items-center gap-1 overflow-hidden text-ellipsis whitespace-nowrap text-sm leading-5"
          :class="messagePreviewClass"
        >
          <Icon
            icon="i-lucide-message-circle-off"
            class="size-3.5 shrink-0 text-ds-fg-subtle"
          />
          <span class="truncate">
            {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
          </span>
        </p>
        <span
          v-if="hasUnread"
          class="inline-flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-ds-state-info px-1.5 text-xs font-bold leading-none text-ds-fg-on-accent shadow-sm"
        >
          {{ formattedUnreadCount }}
        </span>
      </div>
      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="mb-0 mt-1.5"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
    <ContextMenu
      v-if="showContextMenu"
      :x="contextMenu.x"
      :y="contextMenu.y"
      @close="closeContextMenu"
    >
      <ConversationContextMenu
        :status="chat.status"
        :inbox-id="inbox.id"
        :priority="chat.priority"
        :chat-id="chat.id"
        :has-unread-messages="hasUnread"
        :conversation-labels="chat.labels"
        :conversation-url="conversationPath"
        :allowed-options="allowedContextMenuOptions"
        @update-conversation="onUpdateConversation"
        @assign-agent="onAssignAgent"
        @assign-label="onAssignLabel"
        @remove-label="onRemoveLabel"
        @assign-team="onAssignTeam"
        @mark-as-unread="markAsUnread"
        @mark-as-read="markAsRead"
        @assign-priority="assignPriority"
        @delete-conversation="deleteConversation"
        @close="closeContextMenu"
      />
    </ContextMenu>
  </div>
</template>

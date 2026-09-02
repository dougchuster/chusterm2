<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);
</script>

<template>
  <header
    ref="conversationHeader"
    class="flex min-h-14 w-full min-w-0 flex-wrap items-center justify-between gap-x-4 gap-y-2 bg-ds-bg-elevated/95 px-3 py-2 shadow-[var(--ds-shadow-xs)] backdrop-blur md:px-4 xl:flex-nowrap"
  >
    <div class="flex min-w-0 flex-1 basis-48 items-center">
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        compact
        class="shrink-0 ltr:mr-2 rtl:ml-2"
      />
      <Avatar
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="36"
        :status="currentContact.availability_status"
        hide-offline-status
        rounded-full
      />
      <div
        class="flex min-w-0 flex-col items-start overflow-hidden ltr:ml-2.5 rtl:mr-2.5"
      >
        <div class="flex max-w-full items-center gap-1.5">
          <span
            class="truncate font-manrope text-sm font-semibold leading-5 text-ds-fg-default"
          >
            {{ currentContact.name }}
          </span>
          <span
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            role="img"
            :aria-label="$t('CONVERSATION.UNVERIFIED_SESSION')"
            class="grid size-4 shrink-0 place-items-center text-ds-state-warning"
          >
            <i class="i-lucide-triangle-alert size-3.5" aria-hidden="true" />
          </span>
        </div>

        <div
          class="conversation--header--actions flex min-h-4 max-w-full items-center gap-2 overflow-hidden text-ellipsis whitespace-nowrap text-xs text-ds-fg-muted"
        >
          <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          <span
            v-if="isSnoozed"
            role="status"
            class="truncate font-medium text-ds-state-warning"
          >
            {{ snoozedDisplayText }}
          </span>
        </div>
      </div>
    </div>
    <div
      class="header-actions-wrap flex shrink-0 items-center gap-2 ltr:ml-auto rtl:mr-auto"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden lg:flex"
      />
      <MoreActions :conversation-id="currentChat.id" />
    </div>
  </header>
</template>

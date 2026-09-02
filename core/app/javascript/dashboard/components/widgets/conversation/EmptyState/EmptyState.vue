<script>
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import OnboardingView from '../OnboardingView.vue';
import EmptyStateMessage from './EmptyStateMessage.vue';

export default {
  components: {
    OnboardingView,
    EmptyStateMessage,
  },
  props: {
    isOnExpandedLayout: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const { isAdmin } = useAdmin();

    const { accountScopedUrl } = useAccount();

    return {
      isAdmin,
      accountScopedUrl,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      allConversations: 'getAllConversations',
      inboxesList: 'inboxes/getInboxes',
      uiFlags: 'inboxes/getUIFlags',
      loadingChatList: 'getChatListLoadingStatus',
    }),
    loadingIndicatorMessage() {
      if (this.uiFlags.isFetching) {
        return this.$t('CONVERSATION.LOADING_INBOXES');
      }
      return this.$t('CONVERSATION.LOADING_CONVERSATIONS');
    },
    conversationMissingMessage() {
      if (!this.isOnExpandedLayout) {
        return this.$t('CONVERSATION.SELECT_A_CONVERSATION');
      }
      return this.$t('CONVERSATION.404');
    },
    newInboxURL() {
      return this.accountScopedUrl('settings/inboxes/new');
    },
    settingsInboxURL() {
      return this.accountScopedUrl('settings/inboxes');
    },
    hasConversations() {
      return this.allConversations.length > 0;
    },
    editorialTitle() {
      if (!this.hasConversations) {
        return this.$t('CONVERSATION.EDITORIAL_EMPTY.NO_MESSAGES_TITLE');
      }

      return this.$t('CONVERSATION.EDITORIAL_EMPTY.SELECT_TITLE');
    },
    editorialDescription() {
      if (!this.hasConversations) {
        return this.$t('CONVERSATION.EDITORIAL_EMPTY.NO_MESSAGES_DESCRIPTION');
      }

      return this.$t('CONVERSATION.EDITORIAL_EMPTY.SELECT_DESCRIPTION');
    },
    editorialActionLabel() {
      if (!this.hasConversations && this.isAdmin) {
        return this.$t('CONVERSATION.EDITORIAL_EMPTY.ACTION_SETUP');
      }

      return this.$t('CONVERSATION.EDITORIAL_EMPTY.ACTION_INBOXES');
    },
    editorialActionUrl() {
      if (!this.hasConversations && this.isAdmin) {
        return this.newInboxURL;
      }

      return this.settingsInboxURL;
    },
    emptyClassName() {
      if (
        !this.inboxesList.length &&
        !this.uiFlags.isFetching &&
        !this.loadingChatList &&
        this.isAdmin
      ) {
        return 'h-full overflow-auto w-full';
      }
      return 'flex-1 min-w-0 px-0 flex flex-col items-center justify-center h-full bg-ds-bg-surface';
    },
  },
};
</script>

<template>
  <div :class="emptyClassName">
    <woot-loading-state
      v-if="uiFlags.isFetching || loadingChatList"
      :message="loadingIndicatorMessage"
    />
    <!-- No inboxes attached -->
    <div
      v-if="!inboxesList.length && !uiFlags.isFetching && !loadingChatList"
      class="clearfix mx-auto"
    >
      <OnboardingView v-if="isAdmin" />
      <EmptyStateMessage v-else :message="$t('CONVERSATION.NO_INBOX_AGENT')" />
    </div>
    <!-- Show empty state images if not loading -->

    <div
      v-else-if="!uiFlags.isFetching && !loadingChatList"
      class="flex h-full w-full items-center justify-center overflow-auto px-4 py-5 sm:px-6 lg:px-8"
    >
      <section
        v-if="!currentChat.id"
        class="conversation-empty-state flex w-full max-w-md flex-col items-center rounded-xl border border-ds-border-subtle bg-ds-bg-elevated px-5 py-8 text-center shadow-[var(--ds-shadow-sm)] sm:px-7"
      >
        <div
          class="grid size-12 place-items-center rounded-full bg-ds-accent-soft text-ds-accent"
          aria-hidden="true"
        >
          <span class="i-lucide-messages-square size-5" />
        </div>
        <h2
          class="mb-0 mt-4 text-xl font-semibold leading-7 text-ds-fg-default"
        >
          {{ editorialTitle }}
        </h2>
        <p class="mb-0 mt-2 max-w-sm text-sm leading-6 text-ds-fg-muted">
          {{ editorialDescription }}
        </p>
        <span
          class="mt-4 inline-flex min-h-9 items-center rounded-lg bg-ds-bg-active px-3 text-xs font-medium text-ds-fg-muted"
        >
          {{ conversationMissingMessage }}
        </span>
        <a
          v-if="!hasConversations"
          :href="editorialActionUrl"
          class="mt-5 inline-flex h-10 items-center justify-center rounded-lg bg-ds-accent px-4 text-sm font-semibold text-ds-fg-on-accent transition-colors hover:bg-ds-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus focus-visible:ring-offset-2 focus-visible:ring-offset-ds-bg-elevated"
        >
          {{ editorialActionLabel }}
        </a>
      </section>
    </div>
  </div>
</template>

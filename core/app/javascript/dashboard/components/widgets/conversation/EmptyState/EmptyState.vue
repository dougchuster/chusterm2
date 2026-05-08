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
    editorialStats() {
      return [
        {
          label: this.$t('CONVERSATION.EDITORIAL_EMPTY.STATS.INBOXES'),
          value: this.inboxesList.length,
        },
        {
          label: this.$t('CONVERSATION.EDITORIAL_EMPTY.STATS.CONVERSATIONS'),
          value: this.allConversations.length,
        },
      ];
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
      return 'flex-1 min-w-0 px-0 flex flex-col items-center justify-center h-full bg-n-surface-1';
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
        class="conversation-empty-state relative w-full max-w-5xl overflow-hidden rounded-lg border border-n-weak bg-n-surface-2 px-5 py-6 shadow-sm sm:px-7 sm:py-8 lg:px-8"
      >
        <div class="relative z-10 grid gap-6 lg:grid-cols-[minmax(0,1.45fr)_minmax(14rem,0.75fr)] lg:items-end">
          <div class="min-w-0">
            <span class="inline-flex rounded-md bg-n-solid-3 px-3 py-1.5 text-[10px] font-bold uppercase tracking-[0.16em] text-n-slate-10">
              {{ $t('CONVERSATION.EDITORIAL_EMPTY.EYEBROW') }}
            </span>
            <h2 class="mt-4 max-w-[18ch] text-2xl font-bold leading-tight text-n-slate-12 sm:text-3xl lg:text-4xl">
              {{ editorialTitle }}
            </h2>
            <p class="mt-3 max-w-2xl text-sm leading-6 text-n-slate-10 sm:text-base">
              {{ editorialDescription }}
            </p>

            <div class="mt-6 flex flex-wrap gap-2">
              <a
                :href="editorialActionUrl"
                class="inline-flex h-10 items-center justify-center rounded-lg bg-n-brand px-4 text-sm font-semibold text-white transition hover:bg-n-brand/90"
              >
                {{ editorialActionLabel }}
              </a>
              <span class="inline-flex min-h-10 items-center rounded-lg bg-n-solid-3 px-3 text-xs font-semibold uppercase tracking-[0.12em] text-n-slate-10">
                {{ conversationMissingMessage }}
              </span>
            </div>
          </div>

          <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-1">
            <article
              v-for="stat in editorialStats"
              :key="stat.label"
              class="rounded-lg bg-n-surface-1 p-4"
            >
              <span class="text-[10px] font-bold uppercase tracking-[0.16em] text-n-slate-10">
                {{ stat.label }}
              </span>
              <p class="mt-2 text-3xl font-bold text-n-slate-12">
                {{ stat.value }}
              </p>
            </article>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

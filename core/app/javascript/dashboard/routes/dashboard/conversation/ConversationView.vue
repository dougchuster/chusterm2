<script>
import { computed } from 'vue';
import { mapGetters } from 'vuex';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useCockpitResize } from 'dashboard/composables/useCockpitResize';
import ChatList from '../../../components/ChatList.vue';
import ConversationBox from '../../../components/widgets/conversation/ConversationBox.vue';
import wootConstants from 'dashboard/constants/globals';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import CmdBarConversationSnooze from 'dashboard/routes/dashboard/commands/CmdBarConversationSnooze.vue';
import { emitter } from 'shared/helpers/mitt';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import ConversationSidebar from 'dashboard/components/widgets/conversation/ConversationSidebar.vue';
import { useWindowSize } from '@vueuse/core';
import { shouldCloseContactSidebarOnConversationOpen } from './conversationPanelHelper';

export default {
  components: {
    ChatList,
    ConversationBox,
    CmdBarConversationSnooze,
    SidepanelSwitch,
    ConversationSidebar,
  },
  beforeRouteLeave(to, from, next) {
    // Clear selected state if navigating away from a conversation to a route without a conversationId to prevent stale data issues
    // and resolves timing issues during navigation with conversation view and other screens
    if (this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
    next(); // Continue with navigation
  },
  props: {
    inboxId: {
      type: [String, Number],
      default: 0,
    },
    conversationId: {
      type: [String, Number],
      default: 0,
    },
    label: {
      type: String,
      default: '',
    },
    teamId: {
      type: String,
      default: '',
    },
    conversationType: {
      type: String,
      default: '',
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
  },
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();
    const { width: windowWidth } = useWindowSize();
    const {
      conversationListWidth,
      contactSidebarWidth,
      isResizingList,
      isResizingSidebar,
      onListResizeStart,
      onSidebarResizeStart,
      onListResizeKeydown,
      onSidebarResizeKeydown,
      resetListWidth,
      resetSidebarWidth,
      MIN_LIST_WIDTH,
      MAX_LIST_WIDTH,
      MIN_SIDEBAR_WIDTH,
      MAX_SIDEBAR_WIDTH,
    } = useCockpitResize();

    const isStaticSidebar = computed(() => windowWidth.value >= 1440);

    return {
      uiSettings,
      updateUISettings,
      windowWidth,
      conversationListWidth,
      contactSidebarWidth,
      isResizingList,
      isResizingSidebar,
      onListResizeStart,
      onSidebarResizeStart,
      onListResizeKeydown,
      onSidebarResizeKeydown,
      resetListWidth,
      resetSidebarWidth,
      MIN_LIST_WIDTH,
      MAX_LIST_WIDTH,
      MIN_SIDEBAR_WIDTH,
      MAX_SIDEBAR_WIDTH,
      isStaticSidebar,
    };
  },
  computed: {
    ...mapGetters({
      chatList: 'getAllConversations',
      currentChat: 'getSelectedChat',
    }),
    showConversationList() {
      return this.isOnExpandedLayout ? !this.conversationId : true;
    },
    showMessageView() {
      return this.conversationId ? true : !this.isOnExpandedLayout;
    },
    isOnExpandedLayout() {
      const {
        LAYOUT_TYPES: { CONDENSED },
      } = wootConstants;
      const { conversation_display_type: conversationDisplayType = CONDENSED } =
        this.uiSettings;
      return conversationDisplayType !== CONDENSED;
    },

    shouldShowSidebar() {
      if (!this.currentChat.id) {
        return false;
      }

      const {
        is_contact_sidebar_open: isContactSidebarOpen,
        is_copilot_panel_open: isCopilotPanelOpen,
      } = this.uiSettings;
      return isContactSidebarOpen || isCopilotPanelOpen;
    },
  },
  watch: {
    conversationId(newConversationId) {
      this.closePersistedMobileSidebar(newConversationId);
      this.fetchConversationIfUnavailable();
    },
  },

  created() {
    // Clear selected state early if no conversation is selected
    // This prevents child components from accessing stale data
    // and resolves timing issues during navigation
    // with conversation view and other screens
    if (!this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    } else {
      this.closePersistedMobileSidebar(this.conversationId);
    }
  },

  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('portals/index');
    this.initialize();
    this.$watch('$store.state.route', () => this.initialize());
    this.$watch('chatList.length', () => {
      this.setActiveChat();
    });
  },

  methods: {
    closePersistedMobileSidebar(conversationId) {
      if (
        !shouldCloseContactSidebarOnConversationOpen({
          conversationId,
          isContactSidebarOpen: this.uiSettings.is_contact_sidebar_open,
          windowWidth: this.windowWidth,
        })
      ) {
        return;
      }

      this.updateUISettings({
        is_contact_sidebar_open: false,
        is_copilot_panel_open: false,
      });
    },
    onConversationLoad() {
      this.fetchConversationIfUnavailable();
    },
    initialize() {
      this.$store.dispatch('setActiveInbox', this.inboxId);
      this.setActiveChat();
    },
    toggleConversationLayout() {
      const { LAYOUT_TYPES } = wootConstants;
      const {
        conversation_display_type:
          conversationDisplayType = LAYOUT_TYPES.CONDENSED,
      } = this.uiSettings;
      const newViewType =
        conversationDisplayType === LAYOUT_TYPES.CONDENSED
          ? LAYOUT_TYPES.EXPANDED
          : LAYOUT_TYPES.CONDENSED;
      this.updateUISettings({
        conversation_display_type: newViewType,
        previously_used_conversation_display_type: newViewType,
      });
    },
    fetchConversationIfUnavailable() {
      if (!this.conversationId) {
        return;
      }
      const chat = this.findConversation();
      if (!chat) {
        this.$store.dispatch('getConversation', this.conversationId);
      }
    },
    findConversation() {
      const conversationId = parseInt(this.conversationId, 10);
      const [chat] = this.chatList.filter(c => c.id === conversationId);
      return chat;
    },
    setActiveChat() {
      if (this.conversationId) {
        const selectedConversation = this.findConversation();
        // If conversation doesn't exist or selected conversation is same as the active
        // conversation, don't set active conversation.
        if (
          !selectedConversation ||
          selectedConversation.id === this.currentChat.id
        ) {
          return;
        }
        const { messageId } = this.$route.query;
        this.$store
          .dispatch('setActiveChat', {
            data: selectedConversation,
            after: messageId,
          })
          .then(() => {
            emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId });
          });
      } else {
        this.$store.dispatch('clearSelectedState');
      }
    },
  },
};
</script>

<template>
  <section
    class="conversation-view-shell flex h-full w-full min-w-0 bg-ds-bg-canvas p-1.5 sm:p-2 lg:p-3"
  >
    <div
      class="conversation-view-frame relative isolate flex min-h-0 w-full min-w-0 flex-1 overflow-hidden rounded-xl bg-ds-bg-surface shadow-[var(--ds-shadow-sm)]"
    >
      <ChatList
        :show-conversation-list="showConversationList"
        :conversation-inbox="inboxId"
        :label="label"
        :team-id="teamId"
        :conversation-type="conversationType"
        :folders-id="foldersId"
        :is-on-expanded-layout="isOnExpandedLayout"
        :custom-width="isOnExpandedLayout ? undefined : conversationListWidth"
        @conversation-load="onConversationLoad"
      />
      <div
        v-if="!isOnExpandedLayout && showConversationList && showMessageView"
        class="group relative z-30 hidden w-2 -ml-1 -mr-1 cursor-col-resize select-none sm:block focus-visible:outline-none"
        role="separator"
        aria-orientation="vertical"
        tabindex="0"
        :aria-label="$t('CONVERSATION.RESIZE.RESIZE_LIST')"
        :aria-valuemin="MIN_LIST_WIDTH"
        :aria-valuemax="MAX_LIST_WIDTH"
        :aria-valuenow="Math.round(conversationListWidth)"
        @mousedown="onListResizeStart"
        @touchstart="onListResizeStart"
        @dblclick="resetListWidth"
        @keydown="onListResizeKeydown"
      >
        <div
          class="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-ds-border-subtle transition-colors group-hover:bg-ds-accent group-focus-visible:bg-ds-border-focus"
          :class="{ '!bg-ds-accent': isResizingList }"
        />
      </div>
      <ConversationBox
        v-if="showMessageView"
        :inbox-id="inboxId"
        :is-on-expanded-layout="isOnExpandedLayout"
      >
        <SidepanelSwitch v-if="currentChat.id" />
      </ConversationBox>
      <div
        v-if="shouldShowSidebar && isStaticSidebar"
        class="group relative z-30 hidden w-2 -ml-1 -mr-1 cursor-col-resize select-none min-[1440px]:block focus-visible:outline-none"
        role="separator"
        aria-orientation="vertical"
        tabindex="0"
        :aria-label="$t('CONVERSATION.RESIZE.RESIZE_SIDEBAR')"
        :aria-valuemin="MIN_SIDEBAR_WIDTH"
        :aria-valuemax="MAX_SIDEBAR_WIDTH"
        :aria-valuenow="Math.round(contactSidebarWidth)"
        @mousedown="onSidebarResizeStart"
        @touchstart="onSidebarResizeStart"
        @dblclick="resetSidebarWidth"
        @keydown="onSidebarResizeKeydown"
      >
        <div
          class="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-ds-border-subtle transition-colors group-hover:bg-ds-accent group-focus-visible:bg-ds-border-focus"
          :class="{ '!bg-ds-accent': isResizingSidebar }"
        />
      </div>
      <ConversationSidebar
        v-if="shouldShowSidebar"
        :current-chat="currentChat"
        :custom-width="contactSidebarWidth"
      />
      <CmdBarConversationSnooze />
    </div>
  </section>
</template>

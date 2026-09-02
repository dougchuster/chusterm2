<script>
import { ref } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useTrack } from 'dashboard/composables';
import { vOnClickOutside } from '@vueuse/components';
import { REPLY_EDITOR_MODES, CHAR_LENGTH_WARNING } from './constants';
import { CAPTAIN_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EditorModeToggle from './EditorModeToggle.vue';
import CopilotMenuBar from './CopilotMenuBar.vue';

export default {
  name: 'ReplyTopPanel',
  components: {
    NextButton,
    EditorModeToggle,
    CopilotMenuBar,
  },
  directives: {
    OnClickOutside: vOnClickOutside,
  },
  props: {
    mode: {
      type: String,
      default: REPLY_EDITOR_MODES.REPLY,
    },
    isReplyRestricted: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      default: null,
    },
    isMessageLengthReachingThreshold: {
      type: Boolean,
      default: () => false,
    },
    charactersRemaining: {
      type: Number,
      default: () => 0,
    },
    editorContent: {
      type: String,
      default: undefined,
    },
    popoutReplyBox: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['setReplyMode', 'togglePopout', 'executeCopilotAction'],
  setup(props, { emit }) {
    const setReplyMode = mode => {
      emit('setReplyMode', mode);
    };
    const handleReplyClick = () => {
      if (props.isReplyRestricted) return;
      setReplyMode(REPLY_EDITOR_MODES.REPLY);
    };
    const handleNoteClick = () => {
      setReplyMode(REPLY_EDITOR_MODES.NOTE);
    };
    const { captainTasksEnabled } = useCaptain();
    const showCopilotMenu = ref(false);

    const handleCopilotAction = (actionKey, data) => {
      emit('executeCopilotAction', actionKey, data || props.editorContent);
      showCopilotMenu.value = false;
    };

    const toggleCopilotMenu = () => {
      const isOpening = !showCopilotMenu.value;
      if (isOpening) {
        useTrack(CAPTAIN_EVENTS.EDITOR_AI_MENU_OPENED, {
          conversationId: props.conversationId,
          entryPoint: 'top_panel',
        });
      }
      showCopilotMenu.value = isOpening;
    };

    const handleClickOutside = () => {
      showCopilotMenu.value = false;
    };

    const keyboardEvents = {
      'Alt+KeyP': {
        action: () => handleNoteClick(),
        allowOnFocusedInput: true,
      },
      'Alt+KeyL': {
        action: () => handleReplyClick(),
        allowOnFocusedInput: true,
      },
    };
    useKeyboardEvents(keyboardEvents);

    return {
      setReplyMode,
      handleReplyClick,
      handleNoteClick,
      REPLY_EDITOR_MODES,
      captainTasksEnabled,
      handleCopilotAction,
      showCopilotMenu,
      toggleCopilotMenu,
      handleClickOutside,
    };
  },
  computed: {
    charLengthClass() {
      return this.charactersRemaining < 0
        ? 'text-ds-state-danger'
        : 'text-ds-fg-muted';
    },
    characterLengthWarning() {
      return this.charactersRemaining < 0
        ? `${-this.charactersRemaining} ${CHAR_LENGTH_WARNING.NEGATIVE}`
        : `${this.charactersRemaining} ${CHAR_LENGTH_WARNING.UNDER_50}`;
    },
  },
};
</script>

<template>
  <div class="flex min-h-11 items-center justify-between gap-2 px-2.5 py-1.5">
    <EditorModeToggle
      :mode="mode"
      :disabled="disabled"
      :is-reply-restricted="isReplyRestricted"
      @set-mode="setReplyMode"
    />
    <div class="flex min-w-0 flex-1 items-center justify-end">
      <div
        v-if="isMessageLengthReachingThreshold"
        role="status"
        aria-live="polite"
        class="truncate text-xs"
      >
        <span :class="charLengthClass">
          {{ characterLengthWarning }}
        </span>
      </div>
    </div>
    <div class="flex shrink-0 items-center gap-1">
      <div v-if="captainTasksEnabled" class="relative">
        <NextButton
          v-tooltip.top-end="$t('CONVERSATION.SIDEBAR.COPILOT')"
          type="button"
          :variant="showCopilotMenu ? 'faded' : 'ghost'"
          color="tertiary"
          :disabled="disabled || isEditorDisabled"
          sm
          icon="i-lucide-sparkles"
          :aria-label="$t('CONVERSATION.SIDEBAR.COPILOT')"
          :aria-pressed="showCopilotMenu"
          @click="toggleCopilotMenu"
        />
        <CopilotMenuBar
          v-if="showCopilotMenu"
          v-on-click-outside="handleClickOutside"
          :has-selection="false"
          :editor-content="editorContent"
          :conversation-id="conversationId"
          class="ltr:right-0 rtl:left-0 bottom-full mb-2"
          @execute-copilot-action="handleCopilotAction"
        />
      </div>
      <NextButton
        v-tooltip.top-end="
          popoutReplyBox
            ? $t('CONVERSATION.REPLYBOX.COLLAPSE_EDITOR')
            : $t('CONVERSATION.REPLYBOX.EXPAND_EDITOR')
        "
        type="button"
        variant="ghost"
        color="slate"
        sm
        :icon="popoutReplyBox ? 'i-lucide-minimize-2' : 'i-lucide-maximize-2'"
        :aria-label="
          popoutReplyBox
            ? $t('CONVERSATION.REPLYBOX.COLLAPSE_EDITOR')
            : $t('CONVERSATION.REPLYBOX.EXPAND_EDITOR')
        "
        :aria-pressed="popoutReplyBox"
        @click="$emit('togglePopout')"
      />
    </div>
  </div>
</template>

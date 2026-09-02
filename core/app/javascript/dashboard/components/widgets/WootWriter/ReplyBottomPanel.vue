<script>
import { ref } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import FileUpload from 'vue-upload-component';
import * as ActiveStorage from 'activestorage';
import inboxMixin from 'shared/mixins/inboxMixin';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { getAllowedFileTypesByChannel } from '@ChusteRM/utils';
import { ALLOWED_FILE_TYPES } from 'shared/constants/messages';
import VideoCallButton from '../VideoCallButton.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { mapGetters } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  name: 'ReplyBottomPanel',
  components: { NextButton, FileUpload, VideoCallButton },
  mixins: [inboxMixin],
  props: {
    isNote: {
      type: Boolean,
      default: false,
    },
    onSend: {
      type: Function,
      default: () => {},
    },
    sendButtonText: {
      type: String,
      default: '',
    },
    recordingAudioDurationText: {
      type: String,
      default: '00:00',
    },
    // inbox prop is used in /mixins/inboxMixin,
    // remove this props when refactoring to composable if not needed
    // eslint-disable-next-line vue/no-unused-properties
    inbox: {
      type: Object,
      default: () => ({}),
    },
    showFileUpload: {
      type: Boolean,
      default: false,
    },
    showAudioRecorder: {
      type: Boolean,
      default: false,
    },
    onFileUpload: {
      type: Function,
      default: () => {},
    },
    toggleEmojiPicker: {
      type: Function,
      default: () => {},
    },
    showEmojiPicker: {
      type: Boolean,
      default: false,
    },
    toggleAudioRecorder: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorderPlayPause: {
      type: Function,
      default: () => {},
    },
    isRecordingAudio: {
      type: Boolean,
      default: false,
    },
    recordingAudioState: {
      type: String,
      default: '',
    },
    isSendDisabled: {
      type: Boolean,
      default: false,
    },
    isOnPrivateNote: {
      type: Boolean,
      default: false,
    },
    enableMultipleFileUpload: {
      type: Boolean,
      default: true,
    },
    enableWhatsAppTemplates: {
      type: Boolean,
      default: false,
    },
    enableContentTemplates: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      required: true,
    },
    // eslint-disable-next-line vue/no-unused-properties
    message: {
      type: String,
      default: '',
    },
    newConversationModalActive: {
      type: Boolean,
      default: false,
    },
    portalSlug: {
      type: String,
      required: true,
    },
    conversationType: {
      type: String,
      default: '',
    },
    showQuotedReplyToggle: {
      type: Boolean,
      default: false,
    },
    quotedReplyEnabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'replaceText',
    'toggleInsertArticle',
    'selectWhatsappTemplate',
    'selectContentTemplate',
    'toggleQuotedReply',
  ],
  setup(props) {
    const { setSignatureFlagForInbox, fetchSignatureFlagFromUISettings } =
      useUISettings();

    const uploadRef = ref(false);

    const keyboardEvents = {
      '$mod+Alt+KeyA': {
        action: () => {
          // Skip if editor is disabled (e.g., WhatsApp 24-hour window expired)
          if (props.isEditorDisabled) return;

          // TODO: This is really hacky, we need to replace the file picker component with
          // a custom one, where the logic and the component markup is isolated.
          // Once we have the custom component, we can remove the hacky logic below.

          const uploadTriggerButton = document.querySelector(
            '#conversationAttachment'
          );
          if (uploadTriggerButton) uploadTriggerButton.click();
        },
        allowOnFocusedInput: true,
      },
    };

    useKeyboardEvents(keyboardEvents);

    return {
      setSignatureFlagForInbox,
      fetchSignatureFlagFromUISettings,
      uploadRef,
    };
  },
  data() {
    return {
      ALLOWED_FILE_TYPES,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      uiFlags: 'integrations/getUIFlags',
    }),
    wrapClass() {
      return {
        'is-note-mode': this.isNote,
      };
    },
    showAttachButton() {
      if (this.isEditorDisabled) return false;
      return this.showFileUpload || this.isNote;
    },
    showAudioRecorderButton() {
      if (this.isEditorDisabled) return false;
      if (this.isALineChannel || this.isATiktokChannel) {
        return false;
      }
      // Disable audio recorder for safari browser as recording is not supported
      // const isSafari = /^((?!chrome|android|crios|fxios).)*safari/i.test(
      //   navigator.userAgent
      // );

      return (
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.VOICE_RECORDER
        ) && this.showAudioRecorder
        // !isSafari
      );
    },
    showAudioPlayStopButton() {
      if (this.isEditorDisabled) return false;
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isInstagramDM() {
      return this.conversationType === 'instagram_direct_message';
    },
    allowedFileTypes() {
      // Use default file types for private notes
      if (this.isOnPrivateNote) {
        return this.ALLOWED_FILE_TYPES;
      }

      let channelType = this.channelType || this.inbox?.channel_type;

      if (this.isAnInstagramChannel || this.isInstagramDM) {
        channelType = INBOX_TYPES.INSTAGRAM;
      }

      return getAllowedFileTypesByChannel({
        channelType,
        medium: this.inbox?.medium,
      });
    },
    enableDragAndDrop() {
      return !this.newConversationModalActive;
    },
    audioRecorderPlayStopIcon() {
      switch (this.recordingAudioState) {
        // playing paused recording stopped inactive destroyed
        case 'playing':
          return 'i-lucide-pause';
        case 'paused':
          return 'i-lucide-play';
        case 'stopped':
          return 'i-lucide-play';
        default:
          return 'i-lucide-square';
      }
    },
    audioRecorderTooltip() {
      return this.isRecordingAudio
        ? this.$t('CONVERSATION.REPLYBOX.STOP_AUDIO_RECORDING')
        : this.$t('CONVERSATION.REPLYBOX.START_AUDIO_RECORDING');
    },
    audioPlaybackTooltip() {
      return ['paused', 'stopped'].includes(this.recordingAudioState)
        ? this.$t('CONVERSATION.REPLYBOX.PLAY_AUDIO')
        : this.$t('CONVERSATION.REPLYBOX.PAUSE_AUDIO');
    },
    showMessageSignatureButton() {
      if (this.isEditorDisabled) return false;
      return !this.isOnPrivateNote;
    },
    sendWithSignature() {
      // channelType is sourced from inboxMixin
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    signatureToggleTooltip() {
      return this.sendWithSignature
        ? this.$t('CONVERSATION.FOOTER.DISABLE_SIGN_TOOLTIP')
        : this.$t('CONVERSATION.FOOTER.ENABLE_SIGN_TOOLTIP');
    },
    enableInsertArticleInReply() {
      return this.portalSlug;
    },
    isFetchingAppIntegrations() {
      return this.uiFlags.isFetching;
    },
    quotedReplyToggleTooltip() {
      return this.quotedReplyEnabled
        ? this.$t('CONVERSATION.REPLYBOX.QUOTED_REPLY.DISABLE_TOOLTIP')
        : this.$t('CONVERSATION.REPLYBOX.QUOTED_REPLY.ENABLE_TOOLTIP');
    },
  },
  mounted() {
    ActiveStorage.start();
  },
  methods: {
    toggleMessageSignature() {
      this.setSignatureFlagForInbox(this.channelType, !this.sendWithSignature);
    },
    replaceText(text) {
      this.$emit('replaceText', text);
    },
    toggleInsertArticle() {
      this.$emit('toggleInsertArticle');
    },
  },
};
</script>

<template>
  <div
    class="flex flex-wrap items-center justify-between gap-2 px-3 pb-3 pt-2"
    :class="wrapClass"
  >
    <div class="flex min-w-0 flex-1 flex-wrap items-center gap-1">
      <NextButton
        v-if="!isEditorDisabled"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
        type="button"
        icon="i-lucide-smile"
        color="slate"
        :variant="showEmojiPicker ? 'solid' : 'faded'"
        sm
        :aria-label="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
        :aria-pressed="showEmojiPicker"
        @click="toggleEmojiPicker"
      />
      <FileUpload
        v-if="showAttachButton"
        ref="uploadRef"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
        class="group/file-upload"
        input-id="conversationAttachment"
        :size="4096 * 4096"
        :accept="allowedFileTypes"
        :multiple="enableMultipleFileUpload"
        :drop="enableDragAndDrop"
        :drop-directory="false"
        :data="{
          direct_upload_url: '/rails/active_storage/direct_uploads',
          direct_upload: true,
        }"
        @input-file="onFileUpload"
      >
        <NextButton
          v-if="showAttachButton"
          v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
          type="button"
          icon="i-lucide-paperclip"
          color="slate"
          variant="faded"
          sm
          class="transition-colors group-hover/file-upload:bg-ds-bg-hover"
          :aria-label="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
        />
      </FileUpload>
      <NextButton
        v-if="showAudioRecorderButton"
        v-tooltip.top-end="audioRecorderTooltip"
        type="button"
        :icon="!isRecordingAudio ? 'i-lucide-mic' : 'i-lucide-mic-off'"
        color="slate"
        :variant="isRecordingAudio ? 'solid' : 'faded'"
        sm
        :aria-label="audioRecorderTooltip"
        :aria-pressed="isRecordingAudio"
        @click="toggleAudioRecorder"
      />
      <NextButton
        v-if="showAudioPlayStopButton"
        v-tooltip.top-end="audioPlaybackTooltip"
        type="button"
        :icon="audioRecorderPlayStopIcon"
        color="slate"
        variant="faded"
        sm
        :label="recordingAudioDurationText"
        :aria-label="audioPlaybackTooltip"
        :aria-pressed="recordingAudioState === 'playing'"
        @click="toggleAudioRecorderPlayPause"
      />
      <NextButton
        v-if="showMessageSignatureButton"
        v-tooltip.top-end="signatureToggleTooltip"
        type="button"
        icon="i-lucide-signature"
        color="slate"
        :variant="sendWithSignature ? 'solid' : 'faded'"
        sm
        :aria-label="signatureToggleTooltip"
        :aria-pressed="sendWithSignature"
        @click="toggleMessageSignature"
      />
      <NextButton
        v-if="showQuotedReplyToggle"
        v-tooltip.top-end="quotedReplyToggleTooltip"
        type="button"
        icon="i-lucide-quote"
        :variant="quotedReplyEnabled ? 'solid' : 'faded'"
        color="slate"
        sm
        :aria-label="quotedReplyToggleTooltip"
        :aria-pressed="quotedReplyEnabled"
        @click="$emit('toggleQuotedReply')"
      />
      <NextButton
        v-if="enableWhatsAppTemplates"
        v-tooltip.top-end="$t('CONVERSATION.FOOTER.WHATSAPP_TEMPLATES')"
        type="button"
        icon="i-ph-whatsapp-logo"
        color="slate"
        variant="faded"
        sm
        :aria-label="$t('CONVERSATION.FOOTER.WHATSAPP_TEMPLATES')"
        @click="$emit('selectWhatsappTemplate')"
      />
      <NextButton
        v-if="enableContentTemplates"
        v-tooltip.top-end="$t('CONTENT_TEMPLATES.MODAL.TITLE')"
        type="button"
        icon="i-lucide-file-text"
        color="slate"
        variant="faded"
        sm
        :aria-label="$t('CONTENT_TEMPLATES.MODAL.TITLE')"
        @click="$emit('selectContentTemplate')"
      />
      <VideoCallButton
        v-if="
          (isAWebWidgetInbox || isAPIInbox) &&
          !isOnPrivateNote &&
          !isEditorDisabled
        "
        :conversation-id="conversationId"
      />
      <transition name="modal-fade">
        <div
          v-show="uploadRef && uploadRef.dropActive"
          class="fixed inset-0 z-20 flex h-full w-full flex-col items-center justify-center gap-2 bg-ds-bg-canvas/85 text-ds-fg-default backdrop-blur-sm"
        >
          <span class="i-lucide-cloud-upload size-10" aria-hidden="true" />
          <h4 class="break-words font-manrope text-2xl text-ds-fg-default">
            {{ $t('CONVERSATION.REPLYBOX.DRAG_DROP') }}
          </h4>
        </div>
      </transition>
      <NextButton
        v-if="enableInsertArticleInReply"
        v-tooltip.top-end="$t('HELP_CENTER.ARTICLE_SEARCH.OPEN_ARTICLE_SEARCH')"
        type="button"
        icon="i-lucide-book-open-text"
        color="slate"
        variant="faded"
        sm
        :aria-label="$t('HELP_CENTER.ARTICLE_SEARCH.OPEN_ARTICLE_SEARCH')"
        @click="toggleInsertArticle"
      />
    </div>
    <div class="flex shrink-0 ltr:ml-auto rtl:mr-auto">
      <NextButton
        :label="sendButtonText"
        type="submit"
        sm
        :color="isNote ? 'amber' : 'blue'"
        :disabled="isSendDisabled"
        class="flex-shrink-0"
        @click="onSend"
      />
    </div>
  </div>
</template>

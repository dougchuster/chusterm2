<script setup>
import {
  computed,
  onMounted,
  useTemplateRef,
  ref,
  getCurrentInstance,
} from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import MediaUnderstandingStatus from 'next/message/MediaUnderstandingStatus.vue';
import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';
import { downloadFile } from '@ChusteRM/utils';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';

const { attachment } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  showTranscribedText: {
    type: Boolean,
    default: true,
  },
});

const { t } = useI18n();

defineOptions({
  inheritAttrs: false,
});

const timeStampURL = computed(() => {
  return timeStampAppendedURL(attachment.dataUrl);
});

const audioPlayer = useTemplateRef('audioPlayer');

const isPlaying = ref(false);
const isMuted = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const playbackSpeed = ref(1);

const { uid } = getCurrentInstance();

const onLoadedMetadata = () => {
  duration.value = audioPlayer.value?.duration;
};

const playbackSpeedLabel = computed(() => {
  return `${playbackSpeed.value}x`;
});

const playbackSpeedAriaLabel = computed(
  () => `Velocidade de reprodução: ${playbackSpeedLabel.value}`
);
const muteAriaLabel = computed(() =>
  isMuted.value ? 'Ativar áudio' : 'Silenciar áudio'
);
const playAriaLabel = computed(() => t('CONVERSATION.REPLYBOX.PLAY_AUDIO'));
const pauseAriaLabel = computed(() => t('CONVERSATION.REPLYBOX.PAUSE_AUDIO'));
const playPauseAriaLabel = computed(() =>
  isPlaying.value ? pauseAriaLabel.value : playAriaLabel.value
);
const seekAriaLabel = 'Posição do áudio';
const timeSeparator = '/';

// There maybe a chance that the audioPlayer ref is not available
// When the onLoadMetadata is called, so we need to set the duration
// value when the component is mounted
onMounted(() => {
  duration.value = audioPlayer.value?.duration;
  if (audioPlayer.value) audioPlayer.value.playbackRate = playbackSpeed.value;
});

// Listen for global audio play events and pause if it's not this audio
useEmitter('pause_playing_audio', currentPlayingId => {
  if (currentPlayingId !== uid && isPlaying.value) {
    try {
      audioPlayer.value.pause();
    } catch {
      /* ignore pause errors */
    }
    isPlaying.value = false;
  }
});

const formatTime = time => {
  if (!time || Number.isNaN(time)) return '00:00';
  const minutes = Math.floor(time / 60);
  const seconds = Math.floor(time % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

const toggleMute = () => {
  audioPlayer.value.muted = !audioPlayer.value.muted;
  isMuted.value = audioPlayer.value.muted;
};

const onTimeUpdate = () => {
  currentTime.value = audioPlayer.value?.currentTime;
};

const seek = event => {
  const time = Number(event.target.value);
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const playOrPause = () => {
  if (isPlaying.value) {
    audioPlayer.value.pause();
    isPlaying.value = false;
  } else {
    // Emit event to pause all other audio
    emitter.emit('pause_playing_audio', uid);
    audioPlayer.value.play();
    isPlaying.value = true;
  }
};

const onEnd = () => {
  isPlaying.value = false;
  currentTime.value = 0;
  playbackSpeed.value = 1;
  audioPlayer.value.playbackRate = 1;
};

const changePlaybackSpeed = () => {
  const speeds = [1, 1.5, 2];
  const currentIndex = speeds.indexOf(playbackSpeed.value);
  const nextIndex = (currentIndex + 1) % speeds.length;
  playbackSpeed.value = speeds[nextIndex];
  audioPlayer.value.playbackRate = playbackSpeed.value;
};

const downloadAudio = async () => {
  const { fileType, dataUrl, extension } = attachment;
  downloadFile({ url: dataUrl, type: fileType, extension });
};
</script>

<template>
  <audio
    ref="audioPlayer"
    controls
    class="hidden"
    playsinline
    @loadedmetadata="onLoadedMetadata"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  >
    <source :src="timeStampURL" />
  </audio>
  <div
    v-bind="$attrs"
    class="flex w-full flex-col items-center gap-2 rounded-xl bg-ds-bg-elevated p-2 text-ds-fg-default shadow-[var(--ds-shadow-xs)] ring-1 ring-inset ring-ds-border-subtle"
  >
    <div class="flex gap-1 w-full flex-1 items-center justify-start">
      <button
        type="button"
        :aria-label="playPauseAriaLabel"
        :aria-pressed="isPlaying"
        class="grid size-8 place-content-center rounded-lg text-ds-fg-default outline-none transition-colors hover:bg-ds-bg-hover focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="playOrPause"
      >
        <Icon v-if="isPlaying" class="size-5" icon="i-lucide-pause" />
        <Icon v-else class="size-5" icon="i-lucide-play" />
      </button>
      <div class="whitespace-nowrap text-xs tabular-nums text-ds-fg-muted">
        {{ formatTime(currentTime) }} {{ timeSeparator }}
        {{ formatTime(duration) }}
      </div>
      <div class="flex-1 items-center flex px-2">
        <input
          type="range"
          min="0"
          :max="duration"
          :value="currentTime"
          :aria-label="seekAriaLabel"
          class="h-1 w-full cursor-pointer appearance-none rounded-lg bg-ds-border-strong accent-ds-accent"
          @input="seek"
        />
      </div>
      <button
        type="button"
        :aria-label="playbackSpeedAriaLabel"
        class="grid h-7 w-11 place-content-center rounded-full bg-ds-bg-sunken text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="changePlaybackSpeed"
      >
        <span class="text-xs font-semibold">
          {{ playbackSpeedLabel }}
        </span>
      </button>
      <button
        type="button"
        :aria-label="muteAriaLabel"
        :aria-pressed="isMuted"
        class="grid size-8 place-content-center rounded-lg text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="toggleMute"
      >
        <Icon v-if="isMuted" class="size-4" icon="i-lucide-volume-off" />
        <Icon v-else class="size-4" icon="i-lucide-volume-2" />
      </button>
      <button
        type="button"
        :aria-label="$t('CONVERSATION.DOWNLOAD')"
        class="grid size-8 place-content-center rounded-lg text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="downloadAudio"
      >
        <Icon class="size-4" icon="i-lucide-download" />
      </button>
    </div>

    <MediaUnderstandingStatus
      v-if="showTranscribedText"
      :attachment="attachment"
      class="self-start"
    />
    <div
      v-if="attachment.transcribedText && showTranscribedText"
      class="w-full break-words rounded-lg bg-ds-bg-sunken p-3 text-sm leading-5 text-ds-fg-default"
    >
      {{ attachment.transcribedText }}
    </div>
  </div>
</template>

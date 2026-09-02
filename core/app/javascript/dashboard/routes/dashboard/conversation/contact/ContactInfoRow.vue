<script>
import { useAlert } from 'dashboard/composables';
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    EmojiOrIcon,
    NextButton,
  },
  props: {
    href: {
      type: String,
      default: '',
    },
    icon: {
      type: String,
      required: true,
    },
    emoji: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      default: '',
    },
    title: {
      type: String,
      default: '',
    },
    showCopy: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    async onCopy() {
      await copyTextToClipboard(this.value);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
    },
  },
};
</script>

<template>
  <div
    class="group flex min-h-8 w-full min-w-0 items-center gap-1 rounded-lg text-ds-fg-muted"
  >
    <a
      v-if="href"
      :href="href"
      class="flex min-h-8 min-w-0 flex-1 items-center gap-2 rounded-lg px-1 text-ds-fg-muted no-underline transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      :aria-label="title || value"
    >
      <EmojiOrIcon
        :icon="icon"
        :emoji="emoji"
        icon-size="14"
        class="shrink-0 text-ds-fg-subtle"
      />
      <span v-if="value" class="min-w-0 flex-1 truncate text-sm" :title="value">
        {{ value }}
      </span>
      <span v-else class="text-sm text-ds-fg-muted">
        {{ $t('CONTACT_PANEL.NOT_AVAILABLE') }}
      </span>
    </a>

    <div
      v-else
      class="flex min-h-8 min-w-0 flex-1 items-center gap-2 px-1 text-ds-fg-muted"
    >
      <EmojiOrIcon
        :icon="icon"
        :emoji="emoji"
        icon-size="14"
        class="shrink-0 text-ds-fg-subtle"
      />
      <span
        v-if="value"
        v-dompurify-html="value"
        class="min-w-0 flex-1 truncate text-sm"
        :title="value"
      />
      <span v-else class="text-sm text-ds-fg-muted">
        {{ $t('CONTACT_PANEL.NOT_AVAILABLE') }}
      </span>
    </div>

    <div
      v-if="showCopy && value"
      class="flex size-8 shrink-0 items-center justify-center"
    >
      <NextButton
        v-tooltip.top="$t('CUSTOM_ATTRIBUTES.ACTIONS.COPY')"
        :aria-label="`${$t('CUSTOM_ATTRIBUTES.ACTIONS.COPY')}: ${title || value}`"
        icon="i-lucide-clipboard"
        color="primary"
        variant="ghost"
        size="sm"
        @click="onCopy"
      />
    </div>
  </div>
</template>

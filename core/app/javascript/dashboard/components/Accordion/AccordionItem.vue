<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  emoji: {
    type: String,
    default: '',
  },
  isOpen: {
    type: Boolean,
    default: true,
  },
  draggable: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggle']);

const onToggle = () => {
  emit('toggle');
};
</script>

<template>
  <div class="text-sm">
    <button
      type="button"
      class="m-0 flex min-h-11 w-full select-none items-center justify-between gap-3 rounded-xl bg-ds-bg-surface px-3.5 py-2.5 text-left text-ds-fg-default ring-1 ring-inset ring-ds-border-subtle transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      :class="{
        'rounded-b-none': isOpen,
        'drag-handle cursor-grab active:cursor-grabbing': draggable,
      }"
      :aria-expanded="isOpen"
      @click.stop="onToggle"
    >
      <div class="flex min-w-0 items-center gap-2">
        <EmojiOrIcon
          v-if="icon || emoji"
          class="inline-block size-5 shrink-0"
          :icon="icon"
          :emoji="emoji"
        />
        <h5
          class="m-0 truncate p-0 font-manrope text-sm font-semibold text-ds-fg-default"
        >
          {{ title }}
        </h5>
      </div>
      <div class="flex shrink-0 items-center gap-1">
        <slot name="button" />
        <span
          class="flex size-7 items-center justify-center rounded-lg text-ds-fg-muted transition-colors"
          aria-hidden="true"
        >
          <span
            class="size-4"
            :class="isOpen ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
          />
        </span>
      </div>
    </button>
    <div
      v-if="isOpen"
      class="rounded-b-xl bg-ds-bg-surface ring-1 ring-inset ring-ds-border-subtle"
      :class="compact ? 'p-0' : 'px-2 py-4'"
    >
      <slot />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  conversationLabels: {
    type: Array,
    required: true,
  },
});

const accountLabels = useMapGetter('labels/getLabels');

const activeLabels = computed(() => {
  return accountLabels.value.filter(({ title }) =>
    props.conversationLabels.includes(title)
  );
});

const showAllLabels = ref(false);
const showExpandLabelButton = ref(false);
const labelPosition = ref(-1);
const labelContainer = ref(null);
const beforeSlotContainer = ref(null);

const computeVisibleLabelPosition = () => {
  if (!labelContainer.value) return;

  const labels = Array.from(
    labelContainer.value.querySelectorAll('[data-conversation-label]')
  );

  if (!labels.length) {
    labelPosition.value = -1;
    showExpandLabelButton.value = false;
    return;
  }

  const beforeSlotWidth = beforeSlotContainer.value?.offsetWidth || 0;

  const findLastVisibleIndex = availableWidth => {
    let occupiedWidth = beforeSlotWidth;
    let lastVisibleIndex = -1;

    labels.some((label, index) => {
      const nextWidth =
        occupiedWidth + (occupiedWidth > 0 ? 4 : 0) + label.offsetWidth;
      if (nextWidth > availableWidth) return true;

      occupiedWidth = nextWidth;
      lastVisibleIndex = index;
      return false;
    });

    return lastVisibleIndex;
  };

  const containerWidth = labelContainer.value.clientWidth;
  const lastLabelIndex = labels.length - 1;
  const lastVisibleWithoutToggle = findLastVisibleIndex(containerWidth);
  const hasOverflow = lastVisibleWithoutToggle < lastLabelIndex;

  showExpandLabelButton.value = hasOverflow;
  if (showAllLabels.value) {
    labelPosition.value = lastLabelIndex;
  } else if (hasOverflow) {
    labelPosition.value = findLastVisibleIndex(containerWidth - 28);
  } else {
    labelPosition.value = lastLabelIndex;
  }
};

watch(activeLabels, () => {
  nextTick(() => computeVisibleLabelPosition());
});

onMounted(() => {
  computeVisibleLabelPosition();
});

const onShowLabels = e => {
  e.stopPropagation();
  showAllLabels.value = !showAllLabels.value;
  nextTick(() => computeVisibleLabelPosition());
};
</script>

<template>
  <div
    ref="labelContainer"
    v-resize="computeVisibleLabelPosition"
    class="min-w-0"
  >
    <div
      v-if="activeLabels.length || $slots.before"
      class="flex min-w-0 items-center gap-1 overflow-hidden"
      :class="{
        'h-auto flex-row flex-wrap overflow-visible': showAllLabels,
      }"
    >
      <span
        v-if="$slots.before"
        ref="beforeSlotContainer"
        class="inline-flex shrink-0"
      >
        <slot name="before" />
      </span>
      <woot-label
        v-for="(label, index) in activeLabels"
        :key="label ? label.id : index"
        data-conversation-label
        :title="label.display_title || label.title"
        :description="label.description"
        :color="label.color"
        variant="smooth"
        class="!mb-0 max-w-full shrink-0"
        small
        :class="{
          'pointer-events-none invisible absolute':
            !showAllLabels && index > labelPosition,
        }"
      />
      <button
        v-if="showExpandLabelButton"
        type="button"
        :title="
          showAllLabels
            ? $t('CONVERSATION.CARD.HIDE_LABELS')
            : $t('CONVERSATION.CARD.SHOW_LABELS')
        "
        :aria-label="
          showAllLabels
            ? $t('CONVERSATION.CARD.HIDE_LABELS')
            : $t('CONVERSATION.CARD.SHOW_LABELS')
        "
        :aria-expanded="showAllLabels"
        class="grid size-5 shrink-0 place-items-center rounded-md text-ds-fg-muted outline-none transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="onShowLabels"
        @keydown.stop
      >
        <Icon
          :icon="
            showAllLabels ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
          "
          class="size-3.5"
        />
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from '../icon/Icon.vue';
import CopilotThinkingBlock from './CopilotThinkingBlock.vue';

const props = defineProps({
  messages: { type: Array, required: true },
  defaultCollapsed: { type: Boolean, default: false },
});
const { t } = useI18n();
const isExpanded = ref(!props.defaultCollapsed);

const thinkingCount = computed(() => props.messages.length);

watch(
  () => props.defaultCollapsed,
  newValue => {
    if (newValue) {
      isExpanded.value = false;
    }
  }
);
</script>

<template>
  <div class="flex flex-col gap-2">
    <button
      :aria-expanded="isExpanded"
      class="group -ml-3 flex items-center gap-2 rounded text-xs text-ds-fg-subtle transition-colors duration-200 hover:text-ds-fg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
      type="button"
      @click="isExpanded = !isExpanded"
    >
      <Icon
        :icon="isExpanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        class="w-4 h-4 transition-transform duration-200 group-hover:scale-110"
      />
      <span class="flex items-center gap-2">
        {{ t('CAPTAIN.COPILOT.SHOW_STEPS') }}
        <span
          class="inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-ds-bg-active px-1 text-xs font-medium text-ds-fg-muted"
        >
          {{ thinkingCount }}
        </span>
      </span>
    </button>
    <div
      v-show="isExpanded"
      class="space-y-3 transition-all duration-200"
      :class="{
        'opacity-100': isExpanded,
        'opacity-0 max-h-0 overflow-hidden': !isExpanded,
      }"
    >
      <CopilotThinkingBlock
        v-for="copilotMessage in messages"
        :key="copilotMessage.id"
        :content="copilotMessage.message.content"
        :reasoning="copilotMessage.message.reasoning"
      />
    </div>
  </div>
</template>

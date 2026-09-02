<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  active: {
    type: Boolean,
    default: false,
  },
  inbox: {
    type: Object,
    required: true,
  },
});

const reauthorizationRequired = computed(() => {
  return props.inbox.reauthorization_required;
});
</script>

<template>
  <span
    class="grid size-5 place-content-center rounded-full bg-ds-shell-panel-strong text-ds-shell-fg"
  >
    <ChannelIcon :inbox="inbox" class="size-4" />
  </span>
  <div class="flex-1 truncate min-w-0 text-[0.92rem] leading-5">
    {{ label }}
  </div>
  <div
    v-if="reauthorizationRequired"
    v-tooltip.top-end="$t('SIDEBAR.REAUTHORIZE')"
    class="grid size-6 place-content-center rounded-full bg-ds-shell-danger-soft"
  >
    <Icon
      icon="i-lucide-triangle-alert"
      class="size-3.5 text-ds-shell-danger"
    />
  </div>
</template>

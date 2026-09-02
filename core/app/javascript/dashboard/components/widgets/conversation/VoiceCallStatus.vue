<script setup>
import { computed } from 'vue';
import {
  VOICE_CALL_STATUS,
  VOICE_CALL_DIRECTION,
} from 'dashboard/components-next/message/constants';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  status: { type: String, default: '' },
  direction: { type: String, default: '' },
  messagePreviewClass: { type: [String, Array, Object], default: '' },
});

const LABEL_KEYS = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'CONVERSATION.VOICE_CALL.CALL_IN_PROGRESS',
  [VOICE_CALL_STATUS.COMPLETED]: 'CONVERSATION.VOICE_CALL.CALL_ENDED',
};

const ICON_MAP = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'i-lucide-phone-call',
  [VOICE_CALL_STATUS.NO_ANSWER]: 'i-lucide-phone-off',
  [VOICE_CALL_STATUS.FAILED]: 'i-lucide-phone-off',
};

const COLOR_MAP = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'text-ds-state-success',
  [VOICE_CALL_STATUS.RINGING]: 'text-ds-state-success',
  [VOICE_CALL_STATUS.COMPLETED]: 'text-ds-fg-subtle',
  [VOICE_CALL_STATUS.NO_ANSWER]: 'text-ds-state-danger',
  [VOICE_CALL_STATUS.FAILED]: 'text-ds-state-danger',
};

const isOutbound = computed(
  () => props.direction === VOICE_CALL_DIRECTION.OUTBOUND
);
const isFailed = computed(() =>
  [VOICE_CALL_STATUS.NO_ANSWER, VOICE_CALL_STATUS.FAILED].includes(props.status)
);

const labelKey = computed(() => {
  if (LABEL_KEYS[props.status]) return LABEL_KEYS[props.status];
  if (props.status === VOICE_CALL_STATUS.RINGING) {
    return isOutbound.value
      ? 'CONVERSATION.VOICE_CALL.OUTGOING_CALL'
      : 'CONVERSATION.VOICE_CALL.INCOMING_CALL';
  }
  return isFailed.value
    ? 'CONVERSATION.VOICE_CALL.MISSED_CALL'
    : 'CONVERSATION.VOICE_CALL.INCOMING_CALL';
});

const iconName = computed(() => {
  if (ICON_MAP[props.status]) return ICON_MAP[props.status];
  return isOutbound.value
    ? 'i-lucide-phone-outgoing'
    : 'i-lucide-phone-incoming';
});

const statusColor = computed(
  () => COLOR_MAP[props.status] || 'text-ds-fg-subtle'
);
</script>

<template>
  <div
    class="mx-2 my-0 h-6 min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap text-sm leading-6"
    :class="messagePreviewClass"
  >
    <Icon
      class="inline-block -mt-0.5 align-middle size-4"
      :icon="iconName"
      :class="statusColor"
    />
    <span class="mx-1" :class="statusColor">
      {{ $t(labelKey) }}
    </span>
  </div>
</template>

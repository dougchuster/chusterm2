<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getInboxIconByType } from 'dashboard/helper/inbox';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import LiveChatCampaignDetails from './LiveChatCampaignDetails.vue';
import SMSCampaignDetails from './SMSCampaignDetails.vue';

const props = defineProps({
  title: {
    type: String,
    default: '',
  },
  message: {
    type: String,
    default: '',
  },
  isLiveChatType: {
    type: Boolean,
    default: false,
  },
  isEnabled: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String,
    default: '',
  },
  sender: {
    type: Object,
    default: null,
  },
  inbox: {
    type: Object,
    default: null,
  },
  scheduledAt: {
    type: Number,
    default: 0,
  },
  audience: {
    type: Array,
    default: () => [],
  },
  deliveryStats: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const STATUS_COMPLETED = 'completed';

const { formatMessage } = useMessageFormatter();

const isActive = computed(() =>
  props.isLiveChatType ? props.isEnabled : props.status !== STATUS_COMPLETED
);

const statusTextColor = computed(() => ({
  'text-n-teal-11': isActive.value,
  'text-n-slate-12': !isActive.value,
}));

const campaignStatus = computed(() => {
  if (props.isLiveChatType) {
    return props.isEnabled
      ? t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.ENABLED')
      : t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.DISABLED');
  }

  return props.status === STATUS_COMPLETED
    ? t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
    : t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED');
});

const inboxName = computed(() => props.inbox?.name || '');

const inboxIcon = computed(() => {
  const { medium, channel_type: type } = props.inbox;
  return getInboxIconByType(type, medium);
});

const audienceLabel = computed(() => {
  if (!props.audience.length) return '';

  const labels = props.audience
    .map(item => item.name || item.title || item.id)
    .filter(Boolean);

  if (!labels.length) return '';
  if (labels.length === 1) return labels[0];

  return `${labels[0]} +${labels.length - 1}`;
});

const deliveryStatsSummary = computed(() => {
  const stats = props.deliveryStats || {};
  const sent = Number(stats.sent || 0);
  const delivered = Number(stats.delivered || 0);
  const read = Number(stats.read || 0);
  const replied = Number(stats.replied || 0);
  const failed = Number(stats.failed || 0);

  if (![sent, delivered, read, replied, failed].some(Boolean)) return '';

  return [
    sent ? `${sent} env.` : null,
    delivered ? `${delivered} entr.` : null,
    read ? `${read} lidas` : null,
    replied ? `${replied} resp.` : null,
    failed ? `${failed} falhas` : null,
  ]
    .filter(Boolean)
    .join(' / ');
});
</script>

<template>
  <CardLayout layout="row">
    <div class="flex flex-col items-start justify-between flex-1 min-w-0 gap-2">
      <div class="flex justify-between gap-3 w-fit">
        <span
          class="text-base font-medium capitalize text-n-slate-12 line-clamp-1"
        >
          {{ title }}
        </span>
        <span
          class="text-xs font-medium inline-flex items-center h-6 px-2 py-0.5 rounded-md bg-n-alpha-2"
          :class="statusTextColor"
        >
          {{ campaignStatus }}
        </span>
      </div>
      <div
        v-dompurify-html="formatMessage(message, false, false, false)"
        class="text-sm text-n-slate-11 line-clamp-1 [&>p]:mb-0 h-6"
      />
      <div class="flex items-center w-full min-h-6 gap-2 overflow-hidden">
        <LiveChatCampaignDetails
          v-if="isLiveChatType"
          :sender="sender"
          :inbox-name="inboxName"
          :inbox-icon="inboxIcon"
        />
        <SMSCampaignDetails
          v-else
          :inbox-name="inboxName"
          :inbox-icon="inboxIcon"
          :scheduled-at="scheduledAt"
        />
      </div>
      <div
        v-if="audienceLabel || deliveryStatsSummary"
        class="flex w-full min-w-0 flex-wrap items-center gap-2 text-xs text-n-slate-11"
      >
        <span
          v-if="audienceLabel"
          class="max-w-full truncate rounded-md border border-ui-border-subtle px-2 py-1"
        >
          {{ audienceLabel }}
        </span>
        <span
          v-if="deliveryStatsSummary"
          class="max-w-full truncate rounded-md bg-n-alpha-2 px-2 py-1"
        >
          {{ deliveryStatsSummary }}
        </span>
      </div>
    </div>
    <div class="flex items-center justify-end w-20 gap-2">
      <Button
        v-if="isLiveChatType"
        :aria-label="t('CAMPAIGN.LIVE_CHAT.EDIT.TITLE')"
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-sliders-vertical"
        @click="emit('edit')"
      />
      <Button
        :aria-label="t('CAMPAIGN.CONFIRM_DELETE.TITLE')"
        variant="faded"
        color="ruby"
        size="sm"
        icon="i-lucide-trash"
        @click="emit('delete')"
      />
    </div>
  </CardLayout>
</template>

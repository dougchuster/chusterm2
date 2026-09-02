<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const formatDate = dateString => {
  return format(new Date(dateString), 'MMM d, yyyy');
};

const formatCurrency = (amount, currency) => {
  return new Intl.NumberFormat('en', {
    style: 'currency',
    currency: currency || 'USD',
  }).format(amount);
};

const getStatusClass = status => {
  const classes = {
    paid: 'bg-ds-state-success-soft text-ds-state-success',
  };
  return classes[status] || 'bg-ds-bg-sunken text-ds-fg-muted';
};

const getStatusI18nKey = (type, status = '') => {
  return `CONVERSATION_SIDEBAR.SHOPIFY.${type.toUpperCase()}_STATUS.${status.toUpperCase()}`;
};

const fulfillmentStatus = computed(() => {
  const { fulfillment_status: status } = props.order;
  if (!status) {
    return '';
  }
  return t(getStatusI18nKey('FULFILLMENT', status));
});

const financialStatus = computed(() => {
  const { financial_status: status } = props.order;
  if (!status) {
    return '';
  }
  return t(getStatusI18nKey('FINANCIAL', status));
});

const getFulfillmentClass = status => {
  const classes = {
    fulfilled: 'text-ds-state-success',
    partial: 'text-ds-state-warning',
    unfulfilled: 'text-ds-state-danger',
  };
  return classes[status] || 'text-ds-fg-muted';
};
</script>

<template>
  <div
    class="flex flex-col gap-1.5 border-b border-ds-border-subtle py-3 last:border-b-0"
  >
    <div class="flex justify-between items-center">
      <div class="font-medium flex">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex min-w-0 items-center gap-1 truncate rounded-md font-medium text-ds-fg-default outline-none hover:text-ds-accent hover:underline focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        >
          <span class="truncate">
            {{ $t('CONVERSATION_SIDEBAR.SHOPIFY.ORDER_ID', { id: order.id }) }}
          </span>
          <i class="i-lucide-external-link size-3.5 shrink-0" />
        </a>
      </div>
      <div
        :class="getStatusClass(order.financial_status)"
        class="truncate rounded-full px-2 py-1 text-xs font-medium capitalize"
        :title="financialStatus"
      >
        {{ financialStatus }}
      </div>
    </div>
    <div class="flex items-center text-sm text-ds-fg-muted">
      <time
        :datetime="order.created_at"
        class="border-r border-ds-border-subtle pr-2"
      >
        {{ formatDate(order.created_at) }}
      </time>
      <span class="pl-2">
        {{ formatCurrency(order.total_price, order.currency) }}
      </span>
    </div>
    <div v-if="fulfillmentStatus">
      <span
        :class="getFulfillmentClass(order.fulfillment_status)"
        class="font-medium capitalize"
        :title="fulfillmentStatus"
      >
        {{ fulfillmentStatus }}
      </span>
    </div>
  </div>
</template>

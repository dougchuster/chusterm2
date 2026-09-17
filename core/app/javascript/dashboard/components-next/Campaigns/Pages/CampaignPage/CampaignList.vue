<script setup>
import { computed, reactive } from 'vue';
import CampaignCard from 'dashboard/components-next/Campaigns/CampaignCard/CampaignCard.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  campaigns: {
    type: Array,
    required: true,
  },
  isLiveChatType: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['edit', 'delete']);

const handleEdit = campaign => emit('edit', campaign);
const handleDelete = campaign => emit('delete', campaign);

const filterState = reactive({
  search: '',
  status: 'all',
  channel: 'all',
  period: 'all',
  audience: 'all',
});

const filterLabels = {
  search: 'Busca',
  searchPlaceholder: 'Título, mensagem ou público',
  status: 'Status',
  channel: 'Canal',
  period: 'Período',
  audience: 'Lista/segmento',
  noResults: 'Nenhuma campanha encontrada com estes filtros.',
};

const commonOptions = {
  all: 'Todos',
};

const statusOptions = computed(() =>
  props.isLiveChatType
    ? [
        { value: 'enabled', label: 'Ativas' },
        { value: 'disabled', label: 'Inativas' },
      ]
    : [
        { value: 'active', label: 'Agendadas' },
        { value: 'completed', label: 'Concluídas' },
      ]
);

const withAllOption = options => [
  { value: 'all', label: commonOptions.all },
  ...options,
];

const statusSelectOptions = computed(() => withAllOption(statusOptions.value));

const periodOptions = [
  { value: 'today', label: 'Hoje' },
  { value: 'next_7_days', label: 'Próximos 7 dias' },
  { value: 'last_30_days', label: 'Últimos 30 dias' },
  { value: 'future', label: 'Futuras' },
];

const normalize = value =>
  String(value || '')
    .trim()
    .toLowerCase();

const campaignDate = campaign => {
  if (campaign.scheduled_at) {
    return new Date(Number(campaign.scheduled_at) * 1000);
  }

  return campaign.created_at ? new Date(campaign.created_at) : null;
};

const audienceLabels = campaign =>
  Array.isArray(campaign.audience)
    ? campaign.audience
        .map(item => item.name || item.title || item.id)
        .filter(Boolean)
        .map(String)
    : [];

const audienceFilterOptions = computed(() => {
  const options = new Map();
  props.campaigns.forEach(campaign => {
    audienceLabels(campaign).forEach(label => options.set(label, label));
  });

  return [...options.values()].sort((a, b) => a.localeCompare(b));
});

const audienceSelectOptions = computed(() =>
  withAllOption(
    audienceFilterOptions.value.map(audience => ({
      value: audience,
      label: audience,
    }))
  )
);

const channelFilterOptions = computed(() => {
  const options = new Map();
  props.campaigns.forEach(campaign => {
    const channelName = campaign.inbox?.name;
    if (channelName) options.set(channelName, channelName);
  });

  return [...options.values()].sort((a, b) => a.localeCompare(b));
});

const channelSelectOptions = computed(() =>
  withAllOption(
    channelFilterOptions.value.map(channel => ({
      value: channel,
      label: channel,
    }))
  )
);

const periodSelectOptions = computed(() => withAllOption(periodOptions));

const matchesPeriod = campaign => {
  if (filterState.period === 'all') return true;

  const date = campaignDate(campaign);
  if (!date || Number.isNaN(date.getTime())) return false;

  const now = new Date();
  const startOfToday = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate()
  );
  const diffInDays = (date - now) / 86400000;

  if (filterState.period === 'today') {
    return (
      date >= startOfToday && date < new Date(startOfToday.getTime() + 86400000)
    );
  }

  if (filterState.period === 'next_7_days') {
    return diffInDays >= 0 && diffInDays <= 7;
  }

  if (filterState.period === 'last_30_days') {
    return diffInDays <= 0 && diffInDays >= -30;
  }

  if (filterState.period === 'future') {
    return diffInDays >= 0;
  }

  return true;
};

const filteredCampaigns = computed(() => {
  const searchTerm = normalize(filterState.search);

  return props.campaigns.filter(campaign => {
    const haystack = normalize(
      [
        campaign.title,
        campaign.message,
        campaign.inbox?.name,
        campaign.campaign_status,
        ...audienceLabels(campaign),
      ].join(' ')
    );

    const matchesSearch = !searchTerm || haystack.includes(searchTerm);
    const matchesStatus =
      filterState.status === 'all' ||
      campaign.campaign_status === filterState.status ||
      (filterState.status === 'enabled' && campaign.enabled) ||
      (filterState.status === 'disabled' && !campaign.enabled);
    const matchesChannel =
      filterState.channel === 'all' ||
      campaign.inbox?.name === filterState.channel;
    const matchesAudience =
      filterState.audience === 'all' ||
      audienceLabels(campaign).includes(filterState.audience);

    return (
      matchesSearch &&
      matchesStatus &&
      matchesChannel &&
      matchesAudience &&
      matchesPeriod(campaign)
    );
  });
});

const filterSummary = computed(
  () =>
    `${filteredCampaigns.value.length} de ${props.campaigns.length} campanhas`
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      v-if="campaigns.length"
      class="grid gap-3 rounded-lg border border-ui-border-subtle bg-n-alpha-2 p-3 sm:grid-cols-2 lg:grid-cols-[1.4fr_0.9fr_0.9fr_0.9fr_0.9fr_auto]"
    >
      <label class="flex min-w-0 flex-col gap-1 text-xs text-n-slate-11">
        {{ filterLabels.search }}
        <input
          v-model="filterState.search"
          class="h-9 min-w-0 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          :placeholder="filterLabels.searchPlaceholder"
          type="search"
        />
      </label>
      <label class="flex min-w-0 flex-col gap-1 text-xs text-n-slate-11">
        {{ filterLabels.status }}
        <Select
          v-model="filterState.status"
          :options="statusSelectOptions"
          block
        />
      </label>
      <label class="flex min-w-0 flex-col gap-1 text-xs text-n-slate-11">
        {{ filterLabels.channel }}
        <Select
          v-model="filterState.channel"
          :options="channelSelectOptions"
          block
        />
      </label>
      <label class="flex min-w-0 flex-col gap-1 text-xs text-n-slate-11">
        {{ filterLabels.period }}
        <Select
          v-model="filterState.period"
          :options="periodSelectOptions"
          block
        />
      </label>
      <label class="flex min-w-0 flex-col gap-1 text-xs text-n-slate-11">
        {{ filterLabels.audience }}
        <Select
          v-model="filterState.audience"
          :options="audienceSelectOptions"
          block
        />
      </label>
      <div class="flex items-end text-xs font-medium text-n-slate-11">
        {{ filterSummary }}
      </div>
    </div>

    <div
      v-if="campaigns.length && !filteredCampaigns.length"
      class="rounded-lg border border-dashed border-ui-border-subtle px-4 py-8 text-center text-sm text-n-slate-11"
    >
      {{ filterLabels.noResults }}
    </div>

    <CampaignCard
      v-for="campaign in filteredCampaigns"
      :key="campaign.id"
      :title="campaign.title"
      :message="campaign.message"
      :is-enabled="campaign.enabled"
      :status="campaign.campaign_status"
      :sender="campaign.sender"
      :inbox="campaign.inbox"
      :scheduled-at="campaign.scheduled_at"
      :audience="campaign.audience"
      :delivery-stats="campaign.delivery_stats"
      :is-live-chat-type="isLiveChatType"
      @edit="handleEdit(campaign)"
      @delete="handleDelete(campaign)"
    />
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import MarketingAPI from 'dashboard/api/marketing';
import {
  DsButton,
  DsCard,
  DsDataGrid,
  DsEmptyState,
  DsSelect,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();

const loading = ref(true);
const error = ref(null);
const campaigns = ref([]);
const busyCampaignId = ref(null);
const providerFilter = ref('');
const days = ref(30);

const providerOptions = computed(() => [
  { value: '', label: t('MARKETING.CAMPAIGNS.FILTERS.ALL_PROVIDERS') },
  { value: 'meta_ads', label: 'Meta Ads' },
  { value: 'google_ads', label: 'Google Ads' },
  { value: 'ga4', label: 'GA4' },
]);

const periodOptions = computed(() => [
  { value: 7, label: t('MARKETING.PERIOD.D7') },
  { value: 30, label: t('MARKETING.PERIOD.D30') },
  { value: 90, label: t('MARKETING.PERIOD.D90') },
]);

const fmtMoney = value =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(value ?? 0);

const fmtNumber = value =>
  new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(
    value ?? 0
  );

const providerLabel = provider => {
  const labels = {
    meta_ads: 'Meta Ads',
    google_ads: 'Google Ads',
    ga4: 'GA4',
  };
  return labels[provider] || provider;
};

const columns = computed(() => [
  {
    id: 'name',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.NAME'),
    accessorKey: 'name',
    width: 260,
  },
  {
    id: 'provider',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.PROVIDER'),
    accessorKey: 'provider_label',
    width: 130,
  },
  {
    id: 'status',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.STATUS'),
    accessorKey: 'status',
    width: 110,
  },
  {
    id: 'spend',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.SPEND'),
    accessorKey: 'spend_display',
    width: 120,
  },
  {
    id: 'impressions',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.IMPRESSIONS'),
    accessorKey: 'impressions_display',
    width: 130,
  },
  {
    id: 'ctr',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.CTR'),
    accessorKey: 'ctr_display',
    width: 90,
  },
  {
    id: 'cpc',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.CPC'),
    accessorKey: 'cpc_display',
    width: 110,
  },
  {
    id: 'leads',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.LEADS'),
    accessorKey: 'leads_display',
    width: 90,
  },
  {
    id: 'cpl',
    header: t('MARKETING.CAMPAIGNS.COLUMNS.CPL'),
    accessorKey: 'cpl_display',
    width: 110,
  },
  {
    id: 'actions',
    header: '',
    accessorKey: 'actions',
    width: 140,
  },
]);

const gridData = computed(() =>
  campaigns.value.map(campaign => ({
    ...campaign,
    provider_label: providerLabel(campaign.provider),
    spend_display: fmtMoney(campaign.metrics?.spend),
    impressions_display: fmtNumber(campaign.metrics?.impressions),
    ctr_display: `${(campaign.metrics?.ctr ?? 0).toFixed(2)}%`,
    cpc_display: fmtMoney(campaign.metrics?.cpc),
    leads_display: fmtNumber(campaign.metrics?.leads),
    cpl_display: fmtMoney(campaign.metrics?.cpl),
  }))
);

const load = async () => {
  loading.value = true;
  error.value = null;
  try {
    const to = new Date();
    const from = new Date();
    from.setDate(from.getDate() - days.value);
    const response = await MarketingAPI.getCampaigns({
      date_from: from.toISOString().slice(0, 10),
      date_to: to.toISOString().slice(0, 10),
      provider: providerFilter.value || undefined,
    });
    campaigns.value = response.data.campaigns ?? [];
  } catch (e) {
    error.value = e;
  } finally {
    loading.value = false;
  }
};

// Escrita governada: pausar/reativar pede confirmação e vai por job —
// a resposta 202 não garante que a Meta aplicou, só que foi aceito e auditado.
const toggleStatus = async campaign => {
  const next = campaign.status === 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
  const confirmKey =
    next === 'PAUSED'
      ? 'MARKETING.CAMPAIGNS.CONFIRM.PAUSE'
      : 'MARKETING.CAMPAIGNS.CONFIRM.RESUME';
  if (!window.confirm(t(confirmKey, { name: campaign.name }))) return;

  busyCampaignId.value = campaign.id;
  try {
    await MarketingAPI.setCampaignStatus(campaign.id, next);
    useAlert(t('MARKETING.CAMPAIGNS.SUCCESS.STATUS'));
    campaign.status = next;
  } catch (e) {
    useAlert(t('MARKETING.CAMPAIGNS.ERROR.STATUS'));
  } finally {
    busyCampaignId.value = null;
  }
};

onMounted(load);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
  >
    <DsPageHeader
      :title="t('MARKETING.CAMPAIGNS.TITLE')"
      :breadcrumbs="[
        { label: t('MARKETING.TITLE') },
        { label: t('MARKETING.CAMPAIGNS.TITLE') },
      ]"
    >
      <template #actions>
        <div class="flex items-center gap-2">
          <DsSelect
            v-model="providerFilter"
            :options="providerOptions"
            :label="t('MARKETING.CAMPAIGNS.FILTERS.PROVIDER')"
            hide-label
            class="w-44"
            @update:model-value="load"
          />
          <DsSelect
            v-model="days"
            :options="periodOptions"
            :label="t('MARKETING.PERIOD.LABEL')"
            hide-label
            class="w-40"
            @update:model-value="load"
          />
        </div>
      </template>
    </DsPageHeader>

    <div
      role="region"
      tabindex="0"
      :aria-label="$t('MARKETING.PAGE_REGION')"
      class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
    >
      <DsCard v-if="error">
        <DsEmptyState
          icon="i-lucide-cloud-off"
          :title="t('MARKETING.CAMPAIGNS.ERROR.TITLE')"
          :message="t('MARKETING.CAMPAIGNS.ERROR.MESSAGE')"
        />
      </DsCard>

      <DsDataGrid
        v-else
        :columns="columns"
        :data="gridData"
        :loading="loading"
        :empty-title="t('MARKETING.CAMPAIGNS.EMPTY.TITLE')"
        :empty-description="t('MARKETING.CAMPAIGNS.EMPTY.MESSAGE')"
        row-key="id"
        min-width-class="min-w-[1100px]"
      >
        <template #cell-actions="{ row }">
          <div class="flex justify-end">
            <DsButton
              v-if="row.writable && ['ACTIVE', 'PAUSED'].includes(row.status)"
              size="sm"
              variant="ghost"
              :loading="busyCampaignId === row.id"
              @click="toggleStatus(row)"
            >
              {{
                row.status === 'ACTIVE'
                  ? t('MARKETING.CAMPAIGNS.ACTIONS.PAUSE')
                  : t('MARKETING.CAMPAIGNS.ACTIONS.RESUME')
              }}
            </DsButton>
          </div>
        </template>
      </DsDataGrid>
    </div>
  </section>
</template>

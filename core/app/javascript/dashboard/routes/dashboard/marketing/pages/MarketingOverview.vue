<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MarketingAPI from 'dashboard/api/marketing';
import {
  DsCard,
  DsEmptyState,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();

const loading = ref(true);
const error = ref(null);
const data = ref(null);
const days = ref(30);

const periodOptions = computed(() => [
  { value: 7, label: t('MARKETING.PERIOD.D7') },
  { value: 14, label: t('MARKETING.PERIOD.D14') },
  { value: 30, label: t('MARKETING.PERIOD.D30') },
  { value: 90, label: t('MARKETING.PERIOD.D90') },
]);

const totals = computed(() => data.value?.totals ?? {});
const series = computed(() => data.value?.series ?? []);
const providers = computed(() => data.value?.by_provider ?? []);
const hasData = computed(() => series.value.length > 0);

const maxSpend = computed(() =>
  Math.max(...series.value.map(day => day.spend), 1)
);

const providerLabel = provider => {
  const labels = {
    meta_ads: 'Meta Ads',
    google_ads: 'Google Ads',
    ga4: 'GA4',
  };
  return labels[provider] || provider;
};

const fmtMoney = value =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(value ?? 0);

const fmtNumber = value =>
  new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(
    value ?? 0
  );

const kpis = computed(() => [
  {
    key: 'spend',
    label: t('MARKETING.OVERVIEW.KPI.SPEND'),
    value: fmtMoney(totals.value.spend),
    icon: 'i-lucide-wallet',
  },
  {
    key: 'leads',
    label: t('MARKETING.OVERVIEW.KPI.LEADS'),
    value: fmtNumber(totals.value.leads),
    icon: 'i-lucide-user-plus',
  },
  {
    key: 'cpl',
    label: t('MARKETING.OVERVIEW.KPI.CPL'),
    value: fmtMoney(totals.value.cpl),
    icon: 'i-lucide-target',
  },
  {
    key: 'roas',
    label: t('MARKETING.OVERVIEW.KPI.ROAS'),
    value: `${Number(totals.value.roas ?? 0).toFixed(2)}x`,
    icon: 'i-lucide-trending-up',
  },
  {
    key: 'impressions',
    label: t('MARKETING.OVERVIEW.KPI.IMPRESSIONS'),
    value: fmtNumber(totals.value.impressions),
    icon: 'i-lucide-eye',
  },
  {
    key: 'ctr',
    label: t('MARKETING.OVERVIEW.KPI.CTR'),
    value: `${(totals.value.ctr ?? 0).toFixed(2)}%`,
    icon: 'i-lucide-mouse-pointer-click',
  },
]);

const load = async () => {
  loading.value = true;
  error.value = null;
  try {
    const to = new Date();
    const from = new Date();
    from.setDate(from.getDate() - days.value);
    const response = await MarketingAPI.getOverview({
      date_from: from.toISOString().slice(0, 10),
      date_to: to.toISOString().slice(0, 10),
    });
    data.value = response.data;
  } catch (e) {
    error.value = e;
  } finally {
    loading.value = false;
  }
};

onMounted(load);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
  >
    <DsPageHeader
      :title="t('MARKETING.OVERVIEW.TITLE')"
      :breadcrumbs="[
        { label: t('MARKETING.TITLE') },
        { label: t('MARKETING.OVERVIEW.TITLE') },
      ]"
    >
      <template #actions>
        <DsSelect
          v-model="days"
          :options="periodOptions"
          class="w-40"
          @update:model-value="load"
        />
      </template>
    </DsPageHeader>

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <div
        v-if="loading"
        class="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6"
      >
        <DsSkeleton v-for="n in 6" :key="n" class="h-24" />
      </div>

      <DsCard v-else-if="error">
        <DsEmptyState
          icon="i-lucide-cloud-off"
          :title="t('MARKETING.OVERVIEW.ERROR.TITLE')"
          :message="t('MARKETING.OVERVIEW.ERROR.MESSAGE')"
        />
      </DsCard>

      <template v-else>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
          <DsCard v-for="kpi in kpis" :key="kpi.key" class="p-4">
            <div class="flex items-center gap-2 text-ui-text-subtle">
              <span :class="kpi.icon" class="size-4" aria-hidden="true" />
              <span class="text-ui-caption font-medium uppercase tracking-wide">
                {{ kpi.label }}
              </span>
            </div>
            <p class="mt-2 font-display text-2xl font-semibold text-ui-text">
              {{ kpi.value }}
            </p>
          </DsCard>
        </div>

        <DsCard v-if="!hasData">
          <DsEmptyState
            icon="i-lucide-bar-chart-3"
            :title="t('MARKETING.OVERVIEW.EMPTY.TITLE')"
            :message="t('MARKETING.OVERVIEW.EMPTY.MESSAGE')"
          />
        </DsCard>

        <template v-else>
          <DsCard class="p-4 sm:p-6">
            <h2 class="m-0 font-display text-lg font-semibold text-ui-text">
              {{ t('MARKETING.OVERVIEW.SPEND_CHART') }}
            </h2>
            <div
              class="mt-4 flex h-40 items-end gap-1"
              role="img"
              :aria-label="t('MARKETING.OVERVIEW.SPEND_CHART')"
            >
              <div
                v-for="day in series"
                :key="day.date"
                class="group relative flex-1 rounded-t-sm bg-ui-accent/70 transition-colors hover:bg-ui-accent"
                :style="{
                  height: `${Math.max((day.spend / maxSpend) * 100, 2)}%`,
                }"
              >
                <div
                  class="pointer-events-none absolute -top-12 left-1/2 z-ui-overlay hidden -translate-x-1/2 whitespace-nowrap rounded-ui-surface border border-ui-border bg-ui-elevated px-2 py-1 text-ui-caption text-ui-text shadow-ui-overlay group-hover:block"
                >
                  {{
                    t('MARKETING.OVERVIEW.DAY_TOOLTIP', {
                      date: day.date,
                      spend: fmtMoney(day.spend),
                      leads: fmtNumber(day.leads),
                    })
                  }}
                </div>
              </div>
            </div>
          </DsCard>

          <DsCard v-if="providers.length" class="p-4 sm:p-6">
            <h2 class="m-0 font-display text-lg font-semibold text-ui-text">
              {{ t('MARKETING.OVERVIEW.BY_PROVIDER') }}
            </h2>
            <ul class="m-0 mt-4 grid list-none gap-2 p-0 sm:grid-cols-3">
              <li
                v-for="row in providers"
                :key="row.provider"
                class="rounded-ui-surface bg-ui-surface-sunken p-4"
              >
                <p class="m-0 text-ui-body-sm font-medium text-ui-text-subtle">
                  {{ providerLabel(row.provider) }}
                </p>
                <p
                  class="m-0 mt-1 font-display text-xl font-semibold text-ui-text"
                >
                  {{ fmtMoney(row.spend) }}
                </p>
                <p class="m-0 mt-1 text-ui-caption text-ui-text-subtle">
                  {{
                    t('MARKETING.OVERVIEW.PROVIDER_LINE', {
                      leads: fmtNumber(row.leads),
                      conversions: fmtNumber(row.conversions),
                    })
                  }}
                </p>
              </li>
            </ul>
          </DsCard>
        </template>
      </template>
    </div>
  </section>
</template>

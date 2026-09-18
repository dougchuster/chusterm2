<script setup>
// 6.1: uma tela de relatórios — funde Reports (export/funil), CrmMetrics
// (conversão/analista) e AnalyticsCenter (SLA/CSAT/suporte) em três abas
// sob um único shell. As rotas antigas redirecionam para a aba certa.
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import { DsTabs } from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';
import Reports from './Reports.vue';
import CrmMetrics from './CrmMetrics.vue';
import AnalyticsCenter from './AnalyticsCenter.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const VALID_TABS = ['reports', 'metrics', 'analytics'];
const activeTab = ref(
  VALID_TABS.includes(route.query.tab) ? route.query.tab : 'reports'
);

const tabs = computed(() => [
  {
    value: 'reports',
    label: t('CRM.REPORTS.TITLE'),
    icon: 'i-lucide-bar-chart-2',
  },
  {
    value: 'metrics',
    label: t('CRM.METRICS.TITLE'),
    icon: 'i-lucide-trending-up',
  },
  {
    value: 'analytics',
    label: t('CRM.ANALYTICS.TITLE'),
    icon: 'i-lucide-activity',
  },
]);

// Mantém ?tab= na URL para deep-link dos comandos e rotas antigas.
watch(activeTab, value => {
  if (route.query.tab === value) return;
  router.replace({ query: { ...route.query, tab: value } });
});

watch(
  () => route.query.tab,
  value => {
    if (VALID_TABS.includes(value) && value !== activeTab.value) {
      activeTab.value = value;
    }
  }
);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
  >
    <DsPageHeader
      :title="t('CRM.REPORTS_HUB.TITLE')"
      :breadcrumbs="[
        { label: t('CRM.REPORTS_HUB.BREADCRUMB') },
        { label: t('CRM.REPORTS_HUB.TITLE') },
      ]"
    />

    <div class="border-b border-ui-border-subtle px-4 pt-3 sm:px-6">
      <DsTabs
        v-model="activeTab"
        :tabs="tabs"
        :label="t('CRM.REPORTS_HUB.TABS_LABEL')"
      />
    </div>

    <KeepAlive>
      <component :is="activeTab === 'reports' ? Reports : activeTab === 'metrics' ? CrmMetrics : AnalyticsCenter" embedded />
    </KeepAlive>
  </section>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import MarketingAPI from 'dashboard/api/marketing';
import {
  DsCard,
  DsEmptyState,
  DsBadge,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const KEY = 'INSIGHTS';

const alerts = ref([]);
const isLoading = ref(true);

const severityVariant = severity =>
  ({ critical: 'danger', warning: 'warning', info: 'info' })[severity] ||
  'neutral';

const severityIcon = severity =>
  ({
    critical: 'i-lucide-octagon-alert',
    warning: 'i-lucide-triangle-alert',
    info: 'i-lucide-info',
  })[severity] || 'i-lucide-info';

const suggestedQuestions = computed(() => [
  t(`MARKETING.${KEY}.QUESTIONS.SPEND`),
  t(`MARKETING.${KEY}.QUESTIONS.TOP`),
  t(`MARKETING.${KEY}.QUESTIONS.FUNNEL`),
  t(`MARKETING.${KEY}.QUESTIONS.CPL`),
]);

const fetchInsights = async () => {
  isLoading.value = true;
  try {
    const { data } = await MarketingAPI.getInsights();
    alerts.value = data.alerts || [];
  } catch (error) {
    alerts.value = [];
  } finally {
    isLoading.value = false;
  }
};

const openCopilot = () => {
  router.push({
    name: 'copilot',
    params: { accountId: route.params.accountId },
  });
};

onMounted(fetchInsights);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
  >
    <DsPageHeader
      :title="t(`MARKETING.${KEY}.TITLE`)"
      :breadcrumbs="[
        { label: t('MARKETING.TITLE') },
        { label: t(`MARKETING.${KEY}.TITLE`) },
      ]"
    />
    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <DsCard>
        <div class="flex items-start justify-between gap-4 p-4 sm:p-5">
          <div>
            <h2 class="font-heading text-base font-semibold text-ui-text">
              {{ t(`MARKETING.${KEY}.ALERTS.TITLE`) }}
            </h2>
            <p class="mt-1 text-sm text-ui-text-muted">
              {{ t(`MARKETING.${KEY}.ALERTS.SUBTITLE`) }}
            </p>
          </div>
        </div>
        <div v-if="isLoading" class="px-4 pb-5 text-sm text-ui-text-muted">
          {{ t(`MARKETING.${KEY}.LOADING`) }}
        </div>
        <DsEmptyState
          v-else-if="!alerts.length"
          icon="i-lucide-circle-check"
          :title="t(`MARKETING.${KEY}.EMPTY.TITLE`)"
          :message="t(`MARKETING.${KEY}.EMPTY.MESSAGE`)"
        />
        <ul v-else class="flex flex-col gap-2 px-4 pb-5">
          <li
            v-for="alert in alerts"
            :key="alert.kind"
            class="flex items-center gap-3 rounded-ui-card bg-ui-surface-muted/60 px-4 py-3"
          >
            <span
              class="i-lucide size-4 shrink-0"
              :class="severityIcon(alert.severity)"
              aria-hidden="true"
            />
            <span class="flex-1 text-sm text-ui-text">{{ alert.message }}</span>
            <DsBadge :variant="severityVariant(alert.severity)">
              {{
                t(`MARKETING.${KEY}.SEVERITY.${alert.severity.toUpperCase()}`)
              }}
            </DsBadge>
          </li>
        </ul>
      </DsCard>

      <DsCard>
        <div class="p-4 sm:p-5">
          <h2 class="font-heading text-base font-semibold text-ui-text">
            {{ t(`MARKETING.${KEY}.ASK.TITLE`) }}
          </h2>
          <p class="mt-1 text-sm text-ui-text-muted">
            {{ t(`MARKETING.${KEY}.ASK.SUBTITLE`) }}
          </p>
          <ul class="mt-4 flex flex-col gap-2">
            <li
              v-for="question in suggestedQuestions"
              :key="question"
              class="flex items-center justify-between gap-3 rounded-ui-card bg-ui-surface-muted/60 px-4 py-3"
            >
              <span class="text-sm text-ui-text">{{ question }}</span>
              <button
                type="button"
                class="shrink-0 text-sm font-medium text-ui-brand-foreground hover:underline"
                @click="openCopilot"
              >
                {{ t(`MARKETING.${KEY}.ASK.OPEN`) }}
              </button>
            </li>
          </ul>
        </div>
      </DsCard>
    </div>
  </section>
</template>

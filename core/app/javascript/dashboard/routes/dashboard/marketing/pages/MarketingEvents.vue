<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import MarketingAPI from 'dashboard/api/marketing';
import {
  DsCard,
  DsEmptyState,
  DsBadge,
  DsButton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();
const KEY = 'EVENTS';

const events = ref([]);
const counts = ref({});
const isLoading = ref(true);
const statusFilter = ref('');
const busyEventId = ref(null);

const statusOptions = computed(() => [
  { value: '', label: t(`MARKETING.${KEY}.FILTERS.ALL`) },
  { value: 'sent', label: t(`MARKETING.${KEY}.FILTERS.SENT`) },
  { value: 'failed', label: t(`MARKETING.${KEY}.FILTERS.FAILED`) },
  { value: 'pending', label: t(`MARKETING.${KEY}.FILTERS.PENDING`) },
  { value: 'skipped', label: t(`MARKETING.${KEY}.FILTERS.SKIPPED`) },
]);

const statusVariant = status =>
  ({
    sent: 'success',
    failed: 'danger',
    pending: 'warning',
    skipped: 'neutral',
  })[status] || 'neutral';

const fetchEvents = async () => {
  isLoading.value = true;
  try {
    const { data } = await MarketingAPI.getEvents(
      statusFilter.value ? { status: statusFilter.value } : {}
    );
    events.value = data.events || [];
    counts.value = data.counts || {};
  } catch (error) {
    useAlert(t(`MARKETING.${KEY}.ERROR.LOAD`));
  } finally {
    isLoading.value = false;
  }
};

const retry = async event => {
  busyEventId.value = event.id;
  try {
    await MarketingAPI.retryEvent(event.id);
    useAlert(t(`MARKETING.${KEY}.SUCCESS.RETRY`));
    fetchEvents();
  } catch (error) {
    useAlert(t(`MARKETING.${KEY}.ERROR.RETRY`));
  } finally {
    busyEventId.value = null;
  }
};

const formatDate = value => (value ? new Date(value).toLocaleString() : '—');

const providerLabel = provider =>
  ({ meta_ads: 'Meta', google_ads: 'Google Ads', ga4: 'GA4' })[provider] ||
  provider;

onMounted(fetchEvents);
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
    <div
      role="region"
      tabindex="0"
      :aria-label="$t('MARKETING.PAGE_REGION')"
      class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
    >
      <div class="flex flex-wrap items-center gap-2">
        <button
          v-for="option in statusOptions"
          :key="option.value"
          type="button"
          class="rounded-full px-3 py-1.5 text-sm font-medium transition-colors"
          :class="
            statusFilter === option.value
              ? 'bg-ui-surface-active text-ui-text'
              : 'bg-ui-surface-muted/60 text-ui-text-muted hover:text-ui-text'
          "
          @click="
            statusFilter = option.value;
            fetchEvents();
          "
        >
          {{ option.label }}
          <span
            v-if="option.value && counts[option.value]"
            class="ml-1 text-xs text-ui-text-muted"
          >
            ({{ counts[option.value] }})
          </span>
        </button>
      </div>

      <DsCard>
        <div v-if="isLoading" class="p-6 text-sm text-ui-text-muted">
          {{ t(`MARKETING.${KEY}.LOADING`) }}
        </div>
        <DsEmptyState
          v-else-if="!events.length"
          icon="i-lucide-radio-tower"
          :title="t(`MARKETING.${KEY}.EMPTY.TITLE`)"
          :message="t(`MARKETING.${KEY}.EMPTY.MESSAGE`)"
        />
        <div v-else class="overflow-x-auto">
          <table class="w-full min-w-[720px] text-sm">
            <thead>
              <tr
                class="text-left text-xs uppercase tracking-wide text-ui-text-muted"
              >
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.EVENT`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.DEAL`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.PROVIDER`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.STATUS`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.SENT`) }}
                </th>
                <th class="px-4 py-3 text-right">
                  {{ t(`MARKETING.${KEY}.TABLE.ACTIONS`) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="event in events"
                :key="event.id"
                class="border-t border-ui-border-subtle/60"
              >
                <td class="px-4 py-3 font-medium text-ui-text">
                  {{ event.event_name }}
                  <div class="text-xs text-ui-text-muted">
                    {{ event.event_id }}
                  </div>
                </td>
                <td class="px-4 py-3 text-ui-text-muted">
                  <div>{{ event.deal_title || `#${event.crm_deal_id}` }}</div>
                  <div class="text-xs">{{ event.lead_name || '' }}</div>
                </td>
                <td class="px-4 py-3 text-ui-text-muted">
                  {{ providerLabel(event.provider) }}
                </td>
                <td class="px-4 py-3">
                  <DsBadge :variant="statusVariant(event.status)">
                    {{
                      t(`MARKETING.${KEY}.STATUS.${event.status.toUpperCase()}`)
                    }}
                  </DsBadge>
                  <div
                    v-if="event.error"
                    class="mt-1 max-w-56 truncate text-xs text-ui-danger-foreground"
                    :title="event.error"
                  >
                    {{ event.error }}
                  </div>
                </td>
                <td class="px-4 py-3 text-ui-text-muted">
                  {{ formatDate(event.sent_at || event.created_at) }}
                </td>
                <td class="px-4 py-3">
                  <div class="flex justify-end gap-2">
                    <DsButton
                      v-if="event.status === 'failed'"
                      size="sm"
                      variant="ghost"
                      :loading="busyEventId === event.id"
                      @click="retry(event)"
                    >
                      {{ t(`MARKETING.${KEY}.ACTIONS.RETRY`) }}
                    </DsButton>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </DsCard>
    </div>
  </section>
</template>

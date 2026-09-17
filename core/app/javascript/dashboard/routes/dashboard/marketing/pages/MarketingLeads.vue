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
const KEY = 'LEADS';

const leads = ref([]);
const counts = ref({});
const isLoading = ref(true);
const statusFilter = ref('new');
const busyLeadId = ref(null);

const statusOptions = computed(() => [
  { value: 'new', label: t(`MARKETING.${KEY}.FILTERS.NEW`) },
  { value: 'converted', label: t(`MARKETING.${KEY}.FILTERS.CONVERTED`) },
  { value: 'discarded', label: t(`MARKETING.${KEY}.FILTERS.DISCARDED`) },
  { value: '', label: t(`MARKETING.${KEY}.FILTERS.ALL`) },
]);

const statusVariant = status =>
  ({ converted: 'success', discarded: 'neutral', new: 'info' })[status] ||
  'neutral';

const fetchLeads = async () => {
  isLoading.value = true;
  try {
    const { data } = await MarketingAPI.getLeads(
      statusFilter.value ? { status: statusFilter.value } : {}
    );
    leads.value = data.leads || [];
    counts.value = data.counts || {};
  } catch (error) {
    useAlert(t(`MARKETING.${KEY}.ERROR.LOAD`));
  } finally {
    isLoading.value = false;
  }
};

const runAction = async (lead, action) => {
  busyLeadId.value = lead.id;
  try {
    const { data } = await action(lead.id);
    Object.assign(lead, data.lead);
    counts.value = { ...counts.value };
    useAlert(t(`MARKETING.${KEY}.SUCCESS.ACTION`));
  } catch (error) {
    useAlert(t(`MARKETING.${KEY}.ERROR.ACTION`));
  } finally {
    busyLeadId.value = null;
    fetchLeads();
  }
};

const discard = lead => runAction(lead, MarketingAPI.discardLead);
const convert = lead => runAction(lead, id => MarketingAPI.convertLead(id));

const formatDate = value => (value ? new Date(value).toLocaleString() : '—');

onMounted(fetchLeads);
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
            fetchLeads();
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
          v-else-if="!leads.length"
          icon="i-lucide-inbox"
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
                  {{ t(`MARKETING.${KEY}.TABLE.LEAD`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.CONTACT`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.CAMPAIGN`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.STATUS`) }}
                </th>
                <th class="px-4 py-3">
                  {{ t(`MARKETING.${KEY}.TABLE.RECEIVED`) }}
                </th>
                <th class="px-4 py-3 text-right">
                  {{ t(`MARKETING.${KEY}.TABLE.ACTIONS`) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="lead in leads"
                :key="lead.id"
                class="border-t border-ui-border-subtle/60"
              >
                <td class="px-4 py-3 font-medium text-ui-text">
                  {{ lead.display_name }}
                  <div class="text-xs text-ui-text-muted">
                    {{ lead.platform || 'meta' }} · {{ lead.form_id || '—' }}
                  </div>
                </td>
                <td class="px-4 py-3 text-ui-text-muted">
                  <div>{{ lead.email || '—' }}</div>
                  <div class="text-xs">{{ lead.phone || '' }}</div>
                </td>
                <td class="px-4 py-3 text-ui-text-muted">
                  {{ lead.campaign_name || lead.campaign_id || '—' }}
                </td>
                <td class="px-4 py-3">
                  <DsBadge :variant="statusVariant(lead.status)">
                    {{
                      t(`MARKETING.${KEY}.STATUS.${lead.status.toUpperCase()}`)
                    }}
                  </DsBadge>
                </td>
                <td class="px-4 py-3 text-ui-text-muted">
                  {{ formatDate(lead.created_at) }}
                </td>
                <td class="px-4 py-3">
                  <div class="flex justify-end gap-2">
                    <DsButton
                      v-if="lead.status === 'new' && !lead.crm_deal_id"
                      size="sm"
                      :loading="busyLeadId === lead.id"
                      @click="convert(lead)"
                    >
                      {{ t(`MARKETING.${KEY}.ACTIONS.CONVERT`) }}
                    </DsButton>
                    <DsButton
                      v-if="lead.status === 'new'"
                      size="sm"
                      variant="ghost"
                      :loading="busyLeadId === lead.id"
                      @click="discard(lead)"
                    >
                      {{ t(`MARKETING.${KEY}.ACTIONS.DISCARD`) }}
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

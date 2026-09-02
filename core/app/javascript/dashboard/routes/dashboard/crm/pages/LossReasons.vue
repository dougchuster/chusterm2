<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import CrmAPI from '../../../../api/crm';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsInput,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();

const lossReasons = ref([]);
const loading = ref(false);
const newReason = ref('');

async function loadReasons() {
  loading.value = true;
  try {
    const { data } = await CrmAPI.getLossReasons();
    lossReasons.value = data || [];
  } finally {
    loading.value = false;
  }
}

async function addReason() {
  if (!newReason.value.trim()) return;
  await CrmAPI.createLossReason({ name: newReason.value.trim() });
  newReason.value = '';
  await loadReasons();
}

onMounted(loadReasons);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="t('CRM.LOSS_REASONS.TITLE')"
      :breadcrumbs="[
        { label: t('CRM.LOSS_REASONS.BREADCRUMB') },
        { label: t('CRM.LOSS_REASONS.TITLE') },
      ]"
    />

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <DsCard as="section" aria-labelledby="loss-reasons-form-title">
        <h2
          id="loss-reasons-form-title"
          class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
        >
          {{ t('CRM.LOSS_REASONS.TITLE') }}
        </h2>
        <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
          {{ t('CRM.LOSS_REASONS.SUBTITLE') }}
        </p>
        <form
          class="mt-4 flex flex-col gap-2 sm:flex-row"
          @submit.prevent="addReason"
        >
          <DsInput
            v-model="newReason"
            type="text"
            :label="t('CRM.LOSS_REASONS.TITLE')"
            hide-label
            :placeholder="t('CRM.LOSS_REASONS.PLACEHOLDER')"
            class="min-w-0 flex-1"
          />
          <DsButton
            type="submit"
            variant="primary"
            :label="t('CRM.LOSS_REASONS.ADD')"
            :disabled="!newReason.trim()"
          />
        </form>
      </DsCard>

      <div
        v-if="loading"
        role="status"
        :aria-label="t('CRM.LOSS_REASONS.LOADING')"
        class="flex flex-col gap-2"
      >
        <span class="sr-only">{{ t('CRM.LOSS_REASONS.LOADING') }}</span>
        <DsSkeleton v-for="row in 3" :key="row" shape="block" class="h-12" />
      </div>

      <DsCard
        v-else-if="lossReasons.length"
        as="section"
        padding="none"
        :aria-label="t('CRM.LOSS_REASONS.TITLE')"
      >
        <ul class="m-0 flex list-none flex-col divide-y divide-ui-border-subtle p-0">
          <li
            v-for="reason in lossReasons"
            :key="reason.id"
            class="flex min-h-11 min-w-0 items-center justify-between gap-4 px-4 py-2"
          >
            <span class="truncate text-ui-body-sm text-ui-text">
              {{ reason.name }}
            </span>
            <DsBadge
              v-if="reason.legal_area"
              variant="neutral"
              :label="reason.legal_area"
              class="shrink-0"
            />
          </li>
        </ul>
      </DsCard>
    </div>
  </section>
</template>

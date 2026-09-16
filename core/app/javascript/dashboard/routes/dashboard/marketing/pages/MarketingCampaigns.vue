<script setup>
import { useI18n } from 'vue-i18n';
import { DsCard, DsEmptyState } from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

const { t } = useI18n();
const KEY = 'Campaigns'.toUpperCase();
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
        <DsEmptyState
          icon="i-lucide-construction"
          :title="t(`MARKETING.${KEY}.EMPTY.TITLE`)"
          :message="t(`MARKETING.${KEY}.EMPTY.MESSAGE`)"
        />
      </DsCard>
    </div>
  </section>
</template>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import EmailCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import SMSCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/SMSCampaignEmptyState.vue';

const getters = useStoreGetters();
const selectedCampaign = ref(null);
const [showEmailCampaignDialog, toggleEmailCampaignDialog] = useToggle();
const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);
const confirmDeleteCampaignDialogRef = ref(null);
const headerTitle = 'Campanhas de email';
const buttonLabel = 'Nova campanha';
const emptyTitle = 'Nenhuma campanha de email';
const emptySubtitle =
  'Crie campanhas por lista, segmento ou etiqueta usando caixas de email conectadas.';

const emailCampaigns = computed(
  () => getters['campaigns/getEmailCampaigns'].value
);
const hasNoEmailCampaigns = computed(
  () => emailCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="headerTitle"
    :button-label="buttonLabel"
    @click="toggleEmailCampaignDialog()"
    @close="toggleEmailCampaignDialog(false)"
  >
    <template #action>
      <EmailCampaignDialog
        v-if="showEmailCampaignDialog"
        @close="toggleEmailCampaignDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoEmailCampaigns"
      :campaigns="emailCampaigns"
      @delete="handleDelete"
    />
    <SMSCampaignEmptyState
      v-else
      :title="emptyTitle"
      :subtitle="emptySubtitle"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>

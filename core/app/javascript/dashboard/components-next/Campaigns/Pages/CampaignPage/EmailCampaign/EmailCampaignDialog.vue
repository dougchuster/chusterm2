<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import EmailCampaignForm from './EmailCampaignForm.vue';

const emit = defineEmits(['close']);
const store = useStore();
const dialogTitle = 'Nova campanha de email';

const addCampaign = async campaignDetails => {
  try {
    await store.dispatch('campaigns/create', campaignDetails);
    useAlert('Campanha de email criada com sucesso.');
  } catch {
    useAlert('Não foi possível criar a campanha de email.');
  }
};

const handleSubmit = campaignDetails => {
  addCampaign(campaignDetails);
};

const handleClose = () => emit('close');
</script>

<template>
  <div
    class="absolute top-10 z-50 max-h-[80vh] w-[28rem] min-w-0 overflow-y-auto rounded-xl border border-ui-border-subtle bg-n-alpha-3 shadow-md backdrop-blur-[100px] ltr:right-0 rtl:left-0"
  >
    <div class="flex flex-col gap-6 p-6">
      <h3 class="flex-shrink-0 text-base font-medium text-n-slate-12">
        {{ dialogTitle }}
      </h3>
      <EmailCampaignForm @submit="handleSubmit" @cancel="handleClose" />
    </div>
  </div>
</template>

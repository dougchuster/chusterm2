<script setup>
import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { useAdmin } from 'dashboard/composables/useAdmin';

const { isAdmin } = useAdmin();
const getters = useStoreGetters();
const accountId = getters.getCurrentAccountId;

const integrationId = 'linear';

const actionURL = computed(() =>
  frontendURL(
    `accounts/${accountId.value}/settings/integrations/${integrationId}`
  )
);

const openLinearAccount = () => {
  window.open(actionURL.value, '_blank');
};
</script>

<template>
  <div
    class="flex flex-col rounded-xl bg-ds-bg-elevated p-3 text-ds-fg-default"
  >
    <div
      class="mb-3 grid size-12 place-content-center rounded-xl bg-ds-bg-sunken p-2 ring-1 ring-inset ring-ds-border-subtle"
    >
      <img
        :src="`/dashboard/images/integrations/${integrationId}.png`"
        alt=""
        class="size-full object-contain dark:hidden"
      />
      <img
        :src="`/dashboard/images/integrations/${integrationId}-dark.png`"
        alt=""
        class="hidden size-full object-contain dark:block"
      />
    </div>

    <div class="flex-1 mb-4">
      <h3 class="mb-1.5 font-manrope text-sm font-semibold text-ds-fg-default">
        {{ $t('INTEGRATION_SETTINGS.LINEAR.CTA.TITLE') }}
      </h3>
      <p v-if="isAdmin" class="text-sm leading-5 text-ds-fg-muted">
        {{ $t('INTEGRATION_SETTINGS.LINEAR.CTA.DESCRIPTION') }}
      </p>
      <p v-else class="text-sm leading-5 text-ds-fg-muted">
        {{ $t('INTEGRATION_SETTINGS.LINEAR.CTA.AGENT_DESCRIPTION') }}
      </p>
    </div>

    <NextButton
      v-if="isAdmin"
      type="button"
      color="primary"
      variant="faded"
      @click="openLinearAccount"
    >
      {{ $t('INTEGRATION_SETTINGS.LINEAR.CTA.BUTTON_TEXT') }}
    </NextButton>
  </div>
</template>

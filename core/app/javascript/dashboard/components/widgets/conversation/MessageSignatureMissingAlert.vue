<script setup>
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';

const router = useRouter();

const openProfileSettings = () => {
  return router.push({ name: 'profile_settings_index' });
};
</script>

<template>
  <div
    role="status"
    class="my-0 flex max-h-[8vh] items-baseline justify-between overflow-auto rounded-lg bg-ds-state-warning-soft px-2 py-1 text-ds-fg-default ring-1 ring-inset ring-ds-state-warning/25"
  >
    <p class="w-fit !m-0">
      {{ $t('CONVERSATION.FOOTER.MESSAGE_SIGNATURE_NOT_CONFIGURED') }}

      <Button
        type="button"
        link
        color="primary"
        :label="$t('CONVERSATION.FOOTER.CLICK_HERE')"
        @click="openProfileSettings"
      />
    </p>
  </div>
</template>

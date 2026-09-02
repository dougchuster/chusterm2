<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CreatePortalDialog from 'dashboard/components-next/HelpCenter/PortalSwitcher/CreatePortalDialog.vue';

const createPortalDialogRef = ref(null);
const openDialog = () => {
  createPortalDialogRef.value.dialogRef.open();
};

const router = useRouter();

const onPortalCreate = ({ slug: portalSlug, locale }) => {
  router.push({
    name: 'portals_articles_index',
    params: { portalSlug, locale },
  });
};
</script>

<template>
  <EmptyStateLayout
    :title="$t('HELP_CENTER.TITLE')"
    :subtitle="$t('HELP_CENTER.NEW_PAGE.DESCRIPTION')"
    class="bg-n-surface-1"
  >
    <template #actions>
      <Button
        :label="$t('HELP_CENTER.NEW_PAGE.CREATE_PORTAL_BUTTON')"
        icon="i-lucide-plus"
        @click="openDialog"
      />
      <CreatePortalDialog
        ref="createPortalDialogRef"
        @create="onPortalCreate"
      />
    </template>
  </EmptyStateLayout>
</template>

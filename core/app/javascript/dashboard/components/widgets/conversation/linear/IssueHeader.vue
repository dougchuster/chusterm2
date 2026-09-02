<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  identifier: {
    type: String,
    required: true,
  },
  issueUrl: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['unlinkIssue']);
const { t } = useI18n();

const openIssueLabel = computed(() => `Abrir ${props.identifier} no Linear`);

const unlinkIssue = () => {
  emit('unlinkIssue');
};

const openIssue = () => {
  window.open(props.issueUrl, '_blank');
};
</script>

<template>
  <div class="flex items-center justify-between">
    <div
      class="flex items-center gap-2 rounded-lg bg-ds-bg-sunken px-2 py-1.5 ring-1 ring-inset ring-ds-border-subtle"
    >
      <div class="flex items-center gap-1">
        <span class="i-logos-linear-icon size-4" aria-hidden="true" />
        <span class="text-xs font-semibold text-ds-fg-default">
          {{ identifier }}
        </span>
      </div>
      <span class="h-3 w-px bg-ds-border-subtle" />

      <Button
        type="button"
        :aria-label="openIssueLabel"
        link
        xs
        color="primary"
        icon="i-lucide-arrow-up-right"
        class="size-4"
        @click="openIssue"
      />
    </div>

    <Button
      type="button"
      :aria-label="t('INTEGRATION_SETTINGS.LINEAR.UNLINK.TITLE')"
      ghost
      xs
      color="primary"
      icon="i-lucide-unlink"
      @click="unlinkIssue"
    />
  </div>
</template>

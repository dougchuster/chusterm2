<script setup>
import { useI18n } from 'vue-i18n';
import { getI18nKey } from 'dashboard/routes/dashboard/settings/helper/settingsHelper';

import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';

defineProps({
  roles: {
    type: Array,
    required: true,
  },
  loading: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const getFormattedPermissions = role => {
  return role.permissions
    .map(event => t(getI18nKey('CUSTOM_ROLE.PERMISSIONS', event)))
    .join(', ');
};
</script>

<template>
  <BaseTableRow
    v-for="customRole in roles"
    :key="customRole.id"
    :item="customRole"
  >
    <template #default>
      <BaseTableCell>
        <span
          class="block truncate text-[0.96rem] font-semibold tracking-[0.01em] text-n-slate-12"
        >
          {{ customRole.name }}
        </span>
      </BaseTableCell>

      <BaseTableCell>
        <span class="block text-sm leading-6 text-n-slate-11">
          {{ customRole.description }}
        </span>
      </BaseTableCell>

      <BaseTableCell>
        <span class="block text-sm leading-6 text-n-slate-11">
          {{ getFormattedPermissions(customRole) }}
        </span>
      </BaseTableCell>

      <BaseTableCell align="end" class="w-24">
        <div
          class="flex justify-end gap-2 rounded-full border border-n-alpha-1 bg-n-alpha-1/40 px-2 py-1.5"
        >
          <Button
            v-tooltip.top="$t('CUSTOM_ROLE.EDIT.BUTTON_TEXT')"
            icon="i-woot-edit-pen"
            slate
            sm
            @click="emit('edit', customRole)"
          />
          <Button
            v-tooltip.top="$t('CUSTOM_ROLE.DELETE.BUTTON_TEXT')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:bg-n-ruby-2 hover:enabled:text-n-ruby-11"
            :is-loading="loading[customRole.id]"
            @click="emit('delete', customRole)"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>

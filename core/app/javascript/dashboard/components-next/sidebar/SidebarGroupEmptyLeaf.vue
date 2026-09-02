<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <li
    class="pointer-events-none grid h-8 select-none place-content-center rounded-lg border border-dashed border-ds-shell-border px-3 py-1 text-center text-xs text-ds-shell-muted"
  >
    <slot>{{ t('SIDEBAR.NO_ITEMS') }}</slot>
  </li>
</template>

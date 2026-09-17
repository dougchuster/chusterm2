<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
// Public-dir path: binding dinâmico proposital — `src` estático faz o Vite
// tentar resolver o asset em build-time e falhar.
const fallbackLogo = '/brand-assets/logo_thumbnail.svg';
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    alt=""
    aria-hidden="true"
    :src="globalConfig.logoThumbnail"
  />
  <img v-else v-bind="attrs" :src="fallbackLogo" alt="" aria-hidden="true" />
</template>

<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    alt=""
    aria-hidden="true"
    :src="globalConfig.logoThumbnail"
  />
  <svg
    v-else
    v-once
    aria-hidden="true"
    v-bind="attrs"
    width="24"
    height="24"
    viewBox="0 0 64 64"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <defs>
      <linearGradient
        id="chuster-comp-grad"
        x1="0%"
        y1="0%"
        x2="100%"
        y2="100%"
      >
        <stop offset="0%" stop-color="#00eefc" />
        <stop offset="50%" stop-color="#6366f1" />
        <stop offset="100%" stop-color="#df8eff" />
      </linearGradient>
      <linearGradient
        id="chuster-comp-accent"
        x1="100%"
        y1="0%"
        x2="0%"
        y2="100%"
      >
        <stop offset="0%" stop-color="#df8eff" />
        <stop offset="100%" stop-color="#a855f7" />
      </linearGradient>
      <linearGradient
        id="chuster-comp-cyan"
        x1="0%"
        y1="100%"
        x2="100%"
        y2="0%"
      >
        <stop offset="0%" stop-color="#06b6d4" />
        <stop offset="100%" stop-color="#00eefc" />
      </linearGradient>
    </defs>
    <path
      d="M32 8 L51 19.5 V42.5 L32 54 L13 42.5 V19.5 Z"
      stroke="url(#chuster-comp-grad)"
      stroke-width="3"
      stroke-linecap="round"
      stroke-linejoin="round"
      stroke-dasharray="65 20"
    />
    <path
      d="M42 21 C45.5 25.5 45.5 38.5 42 43 C37.5 47.5 26.5 47.5 22 43 C17.5 38.5 17.5 25.5 22 21 C26.5 16.5 35.5 16.5 40 19"
      stroke="url(#chuster-comp-cyan)"
      stroke-width="3"
      stroke-linecap="round"
    />
    <path
      d="M23 42 L32 32 L41 42 M32 22 V42 M32 22 C36.5 22 39 24 39 27.5 C39 31 36.5 33 32 33"
      stroke="url(#chuster-comp-accent)"
      stroke-width="3"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
    <circle cx="32" cy="8" r="3" fill="#00eefc" />
    <circle cx="51" cy="42.5" r="2.5" fill="#df8eff" />
    <circle cx="13" cy="42.5" r="2.5" fill="#6366f1" />
    <circle cx="32" cy="32" r="2" fill="#ffffff" />
  </svg>
</template>

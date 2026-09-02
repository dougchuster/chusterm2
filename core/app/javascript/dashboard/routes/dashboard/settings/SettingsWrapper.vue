<script setup>
import { useRoute } from 'vue-router';

defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();
</script>

<template>
  <div
    class="m-0 flex h-full w-full flex-col overflow-auto bg-n-surface-1 px-3 pb-8 pt-3 text-n-slate-12 sm:px-6 sm:pt-4"
  >
    <div class="flex items-start w-full max-w-5xl mx-auto">
      <router-view v-slot="{ Component }">
        <keep-alive v-if="keepAlive">
          <component :is="Component" :key="route.fullPath" />
        </keep-alive>
        <component :is="Component" v-else :key="route.fullPath" />
      </router-view>
    </div>
  </div>
</template>

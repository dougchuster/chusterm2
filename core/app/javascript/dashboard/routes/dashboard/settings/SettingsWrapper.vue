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
    class="settings-wrapper-shell flex flex-col w-full h-full m-0 pb-8 pt-4 px-6 overflow-auto"
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

<style scoped>
.settings-wrapper-shell {
  background: rgb(var(--bg-app));
  color: rgb(var(--slate-12));
}

@media (max-width: 640px) {
  .settings-wrapper-shell {
    padding-inline: 0.75rem;
    padding-top: 0.75rem;
  }
}
</style>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsHeader from './SettingsHeader.vue';
const props = defineProps({
  headerTitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  keepAlive: { type: Boolean, default: true },
  showBackButton: { type: Boolean, default: false },
  backUrl: { type: [String, Object], default: '' },
});

const { t } = useI18n();

const showSettingsHeader = computed(
  () => props.headerTitle || props.icon || props.showBackButton
);
</script>

<template>
  <div
    class="settings-screen-shell flex h-full w-full flex-col overflow-hidden bg-n-surface-1 text-n-slate-12"
  >
    <div
      class="settings-screen-content flex min-h-0 flex-1 flex-col px-3 pb-6 pt-3 sm:px-6 sm:pt-4"
    >
      <SettingsHeader
        v-if="showSettingsHeader"
        :icon="icon"
        :header-title="t(headerTitle)"
        :show-back-button="showBackButton"
        :back-url="backUrl"
        class="z-20 mx-auto w-full max-w-7xl"
      />

      <router-view
        v-slot="{ Component }"
        class="min-h-0 flex-1 overflow-hidden"
      >
        <div
          class="settings-screen-inner mx-auto flex h-full w-full max-w-7xl min-h-0 flex-col"
        >
          <component :is="Component" v-if="!keepAlive" :key="$route.fullPath" />
          <keep-alive v-else>
            <component :is="Component" :key="$route.fullPath" />
          </keep-alive>
        </div>
      </router-view>
    </div>
  </div>
</template>

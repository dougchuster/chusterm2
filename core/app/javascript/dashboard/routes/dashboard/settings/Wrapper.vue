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
    class="settings-shell settings-screen-shell flex h-full w-full flex-col overflow-hidden"
  >
    <div class="settings-shell__ambient" aria-hidden="true">
      <div class="settings-shell__orb settings-shell__orb--primary" />
      <div class="settings-shell__orb settings-shell__orb--secondary" />
      <div class="settings-shell__grid" />
    </div>

    <div
      class="settings-screen-content relative z-10 flex min-h-0 flex-1 flex-col px-4 pb-6 pt-4 sm:px-6 lg:px-8"
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

<style scoped>
.settings-shell {
  position: relative;
  background: rgb(var(--bg-app));
  color: rgb(var(--slate-12));
}

.settings-shell__ambient {
  display: none;
}

.settings-shell__orb {
  display: none;
}

.settings-shell__orb--primary {
  top: -7rem;
  right: -6rem;
  width: 20rem;
  height: 20rem;
  background: rgba(var(--shell-glow-primary));
}

.settings-shell__orb--secondary {
  top: 18%;
  left: -8rem;
  width: 22rem;
  height: 22rem;
  background: rgba(var(--shell-glow-tertiary));
}

.settings-shell__grid {
  display: none;
}
</style>

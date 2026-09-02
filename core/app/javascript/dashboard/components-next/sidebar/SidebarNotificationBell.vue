<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

const emit = defineEmits(['openNotificationPanel']);

const notificationMetadata = useMapGetter('notifications/getMeta');
const route = useRoute();
const unreadCount = computed(() => {
  if (!notificationMetadata.value.unreadCount) {
    return '';
  }

  return notificationMetadata.value.unreadCount < 100
    ? `${notificationMetadata.value.unreadCount}`
    : '99+';
});

function openNotificationPanel() {
  if (route.name !== 'notifications_index') {
    emit('openNotificationPanel');
  }
}
</script>

<template>
  <button
    type="button"
    class="relative grid size-10 flex-shrink-0 place-content-center rounded-xl text-ds-shell-muted transition-colors hover:bg-ds-shell-hover hover:text-ds-shell-fg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
    :aria-label="$t('SIDEBAR.NOTIFICATIONS')"
    @click="openNotificationPanel"
  >
    <span class="i-lucide-bell size-4" aria-hidden="true" />
    <span
      v-if="unreadCount"
      class="absolute -right-1 -top-1 grid min-h-4 min-w-4 place-items-center rounded-full bg-ds-shell-danger px-1 text-[9px] font-semibold leading-none text-white"
    >
      {{ unreadCount }}
    </span>
  </button>
</template>

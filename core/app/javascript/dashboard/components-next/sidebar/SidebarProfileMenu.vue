<script setup>
import { computed } from 'vue';
import Auth from 'dashboard/api/auth';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import SidebarProfileMenuStatus from './SidebarProfileMenuStatus.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSeparator,
  DropdownItem,
} from 'next/dropdown-menu/base';
import CustomBrandPolicyWrapper from '../../components/CustomBrandPolicyWrapper.vue';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'openKeyShortcutModal']);

defineOptions({
  inheritAttrs: false,
});

const { t } = useI18n();

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const accountId = useMapGetter('getCurrentAccountId');
const globalConfig = useMapGetter('globalConfig/get');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showChatSupport = computed(() => {
  return (
    isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.CONTACT_ChusteRM_SUPPORT_TEAM
    ) && globalConfig.value.chustermInboxToken
  );
});

const menuItems = computed(() => {
  return [
    {
      show: showChatSupport.value,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.CONTACT_SUPPORT'),
      icon: 'i-lucide-life-buoy',
      click: () => {
        window.$ChusteRM.toggle();
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.KEYBOARD_SHORTCUTS'),
      icon: 'i-lucide-keyboard',
      click: () => {
        emit('openKeyShortcutModal');
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.PROFILE_SETTINGS'),
      icon: 'i-lucide-user-pen',
      link: { name: 'profile_settings_index' },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.APPEARANCE'),
      icon: 'i-lucide-palette',
      click: () => {
        const ninja = document.querySelector('ninja-keys');
        ninja.open({ parent: 'appearance_settings' });
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.DOCS'),
      icon: 'i-lucide-book',
      link: 'https://www.chusterm.com/hc/user-guide/en',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.CHANGELOG'),
      icon: 'i-lucide-scroll-text',
      link: 'https://www.chusterm.com/changelog/',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: currentUser.value.type === 'SuperAdmin',
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.SUPER_ADMIN_CONSOLE'),
      icon: 'i-lucide-castle',
      link: '/super_admin',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.LOGOUT'),
      icon: 'i-lucide-power',
      click: Auth.logout,
    },
  ];
});

const allowedMenuItems = computed(() => {
  return menuItems.value.filter(item => item.show);
});

const availabilityLabel = computed(() => {
  const labelByAvailability = {
    online: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
    busy: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
    offline: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
  };

  return (
    labelByAvailability[currentUserAvailability.value] ??
    labelByAvailability.offline
  );
});
</script>

<template>
  <DropdownContainer
    class="relative min-w-0"
    :class="isCollapsed ? 'w-auto' : 'w-full'"
    @close="emit('close')"
  >
    <template #trigger="{ toggle, isOpen }">
      <button
        type="button"
        class="flex min-h-14 items-center gap-3 rounded-2xl border-0 bg-transparent p-2 text-left text-ds-shell-fg transition duration-150 hover:bg-ds-shell-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
        :class="[
          isOpen ? 'bg-ds-shell-hover' : '',
          isCollapsed ? 'justify-center' : 'w-full',
        ]"
        :title="isCollapsed ? currentUser.available_name : undefined"
        aria-haspopup="menu"
        :aria-expanded="isOpen"
        @click="toggle"
      >
        <Avatar
          :size="40"
          :name="currentUser.available_name"
          :src="currentUser.avatar_url"
          :status="currentUserAvailability"
          class="flex-shrink-0 ring-2 ring-ds-shell-accent/20"
          rounded-full
        />
        <div v-if="!isCollapsed" class="min-w-0">
          <div
            class="truncate font-inter text-[0.86rem] font-semibold leading-5 text-ds-shell-fg"
          >
            {{ currentUser.available_name }}
          </div>
          <div
            class="truncate font-inter text-[0.7rem] leading-4 text-ds-shell-muted"
          >
            {{ availabilityLabel }}
          </div>
        </div>
      </button>
    </template>
    <DropdownBody
      class="bottom-16 z-50 mb-2 w-80 overflow-hidden rounded-2xl bg-ds-shell-panel-strong shadow-2xl shadow-black/25 ring-1 ring-inset ring-ds-shell-border ltr:left-0 rtl:right-0"
    >
      <SidebarProfileMenuStatus />
      <DropdownSeparator />
      <template v-for="item in allowedMenuItems" :key="item.label">
        <CustomBrandPolicyWrapper
          :show-on-custom-branded-instance="item.showOnCustomBrandedInstance"
        >
          <DropdownItem v-if="item.show" v-bind="item" />
        </CustomBrandPolicyWrapper>
      </template>
    </DropdownBody>
  </DropdownContainer>
</template>

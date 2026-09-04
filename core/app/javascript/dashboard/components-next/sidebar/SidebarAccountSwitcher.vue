<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import Logo from 'next/icon/Logo.vue';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';

defineProps({
  isCollapsed: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['showCreateAccountModal']);

const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');

const userAccounts = useMapGetter('getUserAccounts');

const showAccountSwitcher = computed(
  () => userAccounts.value.length > 1 && currentAccount.value.name
);

const sortedCurrentUserAccounts = computed(() => {
  return [...(currentUser.value.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  const accountUrl = `/app/accounts/${newId}/dashboard`;
  window.location.href = accountUrl;
};

const emitNewAccount = () => {
  emit('showCreateAccountModal');
};
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle, isOpen }">
      <!-- Collapsed view: Logo trigger -->
      <button
        v-if="isCollapsed"
        type="button"
        class="grid size-11 flex-shrink-0 cursor-pointer place-content-center rounded-2xl border-0 bg-ds-shell-panel text-ds-shell-fg ring-1 ring-inset ring-ds-shell-border transition duration-150 hover:bg-ds-shell-hover hover:ring-ds-shell-accent/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
        :class="{ 'bg-ds-shell-hover ring-ds-shell-accent/40': isOpen }"
        :title="currentAccount.name"
        :aria-label="currentAccount.name"
        aria-haspopup="menu"
        aria-controls="account-options"
        :aria-expanded="isOpen"
        @click="toggle"
      >
        <Logo class="size-8" />
      </button>
      <!-- Expanded view: Account name trigger -->
      <button
        v-else
        id="sidebar-account-switcher"
        type="button"
        :data-account-id="accountId"
        aria-haspopup="menu"
        aria-controls="account-options"
        :aria-expanded="isOpen"
        :aria-disabled="!showAccountSwitcher"
        :disabled="!showAccountSwitcher"
        class="flex min-h-11 w-full items-center justify-between gap-3 rounded-xl border-0 bg-ds-shell-panel px-3 py-1.5 text-ds-shell-fg shadow-sm shadow-black/5 transition duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus disabled:cursor-default"
        :class="[
          isOpen && 'bg-ds-shell-hover ring-ds-shell-accent/40',
          showAccountSwitcher
            ? 'cursor-pointer hover:bg-ds-shell-hover hover:ring-ds-shell-accent/40'
            : 'cursor-default',
        ]"
        @click="() => showAccountSwitcher && toggle()"
      >
        <span class="flex min-w-0 flex-col text-start">
          <span
            class="font-inter text-[0.625rem] font-semibold uppercase leading-4 tracking-[0.12em] text-ds-shell-muted"
          >
            {{ t('SIDEBAR.WORKSPACE') }}
          </span>
          <span
            class="truncate font-inter text-[0.86rem] font-semibold leading-5 text-ds-shell-fg"
            aria-live="polite"
          >
            {{ currentAccount.name }}
          </span>
        </span>

        <span
          v-if="showAccountSwitcher"
          aria-hidden="true"
          class="i-lucide-chevrons-up-down size-4 flex-shrink-0 text-ds-shell-muted"
        />
      </button>
    </template>
    <DropdownBody
      v-if="showAccountSwitcher || isCollapsed"
      id="account-options"
      class="z-50 min-w-80 overflow-hidden rounded-2xl bg-ds-shell-panel-strong shadow-2xl shadow-black/25 ring-1 ring-inset ring-ds-shell-border"
    >
      <DropdownSection :title="t('SIDEBAR_ITEMS.SWITCH_ACCOUNT')">
        <DropdownItem
          v-for="account in sortedCurrentUserAccounts"
          :id="`account-${account.id}`"
          :key="account.id"
          class="cursor-pointer"
          :aria-current="account.id === accountId ? 'true' : undefined"
          role="menuitem"
          :click="() => onChangeAccount(account.id)"
        >
          <template #label>
            <div class="flex items-center gap-2 text-left rtl:text-right">
              <span
                class="min-w-0 max-w-36 truncate text-ds-shell-fg"
                :title="account.name"
              >
                {{ account.name }}
              </span>
              <div
                class="h-3 w-px flex-shrink-0 bg-ds-shell-divider"
                aria-hidden="true"
              />
              <span
                class="max-w-24 truncate capitalize text-ds-shell-muted"
                :title="account.name"
              >
                {{
                  account.custom_role_id
                    ? account.custom_role.name
                    : account.role
                }}
              </span>
            </div>
            <Icon
              v-show="account.id === accountId"
              icon="i-lucide-check"
              class="size-5 text-ds-shell-secondary"
              aria-hidden="true"
            />
          </template>
        </DropdownItem>
      </DropdownSection>
      <DropdownItem
        v-if="globalConfig.createNewAccountFromDashboard"
        :label="t('CREATE_ACCOUNT.NEW_ACCOUNT')"
        icon="i-lucide-plus"
        role="menuitem"
        :click="emitNewAccount"
      />
    </DropdownBody>
  </DropdownContainer>
</template>

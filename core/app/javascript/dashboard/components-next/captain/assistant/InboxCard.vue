<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, reactive, watch } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

import { useMapGetter, useStore } from 'dashboard/composables/store';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { INBOX_TYPES, getInboxIconByType } from 'dashboard/helper/inbox';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  inbox: {
    type: Object,
    required: true,
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['action', 'updateConfig']);

const { t } = useI18n();
const store = useStore();

const [showActionsDropdown, toggleDropdown] = useToggle();

const localConfig = reactive({
  enabled: true,
  autoReplyEnabled: true,
  aiMode: 'auto',
  handoffStrategy: 'human_request',
  routingConfig: {},
  areaOwnerIds: {},
});

const LEGAL_AREAS = [
  ['previdenciario', 'Previdenciario'],
  ['trabalhista', 'Trabalhista'],
  ['civel', 'Civel'],
  ['consumidor', 'Consumidor'],
  ['familia', 'Familia'],
  ['imobiliario', 'Imobiliario'],
  ['criminal', 'Penal'],
  ['tributario', 'Tributario'],
  ['empresarial', 'Empresarial'],
];

const agentList = useMapGetter('agents/getVerifiedAgents');

const inboxName = computed(() => {
  const inbox = props.inbox;
  if (!inbox?.name) {
    return '';
  }

  const isTwilioChannel = inbox.channel_type === INBOX_TYPES.TWILIO;
  const isWhatsAppChannel = inbox.channel_type === INBOX_TYPES.WHATSAPP;
  const isEmailChannel = inbox.channel_type === INBOX_TYPES.EMAIL;

  if (isTwilioChannel || isWhatsAppChannel) {
    const identifier = inbox.messaging_service_sid || inbox.phone_number;
    return identifier ? `${inbox.name} (${identifier})` : inbox.name;
  }

  if (isEmailChannel && inbox.email) {
    return `${inbox.name} (${inbox.email})`;
  }

  return inbox.name;
});

const menuItems = computed(() => [
  {
    label: t('CAPTAIN.INBOXES.OPTIONS.DISCONNECT'),
    value: 'delete',
    action: 'delete',
    icon: 'i-lucide-trash',
  },
]);

const captainInboxConfig = computed(() => props.inbox.captain_inbox || {});

const aiModeOptions = computed(() => [
  { value: 'auto', label: t('CAPTAIN.INBOXES.FORM.AI_MODE.AUTO') },
  {
    value: 'supervised',
    label: t('CAPTAIN.INBOXES.FORM.AI_MODE.SUPERVISED'),
  },
  { value: 'paused', label: t('CAPTAIN.INBOXES.FORM.AI_MODE.PAUSED') },
  {
    value: 'human_only',
    label: t('CAPTAIN.INBOXES.FORM.AI_MODE.HUMAN_ONLY'),
  },
]);

const handoffStrategyOptions = computed(() => [
  {
    value: 'human_request',
    label: t('CAPTAIN.INBOXES.FORM.HANDOFF.HUMAN_REQUEST'),
  },
  {
    value: 'manual_only',
    label: t('CAPTAIN.INBOXES.FORM.HANDOFF.MANUAL_ONLY'),
  },
]);

const isResponsible = computed(() => !!captainInboxConfig.value.enabled);
const isAutoReplyActive = computed(
  () =>
    !!captainInboxConfig.value.enabled &&
    !!captainInboxConfig.value.auto_reply_enabled &&
    captainInboxConfig.value.ai_mode === 'auto'
);

const agentOptions = computed(() =>
  (agentList.value || []).map(agent => ({
    value: String(agent.id),
    label: agent.name || agent.email,
  }))
);

const routingTitle = 'Roteamento CRM por area';
const emptyOwnerLabel = 'Sem responsável fixo';

const areaOwnerOptions = computed(() => [
  { value: '', label: emptyOwnerLabel },
  ...agentOptions.value,
]);

const icon = computed(() => {
  const { medium, channel_type: type } = props.inbox;
  return getInboxIconByType(type, medium, 'line');
});

const handleAction = ({ action, value }) => {
  toggleDropdown(false);
  emit('action', { action, value, id: props.id });
};

const cleanAreaOwnerIds = () => {
  return Object.entries(localConfig.areaOwnerIds).reduce(
    (acc, [area, ownerId]) => {
      if (ownerId) acc[area] = Number(ownerId);
      return acc;
    },
    {}
  );
};

const handleSaveConfig = () => {
  emit('updateConfig', {
    inboxId: props.id,
    enabled: localConfig.enabled,
    autoReplyEnabled: localConfig.autoReplyEnabled,
    aiMode: localConfig.aiMode,
    handoffStrategy: localConfig.handoffStrategy,
    routingConfig: {
      ...localConfig.routingConfig,
      area_owner_ids: cleanAreaOwnerIds(),
    },
  });
};

const applyRoutingConfig = config => {
  localConfig.routingConfig = { ...(config || {}) };
  const ownerIds =
    localConfig.routingConfig.area_owner_ids ||
    localConfig.routingConfig.legal_area_owner_ids ||
    localConfig.routingConfig.area_owners ||
    {};

  localConfig.areaOwnerIds = LEGAL_AREAS.reduce((acc, [area]) => {
    acc[area] = ownerIds[area] ? String(ownerIds[area]) : '';
    return acc;
  }, {});
};

watch(
  captainInboxConfig,
  config => {
    localConfig.enabled = config.enabled ?? true;
    localConfig.autoReplyEnabled = config.auto_reply_enabled ?? true;
    localConfig.aiMode = config.ai_mode || 'auto';
    localConfig.handoffStrategy = config.handoff_strategy || 'human_request';
    applyRoutingConfig(config.routing_config);
  },
  { immediate: true }
);

onMounted(() => {
  if (!agentList.value?.length) {
    store.dispatch('agents/get');
  }
});
</script>

<template>
  <CardLayout>
    <div class="flex flex-col w-full gap-4">
      <div class="flex justify-between w-full gap-1">
        <span class="flex min-w-0 items-center gap-2 text-base text-n-slate-12">
          <span :class="icon" class="size-4 shrink-0" aria-hidden="true" />
          <span class="truncate">{{ inboxName }}</span>
        </span>
        <div class="flex items-center gap-2">
          <Policy
            v-on-clickaway="() => toggleDropdown(false)"
            :permissions="['administrator']"
            class="relative flex items-center group"
          >
            <Button
              icon="i-lucide-ellipsis-vertical"
              color="slate"
              size="xs"
              class="rounded-md group-hover:bg-n-alpha-2"
              @click="toggleDropdown()"
            />
            <DropdownMenu
              v-if="showActionsDropdown"
              :menu-items="menuItems"
              class="mt-1 ltr:right-0 rtl:left-0 top-full"
              @action="handleAction($event)"
            />
          </Policy>
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        <span
          class="px-2 py-1 text-xs font-medium rounded-md"
          :class="
            isResponsible
              ? 'bg-n-blue-3 text-n-blue-11'
              : 'bg-n-slate-3 text-n-slate-11'
          "
        >
          {{ t('CAPTAIN.INBOXES.CONFIG.RESPONSIBLE') }}
        </span>
        <span
          class="px-2 py-1 text-xs font-medium rounded-md"
          :class="
            isAutoReplyActive
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-slate-3 text-n-slate-11'
          "
        >
          {{ t('CAPTAIN.INBOXES.CONFIG.AUTO_REPLY') }}
        </span>
      </div>

      <Policy :permissions="['administrator']" class="flex flex-col gap-4">
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CAPTAIN.INBOXES.FORM.AI_MODE.LABEL') }}
            </span>
            <Select
              v-model="localConfig.aiMode"
              :options="aiModeOptions"
              class="w-full [&>select]:w-full"
            />
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CAPTAIN.INBOXES.FORM.HANDOFF.LABEL') }}
            </span>
            <Select
              v-model="localConfig.handoffStrategy"
              :options="handoffStrategyOptions"
              class="w-full [&>select]:w-full"
            />
          </label>
        </div>

        <div
          class="flex flex-col gap-3 p-3 rounded-lg bg-n-alpha-2 md:flex-row md:items-center md:justify-between"
        >
          <label class="flex items-center justify-between gap-3">
            <span class="text-sm text-n-slate-12">
              {{ t('CAPTAIN.INBOXES.FORM.ENABLED.LABEL') }}
            </span>
            <Switch v-model="localConfig.enabled" />
          </label>

          <label class="flex items-center justify-between gap-3">
            <span class="text-sm text-n-slate-12">
              {{ t('CAPTAIN.INBOXES.FORM.AUTO_REPLY.LABEL') }}
            </span>
            <Switch v-model="localConfig.autoReplyEnabled" />
          </label>
        </div>

        <div class="flex flex-col gap-3 rounded-lg border border-n-weak p-3">
          <div
            class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
          >
            <span class="i-lucide-route size-4 text-n-slate-10" />
            {{ routingTitle }}
          </div>
          <div class="grid grid-cols-1 gap-2 md:grid-cols-2">
            <label
              v-for="[area, label] in LEGAL_AREAS"
              :key="area"
              class="flex flex-col gap-1"
            >
              <span class="text-xs font-medium text-n-slate-11">
                {{ label }}
              </span>
              <Select
                v-model="localConfig.areaOwnerIds[area]"
                :options="areaOwnerOptions"
                block
              />
            </label>
          </div>
        </div>

        <div class="flex justify-end">
          <Button
            :label="t('CAPTAIN.INBOXES.CONFIG.SAVE')"
            size="sm"
            :is-loading="isUpdating"
            :disabled="isUpdating"
            @click="handleSaveConfig"
          />
        </div>
      </Policy>
    </div>
  </CardLayout>
</template>

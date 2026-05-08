<script setup>
/* global axios */
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import QRCode from 'qrcode';
import EmptyState from '../../../../components/widgets/EmptyState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DuplicateInboxBanner from './channels/instagram/DuplicateInboxBanner.vue';
import EmailInboxFinish from './channels/emailChannels/EmailInboxFinish.vue';
import { useInbox } from 'dashboard/composables/useInbox';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const qrCodes = reactive({
  whatsapp: '',
  messenger: '',
  telegram: '',
});

const evolutionQrCode = ref('');
const evolutionPairingCode = ref('');
const evolutionQrLoading = ref(false);
const evolutionQrError = ref('');
const evolutionQrStatus = ref('');
const evolutionHealth = ref(null);
let evolutionQrTimer = null;
let evolutionQrAttempts = 0;
const MAX_EVOLUTION_QR_ATTEMPTS = 30;

const currentInbox = computed(() =>
  store.getters['inboxes/getInbox'](route.params.inbox_id)
);

const isEvolutionChannel = computed(
  () => currentInbox.value?.provider === 'evolution'
);

// Use useInbox composable with the inbox ID
const {
  isAWhatsAppCloudChannel,
  isATwilioChannel,
  isASmsInbox,
  isALineChannel,
  isAnEmailChannel,
  isAWhatsAppChannel,
  isAFacebookInbox,
  isATelegramChannel,
  isATwilioWhatsAppChannel,
} = useInbox(route.params.inbox_id);

const hasDuplicateInstagramInbox = computed(() => {
  const instagramId = currentInbox.value.instagram_id;
  const facebookInbox =
    store.getters['inboxes/getFacebookInboxByInstagramId'](instagramId);

  return (
    currentInbox.value.channel_type === INBOX_TYPES.INSTAGRAM && facebookInbox
  );
});

const shouldShowWhatsAppWebhookDetails = computed(() => {
  return (
    isAWhatsAppCloudChannel.value &&
    currentInbox.value.provider_config?.source !== 'embedded_signup'
  );
});

const isWhatsAppEmbeddedSignup = computed(() => {
  return (
    isAWhatsAppCloudChannel.value &&
    currentInbox.value.provider_config?.source === 'embedded_signup'
  );
});

const message = computed(() => {
  if (isATwilioChannel.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.TWILIO.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (isASmsInbox.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.SMS.BANDWIDTH.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (isALineChannel.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.LINE_CHANNEL.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (isAWhatsAppCloudChannel.value && shouldShowWhatsAppWebhookDetails.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (currentInbox.value.web_widget_script) {
    return t('INBOX_MGMT.FINISH.WEBSITE_SUCCESS');
  }

  if (isWhatsAppEmbeddedSignup.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.FINISH.WHATSAPP_QR_INSTRUCTION'
    )}`;
  }

  return t('INBOX_MGMT.FINISH.MESSAGE');
});

async function fetchEvolutionQrCode() {
  const accountId = window.location.pathname.split('/')[3];
  const inboxId = route.params.inbox_id;
  if (!accountId || !inboxId) return;

  evolutionQrLoading.value = true;
  evolutionQrError.value = '';

  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId}/channels/evolution/qr_code?inbox_id=${inboxId}`
    );
    evolutionQrStatus.value = data.status || '';
    evolutionPairingCode.value = data.pairing_code || data.pairingCode || '';
    evolutionHealth.value = data.evolution_health || null;

    if (data.status === 'connected') {
      evolutionQrLoading.value = false;
      evolutionQrCode.value = '';
      evolutionQrError.value = '';
      return;
    }

    if (data.qrcode) {
      evolutionQrCode.value = data.qrcode;
      evolutionQrLoading.value = false;
    } else if (data.code) {
      evolutionQrCode.value = await QRCode.toDataURL(data.code);
      evolutionQrLoading.value = false;
    } else {
      evolutionQrLoading.value = false;
      // eslint-disable-next-line no-use-before-define
      scheduleEvolutionQrPoll();
    }
  } catch (error) {
    evolutionQrLoading.value = false;
    evolutionQrStatus.value = error?.response?.data?.status || 'error';
    evolutionQrError.value =
      error?.response?.data?.error ||
      'Não foi possível obter o QR code agora. Tentando novamente...';
    // eslint-disable-next-line no-use-before-define
    scheduleEvolutionQrPoll();
  }
}

function scheduleEvolutionQrPoll() {
  if (evolutionQrAttempts >= MAX_EVOLUTION_QR_ATTEMPTS) {
    evolutionQrError.value =
      'Não foi possível obter o QR code. Verifique se a instância Evolution está ativa e tente novamente.';
    return;
  }
  evolutionQrAttempts += 1;
  evolutionQrTimer = setTimeout(fetchEvolutionQrCode, 3000);
}

function startEvolutionQrFetch() {
  if (evolutionQrTimer) clearTimeout(evolutionQrTimer);
  evolutionQrAttempts = 0;
  evolutionQrCode.value = '';
  evolutionPairingCode.value = '';
  evolutionQrStatus.value = '';
  evolutionQrError.value = '';
  evolutionHealth.value = null;
  fetchEvolutionQrCode();
}

async function generateQRCode(platform, identifier) {
  if (!identifier || !identifier.trim()) {
    // eslint-disable-next-line no-console
    console.warn(`Invalid identifier for ${platform} QR code`);
    return;
  }

  try {
    const platformUrls = {
      whatsapp: id => `https://wa.me/${id}`,
      messenger: id => `https://m.me/${id}`,
      telegram: id => `https://t.me/${id}`,
    };

    const url = platformUrls[platform](identifier);
    const qrDataUrl = await QRCode.toDataURL(url);
    qrCodes[platform] = qrDataUrl;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(`Error generating ${platform} QR code:`, error);
    qrCodes[platform] = '';
  }
}

async function generateQRCodes() {
  if (!currentInbox.value) return;

  // Evolution WhatsApp: fetch real Baileys QR from backend instead of generating wa.me link
  if (isEvolutionChannel.value) {
    startEvolutionQrFetch();
    return;
  }

  // WhatsApp (both Cloud and Twilio)
  if (currentInbox.value.phone_number && isAWhatsAppChannel.value) {
    // For Twilio WhatsApp, phone_number format is "whatsapp:+1234567890"
    // Extract just the phone number part for QR code generation
    const phoneNumber = currentInbox.value.phone_number.replace(
      'whatsapp:',
      ''
    );
    await generateQRCode('whatsapp', phoneNumber);
  }

  // Facebook Messenger
  if (currentInbox.value.page_id && isAFacebookInbox.value) {
    await generateQRCode('messenger', currentInbox.value.page_id);
  }

  // Telegram
  if (isATelegramChannel.value && currentInbox.value.bot_name) {
    await generateQRCode('telegram', currentInbox.value.bot_name);
  }
}

// Watch for currentInbox changes and regenerate QR codes when available
watch(
  currentInbox,
  newInbox => {
    if (newInbox) {
      generateQRCodes();
    }
  },
  { immediate: true }
);

onMounted(() => {
  generateQRCodes();
});

onUnmounted(() => {
  if (evolutionQrTimer) clearTimeout(evolutionQrTimer);
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="overflow-auto col-span-6 p-6 w-full h-full">
    <DuplicateInboxBanner
      v-if="hasDuplicateInstagramInbox"
      :content="$t('INBOX_MGMT.ADD.INSTAGRAM.NEW_INBOX_SUGGESTION')"
    />
    <EmptyState
      :title="$t('INBOX_MGMT.FINISH.TITLE')"
      :message="isAnEmailChannel && !currentInbox.provider ? '' : message"
      :button-text="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
    >
      <div class="w-full text-center">
        <div class="my-4 mx-auto max-w-[70%]">
          <woot-code
            v-if="currentInbox.web_widget_script"
            :script="currentInbox.web_widget_script"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isATwilioWhatsAppChannel"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div
          v-if="shouldShowWhatsAppWebhookDetails"
          class="w-[50%] max-w-[50%] ml-[25%]"
        >
          <p class="mt-8 font-medium text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_URL') }}
          </p>
          <woot-code lang="html" :script="currentInbox.callback_webhook_url" />
          <p class="mt-8 font-medium text-n-slate-11">
            {{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_VERIFICATION_TOKEN'
              )
            }}
          </p>
          <woot-code
            lang="html"
            :script="currentInbox.provider_config.webhook_verify_token"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isALineChannel"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isASmsInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <EmailInboxFinish
          v-if="isAnEmailChannel && !currentInbox.provider"
          :inbox="currentInbox"
          :inbox-id="$route.params.inbox_id"
        />
        <div
          v-if="isEvolutionChannel"
          class="flex flex-col gap-3 items-center mt-8"
        >
          <div
            v-if="evolutionHealth?.reauthorization_required"
            class="max-w-lg rounded-lg bg-n-ruby-3 px-3 py-2 text-left text-xs text-n-ruby-11"
          >
            O canal WhatsApp (Evolution) precisa ser reconectado. Gere um novo
            QR code abaixo ou refaça o pareamento na Evolution.
          </div>
          <div
            v-if="evolutionHealth?.last_warning_detail"
            class="max-w-lg rounded-lg bg-n-amber-3 px-3 py-2 text-left text-xs text-n-amber-11"
          >
            <strong>Diagnóstico Evolution:</strong>
            {{ evolutionHealth.last_warning_detail }}
          </div>
          <div
            v-if="
              evolutionHealth?.last_connection_error &&
              !evolutionHealth?.last_warning_detail
            "
            class="max-w-lg rounded-lg bg-n-amber-3 px-3 py-2 text-left text-xs text-n-amber-11"
          >
            Último erro de conexão:
            {{ evolutionHealth.last_connection_error }}
            <span
              v-if="evolutionHealth.last_connection_event_at"
              class="block opacity-80 mt-1"
            >
              ({{ evolutionHealth.last_connection_event_at }})
            </span>
          </div>
          <p class="mt-2 text-sm text-n-slate-9">
            Escaneie o QR code abaixo com o WhatsApp para conectar o numero.
          </p>
          <div v-if="evolutionQrLoading" class="text-sm text-n-slate-10">
            Aguardando QR code da Evolution API...
          </div>
          <div
            v-else-if="evolutionQrStatus === 'connected'"
            class="rounded-lg bg-n-teal-3 px-3 py-2 text-sm text-n-teal-11"
          >
            WhatsApp conectado com sucesso.
          </div>
          <div
            v-else-if="evolutionQrCode"
            class="rounded-lg shadow outline-1 outline-n-strong outline"
          >
            <img
              :src="
                evolutionQrCode.startsWith('data:')
                  ? evolutionQrCode
                  : `data:image/png;base64,${evolutionQrCode}`
              "
              alt="WhatsApp QR Code"
              class="rounded-lg size-48"
            />
          </div>
          <div
            v-if="evolutionPairingCode"
            class="rounded-lg bg-n-alpha-2 px-3 py-2 text-xs text-n-slate-11"
          >
            Código de pareamento: <strong>{{ evolutionPairingCode }}</strong>
          </div>
          <div
            v-if="!evolutionQrCode && evolutionQrStatus === 'pending'"
            class="max-w-sm text-xs text-n-slate-10"
          >
            A instância está em conexão, mas a Evolution ainda não retornou o QR
            code. Mantenha esta tela aberta ou tente novamente em alguns
            segundos.
          </div>
          <div v-if="evolutionQrError" class="text-xs text-n-ruby-10">
            {{ evolutionQrError }}
          </div>
          <button
            v-if="evolutionQrError || (!evolutionQrLoading && !evolutionQrCode)"
            type="button"
            class="rounded bg-gray-100 px-3 py-1 text-xs hover:bg-gray-200 dark:bg-slate-700 dark:hover:bg-slate-600"
            @click="startEvolutionQrFetch"
          >
            Tentar novamente
          </button>
        </div>

        <div
          v-if="isAWhatsAppChannel && !isEvolutionChannel && qrCodes.whatsapp"
          class="flex flex-col gap-3 items-center mt-8"
        >
          <p class="mt-2 text-sm text-n-slate-9">
            {{ $t('INBOX_MGMT.FINISH.WHATSAPP_QR_INSTRUCTION') }}
          </p>
          <div class="rounded-lg shadow outline-1 outline-n-strong outline">
            <img
              :src="qrCodes.whatsapp"
              alt="WhatsApp QR Code"
              class="rounded-lg size-48 dark:invert"
            />
          </div>
        </div>
        <div
          v-if="isAFacebookInbox && qrCodes.messenger"
          class="flex flex-col gap-3 items-center mt-8"
        >
          <p class="mt-2 text-sm text-n-slate-9">
            {{ $t('INBOX_MGMT.FINISH.MESSENGER_QR_INSTRUCTION') }}
          </p>
          <div class="rounded-lg shadow outline-1 outline-n-strong outline">
            <img
              :src="qrCodes.messenger"
              alt="Messenger QR Code"
              class="rounded-lg size-48 dark:invert"
            />
          </div>
        </div>
        <div
          v-if="isATelegramChannel && qrCodes.telegram"
          class="flex flex-col gap-4 items-center mt-8"
        >
          <p class="mt-2 text-sm text-n-slate-9">
            {{ $t('INBOX_MGMT.FINISH.TELEGRAM_QR_INSTRUCTION') }}
          </p>

          <div class="rounded-lg shadow outline-1 outline-n-strong outline">
            <img
              :src="qrCodes.telegram"
              alt="Telegram QR Code"
              class="rounded-lg size-48 dark:invert"
            />
          </div>
        </div>
        <div class="flex gap-2 justify-center mt-4">
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              outline
              slate
              :label="$t('INBOX_MGMT.FINISH.MORE_SETTINGS')"
            />
          </router-link>
          <router-link
            :to="{
              name: 'inbox_dashboard',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              solid
              teal
              :label="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
            />
          </router-link>
        </div>
      </div>
    </EmptyState>
  </div>
</template>

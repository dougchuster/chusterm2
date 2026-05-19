<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n, I18nT } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Icon from 'next/icon/Icon.vue';
import NextButton from 'next/button/Button.vue';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import globalConstants from 'dashboard/constants/globals.js';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from './whatsapp/utils';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

// State — signup flow
const fbSdkLoaded = ref(false);
const isProcessing = ref(false);
const processingMessage = ref('');
const authCodeReceived = ref(false);
const authCode = ref(null);
const businessData = ref(null);
const isAuthenticating = ref(false);
const isLoadingFacebook = ref(false);

// State — multi-number selection
const isSelectingNumber = ref(false);
const availablePhoneNumbers = ref([]);
const selectedPhoneNumberId = ref(null);
const sessionKey = ref(null);

let facebookSdkSetupPromise = null;

const whatsappAppId = computed(() => window.chustermConfig?.whatsappAppId);
const whatsappConfigurationId = computed(
  () => window.chustermConfig?.whatsappConfigurationId
);
const whatsappApiVersion = computed(
  () => window.chustermConfig?.whatsappApiVersion
);

const canLaunchEmbeddedSignup = computed(() => {
  return (
    Boolean(whatsappAppId.value) &&
    Boolean(whatsappConfigurationId.value) &&
    !isLoadingFacebook.value &&
    !isAuthenticating.value
  );
});

const benefits = computed(() => [
  {
    key: 'EASY_SETUP',
    text: t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.BENEFITS.EASY_SETUP'),
  },
  {
    key: 'SECURE_AUTH',
    text: t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.BENEFITS.SECURE_AUTH'),
  },
  {
    key: 'AUTO_CONFIG',
    text: t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.BENEFITS.AUTO_CONFIG'),
  },
]);

const showLoader = computed(() => isAuthenticating.value || isProcessing.value);

// Error handling
const handleSignupError = data => {
  isProcessing.value = false;
  authCodeReceived.value = false;
  isAuthenticating.value = false;
  isSelectingNumber.value = false;

  const errorMessage =
    data.error ||
    data.message ||
    t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE');
  useAlert(errorMessage);
};

const handleSignupCancellation = () => {
  isProcessing.value = false;
  authCodeReceived.value = false;
  isAuthenticating.value = false;
  isSelectingNumber.value = false;
};

const resetSignupState = () => {
  authCodeReceived.value = false;
  authCode.value = null;
  businessData.value = null;
  availablePhoneNumbers.value = [];
  selectedPhoneNumberId.value = null;
  sessionKey.value = null;
  isSelectingNumber.value = false;
};

const handleSignupSuccess = inboxData => {
  isProcessing.value = false;
  isAuthenticating.value = false;
  isSelectingNumber.value = false;

  if (inboxData && inboxData.id) {
    useAlert(t('INBOX_MGMT.FINISH.MESSAGE'));
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: {
        page: 'new',
        inbox_id: inboxData.id,
      },
    });
  } else {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SUCCESS_FALLBACK'));
    router.replace({ name: 'settings_inbox_list' });
  }
};

// Dispatch and handle response — including needs_number_selection
const dispatchSignup = async params => {
  const responseData = await store.dispatch(
    'inboxes/createWhatsAppEmbeddedSignup',
    params
  );

  if (responseData && responseData.needs_number_selection) {
    availablePhoneNumbers.value = responseData.phone_numbers || [];
    sessionKey.value = responseData.session_key;
    selectedPhoneNumberId.value = availablePhoneNumbers.value[0]?.id || null;
    isSelectingNumber.value = true;
    isProcessing.value = false;
    isAuthenticating.value = false;
    return null;
  }

  return responseData;
};

// Complete signup flow after business data + auth code are both available
const completeSignupFlow = async businessDataParam => {
  if (!authCodeReceived.value || !authCode.value) {
    handleSignupError({
      error: t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.AUTH_NOT_COMPLETED'),
    });
    return;
  }

  isProcessing.value = true;
  processingMessage.value = t(
    'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.PROCESSING'
  );

  try {
    const params = {
      code: authCode.value,
      business_id: businessDataParam?.business_id || '',
      waba_id: businessDataParam.waba_id,
      phone_number_id: businessDataParam?.phone_number_id || '',
      flow_type: businessDataParam?.flow_type || '',
    };

    const responseData = await dispatchSignup(params);
    if (responseData) {
      authCode.value = null;
      handleSignupSuccess(responseData);
    }
  } catch (error) {
    const errorMessage =
      parseAPIErrorResponse(error) ||
      t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE');
    handleSignupError({ error: errorMessage });
  }
};

// Confirm the number chosen by the user and complete onboarding
const confirmNumberSelection = async () => {
  if (!selectedPhoneNumberId.value) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SELECT_A_NUMBER'));
    return;
  }

  isProcessing.value = true;
  isSelectingNumber.value = false;
  processingMessage.value = t(
    'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.PROCESSING'
  );

  try {
    const params = {
      waba_id: businessData.value?.waba_id,
      business_id: businessData.value?.business_id,
      phone_number_id: selectedPhoneNumberId.value,
      session_key: sessionKey.value,
    };

    const responseData = await store.dispatch(
      'inboxes/createWhatsAppEmbeddedSignup',
      params
    );

    authCode.value = null;
    handleSignupSuccess(responseData);
  } catch (error) {
    const errorMessage =
      parseAPIErrorResponse(error) ||
      t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE');
    handleSignupError({ error: errorMessage });
  }
};

// Message handling (postMessage from Facebook SDK)
const handleEmbeddedSignupData = async data => {
  if (
    data.event === 'FINISH' ||
    data.event === 'FINISH_ONLY_WABA' ||
    data.event === 'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING'
  ) {
    const businessDataLocal = {
      ...(data.data || {}),
      flow_type: data.event,
    };

    if (isValidBusinessData(businessDataLocal)) {
      businessData.value = businessDataLocal;
      if (authCodeReceived.value && authCode.value) {
        await completeSignupFlow(businessDataLocal);
      } else {
        processingMessage.value = t(
          'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.WAITING_FOR_AUTH'
        );
      }
    } else {
      handleSignupError({
        error: t(
          'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.INVALID_BUSINESS_DATA'
        ),
      });
    }
  } else if (data.event === 'CANCEL') {
    handleSignupCancellation();
  } else if (data.event === 'ERROR' || data.event === 'error') {
    handleSignupError({
      error:
        data.data?.error_message ||
        data.error_message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SIGNUP_ERROR'),
    });
  }
};

const handleSignupMessage = createMessageHandler(handleEmbeddedSignupData);

const prepareFacebookSdk = async ({ alertOnError = false } = {}) => {
  if (fbSdkLoaded.value) return true;

  if (!whatsappAppId.value) {
    if (alertOnError) useAlert(t('INBOX.REAUTHORIZE.WHATSAPP_APP_ID_MISSING'));
    return false;
  }

  if (!whatsappConfigurationId.value) {
    if (alertOnError) {
      useAlert(t('INBOX.REAUTHORIZE.WHATSAPP_CONFIG_ID_MISSING'));
    }
    return false;
  }

  if (!facebookSdkSetupPromise) {
    isLoadingFacebook.value = true;
    facebookSdkSetupPromise = setupFacebookSdk(
      whatsappAppId.value,
      whatsappApiVersion.value
    )
      .then(() => {
        fbSdkLoaded.value = true;
        return true;
      })
      .catch(error => {
        facebookSdkSetupPromise = null;
        if (alertOnError) {
          useAlert(error.message || t('INBOX.REAUTHORIZE.FACEBOOK_LOAD_ERROR'));
        }
        return false;
      })
      .finally(() => {
        isLoadingFacebook.value = false;
      });
  }

  return facebookSdkSetupPromise;
};

const launchEmbeddedSignup = async () => {
  if (!fbSdkLoaded.value) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.LOADING_SDK'));
    prepareFacebookSdk({ alertOnError: true });
    return;
  }

  try {
    resetSignupState();
    isAuthenticating.value = true;
    processingMessage.value = t(
      'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.AUTH_PROCESSING'
    );

    const code = await initWhatsAppEmbeddedSignup(
      whatsappConfigurationId.value
    );

    authCode.value = code;
    authCodeReceived.value = true;
    processingMessage.value = t(
      'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.WAITING_FOR_BUSINESS_INFO'
    );

    if (businessData.value) {
      completeSignupFlow(businessData.value);
    }
  } catch (error) {
    if (error.message === 'Login cancelled') {
      isProcessing.value = false;
      isAuthenticating.value = false;
      useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
    } else {
      handleSignupError({
        error: error.message || t('INBOX.REAUTHORIZE.FACEBOOK_LOAD_ERROR'),
      });
    }
  }
};

// Lifecycle
onMounted(() => {
  window.addEventListener('message', handleSignupMessage);
  prepareFacebookSdk();
});

onBeforeUnmount(() => {
  window.removeEventListener('message', handleSignupMessage);
});
</script>

<template>
  <div class="h-full">
    <LoadingState v-if="showLoader" :message="processingMessage" />

    <!-- Multi-number selection -->
    <div v-else-if="isSelectingNumber" class="flex flex-col gap-4">
      <div class="flex flex-col items-start mb-2">
        <div class="flex justify-start mb-4">
          <div
            class="flex size-11 items-center justify-center rounded-full bg-n-alpha-2"
          >
            <Icon icon="i-woot-whatsapp" class="text-n-slate-10 size-6" />
          </div>
        </div>
        <h3 class="mb-1 text-base font-medium text-n-slate-12">
          {{
            $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SELECT_NUMBER_TITLE')
          }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SELECT_NUMBER_DESC') }}
        </p>
      </div>

      <div class="flex flex-col gap-2">
        <label
          v-for="phone in availablePhoneNumbers"
          :key="phone.id"
          class="flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors"
          :class="
            selectedPhoneNumberId === phone.id
              ? 'border-n-brand bg-n-alpha-2'
              : 'border-n-weak hover:border-n-brand'
          "
        >
          <input
            v-model="selectedPhoneNumberId"
            type="radio"
            :value="phone.id"
            class="accent-n-brand"
          />
          <span class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">
              {{ phone.display_phone_number }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ phone.verified_name }}
            </span>
          </span>
        </label>
      </div>

      <div class="flex gap-2 mt-2">
        <NextButton
          faded
          slate
          class="flex-1"
          @click="handleSignupCancellation"
        >
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCEL_BUTTON') }}
        </NextButton>
        <NextButton
          :disabled="!selectedPhoneNumberId"
          class="flex-1"
          @click="confirmNumberSelection"
        >
          {{
            $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CONFIRM_NUMBER_BUTTON')
          }}
        </NextButton>
      </div>
    </div>

    <!-- Initial signup screen -->
    <div v-else>
      <div class="flex flex-col items-start mb-6 text-start">
        <div class="flex justify-start mb-6">
          <div
            class="flex size-11 items-center justify-center rounded-full bg-n-alpha-2"
          >
            <Icon icon="i-woot-whatsapp" class="text-n-slate-10 size-6" />
          </div>
        </div>

        <h3 class="mb-2 text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.TITLE') }}
        </h3>
        <p class="text-sm leading-[24px] text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.DESC') }}
        </p>
      </div>

      <div class="flex flex-col gap-2 mb-6">
        <div
          v-for="benefit in benefits"
          :key="benefit.key"
          class="flex gap-2 items-center text-sm text-n-slate-11"
        >
          <Icon icon="i-lucide-check" class="text-n-slate-11 size-4" />
          {{ benefit.text }}
        </div>
      </div>

      <div class="flex flex-col gap-2 mb-6">
        <I18nT
          keypath="INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.LEARN_MORE.TEXT"
          tag="span"
          class="text-sm text-n-slate-11"
        >
          <template #link>
            <a
              :href="globalConstants.WHATSAPP_EMBEDDED_SIGNUP_DOCS_URL"
              target="_blank"
              rel="noopener noreferrer"
              class="underline text-n-brand"
            >
              {{
                $t(
                  'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.LEARN_MORE.LINK_TEXT'
                )
              }}
            </a>
          </template>
        </I18nT>
      </div>

      <div class="flex mt-4">
        <NextButton
          :disabled="!canLaunchEmbeddedSignup"
          :is-loading="isAuthenticating || isLoadingFacebook"
          faded
          slate
          class="w-full"
          @click="launchEmbeddedSignup"
        >
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SUBMIT_BUTTON') }}
        </NextButton>
      </div>
    </div>
  </div>
</template>

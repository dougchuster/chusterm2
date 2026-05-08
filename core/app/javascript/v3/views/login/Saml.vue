<script setup>
import { ref, nextTick, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  authError: {
    type: String,
    default: '',
  },
  target: {
    type: String,
    default: 'web',
  },
});

const store = useStore();
const { t } = useI18n();

const credentials = ref({
  email: '',
});

const loginApi = ref({
  showLoading: false,
  hasErrored: false,
});

const validations = {
  credentials: {
    email: {
      required,
      email,
    },
  },
};

const v$ = useVuelidate(validations, { credentials });

const globalConfig = computed(() => store.getters['globalConfig/get']);
const installationName = computed(
  () => globalConfig.value?.installationName || 'ChusteRM'
);
const brandLogo = computed(
  () => globalConfig.value?.logoDark || globalConfig.value?.logo || ''
);
const csrfToken = ref('');

const handleAuthError = () => {
  if (!props.authError) {
    return;
  }

  useAlert(t('LOGIN.SAML.API.ERROR_MESSAGE'));
  loginApi.value.hasErrored = true;
};

const handleSubmit = event => {
  v$.value.credentials.email.$touch();

  if (v$.value.credentials.email.$invalid) {
    event.preventDefault();
    loginApi.value.hasErrored = true;
    return;
  }

  loginApi.value.hasErrored = false;
  loginApi.value.showLoading = true;
};

onMounted(async () => {
  csrfToken.value =
    document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content') || '';

  await nextTick(handleAuthError);
});
</script>

<template>
  <main class="min-h-screen bg-[#060e20] text-[#dee5ff] selection:bg-[#bdc2ff]/20 selection:text-[#dee5ff]">
    <div class="relative flex min-h-screen flex-col lg:flex-row">
      <section class="relative hidden overflow-hidden bg-[#040913] lg:flex lg:w-[52%] xl:w-[54%]">
        <div class="absolute inset-0 bg-gradient-to-br from-[#1a1020] via-[#1a1128] to-[#060e20]" />
        <div class="absolute -left-16 top-24 h-72 w-72 rounded-full bg-[#c890ff]/12 blur-3xl" />
        <div class="absolute right-12 top-14 h-64 w-64 rounded-full bg-[#6366F1]/12 blur-3xl" />
        <div class="absolute bottom-[-10rem] left-[-5rem] h-[30rem] w-[38rem] rounded-[100%] border border-[#c890ff]/12" />
        <div class="absolute bottom-[-12rem] left-[1rem] h-[30rem] w-[40rem] rounded-[100%] border border-[#bdc2ff]/10" />
        <div class="absolute bottom-[-14rem] left-[7rem] h-[30rem] w-[42rem] rounded-[100%] border border-white/5" />
        <div class="absolute inset-x-0 bottom-0 h-64 bg-gradient-to-t from-[#000000] via-[#060e20]/90 to-transparent" />

        <div class="relative z-10 flex w-full items-center px-12 py-14 xl:px-16">
          <div class="max-w-[34rem]">
            <div class="mb-10 flex items-center gap-4">
              <img
                v-if="brandLogo"
                :src="brandLogo"
                :alt="installationName"
                class="h-10 w-auto object-contain"
              />
              <div v-else class="font-['Manrope'] text-3xl font-extrabold tracking-tight text-[#bdc2ff]">
                {{ installationName }}
              </div>
              <span class="rounded-full bg-[#0f1e3f]/80 px-4 py-2 text-[10px] font-bold uppercase tracking-[0.24em] text-[#b9c8de] backdrop-blur-xl">
                {{ t('LOGIN.SAML.INTRO.EYEBROW') }}
              </span>
            </div>

            <h1 class="max-w-[13ch] font-['Manrope'] text-5xl font-extrabold leading-[1.05] tracking-[-0.04em] text-[#dee5ff] xl:text-6xl">
              {{ t('LOGIN.SAML.INTRO.HERO_TITLE_PREFIX') }}
              <span class="text-[#c890ff]">{{ t('LOGIN.SAML.INTRO.HERO_TITLE_EMPHASIS') }}</span>
            </h1>

            <p class="mt-8 max-w-xl text-lg leading-8 text-[#99aad9]">
              {{ t('LOGIN.SAML.INTRO.HERO_DESCRIPTION') }}
            </p>

            <div class="mt-10 flex max-w-[27rem] items-start gap-4 rounded-[20px] bg-[#11244c]/35 p-5 shadow-[0_24px_60px_rgba(0,0,0,0.28)] ring-1 ring-white/5 backdrop-blur-xl">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[#c890ff]/18 text-[#c890ff]">
                <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M12 2 4 6v6c0 5.2 3.3 8.9 8 10 4.7-1.1 8-4.8 8-10V6l-8-4Zm-1.1 13.6-3.2-3.2 1.4-1.4 1.8 1.8 4.2-4.2 1.4 1.4-5.6 5.6Z" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-semibold text-[#dee5ff]">{{ t('LOGIN.SAML.INTRO.FEATURE_TITLE') }}</p>
                <p class="mt-1 text-sm leading-6 text-[#99aad9]">{{ t('LOGIN.SAML.INTRO.FEATURE_DESCRIPTION') }}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="relative flex min-h-screen flex-1 items-center justify-center overflow-hidden px-5 py-8 sm:px-8 lg:px-12 xl:px-16">
        <div class="absolute inset-0 bg-[#060e20]" />
        <div class="absolute left-1/2 top-0 h-64 w-64 -translate-x-1/2 rounded-full bg-[#6366F1]/8 blur-3xl lg:hidden" />
        <div class="absolute bottom-[-5rem] right-[-4rem] h-64 w-64 rounded-full bg-[#c890ff]/10 blur-3xl lg:hidden" />

        <div class="relative z-10 w-full max-w-[32rem]">
          <div class="mb-8 lg:hidden">
            <div class="flex flex-col items-center text-center">
              <img
                v-if="brandLogo"
                :src="brandLogo"
                :alt="installationName"
                class="h-10 w-auto object-contain"
              />
              <div v-else class="font-['Manrope'] text-3xl font-extrabold tracking-tight text-[#bdc2ff]">
                {{ installationName }}
              </div>
              <span class="mt-4 rounded-full bg-[#0f1e3f] px-4 py-2 text-[10px] font-bold uppercase tracking-[0.24em] text-[#b9c8de]">
                {{ t('LOGIN.SAML.INTRO.EYEBROW') }}
              </span>
            </div>
          </div>

          <div
            class="rounded-[28px] bg-[#06122c]/88 p-6 shadow-[0_32px_80px_rgba(0,0,0,0.45)] ring-1 ring-white/5 backdrop-blur-xl sm:p-8"
            :class="{ 'animate-wiggle': loginApi.hasErrored }"
          >
            <div class="mb-8">
              <span class="text-[10px] font-bold uppercase tracking-[0.24em] text-[#99aad9]">
                {{ t('LOGIN.SAML.INTRO.EYEBROW') }}
              </span>
              <h2 class="mt-3 font-['Manrope'] text-4xl font-extrabold tracking-[-0.04em] text-[#dee5ff]">
                {{ t('LOGIN.SAML.TITLE') }}
              </h2>
              <p class="mt-3 text-base leading-7 text-[#99aad9]">
                {{ t('LOGIN.SAML.SUBTITLE') }}
              </p>
            </div>

            <div
              v-if="authError"
              class="mb-6 rounded-[18px] bg-[#871c34]/20 px-4 py-3 text-sm leading-6 text-[#ff97a3] ring-1 ring-[#f97386]/20"
            >
              {{ t('LOGIN.SAML.API.ERROR_MESSAGE') }}
            </div>

            <form class="space-y-6" method="POST" action="/api/v1/auth/saml_login" @submit="handleSubmit">
              <div class="space-y-2">
                <label class="block px-1 text-[10px] font-bold uppercase tracking-[0.24em] text-[#99aad9]" for="sso-email">
                  {{ t('LOGIN.SAML.WORK_EMAIL.LABEL') }}
                </label>
                <div
                  class="flex items-center rounded-[18px] bg-black px-4 transition-all duration-300"
                  :class="v$.credentials.email.$error ? 'ring-1 ring-[#f97386]/40' : 'focus-within:bg-[#0f1e3f] focus-within:ring-2 focus-within:ring-[#bdc2ff]/20'"
                >
                  <svg class="mr-3 h-5 w-5 shrink-0 text-[#99aad9]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
                    <path d="M4 6h16v12H4z" />
                    <path d="m4 7 8 6 8-6" />
                  </svg>
                  <input
                    id="sso-email"
                    v-model="credentials.email"
                    name="email"
                    type="email"
                    class="w-full bg-transparent py-4 text-sm text-[#dee5ff] outline-none placeholder:text-[#99aad9]/40"
                    :placeholder="t('LOGIN.SAML.WORK_EMAIL.PLACEHOLDER')"
                    :tabindex="1"
                    required
                    autocomplete="email"
                    @input="v$.credentials.email.$touch"
                  />
                </div>
                <p v-if="v$.credentials.email.$error" class="px-1 text-xs text-[#ff97a3]">
                  {{ t('LOGIN.EMAIL.ERROR') }}
                </p>
              </div>

              <input
                type="hidden"
                class="h-0"
                name="authenticity_token"
                :value="csrfToken"
              />
              <input type="hidden" class="h-0" name="target" :value="target" />

              <button
                type="submit"
                class="flex w-full items-center justify-center gap-3 rounded-full bg-gradient-to-r from-[#bdc2ff] to-[#8a95ff] px-6 py-4 text-sm font-bold text-[#28329c] shadow-[0_18px_44px_rgba(189,194,255,0.18)] transition-all duration-300 hover:shadow-[0_24px_54px_rgba(189,194,255,0.24)] disabled:cursor-not-allowed disabled:opacity-70"
                :disabled="loginApi.showLoading"
                :tabindex="2"
              >
                <svg
                  v-if="loginApi.showLoading"
                  class="h-5 w-5 animate-spin text-[#28329c]"
                  viewBox="0 0 24 24"
                  fill="none"
                  aria-hidden="true"
                >
                  <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-opacity="0.25" stroke-width="3" />
                  <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
                </svg>
                <span>{{ t('LOGIN.SAML.SUBMIT') }}</span>
              </button>
            </form>

            <p class="mt-8 text-center text-sm leading-7 text-[#99aad9] lg:text-left">
              <router-link
                to="/app/login"
                class="font-semibold text-[#c890ff] transition-colors hover:text-[#bc80f8]"
              >
                {{ t('LOGIN.SAML.BACK_TO_LOGIN') }}
              </router-link>
            </p>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>

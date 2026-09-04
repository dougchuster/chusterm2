<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
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
const logoParts = computed(() => {
  const brand = installationName.value || 'ChusteRM';
  return {
    prefix: brand.slice(0, 1),
    middle: brand.slice(1, -2),
    suffix: brand.slice(-2),
  };
});
const csrfToken = ref('');
const COLOR_SCHEME_STORAGE_KEY = 'color_scheme';
const LEGACY_LOGIN_THEME_STORAGE_KEY = 'chusterm-login-theme';
const THEME_MEDIA_QUERY = '(prefers-color-scheme: dark)';

// Theming logic
const localTheme = ref('system');

const getPreferredTheme = () => {
  const storedTheme =
    localStorage.getItem(COLOR_SCHEME_STORAGE_KEY) ||
    localStorage.getItem(LEGACY_LOGIN_THEME_STORAGE_KEY);

  if (['light', 'dark', 'auto', 'system'].includes(storedTheme)) {
    return storedTheme;
  }

  return 'auto';
};

const getResolvedTheme = () => {
  const preferredTheme = getPreferredTheme();
  const isOSOnDarkMode =
    window.matchMedia && window.matchMedia(THEME_MEDIA_QUERY).matches;

  if (preferredTheme === 'dark') {
    return 'dark';
  }

  if (preferredTheme === 'auto' || preferredTheme === 'system') {
    return isOSOnDarkMode ? 'dark' : 'light';
  }

  return 'light';
};

function applyTheme() {
  document.documentElement.dataset.theme = localTheme.value;
  document.body.dataset.theme = localTheme.value;
  document.documentElement.classList.toggle(
    'dark',
    localTheme.value === 'dark'
  );
  document.body.classList.toggle('dark', localTheme.value === 'dark');
  document.body.classList.toggle('theme-dark', localTheme.value === 'dark');
  document.body.classList.toggle('theme-light', localTheme.value !== 'dark');
  document.documentElement.style.setProperty('color-scheme', localTheme.value);
}

const toggleTheme = () => {
  localTheme.value = localTheme.value === 'dark' ? 'light' : 'dark';
  localStorage.setItem(COLOR_SCHEME_STORAGE_KEY, localTheme.value);
  localStorage.setItem(LEGACY_LOGIN_THEME_STORAGE_KEY, localTheme.value);
  applyTheme();
};

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

  // Initialize theme
  localTheme.value = getResolvedTheme();
  applyTheme();

  window.matchMedia(THEME_MEDIA_QUERY).addEventListener('change', e => {
    const preferredTheme = getPreferredTheme();
    if (preferredTheme === 'auto' || preferredTheme === 'system') {
      localTheme.value = e.matches ? 'dark' : 'light';
      applyTheme();
    }
  });

  await nextTick(handleAuthError);
});
</script>

<template>
  <main class="auth-modern" :class="localTheme">
    <button
      class="theme-toggle-btn"
      :aria-label="
        localTheme === 'dark'
          ? 'Mudar para tema claro'
          : 'Mudar para tema escuro'
      "
      @click="toggleTheme"
    >
      <i v-if="localTheme === 'dark'" class="i-lucide-sun size-5" />
      <i v-else class="i-lucide-moon size-5" />
    </button>

    <div class="auth-bg-elements" aria-hidden="true">
      <div class="orb orb-1" />
      <div class="orb orb-2" />
      <div class="orb orb-3" />
      <div class="glass-overlay" />
    </div>

    <div class="auth-wrapper">
      <div class="auth-glass-card">
        <!-- Hero/Brand Side -->
        <aside class="auth-hero" :aria-label="$t('LOGIN.SAML.INTRO.EYEBROW')">
          <div class="auth-hero-content">
            <div class="custom-logo">
              <img
                class="logo-icon"
                :src="'/brand-assets/logo_thumbnail.svg'"
                alt=""
                aria-hidden="true"
              />
              <span class="logo-text">
                <span class="logo-name"
                  >{{ logoParts.prefix }}{{ logoParts.middle }}</span
                >
                <span class="logo-badge">{{ logoParts.suffix }}</span>
              </span>
            </div>
            <h2 class="auth-headline">
              {{ $t('LOGIN.SAML.INTRO.HERO_TITLE_PREFIX') }}
              <span class="text-gradient">{{
                $t('LOGIN.SAML.INTRO.HERO_TITLE_EMPHASIS')
              }}</span>
            </h2>
            <p class="auth-description">
              {{ $t('LOGIN.SAML.INTRO.HERO_DESCRIPTION') }}
            </p>
          </div>
        </aside>

        <!-- Form Side -->
        <section class="auth-form-pane" :aria-label="$t('LOGIN.SAML.TITLE')">
          <div class="auth-form-content">
            <header class="auth-header">
              <div class="auth-brand-mobile">
                <div class="custom-logo">
                  <span class="logo-text">
                    <span class="logo-name"
                      >{{ logoParts.prefix }}{{ logoParts.middle }}</span
                    >
                    <span class="logo-badge">{{ logoParts.suffix }}</span>
                  </span>
                </div>
              </div>
              <span class="auth-eyebrow">{{
                $t('LOGIN.SAML.INTRO.EYEBROW')
              }}</span>
              <h1 class="auth-title">{{ $t('LOGIN.SAML.TITLE') }}</h1>
              <p class="auth-subtitle">{{ $t('LOGIN.SAML.SUBTITLE') }}</p>
            </header>

            <div :class="{ 'shake-animation': loginApi.hasErrored }">
              <div v-if="authError" class="auth-alert-box" role="alert">
                <i class="i-lucide-circle-alert size-4 shrink-0" />
                <span>{{ $t('LOGIN.SAML.API.ERROR_MESSAGE') }}</span>
              </div>

              <div class="auth-interactive-area">
                <form
                  class="auth-form"
                  method="POST"
                  action="/api/v1/auth/saml_login"
                  @submit="handleSubmit"
                >
                  <div class="input-group">
                    <label for="sso-email">{{
                      $t('LOGIN.SAML.WORK_EMAIL.LABEL')
                    }}</label>
                    <div
                      class="input-wrapper"
                      :class="{ 'has-error': v$.credentials.email.$error }"
                    >
                      <i
                        class="input-icon i-lucide-mail size-4"
                        aria-hidden="true"
                      />
                      <input
                        id="sso-email"
                        v-model="credentials.email"
                        class="modern-input"
                        type="email"
                        name="email"
                        :placeholder="$t('LOGIN.SAML.WORK_EMAIL.PLACEHOLDER')"
                        autocomplete="email"
                        spellcheck="false"
                        @input="v$.credentials.email.$touch"
                      />
                    </div>
                  </div>

                  <input
                    type="hidden"
                    name="authenticity_token"
                    :value="csrfToken"
                  />
                  <input type="hidden" name="target" :value="target" />

                  <button
                    type="submit"
                    class="auth-submit-btn"
                    :disabled="loginApi.showLoading"
                  >
                    <span>{{ $t('LOGIN.SAML.SUBMIT') }}</span>
                  </button>
                </form>

                <router-link to="/app/login" class="auth-sso-btn">
                  <i class="i-lucide-arrow-left size-4" aria-hidden="true" />
                  <span>{{ $t('LOGIN.SAML.BACK_TO_LOGIN') }}</span>
                </router-link>
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  </main>
</template>

<style scoped>
.auth-modern {
  position: fixed !important;
  inset: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  font-family: 'Inter', sans-serif !important;
  overflow: hidden !important;
  z-index: 999999 !important;
  width: 100vw !important;
  height: 100vh !important;
  transition:
    background-color 0.5s ease,
    color 0.5s ease;
}

.auth-modern.light {
  --bg-base: #f8fafc;
  --text-main: #0f172a;
  --text-muted: #64748b;
  --card-bg: rgba(255, 255, 255, 0.85);
  --card-border: rgba(226, 232, 240, 0.9);
  --form-bg: rgba(255, 255, 255, 0.95);
  --hero-bg: #f8fafc;
  --input-bg: rgba(248, 250, 252, 0.9);
  --input-border: #e2e8f0;
  --input-text: #0f172a;
  --btn-bg: linear-gradient(135deg, #4f46e5 0%, #6366f1 100%);
  --btn-hover: linear-gradient(135deg, #4338ca 0%, #4f46e5 100%);
  --btn-text: #ffffff;
  --btn-shadow: 0 10px 25px -5px rgba(99, 102, 241, 0.35);
  --divider: #e2e8f0;
  background-color: var(--bg-base);
  color: var(--text-main);
  color-scheme: light;
}

.auth-modern.dark {
  --bg-base: #060e20;
  --text-main: #f8fafc;
  --text-muted: #94a3b8;
  --card-bg: rgba(15, 23, 42, 0.75);
  --card-border: rgba(255, 255, 255, 0.1);
  --form-bg: rgba(10, 15, 30, 0.85);
  --hero-bg: #091226;
  --input-bg: rgba(15, 23, 42, 0.65);
  --input-border: rgba(255, 255, 255, 0.12);
  --input-text: #f8fafc;
  --btn-bg: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #df8eff 100%);
  --btn-hover: linear-gradient(135deg, #4f46e5 0%, #7c3aed 50%, #c084fc 100%);
  --btn-text: #ffffff;
  --btn-shadow: 0 12px 30px -5px rgba(124, 58, 237, 0.45);
  --divider: rgba(255, 255, 255, 0.1);
  background-color: var(--bg-base);
  color: var(--text-main);
  color-scheme: dark;
}

.theme-toggle-btn {
  position: absolute;
  top: 1.5rem;
  right: 1.5rem;
  z-index: 50;
  width: 2.75rem;
  height: 2.75rem;
  border-radius: 9999px;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  color: var(--text-muted);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  backdrop-filter: blur(12px);
  transition: all 0.25s ease;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.theme-toggle-btn:hover {
  color: var(--text-main);
  border-color: #6366f1;
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(99, 102, 241, 0.2);
}

.auth-bg-elements {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}

.orb {
  position: absolute;
  border-radius: 9999px;
  filter: blur(100px);
  opacity: 0.45;
  animation: floatOrb 20s ease-in-out infinite alternate;
}

.auth-modern.light .orb {
  opacity: 0.25;
}

.orb-1 {
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, #6366f1 0%, rgba(99, 102, 241, 0) 70%);
  top: -10%;
  left: -5%;
}

.orb-2 {
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, #00eefc 0%, rgba(0, 238, 252, 0) 70%);
  bottom: -15%;
  right: -5%;
  animation-delay: -5s;
}

.orb-3 {
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, #df8eff 0%, rgba(223, 142, 255, 0) 70%);
  top: 40%;
  left: 45%;
  animation-delay: -10s;
}

@keyframes floatOrb {
  0% {
    transform: translate(0, 0) scale(1);
  }
  50% {
    transform: translate(40px, 30px) scale(1.08);
  }
  100% {
    transform: translate(-30px, 50px) scale(0.95);
  }
}

.glass-overlay {
  position: absolute;
  inset: 0;
  backdrop-filter: blur(40px);
}

.auth-wrapper {
  position: relative;
  z-index: 10;
  width: 100%;
  max-width: 1040px;
  margin: 1.5rem;
}

.auth-glass-card {
  display: flex;
  min-height: 560px;
  border-radius: 1.75rem;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  backdrop-filter: blur(28px);
  box-shadow:
    0 25px 50px -12px rgba(0, 0, 0, 0.4),
    0 0 40px rgba(99, 102, 241, 0.08);
  overflow: hidden;
}

.auth-hero {
  flex: 1.1;
  background: var(--hero-bg);
  padding: 3.5rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  position: relative;
  border-right: 1px solid var(--card-border);
}

.auth-hero-content {
  position: relative;
  z-index: 2;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.custom-logo {
  display: flex;
  align-items: center;
  gap: 0.875rem;
}

.logo-icon {
  width: 2.75rem;
  height: 2.75rem;
}

.logo-text {
  font-size: 1.625rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 0.375rem;
  letter-spacing: -0.02em;
}

.logo-name {
  color: var(--text-main);
  font-family: 'Plus Jakarta Sans', 'Manrope', sans-serif;
}

.logo-badge {
  background: linear-gradient(135deg, #00eefc 0%, #df8eff 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  font-weight: 800;
}

.auth-headline {
  font-family: 'Plus Jakarta Sans', 'Manrope', sans-serif;
  font-size: 2.25rem;
  line-height: 1.2;
  font-weight: 700;
  color: var(--text-main);
  letter-spacing: -0.02em;
}

.text-gradient {
  background: linear-gradient(135deg, #00eefc 0%, #a855f7 50%, #df8eff 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.auth-description {
  font-size: 0.9375rem;
  line-height: 1.6;
  color: var(--text-muted);
}

.auth-form-pane {
  flex: 1;
  background: var(--form-bg);
  padding: 3.5rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.auth-form-content {
  width: 100%;
  max-width: 360px;
  margin: 0 auto;
}

.auth-header {
  margin-bottom: 2rem;
}

.auth-brand-mobile {
  display: none;
  margin-bottom: 1.5rem;
}

.auth-eyebrow {
  display: inline-block;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #6366f1;
  margin-bottom: 0.5rem;
}

.auth-title {
  font-family: 'Plus Jakarta Sans', 'Manrope', sans-serif;
  font-size: 1.75rem;
  font-weight: 700;
  color: var(--text-main);
  letter-spacing: -0.02em;
  margin-bottom: 0.375rem;
}

.auth-subtitle {
  font-size: 0.875rem;
  color: var(--text-muted);
}

.auth-interactive-area {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.input-group label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-main);
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.input-icon {
  position: absolute;
  left: 1rem;
  color: var(--text-muted);
  pointer-events: none;
}

.modern-input {
  width: 100%;
  padding: 0.8125rem 1rem 0.8125rem 2.75rem;
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  border-radius: 0.875rem;
  color: var(--input-text);
  font-size: 0.875rem;
  outline: none;
  transition: all 0.2s ease;
}

.modern-input:focus {
  border-color: #6366f1;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.2);
  background: var(--card-bg);
}

.input-wrapper.has-error .modern-input {
  border-color: #ef4444;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.2);
}

.auth-submit-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 0.875rem 1.5rem;
  border-radius: 0.875rem;
  background: var(--btn-bg);
  border: none;
  color: var(--btn-text);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  box-shadow: var(--btn-shadow);
  transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  margin-top: 0.5rem;
}

.auth-submit-btn:hover:not(:disabled) {
  background: var(--btn-hover);
  transform: translateY(-2px);
  box-shadow: 0 16px 32px -5px rgba(124, 58, 237, 0.55);
}

.auth-sso-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.625rem;
  width: 100%;
  padding: 0.75rem 1rem;
  border-radius: 0.875rem;
  background: transparent;
  border: 1px solid var(--input-border);
  color: var(--text-muted);
  font-size: 0.8125rem;
  font-weight: 500;
  text-decoration: none;
  transition: all 0.2s ease;
}

.auth-sso-btn:hover {
  color: var(--text-main);
  border-color: #6366f1;
  background: var(--card-bg);
}

.auth-alert-box {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-radius: 0.75rem;
  background: rgba(239, 68, 68, 0.12);
  border: 1px solid rgba(239, 68, 68, 0.25);
  color: #ef4444;
  font-size: 0.8125rem;
  font-weight: 500;
  margin-bottom: 1.25rem;
}

@media (max-width: 900px) {
  .auth-glass-card {
    flex-direction: column;
    min-height: auto;
  }
  .auth-hero {
    display: none;
  }
  .auth-brand-mobile {
    display: flex;
    justify-content: center;
  }
  .auth-form-pane {
    padding: 2.5rem 1.75rem;
  }
}
</style>

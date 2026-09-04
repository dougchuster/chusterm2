<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script>
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';

import Spinner from 'shared/components/Spinner.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const COLOR_SCHEME_STORAGE_KEY = 'color_scheme';
const LEGACY_LOGIN_THEME_STORAGE_KEY = 'chusterm-login-theme';
const THEME_MEDIA_QUERY = '(prefers-color-scheme: dark)';

export default {
  components: {
    Spinner,
    MfaVerification,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      localTheme: 'system',
      credentials: { email: '', password: '' },
      loginApi: { message: '', showLoading: false, hasErrored: false },
      error: '',
      mfaRequired: false,
      mfaToken: null,
      showPassword: false,
    };
  },
  validations() {
    return {
      credentials: {
        password: { required },
        email: { required, email },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chustermConfig?.allowedLoginMethods || ['email'];
    },
    showSignupLink() {
      return window.chustermConfig?.signupEnabled === 'true';
    },
    showEmailLogin() {
      return this.allowedLoginMethods.includes('email');
    },
    showGoogleLogin() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chustermConfig?.googleOAuthClientId) &&
        Boolean(window.chustermConfig?.googleOAuthCallbackUrl)
      );
    },
    showSsoLogin() {
      return (
        window.chustermConfig?.isEnterprise === 'true' &&
        this.allowedLoginMethods.includes('saml')
      );
    },
    installationName() {
      return this.globalConfig?.installationName || 'ChusteRM';
    },
    brandLogo() {
      return this.globalConfig?.logo || this.globalConfig?.logoDark || '';
    },
    logoParts() {
      const brand = this.installationName || 'ChusteRM';
      return {
        prefix: brand.slice(0, 1),
        middle: brand.slice(1, -2),
        suffix: brand.slice(-2),
      };
    },
    featurePills() {
      return [
        { icon: 'i-lucide-message-square', label: 'Omnichannel CRM' },
        { icon: 'i-lucide-bot', label: 'AI Agent Orchestration' },
        { icon: 'i-lucide-kanban', label: 'Kanban & Smart Scoring' },
      ];
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }

    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      this.requestIdleCallbackPolyfill(() => {
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  mounted() {
    this.localTheme = this.getResolvedTheme();
    this.applyTheme();

    window.matchMedia(THEME_MEDIA_QUERY).addEventListener('change', e => {
      const preferredTheme = this.getPreferredTheme();
      if (preferredTheme === 'auto' || preferredTheme === 'system') {
        this.localTheme = e.matches ? 'dark' : 'light';
        this.applyTheme();
      }
    });
  },

  methods: {
    toggleTheme() {
      this.localTheme = this.localTheme === 'dark' ? 'light' : 'dark';
      localStorage.setItem(COLOR_SCHEME_STORAGE_KEY, this.localTheme);
      localStorage.setItem(LEGACY_LOGIN_THEME_STORAGE_KEY, this.localTheme);
      this.applyTheme();
    },
    getPreferredTheme() {
      const storedTheme =
        localStorage.getItem(COLOR_SCHEME_STORAGE_KEY) ||
        localStorage.getItem(LEGACY_LOGIN_THEME_STORAGE_KEY);

      if (['light', 'dark', 'auto', 'system'].includes(storedTheme)) {
        return storedTheme;
      }

      return 'auto';
    },
    getResolvedTheme() {
      const preferredTheme = this.getPreferredTheme();
      const isOSOnDarkMode =
        window.matchMedia && window.matchMedia(THEME_MEDIA_QUERY).matches;

      if (preferredTheme === 'dark') {
        return 'dark';
      }

      if (preferredTheme === 'auto' || preferredTheme === 'system') {
        return isOSOnDarkMode ? 'dark' : 'light';
      }

      return 'light';
    },
    applyTheme() {
      document.documentElement.dataset.theme = this.localTheme;
      document.body.dataset.theme = this.localTheme;
      document.documentElement.classList.toggle(
        'dark',
        this.localTheme === 'dark'
      );
      document.body.classList.toggle('dark', this.localTheme === 'dark');
      document.body.classList.toggle('theme-dark', this.localTheme === 'dark');
      document.body.classList.toggle('theme-light', this.localTheme !== 'dark');
      document.documentElement.style.setProperty(
        'color-scheme',
        this.localTheme
      );
    },
    getTranslatedMessage(key) {
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    getGoogleAuthUrl() {
      const baseUrl = 'https://accounts.google.com/o/oauth2/auth';
      const clientId = window.chustermConfig?.googleOAuthClientId;
      const redirectUri = window.chustermConfig?.googleOAuthCallbackUrl;

      if (!clientId || !redirectUri) {
        return '#';
      }

      const queryString = new URLSearchParams({
        client_id: clientId,
        redirect_uri: redirectUri,
        response_type: 'code',
        scope: 'email profile',
      }).toString();

      return `${baseUrl}?${queryString}`;
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (this.email) {
            window.location = '/app/login';
          }

          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      this.v$.$touch();

      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        this.loginApi.hasErrored = true;
        return;
      }

      if (this.v$.credentials.password.$invalid) {
        this.showAlertMessage(this.$t('LOGIN.PASSWORD.ERROR'));
        this.loginApi.hasErrored = true;
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      this.mfaRequired = false;
      this.mfaToken = null;
      window.location = '/app/login';
    },
  },
};
</script>

<template>
  <main class="auth-modern" :class="localTheme">
    <!-- Botão de Troca de Tema -->
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

    <!-- Animated Background Elements -->
    <div class="auth-bg-elements" aria-hidden="true">
      <div class="orb orb-1" />
      <div class="orb orb-2" />
      <div class="orb orb-3" />
      <div class="glass-overlay" />
    </div>

    <div class="auth-wrapper">
      <div class="auth-glass-card">
        <!-- Hero/Brand Side -->
        <aside class="auth-hero" :aria-label="$t('LOGIN.INTRO.BRAND_LABEL')">
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
              {{ $t('LOGIN.INTRO.TAGLINE') }}
            </h2>
            <p class="auth-description">
              {{ $t('LOGIN.INTRO.HERO_DESCRIPTION') }}
            </p>

            <div class="auth-feature-pills">
              <div
                v-for="pill in featurePills"
                :key="pill.label"
                class="feature-pill"
              >
                <i class="size-4" :class="[pill.icon]" />
                <span>{{ pill.label }}</span>
              </div>
            </div>
          </div>
        </aside>

        <!-- Form Side -->
        <section
          class="auth-form-pane"
          :aria-label="$t('LOGIN.INTRO.FORM_LABEL')"
        >
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
              <h1 class="auth-title">{{ $t('LOGIN.INTRO.WELCOME_TITLE') }}</h1>
              <p class="auth-subtitle">{{ $t('LOGIN.INTRO.FORM_SUBTITLE') }}</p>
            </header>

            <div v-if="mfaRequired" class="auth-mfa-container">
              <MfaVerification
                :mfa-token="mfaToken"
                @verified="handleMfaVerified"
                @cancel="handleMfaCancel"
              />
            </div>

            <div v-else :class="{ 'shake-animation': loginApi.hasErrored }">
              <div
                v-if="loginApi.message && loginApi.hasErrored"
                class="auth-alert-box"
                role="alert"
              >
                <i class="i-lucide-circle-alert size-4 shrink-0" />
                <span>{{ loginApi.message }}</span>
              </div>

              <div v-if="email" class="auth-loading-state" role="status">
                <span class="auth-spinner-ring" aria-hidden="true" />
                <div class="loading-text">
                  <p>{{ $t('LOGIN.INTRO.LOADING_TITLE') }}</p>
                  <span>{{ $t('LOGIN.INTRO.LOADING_DESCRIPTION') }}</span>
                </div>
              </div>

              <div v-else class="auth-interactive-area">
                <a
                  v-if="showGoogleLogin"
                  :href="getGoogleAuthUrl()"
                  class="auth-social-btn"
                >
                  <span class="i-logos-google-icon size-5" aria-hidden="true" />
                  <span>{{ $t('LOGIN.OAUTH.GOOGLE_LOGIN') }}</span>
                </a>

                <div
                  v-if="showGoogleLogin && showEmailLogin"
                  class="auth-divider"
                >
                  <span class="line" aria-hidden="true" />
                  <small>{{ $t('LOGIN.INTRO.OR_WITH_EMAIL') }}</small>
                  <span class="line" aria-hidden="true" />
                </div>

                <form
                  v-if="showEmailLogin"
                  class="auth-form"
                  @submit.prevent="submitFormLogin"
                >
                  <div class="input-group">
                    <label for="login-email">{{
                      $t('LOGIN.EMAIL.LABEL')
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
                        id="login-email"
                        v-model="credentials.email"
                        class="modern-input"
                        type="email"
                        :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                        data-testid="email_input"
                        autocomplete="email"
                        spellcheck="false"
                        @input="v$.credentials.email.$touch"
                      />
                    </div>
                  </div>

                  <div class="input-group">
                    <div class="input-group-header">
                      <label for="login-password">{{
                        $t('LOGIN.PASSWORD.LABEL')
                      }}</label>
                      <router-link
                        to="/app/auth/reset/password"
                        class="forgot-link"
                      >
                        {{ $t('LOGIN.FORGOT_PASSWORD') }}
                      </router-link>
                    </div>
                    <div
                      class="input-wrapper"
                      :class="{ 'has-error': v$.credentials.password.$error }"
                    >
                      <i
                        class="input-icon i-lucide-lock-keyhole size-4"
                        aria-hidden="true"
                      />
                      <input
                        id="login-password"
                        v-model="credentials.password"
                        class="modern-input"
                        :type="showPassword ? 'text' : 'password'"
                        :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                        data-testid="password_input"
                        autocomplete="current-password"
                        spellcheck="false"
                        @input="v$.credentials.password.$touch"
                      />
                      <button
                        type="button"
                        class="password-toggle"
                        :aria-label="
                          showPassword
                            ? $t('LOGIN.HIDE_PASSWORD')
                            : $t('LOGIN.SHOW_PASSWORD')
                        "
                        @click="showPassword = !showPassword"
                      >
                        <i
                          :class="
                            showPassword
                              ? 'i-lucide-eye-off size-4'
                              : 'i-lucide-eye size-4'
                          "
                        />
                      </button>
                    </div>
                  </div>

                  <button
                    type="submit"
                    class="auth-submit-btn"
                    :disabled="loginApi.showLoading"
                    data-testid="submit_button"
                  >
                    <Spinner
                      v-if="loginApi.showLoading"
                      :color-scheme="
                        localTheme === 'dark' ? 'primary' : 'white'
                      "
                      size="small"
                    />
                    <span v-else>{{ $t('LOGIN.SUBMIT') }}</span>
                  </button>
                </form>

                <router-link
                  v-if="showSsoLogin"
                  to="/app/login/sso"
                  class="auth-sso-btn"
                >
                  <i class="i-lucide-shield-check size-4" aria-hidden="true" />
                  <span>{{ $t('LOGIN.SAML.LABEL') }}</span>
                </router-link>

                <p v-if="showSignupLink" class="auth-signup-text">
                  {{ $t('LOGIN.INTRO.SIGNUP_PROMPT') }}
                  <router-link to="/app/auth/signup" class="signup-link">
                    {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
                  </router-link>
                </p>
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

/* THEME VARIABLES */
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
  --social-bg: #ffffff;
  --social-border: #e2e8f0;
  --social-text: #334155;
  --social-hover: #f1f5f9;
  --btn-bg: linear-gradient(135deg, #4f46e5 0%, #6366f1 100%);
  --btn-hover: linear-gradient(135deg, #4338ca 0%, #4f46e5 100%);
  --btn-text: #ffffff;
  --btn-shadow: 0 10px 25px -5px rgba(99, 102, 241, 0.35);
  --divider: #e2e8f0;
  --pill-bg: rgba(241, 245, 249, 0.8);
  --pill-border: rgba(226, 232, 240, 0.8);
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
  --social-bg: rgba(15, 23, 42, 0.6);
  --social-border: rgba(255, 255, 255, 0.12);
  --social-text: #f8fafc;
  --social-hover: rgba(30, 41, 59, 0.8);
  --btn-bg: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #df8eff 100%);
  --btn-hover: linear-gradient(135deg, #4f46e5 0%, #7c3aed 50%, #c084fc 100%);
  --btn-text: #ffffff;
  --btn-shadow: 0 12px 30px -5px rgba(124, 58, 237, 0.45);
  --divider: rgba(255, 255, 255, 0.1);
  --pill-bg: rgba(15, 23, 42, 0.6);
  --pill-border: rgba(255, 255, 255, 0.08);
  background-color: var(--bg-base);
  color: var(--text-main);
  color-scheme: dark;
}

/* THEME TOGGLE BUTTON */
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

/* BACKGROUND ORBS */
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

/* AUTH WRAPPER & GLASS CARD */
.auth-wrapper {
  position: relative;
  z-index: 10;
  width: 100%;
  max-width: 1040px;
  margin: 1.5rem;
}

.auth-glass-card {
  display: flex;
  min-height: 600px;
  border-radius: 1.75rem;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  backdrop-filter: blur(28px);
  box-shadow:
    0 25px 50px -12px rgba(0, 0, 0, 0.4),
    0 0 40px rgba(99, 102, 241, 0.08);
  overflow: hidden;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

/* HERO SECTION */
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

.auth-description {
  font-size: 0.9375rem;
  line-height: 1.6;
  color: var(--text-muted);
}

.auth-feature-pills {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: 0.5rem;
}

.feature-pill {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.625rem 1rem;
  border-radius: 0.875rem;
  background: var(--pill-bg);
  border: 1px solid var(--pill-border);
  color: var(--text-main);
  font-size: 0.875rem;
  font-weight: 500;
  transition: all 0.2s ease;
}

.feature-pill i {
  color: #00eefc;
}

/* FORM SECTION */
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

.auth-social-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.75rem 1.25rem;
  border-radius: 0.875rem;
  background: var(--social-bg);
  border: 1px solid var(--social-border);
  color: var(--social-text);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  transition: all 0.2s ease;
}

.auth-social-btn:hover {
  background: var(--social-hover);
  border-color: #6366f1;
  transform: translateY(-1px);
}

.auth-divider {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.auth-divider .line {
  flex: 1;
  height: 1px;
  background: var(--divider);
}

.auth-divider small {
  font-size: 0.75rem;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
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

.input-group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.input-group label,
.input-group-header label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-main);
}

.forgot-link {
  font-size: 0.75rem;
  font-weight: 500;
  color: #6366f1;
  text-decoration: none;
  transition: color 0.2s;
}

.forgot-link:hover {
  color: #8b5cf6;
  text-decoration: underline;
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
  padding: 0.8125rem 2.75rem 0.8125rem 2.75rem;
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

.password-toggle {
  position: absolute;
  right: 0.875rem;
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.25rem;
  border-radius: 0.375rem;
  transition: color 0.2s;
}

.password-toggle:hover {
  color: var(--text-main);
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

.auth-submit-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
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
  border: 1px dashed var(--input-border);
  color: var(--text-muted);
  font-size: 0.8125rem;
  font-weight: 500;
  text-decoration: none;
  transition: all 0.2s ease;
}

.auth-sso-btn:hover {
  color: var(--text-main);
  border-color: #6366f1;
}

.auth-signup-text {
  font-size: 0.8125rem;
  color: var(--text-muted);
  text-align: center;
  margin-top: 0.5rem;
}

.signup-link {
  color: #6366f1;
  font-weight: 600;
  text-decoration: none;
  margin-left: 0.25rem;
}

.signup-link:hover {
  text-decoration: underline;
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

.shake-animation {
  animation: shake 0.5s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
}

@keyframes shake {
  10%,
  90% {
    transform: translate3d(-1px, 0, 0);
  }
  20%,
  80% {
    transform: translate3d(2px, 0, 0);
  }
  30%,
  50%,
  70% {
    transform: translate3d(-3px, 0, 0);
  }
  40%,
  60% {
    transform: translate3d(3px, 0, 0);
  }
}

/* RESPONSIVE */
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

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
      // O tema é aplicado dinamicamente usando uma classe no container principal
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
    <div class="auth-bg-elements">
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
              <svg
                class="logo-icon"
                viewBox="0 0 64 64"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
              >
                <defs>
                  <linearGradient
                    id="node-grad"
                    x1="0%"
                    y1="0%"
                    x2="100%"
                    y2="100%"
                  >
                    <stop offset="0%" stop-color="#06b6d4" />
                    <stop offset="100%" stop-color="#3b82f6" />
                  </linearGradient>
                  <linearGradient
                    id="ring-grad"
                    x1="100%"
                    y1="100%"
                    x2="0%"
                    y2="0%"
                  >
                    <stop offset="0%" stop-color="#ec4899" />
                    <stop offset="100%" stop-color="#a855f7" />
                  </linearGradient>
                </defs>
                <circle
                  cx="32"
                  cy="32"
                  r="24"
                  stroke="url(#ring-grad)"
                  stroke-width="6"
                  stroke-linecap="round"
                  stroke-dasharray="80 30"
                  transform="rotate(45 32 32)"
                />
                <circle
                  cx="32"
                  cy="32"
                  r="16"
                  stroke="url(#node-grad)"
                  stroke-width="5"
                  stroke-linecap="round"
                  stroke-dasharray="40 20"
                  transform="rotate(-30 32 32)"
                />
                <circle cx="32" cy="32" r="8" fill="url(#node-grad)" />
                <circle cx="56" cy="32" r="4" fill="#ec4899" />
                <circle cx="8" cy="32" r="4" fill="#06b6d4" />
              </svg>
              <span class="logo-text">
                <span class="logo-highlight">{{ logoParts.prefix }}</span>
                <span>{{ logoParts.middle }}</span>
                <span class="logo-highlight">{{ logoParts.suffix }}</span>
              </span>
            </div>
            <h2 class="auth-headline">{{ $t('LOGIN.INTRO.TAGLINE') }}</h2>
            <p class="auth-description">
              {{ $t('LOGIN.INTRO.HERO_DESCRIPTION') }}
            </p>
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
                  <svg
                    class="logo-icon"
                    viewBox="0 0 64 64"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <circle
                      cx="32"
                      cy="32"
                      r="24"
                      stroke="url(#ring-grad)"
                      stroke-width="6"
                      stroke-linecap="round"
                      stroke-dasharray="80 30"
                      transform="rotate(45 32 32)"
                    />
                    <circle
                      cx="32"
                      cy="32"
                      r="16"
                      stroke="url(#node-grad)"
                      stroke-width="5"
                      stroke-linecap="round"
                      stroke-dasharray="40 20"
                      transform="rotate(-30 32 32)"
                    />
                    <circle cx="32" cy="32" r="8" fill="url(#node-grad)" />
                    <circle cx="56" cy="32" r="4" fill="#ec4899" />
                    <circle cx="8" cy="32" r="4" fill="#06b6d4" />
                  </svg>
                  <span class="logo-text">
                    <span class="logo-highlight">{{ logoParts.prefix }}</span>
                    <span>{{ logoParts.middle }}</span>
                    <span class="logo-highlight">{{ logoParts.suffix }}</span>
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
                <i class="i-lucide-circle-alert size-4" />
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
                        :tabindex="1"
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
                        :tabindex="2"
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
                    :tabindex="3"
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
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Outfit:wght@500;700;800&display=swap');

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
  --card-bg: rgba(255, 255, 255, 0.7);
  --card-border: rgba(255, 255, 255, 0.8);
  --form-bg: rgba(255, 255, 255, 0.9);
  --hero-bg: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.8) 0%,
    rgba(248, 250, 252, 0.4) 100%
  );
  --input-bg: rgba(241, 245, 249, 0.8);
  --input-border: #e2e8f0;
  --input-text: #0f172a;
  --social-bg: #ffffff;
  --social-border: #e2e8f0;
  --social-text: #334155;
  --social-hover: #f1f5f9;
  --btn-bg: #0f172a;
  --btn-hover: #1e293b;
  --btn-text: #ffffff;
  --btn-shadow: 0 4px 14px 0 rgba(15, 23, 42, 0.39);
  --btn-border: rgba(15, 23, 42, 1);
  --divider: #e2e8f0;

  background-color: var(--bg-base) !important;
  color: var(--text-main) !important;
}

.auth-modern.dark {
  --bg-base: #0b0f19;
  --text-main: #ffffff;
  --text-muted: #94a3b8;
  --card-bg: rgba(15, 23, 42, 0.4);
  --card-border: rgba(255, 255, 255, 0.12);
  --form-bg: rgba(2, 6, 23, 0.5);
  --hero-bg: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.08) 0%,
    rgba(255, 255, 255, 0.01) 100%
  );
  --input-bg: rgba(0, 0, 0, 0.2);
  --input-border: rgba(255, 255, 255, 0.1);
  --input-text: #ffffff;
  --social-bg: rgba(255, 255, 255, 0.05);
  --social-border: rgba(255, 255, 255, 0.1);
  --social-text: #ffffff;
  --social-hover: rgba(255, 255, 255, 0.1);
  --btn-bg: #ffffff;
  --btn-hover: #f8fafc;
  --btn-text: #0f172a;
  --btn-shadow: 0 4px 14px 0 rgba(255, 255, 255, 0.25);
  --btn-border: rgba(255, 255, 255, 1);
  --divider: rgba(255, 255, 255, 0.1);

  background-color: var(--bg-base) !important;
  color: var(--text-main) !important;
}

/* Theme Toggle Button */
.theme-toggle-btn {
  position: absolute;
  top: 1.5rem;
  right: 1.5rem;
  z-index: 50;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 50%;
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-main);
  cursor: pointer;
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  transition: all 0.3s ease;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.theme-toggle-btn:hover {
  transform: scale(1.05);
  background: var(--form-bg);
}

/* Background Animations */
.auth-bg-elements {
  position: absolute;
  inset: 0;
  z-index: 0;
  overflow: hidden;
  background-color: var(--bg-base);
  transition: background-color 0.5s ease;
}

.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  opacity: 0.8;
  animation: float 20s infinite ease-in-out alternate;
  mix-blend-mode: screen;
}

.auth-modern.light .orb {
  mix-blend-mode: multiply;
  opacity: 0.4;
}

.orb-1 {
  width: 700px;
  height: 700px;
  background: #4f46e5;
  top: -150px;
  left: -150px;
  animation-duration: 25s;
}

.orb-2 {
  width: 600px;
  height: 600px;
  background: #ec4899;
  bottom: -150px;
  right: -100px;
  animation-duration: 28s;
  animation-delay: -5s;
}

.orb-3 {
  width: 500px;
  height: 500px;
  background: #0ea5e9;
  top: 40%;
  left: 30%;
  animation-duration: 22s;
  animation-delay: -10s;
  opacity: 0.6;
}

.auth-modern.light .orb-1 {
  background: #cbd5e1;
}
.auth-modern.light .orb-2 {
  background: #93c5fd;
}
.auth-modern.light .orb-3 {
  background: #bae6fd;
}

.glass-overlay {
  position: absolute;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)' opacity='0.05'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 1;
}

@keyframes float {
  0% {
    transform: translate(0, 0) scale(1);
  }
  33% {
    transform: translate(40px, -60px) scale(1.1);
  }
  66% {
    transform: translate(-30px, 30px) scale(0.9);
  }
  100% {
    transform: translate(0, 0) scale(1);
  }
}

/* Main Layout */
.auth-wrapper {
  position: relative;
  z-index: 10;
  width: 100%;
  max-width: 1100px;
  padding: 2rem;
  perspective: 1200px;
}

.auth-glass-card {
  display: flex;
  background: var(--card-bg);
  backdrop-filter: blur(40px);
  -webkit-backdrop-filter: blur(40px);
  border: 1px solid var(--card-border);
  border-radius: 28px;
  box-shadow: 0 30px 60px -12px rgba(0, 0, 0, 0.2);
  overflow: hidden;
  min-height: 640px;
  animation: cardEntrance 1s cubic-bezier(0.2, 0.8, 0.2, 1);
  transition:
    background 0.5s ease,
    border-color 0.5s ease;
}

.auth-modern.dark .auth-glass-card {
  box-shadow:
    0 30px 60px -12px rgba(0, 0, 0, 0.5),
    inset 0 0 0 1px rgba(255, 255, 255, 0.05);
}

@keyframes cardEntrance {
  from {
    opacity: 0;
    transform: translateY(50px) scale(0.97);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

/* Hero Section */
.auth-hero {
  flex: 1;
  padding: 4rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  background: var(--hero-bg);
  border-right: 1px solid var(--card-border);
}

/* Custom Vector Logo */
.custom-logo {
  display: flex;
  align-items: center;
  gap: 8px;
}

.logo-icon {
  width: 48px;
  height: 48px;
  filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.2));
  animation: logoSpin 30s linear infinite;
}

@keyframes logoSpin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.logo-text {
  font-family: 'Outfit', sans-serif;
  font-size: 2.25rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--text-main);
  transition: color 0.5s ease;
}

.logo-highlight {
  background: linear-gradient(135deg, #a855f7, #ec4899);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.auth-brand-mark {
  margin-bottom: 2rem;
}

.auth-badge {
  font-family: 'Outfit', sans-serif;
  font-size: 2.5rem;
  font-weight: 800;
  color: var(--text-main);
  display: block;
  margin-bottom: 2.5rem;
}

.auth-headline {
  font-family: 'Outfit', sans-serif;
  font-size: 3.5rem;
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.03em;
  margin-bottom: 1.25rem;
  color: var(--text-main);
}

.auth-description {
  font-size: 1.15rem;
  line-height: 1.6;
  color: var(--text-muted);
  max-width: 90%;
}

/* Form Section */
.auth-form-pane {
  flex: 0 0 460px;
  padding: 4rem 3rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  background: var(--form-bg);
}

.auth-form-content {
  width: 100%;
}

.auth-brand-mobile {
  display: none;
  margin-bottom: 2rem;
  text-align: center;
}

.auth-wordmark-mobile {
  font-family: 'Outfit', sans-serif;
  font-size: 1.5rem;
  font-weight: 800;
  color: var(--text-main);
}

.auth-title {
  font-family: 'Outfit', sans-serif;
  font-size: 2rem;
  font-weight: 700;
  color: var(--text-main);
  margin-bottom: 0.5rem;
}

.auth-subtitle {
  color: var(--text-muted);
  font-size: 0.95rem;
  margin-bottom: 2.5rem;
}

.auth-interactive-area {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

/* Social Buttons */
.auth-social-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.9rem;
  background: var(--social-bg);
  border: 1px solid var(--social-border);
  border-radius: 14px;
  font-weight: 600;
  font-size: 0.95rem;
  color: var(--social-text);
  text-decoration: none;
  transition: all 0.3s ease;
}

.auth-social-btn:hover {
  background: var(--social-hover);
  transform: translateY(-2px);
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
  color: var(--text-muted);
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

/* Inputs */
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
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--text-main);
}

.input-group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.forgot-link {
  font-size: 0.8rem;
  font-weight: 600;
  color: #3b82f6;
  text-decoration: none;
  transition: color 0.2s;
}

.forgot-link:hover {
  text-decoration: underline;
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  border-radius: 12px;
  transition: all 0.3s ease;
  overflow: hidden;
}

.input-wrapper:focus-within {
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
}

.input-wrapper.has-error {
  border-color: #ef4444;
}

.input-icon {
  margin-left: 1rem;
  color: var(--text-muted);
  flex-shrink: 0;
  transition: color 0.3s ease;
}

.input-wrapper:focus-within .input-icon {
  color: #3b82f6;
}

main.auth-modern div.auth-wrapper input.modern-input {
  flex: 1;
  border: none;
  background: transparent !important;
  background-color: transparent !important;
  padding: 0.9rem 1rem 0.9rem 0.75rem;
  font-family: 'Inter', sans-serif;
  font-size: 0.95rem;
  color: var(--input-text);
  outline: none;
}

main.auth-modern div.auth-wrapper input.modern-input:-webkit-autofill,
main.auth-modern div.auth-wrapper input.modern-input:-webkit-autofill:hover,
main.auth-modern div.auth-wrapper input.modern-input:-webkit-autofill:focus,
main.auth-modern div.auth-wrapper input.modern-input:-webkit-autofill:active {
  transition: background-color 5000s ease-in-out 0s !important;
  -webkit-text-fill-color: var(--input-text) !important;
}

.modern-input::placeholder {
  color: var(--text-muted);
}

/* Auto-fill fix that respects the theme */
.modern-input:-webkit-autofill,
.modern-input:-webkit-autofill:hover,
.modern-input:-webkit-autofill:focus,
.modern-input:-webkit-autofill:active {
  -webkit-text-fill-color: var(--input-text) !important;
  transition: background-color 5000s ease-in-out 0s !important;
}

.password-toggle {
  background: none;
  border: none;
  padding: 0 1rem;
  color: var(--text-muted);
  cursor: pointer;
  display: flex;
  align-items: center;
  transition: color 0.2s;
}

.password-toggle:hover {
  color: var(--text-main);
}

/* Submit Button */
main.auth-modern div.auth-wrapper button.auth-submit-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 1rem;
  margin-top: 0.5rem;
  background: var(--btn-bg) !important;
  color: var(--btn-text) !important;
  border: 1px solid var(--btn-border) !important;
  border-radius: 14px;
  font-family: 'Inter', sans-serif;
  font-size: 1.05rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: var(--btn-shadow) !important;
  letter-spacing: 0.01em;
}

main.auth-modern div.auth-wrapper button.auth-submit-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.15) !important;
  background: var(--btn-hover) !important;
}

main.auth-modern div.auth-wrapper button.auth-submit-btn:active:not(:disabled) {
  transform: translateY(0);
}

main.auth-modern div.auth-wrapper button.auth-submit-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  transform: none;
}

/* Secondary Actions */
.auth-sso-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.875rem;
  background: transparent;
  border: 1px solid var(--input-border);
  border-radius: 12px;
  color: var(--text-main);
  font-weight: 600;
  font-size: 0.95rem;
  text-decoration: none;
  transition: all 0.2s ease;
}

.auth-sso-btn:hover {
  background: var(--social-bg);
  border-color: var(--text-muted);
}

.auth-signup-text {
  text-align: center;
  font-size: 0.9rem;
  color: var(--text-muted);
  margin-top: 1rem;
}

.signup-link {
  color: #3b82f6;
  font-weight: 600;
  text-decoration: none;
}

.signup-link:hover {
  text-decoration: underline;
}

/* Alerts and Loading */
.auth-alert-box {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  background: rgba(239, 68, 68, 0.1);
  border-left: 4px solid #ef4444;
  border-radius: 8px;
  color: #ef4444;
  font-size: 0.875rem;
  font-weight: 600;
  margin-bottom: 1.5rem;
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
    transform: translate3d(-4px, 0, 0);
  }
  40%,
  60% {
    transform: translate3d(4px, 0, 0);
  }
}

.auth-loading-state {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.5rem;
  background: var(--input-bg);
  border-radius: 12px;
  border: 1px dashed var(--input-border);
}

.loading-text p {
  font-weight: 600;
  color: var(--text-main);
  margin: 0 0 0.25rem;
}

.loading-text span {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.auth-spinner-ring {
  width: 2.5rem;
  height: 2.5rem;
  border: 3px solid rgba(59, 130, 246, 0.2);
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* Responsive */
@media (max-width: 900px) {
  .auth-glass-card {
    flex-direction: column;
    min-height: auto;
  }

  .auth-hero {
    padding: 3rem 2rem;
    border-right: none;
    border-bottom: 1px solid var(--card-border);
  }

  .auth-headline {
    font-size: 2.5rem;
  }

  .auth-form-pane {
    flex: auto;
    padding: 3rem 2rem;
  }
}

@media (max-width: 480px) {
  .auth-wrapper {
    padding: 1rem;
  }

  .theme-toggle-btn {
    top: 1rem;
    right: 1rem;
    width: 40px;
    height: 40px;
  }

  .auth-hero {
    padding: 2rem 1.5rem;
  }

  .auth-headline {
    font-size: 2rem;
  }

  .auth-form-pane {
    padding: 2rem 1.5rem;
  }

  .auth-title {
    font-size: 1.75rem;
  }
}
</style>

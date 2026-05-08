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
  methods: {
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
  <main class="auth">
    <!-- Painel decorativo (esquerda em desktop) -->
    <aside class="auth__brand" aria-hidden="true">
      <div class="auth__brand-stage">
        <div class="auth__brand-mark">
          <img
            v-if="brandLogo"
            :src="brandLogo"
            :alt="installationName"
            class="auth__brand-logo"
          />
          <span v-else class="auth__brand-wordmark">
            {{ installationName }}
          </span>
        </div>
        <p class="auth__brand-tagline">
          {{ $t('LOGIN.INTRO.TAGLINE') }}
        </p>
      </div>
      <div class="auth__brand-glow auth__brand-glow--one" />
      <div class="auth__brand-glow auth__brand-glow--two" />
    </aside>

    <!-- Form (direita em desktop) -->
    <section class="auth__pane" :aria-label="$t('LOGIN.INTRO.FORM_LABEL')">
      <div class="auth__card">
        <header class="auth__header">
          <div class="auth__brand-mobile">
            <img
              v-if="brandLogo"
              :src="brandLogo"
              :alt="installationName"
              class="auth__brand-logo"
            />
            <span v-else class="auth__brand-wordmark">
              {{ installationName }}
            </span>
          </div>
          <h1 class="auth__title">{{ $t('LOGIN.INTRO.WELCOME_TITLE') }}</h1>
          <p class="auth__subtitle">
            {{ $t('LOGIN.INTRO.FORM_SUBTITLE') }}
          </p>
        </header>

        <div v-if="mfaRequired" class="auth__mfa">
          <MfaVerification
            :mfa-token="mfaToken"
            @verified="handleMfaVerified"
            @cancel="handleMfaCancel"
          />
        </div>

        <div v-else :class="{ 'auth--shake': loginApi.hasErrored }">
          <div
            v-if="loginApi.message && loginApi.hasErrored"
            class="auth__alert"
            role="alert"
          >
            <i class="i-lucide-circle-alert size-4" />
            <span>{{ loginApi.message }}</span>
          </div>

          <div v-if="email" class="auth__loading" role="status">
            <span class="auth__spinner" aria-hidden="true" />
            <div>
              <p>{{ $t('LOGIN.INTRO.LOADING_TITLE') }}</p>
              <span>{{ $t('LOGIN.INTRO.LOADING_DESCRIPTION') }}</span>
            </div>
          </div>

          <div v-else class="auth__content">
            <a
              v-if="showGoogleLogin"
              :href="getGoogleAuthUrl()"
              class="auth__provider"
            >
              <span class="i-logos-google-icon size-5" aria-hidden="true" />
              <span>{{ $t('LOGIN.OAUTH.GOOGLE_LOGIN') }}</span>
            </a>

            <div v-if="showGoogleLogin && showEmailLogin" class="auth__divider">
              <span aria-hidden="true" />
              <small>{{ $t('LOGIN.INTRO.OR_WITH_EMAIL') }}</small>
              <span aria-hidden="true" />
            </div>

            <form
              v-if="showEmailLogin"
              class="auth__form"
              @submit.prevent="submitFormLogin"
            >
              <div class="auth__field">
                <label for="login-email">
                  {{ $t('LOGIN.EMAIL.LABEL') }}
                </label>
                <div
                  class="auth__control"
                  :class="{
                    'auth__control--error': v$.credentials.email.$error,
                  }"
                >
                  <i
                    class="auth__control-icon i-lucide-mail size-4"
                    aria-hidden="true"
                  />
                  <input
                    id="login-email"
                    v-model="credentials.email"
                    class="auth__input"
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

              <div class="auth__field">
                <div class="auth__field-row">
                  <label for="login-password">
                    {{ $t('LOGIN.PASSWORD.LABEL') }}
                  </label>
                  <router-link to="/app/auth/reset/password" class="auth__link">
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </div>
                <div
                  class="auth__control"
                  :class="{
                    'auth__control--error': v$.credentials.password.$error,
                  }"
                >
                  <i
                    class="auth__control-icon i-lucide-lock-keyhole size-4"
                    aria-hidden="true"
                  />
                  <input
                    id="login-password"
                    v-model="credentials.password"
                    class="auth__input"
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
                    class="auth__toggle"
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
                class="auth__submit"
                :disabled="loginApi.showLoading"
                data-testid="submit_button"
                :tabindex="3"
              >
                <Spinner
                  v-if="loginApi.showLoading"
                  color-scheme="white"
                  size="small"
                />
                <span v-else>{{ $t('LOGIN.SUBMIT') }}</span>
              </button>
            </form>

            <router-link
              v-if="showSsoLogin"
              to="/app/login/sso"
              class="auth__sso"
            >
              <i class="i-lucide-shield-check size-4" aria-hidden="true" />
              <span>{{ $t('LOGIN.SAML.LABEL') }}</span>
            </router-link>

            <p v-if="showSignupLink" class="auth__signup">
              {{ $t('LOGIN.INTRO.SIGNUP_PROMPT') }}
              <router-link to="/app/auth/signup" class="auth__link">
                {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
              </router-link>
            </p>
          </div>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
/* ──────────────────────────────────────────────────────────
 * Login — minimal, dark/light via tokens DS.
 * Layout: 2 colunas em desktop (brand visual + form),
 *         1 coluna em mobile (form full-width).
 * ────────────────────────────────────────────────────────── */

@keyframes auth-shake {
  0%,
  100% {
    transform: translateX(0);
  }
  25% {
    transform: translateX(-4px);
  }
  75% {
    transform: translateX(4px);
  }
}

@keyframes auth-spin {
  to {
    transform: rotate(360deg);
  }
}

@keyframes auth-glow-pulse {
  0%,
  100% {
    opacity: 0.6;
    transform: scale(1);
  }
  50% {
    opacity: 0.9;
    transform: scale(1.06);
  }
}

.auth {
  position: fixed;
  inset: 0;
  display: grid;
  grid-template-columns: 1fr 1fr;
  font-family: var(--ds-font-sans);
  color: rgb(var(--ds-fg-default));
  background: rgb(var(--ds-bg-canvas));
}

/* ── Painel de marca (esquerda) ──────────────────────────── */

.auth__brand {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  padding: 3rem;
  background: radial-gradient(
      circle at 30% 30%,
      rgb(var(--ds-accent-primary) / 0.45),
      transparent 55%
    ),
    radial-gradient(
      circle at 70% 70%,
      rgb(var(--ds-accent-secondary) / 0.35),
      transparent 55%
    ),
    linear-gradient(
      135deg,
      rgb(var(--ds-accent-primary) / 0.08),
      rgb(var(--ds-accent-secondary) / 0.06)
    ),
    rgb(var(--ds-bg-elevated));
}

.auth__brand-stage {
  position: relative;
  z-index: 2;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.25rem;
  text-align: center;
  max-width: 24rem;
}

.auth__brand-mark {
  display: flex;
  align-items: center;
  justify-content: center;
}

.auth__brand-logo {
  max-width: 18rem;
  max-height: 4.5rem;
  object-fit: contain;
  filter: drop-shadow(0 8px 24px rgb(var(--ds-accent-primary) / 0.3));
}

.auth__brand-wordmark {
  font-size: clamp(2.25rem, 4vw, 3rem);
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
  color: rgb(var(--ds-fg-default));
}

.auth__brand-tagline {
  margin: 0;
  font-size: 1rem;
  font-weight: 500;
  line-height: 1.5;
  color: rgb(var(--ds-fg-muted));
  max-width: 22rem;
}

/* Glows decorativos */
.auth__brand-glow {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  pointer-events: none;
  animation: auth-glow-pulse 8s ease-in-out infinite;
}

.auth__brand-glow--one {
  top: -10%;
  left: -10%;
  width: 60%;
  height: 60%;
  background: rgb(var(--ds-accent-primary) / 0.35);
}

.auth__brand-glow--two {
  bottom: -10%;
  right: -10%;
  width: 55%;
  height: 55%;
  background: rgb(var(--ds-accent-secondary) / 0.3);
  animation-delay: 4s;
}

/* ── Painel do form (direita) ────────────────────────────── */

.auth__pane {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: clamp(1.5rem, 4vw, 3rem);
  overflow-y: auto;
}

.auth__card {
  width: 100%;
  max-width: 24rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.auth__brand-mobile {
  display: none;
  align-items: center;
  justify-content: center;
  margin-bottom: 0.5rem;
}

.auth__brand-mobile .auth__brand-logo {
  max-width: 11rem;
  max-height: 2.5rem;
}

.auth__brand-mobile .auth__brand-wordmark {
  font-size: 1.65rem;
}

.auth__header {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.auth__title {
  margin: 0;
  font-size: clamp(1.6rem, 2.5vw, 1.85rem);
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
  color: rgb(var(--ds-fg-default));
}

.auth__subtitle {
  margin: 0;
  font-size: 0.92rem;
  line-height: 1.5;
  color: rgb(var(--ds-fg-muted));
}

.auth__content,
.auth__form {
  display: flex;
  flex-direction: column;
}

.auth__content {
  gap: 1rem;
}

.auth__form {
  gap: 0.85rem;
}

/* ── Provider buttons (Google) ───────────────────────────── */

.auth__provider {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  width: 100%;
  min-height: 2.85rem;
  padding: 0.7rem 1rem;
  font-size: 0.92rem;
  font-weight: 600;
  border-radius: var(--ds-radius-md);
  border: 1px solid rgb(var(--ds-border-default));
  color: rgb(var(--ds-fg-default));
  background: rgb(var(--ds-bg-surface));
  transition:
    background-color var(--ds-duration-base) var(--ds-easing-standard),
    border-color var(--ds-duration-base) var(--ds-easing-standard);
}

.auth__provider:hover {
  border-color: rgb(var(--ds-border-strong));
  background: rgb(var(--ds-bg-hover));
}

.auth__divider {
  display: flex;
  align-items: center;
  gap: 0.7rem;
}

.auth__divider span {
  flex: 1;
  height: 1px;
  background: rgb(var(--ds-border-subtle));
}

.auth__divider small {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgb(var(--ds-fg-subtle));
}

/* ── Form fields ─────────────────────────────────────────── */

.auth__field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.auth__field label {
  font-size: 0.82rem;
  font-weight: 600;
  line-height: 1.25;
  color: rgb(var(--ds-fg-default));
}

.auth__field-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.auth__link {
  font-size: 0.78rem;
  font-weight: 600;
  color: rgb(var(--ds-accent-primary));
  text-decoration: none;
}

:deep(.dark) .auth__link,
.dark .auth__link {
  color: rgb(var(--iris-11));
}

.auth__link:hover {
  text-decoration: underline;
}

.auth__control {
  position: relative;
  display: flex;
  align-items: center;
  min-height: 2.85rem;
  border: 1px solid rgb(var(--ds-border-default));
  border-radius: var(--ds-radius-md);
  background: rgb(var(--ds-bg-sunken));
  transition:
    border-color var(--ds-duration-base) var(--ds-easing-standard),
    box-shadow var(--ds-duration-base) var(--ds-easing-standard),
    background-color var(--ds-duration-base) var(--ds-easing-standard);
}

.auth__control:focus-within {
  border-color: rgb(var(--ds-border-focus));
  background: rgb(var(--ds-bg-surface));
  box-shadow: 0 0 0 3px rgb(var(--ds-accent-primary) / 0.2);
}

.auth__control--error {
  border-color: rgb(var(--ds-state-danger));
}

.auth__control-icon {
  flex-shrink: 0;
  margin: 0 0.65rem 0 0.85rem;
  color: rgb(var(--ds-fg-subtle));
}

.auth__toggle {
  display: grid;
  place-items: center;
  width: 2.6rem;
  height: 100%;
  flex-shrink: 0;
  border: 0;
  background: transparent;
  color: rgb(var(--ds-fg-subtle));
  cursor: pointer;
}

.auth__toggle:hover,
.auth__toggle:focus-visible {
  color: rgb(var(--ds-accent-primary));
  outline: none;
}

/* Reset agressivo do <input> nativo */
.auth .auth__control input.auth__input,
.auth .auth__control input.auth__input[type='email'],
.auth .auth__control input.auth__input[type='password'],
.auth .auth__control input.auth__input[type='text'] {
  all: unset !important;
  flex: 1 !important;
  min-width: 0 !important;
  height: 100% !important;
  padding: 0 0.85rem 0 0 !important;
  font-family: inherit !important;
  font-size: 0.94rem !important;
  font-weight: 500 !important;
  line-height: 1.4 !important;
  color: rgb(var(--ds-fg-default)) !important;
  caret-color: rgb(var(--ds-accent-primary)) !important;
  background: transparent !important;
}

.auth .auth__control input.auth__input::placeholder {
  color: rgb(var(--ds-fg-subtle)) !important;
  opacity: 1 !important;
}

.auth .auth__control input.auth__input:-webkit-autofill {
  -webkit-text-fill-color: rgb(var(--ds-fg-default)) !important;
  caret-color: rgb(var(--ds-accent-primary)) !important;
  -webkit-box-shadow: 0 0 0 1000px rgb(var(--ds-bg-sunken)) inset !important;
  transition: background-color 9999s ease-out 0s;
}

/* ── Submit button — sempre roxo da marca ────────────────── */

.auth .auth__submit[type='submit'] {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  gap: 0.5rem !important;
  width: 100% !important;
  min-height: 2.95rem !important;
  margin-top: 0.4rem !important;
  padding: 0.78rem 1rem !important;
  font-family: inherit !important;
  font-size: 0.94rem !important;
  font-weight: 600 !important;
  border: 0 !important;
  border-radius: var(--ds-radius-md) !important;
  color: rgb(var(--ds-fg-on-accent)) !important;
  background: rgb(var(--ds-accent-primary)) !important;
  box-shadow:
    0 1px 2px rgb(var(--ds-accent-primary) / 0.4),
    0 8px 24px rgb(var(--ds-accent-primary) / 0.25) !important;
  cursor: pointer !important;
  transition:
    background-color var(--ds-duration-base) var(--ds-easing-standard),
    box-shadow var(--ds-duration-base) var(--ds-easing-standard),
    transform var(--ds-duration-base) var(--ds-easing-standard) !important;
}

.auth .auth__submit[type='submit']:hover:not(:disabled) {
  transform: translateY(-1px);
  background: rgb(var(--ds-accent-primary-hover)) !important;
  box-shadow:
    0 1px 2px rgb(var(--ds-accent-primary) / 0.5),
    0 12px 32px rgb(var(--ds-accent-primary) / 0.35) !important;
}

.auth .auth__submit[type='submit']:disabled {
  cursor: not-allowed;
  opacity: 0.6;
  transform: none;
}

/* ── Estados auxiliares ──────────────────────────────────── */

.auth__alert {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  padding: 0.7rem 0.85rem;
  font-size: 0.86rem;
  border: 1px solid rgb(var(--ds-state-danger) / 0.3);
  border-radius: var(--ds-radius-md);
  color: rgb(var(--ds-state-danger));
  background: rgb(var(--ds-state-danger-soft));
}

.auth__loading {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  padding: 1rem;
  border: 1px solid rgb(var(--ds-border-subtle));
  border-radius: var(--ds-radius-md);
  background: rgb(var(--ds-bg-sunken));
}

.auth__loading p {
  margin: 0;
  font-size: 0.94rem;
  font-weight: 600;
  color: rgb(var(--ds-fg-default));
}

.auth__loading span {
  font-size: 0.82rem;
  color: rgb(var(--ds-fg-muted));
}

.auth__spinner {
  width: 2rem;
  height: 2rem;
  flex-shrink: 0;
  border: 3px solid rgb(var(--ds-accent-primary) / 0.18);
  border-top-color: rgb(var(--ds-accent-primary));
  border-radius: 50%;
  animation: auth-spin 0.8s linear infinite;
}

.auth__sso {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  min-height: 2.6rem;
  padding: 0.55rem 0.95rem;
  font-size: 0.86rem;
  font-weight: 600;
  border-radius: var(--ds-radius-md);
  border: 1px solid rgb(var(--ds-border-subtle));
  color: rgb(var(--ds-fg-muted));
  background: transparent;
  text-decoration: none;
  transition:
    color var(--ds-duration-base) var(--ds-easing-standard),
    border-color var(--ds-duration-base) var(--ds-easing-standard),
    background-color var(--ds-duration-base) var(--ds-easing-standard);
}

.auth__sso:hover {
  color: rgb(var(--ds-fg-default));
  border-color: rgb(var(--ds-border-default));
  background: rgb(var(--ds-bg-hover));
}

.auth__signup {
  margin: 0;
  font-size: 0.86rem;
  text-align: center;
  color: rgb(var(--ds-fg-muted));
}

.auth__mfa {
  max-height: 70vh;
  overflow: auto;
}

.auth--shake {
  animation: auth-shake 0.34s ease-in-out;
}

/* ── Mobile ─────────────────────────────────────────────── */

@media (max-width: 900px) {
  .auth {
    grid-template-columns: 1fr;
  }

  .auth__brand {
    display: none;
  }

  .auth__brand-mobile {
    display: flex;
  }
}

@media (max-width: 480px) {
  .auth__pane {
    padding: 1.5rem 1.25rem;
  }

  .auth .auth__control input.auth__input {
    font-size: 16px !important; /* evita zoom no iOS */
  }
}

/* Login hardening: the auth route can render before the dashboard design
   tokens are available, so this page keeps its own visible theme tokens. */
.auth {
  --auth-bg: #edf4fb;
  --auth-panel: #ffffff;
  --auth-panel-soft: #f8fbff;
  --auth-side: #f7fbff;
  --auth-text: #0f172a;
  --auth-muted: #475569;
  --auth-subtle: #64748b;
  --auth-border: #c9d8ea;
  --auth-border-strong: #8fa8c7;
  --auth-input: #ffffff;
  --auth-input-hover: #f8fbff;
  --auth-primary: #2563eb;
  --auth-primary-strong: #1d4ed8;
  --auth-primary-soft: #dbeafe;
  --auth-teal: #0f766e;
  --auth-danger: #e11d48;
  --auth-danger-soft: #fff1f2;
  --auth-shadow: 0 28px 80px rgba(15, 23, 42, 0.16);
  --auth-radius: 1.35rem;

  grid-template-columns: minmax(390px, 0.88fr) minmax(0, 1.12fr);
  min-height: 100dvh;
  overflow: hidden;
  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    'Segoe UI',
    sans-serif;
  color: var(--auth-text);
  background: linear-gradient(
      180deg,
      rgba(255, 255, 255, 0.74),
      transparent 42%
    ),
    var(--auth-bg);
}

:deep(.dark) .auth,
:deep(.theme-dark) .auth,
:deep([data-theme='dark']) .auth {
  --auth-bg: #09111f;
  --auth-panel: #101827;
  --auth-panel-soft: #0d1524;
  --auth-side: #0f1b2c;
  --auth-text: #f8fafc;
  --auth-muted: #cbd5e1;
  --auth-subtle: #94a3b8;
  --auth-border: #26364e;
  --auth-border-strong: #3d5270;
  --auth-input: #0b1423;
  --auth-input-hover: #111d30;
  --auth-primary: #60a5fa;
  --auth-primary-strong: #3b82f6;
  --auth-primary-soft: rgba(96, 165, 250, 0.18);
  --auth-teal: #2dd4bf;
  --auth-danger: #fb7185;
  --auth-danger-soft: rgba(251, 113, 133, 0.12);
  --auth-shadow: 0 32px 90px rgba(0, 0, 0, 0.42);
}

.auth__pane {
  grid-column: 1;
  grid-row: 1;
  min-height: 100dvh;
  padding: clamp(1.5rem, 4vw, 4rem);
  background: var(--auth-bg);
}

.auth__brand {
  grid-column: 2;
  grid-row: 1;
  justify-content: flex-start;
  padding: clamp(2rem, 5vw, 5rem);
  border-left: 1px solid var(--auth-border);
  border-right: 0;
  background: linear-gradient(rgba(37, 99, 235, 0.08) 1px, transparent 1px),
    linear-gradient(90deg, rgba(37, 99, 235, 0.08) 1px, transparent 1px),
    linear-gradient(135deg, var(--auth-side), var(--auth-panel-soft));
  background-size:
    72px 72px,
    72px 72px,
    auto;
}

.auth__brand-stage {
  align-items: flex-start;
  width: min(100%, 38rem);
  max-width: 38rem;
  padding: clamp(1.5rem, 3vw, 2.3rem);
  text-align: left;
  border: 1px solid var(--auth-border);
  border-radius: calc(var(--auth-radius) + 0.35rem);
  background: rgba(255, 255, 255, 0.74);
  box-shadow: var(--auth-shadow);
  backdrop-filter: blur(18px);
}

:deep(.dark) .auth__brand-stage,
:deep(.theme-dark) .auth__brand-stage,
:deep([data-theme='dark']) .auth__brand-stage {
  background: rgba(15, 23, 42, 0.74);
}

.auth__brand-stage::after {
  content: 'Organize atendimentos, leads, clientes e reunioes em um CRM simples para sua equipe.';
  display: block;
  max-width: 31rem;
  margin-top: 0.25rem;
  font-size: 1rem;
  line-height: 1.7;
  color: var(--auth-muted);
}

.auth__brand-mark {
  justify-content: flex-start;
}

.auth__brand-logo {
  max-width: 15rem;
  max-height: 4rem;
  filter: none;
}

.auth__brand-wordmark {
  color: var(--auth-text);
  font-size: clamp(2.2rem, 4.8vw, 4rem);
  font-weight: 850;
  letter-spacing: 0;
}

.auth__brand-tagline {
  max-width: 34rem;
  color: var(--auth-text);
  font-size: clamp(2rem, 4vw, 4.7rem);
  font-weight: 850;
  line-height: 0.98;
  letter-spacing: 0;
}

.auth__brand-glow {
  display: none;
}

.auth__card {
  max-width: 28rem;
  padding: clamp(1.35rem, 3.2vw, 2.25rem);
  gap: 1.35rem;
  border: 1px solid var(--auth-border);
  border-radius: var(--auth-radius);
  background: var(--auth-panel);
  box-shadow: var(--auth-shadow);
}

.auth__brand-mobile {
  justify-content: flex-start;
}

.auth__title {
  color: var(--auth-text);
  font-size: clamp(1.9rem, 4vw, 2.45rem);
  font-weight: 850;
  letter-spacing: 0;
}

.auth__subtitle,
.auth__signup {
  color: var(--auth-muted);
}

.auth__provider,
.auth__sso {
  min-height: 3rem;
  border: 1px solid var(--auth-border);
  border-radius: 0.95rem;
  color: var(--auth-text);
  background: var(--auth-panel);
}

.auth__provider:hover,
.auth__sso:hover {
  border-color: var(--auth-border-strong);
  background: var(--auth-input-hover);
}

.auth__divider span {
  background: var(--auth-border);
}

.auth__divider small,
.auth__control-icon,
.auth__toggle {
  color: var(--auth-subtle);
}

.auth__field label {
  color: var(--auth-text);
  font-weight: 750;
}

.auth__link,
:deep(.dark) .auth__link,
.dark .auth__link {
  color: var(--auth-teal);
}

.auth__control {
  min-height: 3.1rem;
  overflow: hidden;
  border: 1px solid var(--auth-border);
  border-radius: 0.95rem;
  background: var(--auth-input);
  box-shadow: 0 1px 0 rgba(15, 23, 42, 0.04);
}

.auth__control:hover {
  border-color: var(--auth-border-strong);
  background: var(--auth-input-hover);
}

.auth__control:focus-within {
  border-color: var(--auth-primary);
  background: var(--auth-input);
  box-shadow:
    0 0 0 4px var(--auth-primary-soft),
    0 12px 28px rgba(37, 99, 235, 0.12);
}

.auth__control--error {
  border-color: var(--auth-danger);
}

.auth__control-icon {
  margin: 0 0.75rem 0 0.95rem;
}

.auth__toggle {
  width: 3rem;
}

.auth__toggle:hover,
.auth__toggle:focus-visible {
  color: var(--auth-primary);
}

.auth .auth__control input.auth__input,
.auth .auth__control input.auth__input[type='email'],
.auth .auth__control input.auth__input[type='password'],
.auth .auth__control input.auth__input[type='text'] {
  color: var(--auth-text) !important;
  caret-color: var(--auth-primary) !important;
}

.auth .auth__control input.auth__input::placeholder {
  color: var(--auth-subtle) !important;
}

.auth .auth__control input.auth__input:-webkit-autofill {
  -webkit-text-fill-color: var(--auth-text) !important;
  caret-color: var(--auth-primary) !important;
  -webkit-box-shadow: 0 0 0 1000px var(--auth-input) inset !important;
}

.auth .auth__submit[type='submit'] {
  min-height: 3.15rem !important;
  border-radius: 0.95rem !important;
  color: #ffffff !important;
  background: linear-gradient(
    135deg,
    var(--auth-primary),
    var(--auth-primary-strong)
  ) !important;
  box-shadow:
    0 12px 28px rgba(37, 99, 235, 0.28),
    inset 0 1px 0 rgba(255, 255, 255, 0.26) !important;
}

.auth .auth__submit[type='submit']:hover:not(:disabled) {
  background: linear-gradient(
    135deg,
    var(--auth-primary-strong),
    var(--auth-primary)
  ) !important;
  box-shadow:
    0 16px 36px rgba(37, 99, 235, 0.34),
    inset 0 1px 0 rgba(255, 255, 255, 0.28) !important;
}

.auth .auth__submit[type='submit']:disabled {
  color: rgba(255, 255, 255, 0.82) !important;
  background: linear-gradient(135deg, #93c5fd, #60a5fa) !important;
  opacity: 0.92;
}

.auth__alert {
  border-color: rgba(225, 29, 72, 0.28);
  color: var(--auth-danger);
  background: var(--auth-danger-soft);
}

.auth__loading {
  border-color: var(--auth-border);
  background: var(--auth-input-hover);
}

.auth__loading p {
  color: var(--auth-text);
}

.auth__loading span {
  color: var(--auth-muted);
}

.auth__spinner {
  border-color: rgba(37, 99, 235, 0.2);
  border-top-color: var(--auth-primary);
}

@media (max-width: 900px) {
  .auth {
    grid-template-columns: 1fr;
    overflow: auto;
  }

  .auth__brand {
    display: none;
  }

  .auth__pane {
    grid-column: 1;
    min-height: 100dvh;
  }

  .auth__brand-mobile {
    display: flex;
  }

  .auth__card {
    max-width: 30rem;
  }
}

@media (max-width: 520px) {
  .auth__pane {
    padding: 1rem;
  }

  .auth__card {
    padding: 1.15rem;
    border-radius: 1.1rem;
  }

  .auth__title {
    font-size: 1.7rem;
  }
}
</style>

<script>
import SnackbarContainer from './components/SnackBar/Container.vue';
import { setColorTheme } from 'dashboard/helper/themeHelper';
import { setI18nLocale } from 'dashboard/i18n';

const COLOR_SCHEME_STORAGE_KEY = 'color_scheme';
const LEGACY_LOGIN_THEME_STORAGE_KEY = 'chusterm-login-theme';
const THEME_MEDIA_QUERY = '(prefers-color-scheme: dark)';

export default {
  components: { SnackbarContainer },
  data() {
    return {
      themeMediaQuery: null,
      themeStorageHandler: null,
    };
  },
  mounted() {
    this.initializeColorTheme();
    this.listenToThemeChanges();
    this.listenToStorageChanges();
    this.setLocale(window.chustermConfig.selectedLocale);
  },
  unmounted() {
    if (this.themeMediaQuery) {
      this.themeMediaQuery.onchange = null;
    }
    if (this.themeStorageHandler) {
      window.removeEventListener('storage', this.themeStorageHandler);
    }
  },
  methods: {
    initializeColorTheme() {
      const isOSOnDarkMode = window.matchMedia(THEME_MEDIA_QUERY).matches;
      setColorTheme(isOSOnDarkMode);
    },
    listenToThemeChanges() {
      this.themeMediaQuery = window.matchMedia(THEME_MEDIA_QUERY);
      this.themeMediaQuery.onchange = event => {
        setColorTheme(event.matches);
      };
    },
    listenToStorageChanges() {
      this.themeStorageHandler = event => {
        if (
          event.key === COLOR_SCHEME_STORAGE_KEY ||
          event.key === LEGACY_LOGIN_THEME_STORAGE_KEY
        ) {
          this.initializeColorTheme();
        }
      };
      window.addEventListener('storage', this.themeStorageHandler);
    },
    setLocale(locale) {
      const isAuthRoute =
        window.location.pathname.startsWith('/app/login') ||
        window.location.pathname.startsWith('/app/auth');
      setI18nLocale(this.$root.$i18n, isAuthRoute ? 'pt_BR' : locale);
    },
  },
};
</script>

<template>
  <div
    class="h-full min-h-screen w-full bg-ds-bg-canvas text-ds-fg-default antialiased"
  >
    <router-view />
    <SnackbarContainer />
  </div>
</template>

<style lang="scss">
@tailwind base;
@tailwind components;
@tailwind utilities;

@import '@fontsource-variable/manrope/wght.css';
@import 'shared/assets/fonts/InterDisplay/inter-display';
@import 'shared/assets/fonts/inter';
@import '../dashboard/assets/scss/next-colors';
@import '../dashboard/assets/scss/design-tokens';

html,
body {
  font-family: var(--ds-font-sans);
  @apply h-full w-full;

  input,
  select {
    outline: none;
  }
}

.text-link {
  @apply text-n-brand font-medium hover:text-n-blue-10;
}

.v-popper--theme-tooltip .v-popper__inner {
  background: black !important;
  font-size: 0.75rem;
  padding: 4px 8px !important;
  border-radius: 6px;
  font-weight: 400;
}

.v-popper--theme-tooltip .v-popper__arrow-container {
  display: none;
}
</style>

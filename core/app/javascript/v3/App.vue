<script>
import SnackbarContainer from './components/SnackBar/Container.vue';

const COLOR_SCHEME_STORAGE_KEY = 'color_scheme';
const LEGACY_LOGIN_THEME_STORAGE_KEY = 'chusterm-login-theme';
const THEME_MEDIA_QUERY = '(prefers-color-scheme: dark)';

export default {
  components: { SnackbarContainer },
  data() {
    return { theme: 'light' };
  },
  mounted() {
    this.setColorTheme();
    this.listenToThemeChanges();
    this.setLocale(window.chustermConfig.selectedLocale);
  },
  methods: {
    setColorTheme() {
      const isOSOnDarkMode = window.matchMedia(THEME_MEDIA_QUERY).matches;
      const preferredTheme = this.getPreferredTheme();
      const resolvedTheme =
        preferredTheme === 'dark' ||
        ((preferredTheme === 'auto' || preferredTheme === 'system') &&
          isOSOnDarkMode)
          ? 'dark'
          : 'light';

      this.applyDocumentTheme(resolvedTheme);
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
    applyDocumentTheme(resolvedTheme) {
      this.theme = resolvedTheme;
      document.documentElement.dataset.theme = resolvedTheme;
      document.body.dataset.theme = resolvedTheme;
      document.documentElement.classList.toggle(
        'dark',
        resolvedTheme === 'dark'
      );
      document.body.classList.toggle('dark', resolvedTheme === 'dark');
      document.body.classList.toggle('theme-dark', resolvedTheme === 'dark');
      document.body.classList.toggle('theme-light', resolvedTheme !== 'dark');
      document.documentElement.style.setProperty('color-scheme', resolvedTheme);
    },
    listenToThemeChanges() {
      const mql = window.matchMedia(THEME_MEDIA_QUERY);

      mql.onchange = e => {
        const preferredTheme = this.getPreferredTheme();
        if (preferredTheme === 'auto' || preferredTheme === 'system') {
          this.applyDocumentTheme(e.matches ? 'dark' : 'light');
        }
      };

      window.addEventListener('storage', e => {
        if (
          e.key === COLOR_SCHEME_STORAGE_KEY ||
          e.key === LEGACY_LOGIN_THEME_STORAGE_KEY
        ) {
          this.setColorTheme();
        }
      });
    },
    setLocale(locale) {
      const isAuthRoute =
        window.location.pathname.startsWith('/app/login') ||
        window.location.pathname.startsWith('/app/auth');
      this.$root.$i18n.locale = isAuthRoute ? 'pt_BR' : locale || 'pt_BR';
    },
  },
};
</script>

<template>
  <div class="h-full min-h-screen w-full antialiased" :class="theme">
    <router-view />
    <SnackbarContainer />
  </div>
</template>

<style lang="scss">
@tailwind base;
@tailwind components;
@tailwind utilities;

@import '../dashboard/assets/scss/next-colors';

html,
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
    Oxygen-Sans, Ubuntu, Cantarell, 'Helvetica Neue', sans-serif;
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

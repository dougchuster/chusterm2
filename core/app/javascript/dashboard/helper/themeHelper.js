import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

const LEGACY_LOGIN_THEME_STORAGE_KEY = 'chusterm-login-theme';

export const setColorTheme = isOSOnDarkMode => {
  const storedColorScheme =
    LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) ||
    LocalStorage.get(LEGACY_LOGIN_THEME_STORAGE_KEY);
  const selectedColorScheme = ['light', 'dark', 'auto', 'system'].includes(
    storedColorScheme
  )
    ? storedColorScheme
    : 'auto';
  const followsSystemTheme = ['auto', 'system'].includes(selectedColorScheme);
  const shouldUseDarkTheme =
    (followsSystemTheme && isOSOnDarkMode) || selectedColorScheme === 'dark';

  const resolvedTheme = shouldUseDarkTheme ? 'dark' : 'light';
  document.documentElement.dataset.theme = resolvedTheme;
  document.body.dataset.theme = resolvedTheme;
  document.documentElement.classList.toggle('dark', shouldUseDarkTheme);

  if (shouldUseDarkTheme) {
    document.body.classList.add('dark');
    document.body.classList.add('theme-dark');
    document.body.classList.remove('theme-light');
    document.documentElement.style.setProperty('color-scheme', 'dark');
  } else {
    document.body.classList.remove('dark');
    document.body.classList.remove('theme-dark');
    document.body.classList.add('theme-light');
    document.documentElement.style.setProperty('color-scheme', 'light');
  }
};

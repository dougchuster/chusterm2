import { getCurrentInstance } from 'vue';
import { useI18n } from 'vue-i18n';

/**
 * Shared translation helper for design-system components.
 *
 * Design-system components are rendered both inside the dashboard (where the
 * global i18n instance is available) and in isolated unit tests or previews
 * where it is not. This composable resolves a key through whichever i18n
 * instance is reachable and falls back to the English literal otherwise.
 *
 * Must be called during component setup.
 */
export function useDsTranslate() {
  let i18n = null;
  try {
    i18n = useI18n();
  } catch (error) {
    // Rendered outside an i18n context: fallbacks are used instead.
  }

  const instance = getCurrentInstance();

  const interpolate = (text, values) => {
    if (typeof text !== 'string') return text;
    return Object.keys(values).reduce(
      (acc, param) =>
        acc.replace(new RegExp(`{${param}}`, 'g'), String(values[param])),
      text
    );
  };

  const translate = (key, fallback, values = {}) => {
    const globals = instance?.appContext?.config?.globalProperties;
    const customT = instance?.proxy?.$t || globals?.$t;
    const customTe = instance?.proxy?.$te || globals?.$te;

    if (typeof customTe === 'function' && customTe(key)) {
      // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
      return customT(key, values);
    }

    if (typeof customT === 'function') {
      // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
      const resolved = customT(key, values);
      if (resolved && resolved !== key) return resolved;
    }

    if (typeof i18n?.te === 'function' && i18n.te(key)) {
      // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
      return i18n.t(key, values);
    }

    return interpolate(fallback, values);
  };

  return { translate };
}

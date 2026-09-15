// Apenas o fallback (en) e o locale padrão do produto (pt_BR) entram no chunk
// inicial. Os outros 50+ idiomas viram chunks próprios carregados sob demanda
// por setI18nLocale — tira ~10,5 MB de JS do primeiro load (CRM-010).
import en from './locale/en';
import pt_BR from './locale/pt_BR';

// 'zh' é um diretório parcial (index.js sem os JSONs) que nunca foi servido —
// fica fora do glob até ser completado ou removido.
const localeLoaders = import.meta.glob([
  './locale/*/index.js',
  '!./locale/zh/index.js',
  // en/pt_BR já são import estático — fora do glob para não gerar chunk duplo.
  '!./locale/en/index.js',
  '!./locale/pt_BR/index.js',
]);
const loadedLocales = new Set(['en', 'pt_BR']);

/**
 * Carrega o locale sob demanda (se ainda não estiver no bundle) e o ativa.
 * @param {object} composer - `this.$root.$i18n` no modo composition do vue-i18n
 * @param {string} locale - código do locale (ex.: 'fr', 'zh_CN')
 */
export async function setI18nLocale(composer, locale) {
  const target = locale || 'pt_BR';
  if (!loadedLocales.has(target)) {
    const loader = localeLoaders[`./locale/${target}/index.js`];
    if (loader) {
      const messages = (await loader()).default;
      composer.setLocaleMessage(target, messages);
      loadedLocales.add(target);
    }
    // Locale sem arquivo: vue-i18n cai no fallbackLocale ('en') com warning.
  }
  composer.locale = target;
}

export default {
  en,
  pt_BR,
};

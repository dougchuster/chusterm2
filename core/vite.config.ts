/// <reference types="vitest" />

/**
What's going on with library mode?

Glad you asked, here's a quick rundown:

1. vite-plugin-ruby will automatically bring all the entrypoints like dashbord and widget as input to vite.
2. vite needs to be in library mode to build the SDK as a single file. (UMD) format and set `inlineDynamicImports` to true.
3. But when setting `inlineDynamicImports` to true, vite will not be able to handle mutliple entrypoints.

This puts us in a deadlock, now there are two ways around this, either add another separate build pipeline to
the app using vanilla rollup or rspack or something. The second option is to remove sdk building from the main pipeline
and build it separately using Vite itself, toggled by an ENV variable.

`BUILD_MODE=library bin/vite build` should build only the SDK and save it to `public/packs/js/sdk.js`
`bin/vite build` will build the rest of the app as usual. But exclude the SDK.

We need to edit the `asset:precompile` rake task to include the SDK in the precompile list.
*/
import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import path from 'path';
import vue from '@vitejs/plugin-vue';

const isLibraryMode = process.env.BUILD_MODE === 'library';
const isTestMode = process.env.TEST === 'true';

const vueOptions = {
  template: {
    compilerOptions: {
      isCustomElement: tag => ['ninja-keys'].includes(tag),
    },
  },
};

let plugins = [ruby(), vue(vueOptions)];

if (isLibraryMode) {
  plugins = [];
} else if (isTestMode) {
  plugins = [vue(vueOptions)];
}

// Separa bibliotecas pesadas, localizações i18n e o catálogo de ícones em chunks dedicados.
// Sem isso, 20+ MB de traduções e ícones eram arrastados para um chunk único gigante.
const manualChunks = (id: string) => {
  const normalizedId = id.replace(/\\/g, '/');
  if (normalizedId.includes('FluentIcon/dashboard-icons.json')) return 'icons-dashboard';
  if (normalizedId.includes('FluentIcon/icons.json')) return 'icons-base';
  if (normalizedId.includes('dashboard/i18n/locale/')) return 'i18n-locales';
  if (!normalizedId.includes('node_modules')) return undefined;
  if (
    normalizedId.includes('node_modules/vue/') ||
    normalizedId.includes('node_modules/@vue/') ||
    normalizedId.includes('node_modules/vue-router/') ||
    normalizedId.includes('node_modules/vue-i18n/') ||
    normalizedId.includes('node_modules/pinia/')
  ) {
    return 'vendor-vue';
  }
  if (
    normalizedId.includes('node_modules/axios') ||
    normalizedId.includes('node_modules/date-fns') ||
    normalizedId.includes('node_modules/lodash')
  ) {
    return 'vendor-utils';
  }
  if (normalizedId.includes('node_modules/@sentry')) return 'vendor-sentry';
  if (normalizedId.includes('node_modules/chart.js') || normalizedId.includes('node_modules/vue-chartjs')) return 'vendor-charts';
  if (normalizedId.includes('node_modules/@formkit')) return 'vendor-formkit';
  if (normalizedId.includes('node_modules/@tiptap') || normalizedId.includes('node_modules/prosemirror')) return 'vendor-editor';
  if (normalizedId.includes('node_modules/highlight.js')) return 'vendor-highlight';
  if (normalizedId.includes('node_modules/vue-dompurify-html') || normalizedId.includes('node_modules/dompurify')) return 'vendor-dompurify';
  if (normalizedId.includes('node_modules/floating-vue')) return 'vendor-floating';
  if (normalizedId.includes('node_modules/lucide')) return 'vendor-lucide';
  return undefined;
};

export default defineConfig({
  plugins: plugins,
  build: {
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        // [NOTE] when not in library mode, no new keys will be addedd or overwritten
        // setting dir: isLibraryMode ? 'public/packs' : undefined will not work
        ...(isLibraryMode
          ? {
              dir: 'public/packs',
              entryFileNames: chunkInfo => {
                if (chunkInfo.name === 'sdk') {
                  return 'js/sdk.js';
                }
                return '[name].js';
              },
            }
          : {
              manualChunks,
            }),
        inlineDynamicImports: isLibraryMode, // Disable code-splitting for SDK
      },
    },
    lib: isLibraryMode
      ? {
          entry: path.resolve(__dirname, './app/javascript/entrypoints/sdk.js'),
          formats: ['iife'], // IIFE format for single file
          name: 'sdk',
        }
      : undefined,
  },
  resolve: {
    alias: {
      vue: 'vue/dist/vue.esm-bundler.js',
      components: path.resolve('./app/javascript/dashboard/components'),
      next: path.resolve('./app/javascript/dashboard/components-next'),
      v3: path.resolve('./app/javascript/v3'),
      dashboard: path.resolve('./app/javascript/dashboard'),
      helpers: path.resolve('./app/javascript/shared/helpers'),
      shared: path.resolve('./app/javascript/shared'),
      survey: path.resolve('./app/javascript/survey'),
      widget: path.resolve('./app/javascript/widget'),
      assets: path.resolve('./app/javascript/dashboard/assets'),
    },
  },
  test: {
    environment: 'jsdom',
    include: ['app/**/*.{test,spec}.?(c|m)[jt]s?(x)'],
    coverage: {
      reporter: ['lcov', 'text'],
      include: ['app/**/*.js', 'app/**/*.vue'],
      exclude: [
        'app/**/*.@(spec|stories|routes).js',
        '**/specs/**/*',
        '**/i18n/**/*',
      ],
    },
    globals: true,
    outputFile: 'coverage/sonar-report.xml',
    pool: 'threads',
    poolOptions: {
      threads: {
        singleThread: false,
      },
    },
    server: {
      deps: {
        inline: ['tinykeys', '@material/mwc-icon'],
      },
    },
    setupFiles: ['fake-indexeddb/auto', 'vitest.setup.js'],
    mockReset: true,
    clearMocks: true,
  },
});

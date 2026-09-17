import { computed, ref } from 'vue';
import { fetchCrmOptions } from 'dashboard/helper/crmOptions';

// Fase 2: detecta os packs instalados na conta a partir do payload de
// /crm/options. Regra de compat: quando o backend não envia `packs`
// (modo legado, flag crm_universal desligada), tudo continua visível —
// a conta jurídica em produção nunca perde seção.
const packs = ref(null);
let loaded = false;

async function ensureLoaded() {
  if (loaded) return;
  loaded = true;
  const options = await fetchCrmOptions();
  packs.value = Array.isArray(options.packs) ? options.packs : null;
}

export function useCrmPack() {
  ensureLoaded();

  return {
    // null => legado (mostra tudo); array => packs instalados
    packs: computed(() => packs.value),
    hasPack: slug => (packs.value === null ? true : packs.value.includes(slug)),
    hasLegalPack: computed(() =>
      packs.value === null ? true : packs.value.includes('legal')
    ),
  };
}

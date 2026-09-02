import { computed, ref } from 'vue';

const STORAGE_KEY = 'crm-board-density';
const DENSITIES = ['compact', 'normal', 'detailed'];

/**
 * F2.4 — densidade do card, lembrada por navegador.
 *
 * A preferência fica no `localStorage` e não no servidor: trocar de densidade
 * não é decisão que valha uma coluna no banco.
 */
export function useBoardDensity(t) {
  const cardDensity = ref('normal');

  // Chaves estáticas de propósito: chave dinâmica esconde a string do extrator
  // de tradução e do lint.
  const densityOptions = computed(() => [
    { value: 'compact', label: t('CRM.DENSITY.COMPACT') },
    { value: 'normal', label: t('CRM.DENSITY.NORMAL') },
    { value: 'detailed', label: t('CRM.DENSITY.DETAILED') },
  ]);

  const readStoredDensity = () => {
    try {
      const stored = window.localStorage?.getItem(STORAGE_KEY);
      if (DENSITIES.includes(stored)) cardDensity.value = stored;
    } catch {
      // Navegador com armazenamento bloqueado: a densidade padrão serve.
    }
  };

  const setDensity = value => {
    if (!DENSITIES.includes(value)) return;

    cardDensity.value = value;
    try {
      window.localStorage?.setItem(STORAGE_KEY, value);
    } catch {
      // Idem: perder a preferência é melhor do que quebrar o quadro.
    }
  };

  return { cardDensity, densityOptions, readStoredDensity, setDensity };
}

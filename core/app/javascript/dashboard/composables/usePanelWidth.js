import { computed, ref } from 'vue';

const DEFAULT_WIDTH = 480;
const MIN_WIDTH = 360;
const MAX_WIDTH_RATIO = 0.9;

/**
 * CRM-032 — largura de painel lateral lembrada por navegador.
 *
 * O valor fica no `localStorage` por chave (cada painel guarda a sua) e o
 * arraste acontece no ponteiro: pointermove atualiza, pointerup fixa.
 */
export function usePanelWidth(storageKey) {
  const width = ref(DEFAULT_WIDTH);
  const dragging = ref(false);

  const maxWidth = () =>
    Math.max(MIN_WIDTH, Math.floor(window.innerWidth * MAX_WIDTH_RATIO));

  const readStoredWidth = () => {
    try {
      const stored = Number(window.localStorage?.getItem(storageKey));
      if (Number.isFinite(stored) && stored >= MIN_WIDTH) {
        width.value = Math.min(stored, maxWidth());
      }
    } catch {
      // Armazenamento bloqueado: largura padrão serve.
    }
  };

  const panelStyle = computed(() => ({ width: `${width.value}px` }));

  const startResize = event => {
    dragging.value = true;
    const startX = event.clientX;
    const startWidth = width.value;
    const move = e => {
      // Painel ancorado à direita: arrastar para a esquerda aumenta.
      width.value = Math.min(
        maxWidth(),
        Math.max(MIN_WIDTH, startWidth + (startX - e.clientX))
      );
    };
    const up = () => {
      dragging.value = false;
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
      try {
        window.localStorage?.setItem(storageKey, String(width.value));
      } catch {
        // Perder a preferência é melhor do que quebrar o arraste.
      }
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
  };

  return { width, dragging, panelStyle, readStoredWidth, startResize };
}

import { onMounted, onUnmounted } from 'vue';

/**
 * Pan horizontal "agarrar e arrastar" para o quadro (estilo Trello).
 *
 * Segurar o botão esquerdo numa área vazia do board e arrastar movimenta o
 * scroll horizontal — o usuário não precisa caçar a barra de rolagem nem
 * usar shift+wheel para alcançar as colunas da frente.
 *
 * O gesto só começa fora de cards e controles, então:
 * - o drag dos cards (`.crm-drag-handle`) continua intacto;
 * - seleção de texto e cliques normais não são engolidos;
 * - toque é ignorado (scroll nativo já resolve no mobile).
 *
 * Uso: `useDragToScroll(scrollerRef)` num template ref do container rolável.
 */

// Onde o gesto NÃO pode começar: card (draggable próprio) e qualquer controle
// que já tem intenção de clique/edição. Espaços vazios da coluna e o padding
// do board continuam válidos — é neles que o usuário "agarra" o quadro.
const IGNORED_START = [
  '[data-testid="crm-board-card"]',
  'button',
  'a',
  'input',
  'select',
  'textarea',
  'label',
  '[role="button"]',
  '[role="link"]',
  '[role="menu"]',
  '[contenteditable="true"]',
  '[data-drag-scroll-ignore]',
].join(', ');

// Abaixo disso é só um clique trêmulo — não vira pan nem engole o click.
const DRAG_THRESHOLD_PX = 6;

export function useDragToScroll(scrollerRef) {
  const abort = new AbortController();
  let startX = 0;
  let startScrollLeft = 0;
  let pointerId = null;
  let panning = false;

  const el = () => scrollerRef.value;

  const release = () => {
    const node = el();
    if (node && pointerId != null && node.hasPointerCapture?.(pointerId)) {
      node.releasePointerCapture(pointerId);
    }
    pointerId = null;
    node?.classList.remove('cursor-grabbing', 'select-none');
  };

  const onPointerDown = event => {
    const node = el();
    if (!node || event.button !== 0 || event.pointerType === 'touch') return;
    if (event.target.closest(IGNORED_START)) return;

    pointerId = event.pointerId;
    panning = false;
    startX = event.clientX;
    startScrollLeft = node.scrollLeft;
    node.setPointerCapture?.(pointerId);
  };

  const onPointerMove = event => {
    const node = el();
    if (!node || pointerId == null || event.pointerId !== pointerId) return;

    const delta = event.clientX - startX;
    if (!panning && Math.abs(delta) < DRAG_THRESHOLD_PX) return;
    if (!panning) {
      panning = true;
      node.classList.add('cursor-grabbing', 'select-none');
    }
    node.scrollLeft = startScrollLeft - delta;
  };

  const onPointerEnd = event => {
    if (pointerId == null || event.pointerId !== pointerId) return;
    const wasPanning = panning;
    panning = false;
    release();

    // O click que segue o mouseup cairia em cima de onde o pan parou —
    // suprime só esse click para não disparar ação sem querer.
    if (wasPanning) {
      el()?.addEventListener(
        'click',
        e => {
          e.preventDefault();
          e.stopPropagation();
        },
        { capture: true, once: true, signal: abort.signal }
      );
    }
  };

  onMounted(() => {
    const node = el();
    if (!node) return;
    node.addEventListener('pointerdown', onPointerDown, {
      signal: abort.signal,
    });
    node.addEventListener('pointermove', onPointerMove, {
      signal: abort.signal,
    });
    node.addEventListener('pointerup', onPointerEnd, { signal: abort.signal });
    node.addEventListener('pointercancel', onPointerEnd, {
      signal: abort.signal,
    });
  });

  onUnmounted(() => {
    release();
    abort.abort();
  });
}

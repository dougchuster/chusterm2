import { Page, expect, test } from '@playwright/test';

/**
 * Baseline de performance do Kanban — F0.3 do PLANO-KANBAN-CRM-2026.md.
 *
 * Nao e um teste de regressao: nao afirma metas, apenas mede e imprime numeros
 * para `docs/qa/KANBAN-BASELINE.md`. A F7 roda o mesmo arquivo e compara.
 *
 * Uso:
 *   QA_FIXTURE_NAMESPACE=kb500 QA_FIXTURE_PASSWORD=... \
 *   KANBAN_BASELINE_ACCOUNT=121 KANBAN_BASELINE_LABEL="500 negocios" \
 *   pnpm exec playwright test tests/kanban-baseline.spec.ts --project=chromium-desktop
 */

const accountId = process.env.KANBAN_BASELINE_ACCOUNT;
const label = process.env.KANBAN_BASELINE_LABEL ?? 'sem rotulo';
const settleMs = Number(process.env.KANBAN_BASELINE_SETTLE_MS ?? 1500);

// Cobre os dois boards: Legacy (`article.crm-deal-card`) e Operational — ambos
// carregam `cursor-grab` no `article` raiz do card.
const CARD = 'article.cursor-grab';

interface FrameStats {
  fpsMediano: number;
  p95FrameMs: number;
  maxFrameMs: number;
  framesLongos: number;
  amostras: number;
  somaFramesMs: number;
  janelaRealMs: number;
  pegouOCard: boolean;
}

const SEM_DRAG: FrameStats = {
  fpsMediano: 0,
  p95FrameMs: 0,
  maxFrameMs: 0,
  framesLongos: 0,
  amostras: 0,
  somaFramesMs: 0,
  janelaRealMs: 0,
  pegouOCard: false,
};

/**
 * Bloqueia qualquer escrita no dominio de negocios. A baseline e uma medicao,
 * nao uma mutacao: a fixture precisa ficar identica antes e depois para o teste
 * poder rodar quantas vezes for necessario.
 *
 * O glob nao exige `/` depois de `deals` de proposito — `POST .../crm/deals`
 * (criacao) nao tem segmento seguinte e escaparia de `**\/crm/deals/**`.
 */
async function blockWrites(page: Page) {
  await page.route('**/crm/deals**', route =>
    route.request().method() === 'GET' ? route.fallback() : route.abort()
  );
}

/**
 * "Board pronto" = a contagem de cards no DOM parou de crescer. E o momento em
 * que o atendente consegue enxergar e arrastar a fila. `settleMs` e so o
 * criterio de confirmacao: o instante devolvido e o da estabilizacao, nao o do
 * fim da janela de confirmacao.
 */
async function waitForBoardReady(page: Page): Promise<{ cards: number; stableAt: number }> {
  let previous = -1;
  let stableSince = 0;
  let cards = 0;
  const deadline = Date.now() + 180_000;

  while (Date.now() < deadline) {
    cards = await page.locator(CARD).count();
    if (cards > 0 && cards === previous) {
      if (!stableSince) stableSince = Date.now();
      if (Date.now() - stableSince >= settleMs) break;
    } else {
      stableSince = 0;
    }
    previous = cards;
    await page.waitForTimeout(100);
  }

  return { cards, stableAt: stableSince || Date.now() };
}

/**
 * FPS durante o drag.
 *
 * A primeira versao deste harness movia o ponteiro num laco de
 * `mouse.move` + `waitForTimeout(16)`. Cada passo pagava um round-trip do CDP,
 * entao a janela real ficava ~7x maior que a nominal e a pagina ganhava folga
 * ociosa entre os eventos — o oposto de um arrasto real. A mediana dava 60fps
 * por artefato de medicao.
 *
 * Agora o movimento sai em poucas chamadas com `steps`, que enfileira os
 * eventos intermediarios de uma vez. `janelaRealMs` fica registrado para que
 * qualquer distorcao futura seja visivel: se a janela real destoar da soma dos
 * frames, o numero nao vale.
 */
async function measureDragFps(page: Page): Promise<FrameStats> {
  const card = page.locator(CARD).first();
  await card.scrollIntoViewIfNeeded();
  const box = await card.boundingBox();
  if (!box) return SEM_DRAG;

  const originX = box.x + box.width / 2;
  const originY = box.y + box.height / 2;

  // Guardamos o instante absoluto de cada frame (nao o delta), para poder
  // recortar exatamente a janela do arrasto depois. Delta e origem de tempo
  // diferentes nao se comparam.
  await page.evaluate(() => {
    (window as any).__frameTimes = [];
    (window as any).__sampling = true;
    const tick = (now: number) => {
      (window as any).__frameTimes.push(now);
      if ((window as any).__sampling) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });

  await page.mouse.move(originX, originY);
  await page.mouse.down();
  // `vuedraggable` usa :delay=120ms — o ponteiro precisa segurar antes de mover.
  await page.waitForTimeout(200);
  await page.mouse.move(originX + 14, originY + 14);
  const pegouOCard = (await page.locator('.opacity-40').count()) > 0;

  const startedAt = Date.now();
  await page.evaluate(() => {
    (window as any).__dragStart = performance.now();
  });

  for (const [dx, dy] of [
    [260, 120],
    [-200, 240],
    [300, -160],
    [-160, 60],
  ]) {
    // eslint-disable-next-line no-await-in-loop
    await page.mouse.move(originX + dx, originY + dy, { steps: 40 });
  }

  const janelaRealMs = Date.now() - startedAt;
  await page.keyboard.press('Escape');
  await page.mouse.up();

  const stats = await page.evaluate(() => {
    (window as any).__sampling = false;
    const start = (window as any).__dragStart ?? 0;
    const times: number[] = (window as any).__frameTimes ?? [];
    // Só a janela do arrasto: o primeiro frame a partir de __dragStart em diante.
    const window0 = times.filter(t => t >= start);
    const deltas: number[] = [];
    for (let i = 1; i < window0.length; i += 1) deltas.push(window0[i] - window0[i - 1]);
    const frames = deltas.sort((a, b) => a - b);
    if (!frames.length) {
      return { fpsMediano: 0, p95FrameMs: 0, maxFrameMs: 0, framesLongos: 0, amostras: 0, somaFramesMs: 0 };
    }
    const at = (q: number) => frames[Math.min(frames.length - 1, Math.floor(frames.length * q))];
    return {
      fpsMediano: Math.round(1000 / at(0.5)),
      p95FrameMs: Math.round(at(0.95)),
      maxFrameMs: Math.round(frames[frames.length - 1]),
      framesLongos: frames.filter(f => f > 16.7).length,
      amostras: frames.length,
      // Sanidade: se `somaFramesMs` destoar de `janelaRealMs`, o recorte esta
      // errado e os numeros de FPS nao valem.
      somaFramesMs: Math.round(frames.reduce((a, b) => a + b, 0)),
    };
  });

  return { ...stats, janelaRealMs, pegouOCard };
}

test.describe('baseline do Kanban', () => {
  test.skip(!accountId, 'defina KANBAN_BASELINE_ACCOUNT');
  test.setTimeout(240_000);

  test(`mede carga e drag — ${label}`, async ({ page }) => {
    await blockWrites(page);

    let counting = true;
    const dealRequests: number[] = [];
    page.on('response', response => {
      if (!counting) return;
      if (response.request().method() !== 'GET') return;
      if (/\/crm\/deals(\?|$)/.test(response.url())) dealRequests.push(Date.now());
    });

    const startedAt = Date.now();
    await page.goto(`/app/accounts/${accountId}/crm`, { waitUntil: 'commit' });

    const { cards, stableAt } = await waitForBoardReady(page);
    const boardReadyMs = stableAt - startedAt;
    counting = false;
    expect(cards, 'o board precisa renderizar ao menos um card').toBeGreaterThan(0);

    const domNodes = await page.evaluate(() => document.getElementsByTagName('*').length);
    // Legacy renderiza `CRMDealCard.vue`, que carrega a classe `crm-deal-card`.
    // Operational monta o `article` inline, sem ela.
    const board = (await page.locator('article.crm-deal-card').count()) ? 'legacy' : 'operational';

    const drag = await measureDragFps(page);

    // `bootMs` = custo do SPA ate a primeira resposta de negocios (nao depende
    // do volume). `paginacaoMs` = o preco do K-01: paginar tudo no cliente.
    // `renderMs` = do fim da rede ate os cards estarem no DOM.
    const firstDeal = dealRequests.length ? dealRequests[0] - startedAt : -1;
    const lastDeal = dealRequests.length ? dealRequests[dealRequests.length - 1] - startedAt : -1;

    // eslint-disable-next-line no-console -- harness de medicao: a saida JSON e o entregavel
    console.log(
      JSON.stringify(
        {
          label,
          board,
          cardsNoDom: cards,
          boardReadyMs,
          dealRequests: dealRequests.length,
          bootMs: firstDeal,
          paginacaoMs: lastDeal >= 0 ? lastDeal - firstDeal : -1,
          renderMs: lastDeal >= 0 ? boardReadyMs - lastDeal : -1,
          domNodes,
          nosPorCard: cards ? Math.round(domNodes / cards) : 0,
          drag,
        },
        null,
        2
      )
    );
  });
});

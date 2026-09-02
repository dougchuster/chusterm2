import { Browser, Page, expect, test } from '@playwright/test';

/**
 * F1.7 + F1.8 do PLANO-KANBAN-CRM-2026.md — o DoD da Fase 1:
 *
 *   "dois navegadores lado a lado; mover card em um aparece no outro em <1s"
 *
 * Duas sessões independentes, o mesmo board. Uma arrasta o card entre colunas;
 * a outra não faz nada. Mede quanto tempo o card leva para aparecer na coluna
 * nova da segunda sessão, sem refetch e sem F5.
 *
 * Uso:
 *   QA_FIXTURE_NAMESPACE=kb500 QA_FIXTURE_PASSWORD=... \
 *   KANBAN_REALTIME_ACCOUNT=121 \
 *   pnpm exec playwright test tests/kanban-realtime.spec.ts --project=chromium-desktop
 *
 * PRÉ-REQUISITO: a aplicação precisa estar servindo o frontend **desta**
 * branch. O compose local serve assets pré-compilados em `public/vite`; sem
 * rebuild, o board carregado é o anterior à F1.8 e o teste falha por ausência
 * do composable, não por falha de realtime.
 */

const accountId = process.env.KANBAN_REALTIME_ACCOUNT;
const settleMs = Number(process.env.KANBAN_REALTIME_SETTLE_MS ?? 1500);
const limiteMs = Number(process.env.KANBAN_REALTIME_BUDGET_MS ?? 1000);

const CARD = 'article.cursor-grab';
const COLUNA = '[data-testid="crm-board-column"], section:has(> header)';

const abrirBoard = async (page: Page) => {
  await page.goto(`/app/accounts/${accountId}/crm`);
  await page.waitForSelector(CARD, { timeout: 30_000 });
  await page.waitForTimeout(settleMs);
};

/** Identidade estável do card, para achá-lo na outra sessão. */
const tituloDoPrimeiroCard = async (page: Page) => {
  const card = page.locator(CARD).first();
  await expect(card).toBeVisible();
  return (await card.innerText()).split('\n')[0].trim();
};

const colunaDoCard = async (page: Page, titulo: string) => {
  return page.evaluate(
    ({ seletorCard, seletorColuna, alvo }) => {
      const cards = Array.from(document.querySelectorAll(seletorCard));
      const card = cards.find(node =>
        (node as HTMLElement).innerText.includes(alvo)
      );
      if (!card) return null;
      const coluna = card.closest(seletorColuna);
      return coluna
        ? (coluna.querySelector('header')?.innerText ?? '').trim()
        : null;
    },
    { seletorCard: CARD, seletorColuna: COLUNA, alvo: titulo }
  );
};

const novaSessao = async (browser: Browser) => {
  const context = await browser.newContext();
  const page = await context.newPage();
  await abrirBoard(page);
  return { context, page };
};

test.describe('Kanban em tempo real entre duas sessões', () => {
  test.skip(!accountId, 'defina KANBAN_REALTIME_ACCOUNT');

  test('o card movido por um atendente aparece no board do outro', async ({
    browser,
  }) => {
    const atendenteA = await novaSessao(browser);
    const atendenteB = await novaSessao(browser);

    try {
      const titulo = await tituloDoPrimeiroCard(atendenteA.page);
      const colunaOriginal = await colunaDoCard(atendenteB.page, titulo);
      expect(colunaOriginal).not.toBeNull();

      const card = atendenteA.page.locator(CARD).first();
      const colunaDestino = atendenteA.page.locator(COLUNA).nth(1);

      const partiuEm = Date.now();
      await card.dragTo(colunaDestino);

      await expect
        .poll(async () => colunaDoCard(atendenteB.page, titulo), {
          timeout: 15_000,
          intervals: [50, 50, 100, 100, 250],
        })
        .not.toBe(colunaOriginal);

      const latenciaMs = Date.now() - partiuEm;

      // eslint-disable-next-line no-console
      console.log(
        `[F1.8] card "${titulo}" apareceu na coluna nova da segunda sessão em ${latenciaMs}ms (orçamento ${limiteMs}ms)`
      );

      expect(latenciaMs).toBeLessThan(limiteMs);
    } finally {
      await atendenteA.context.close();
      await atendenteB.context.close();
    }
  });

  test('a segunda sessão não recarrega o board inteiro para aplicar o evento', async ({
    browser,
  }) => {
    const atendenteA = await novaSessao(browser);
    const atendenteB = await novaSessao(browser);

    try {
      const chamadas: string[] = [];
      atendenteB.page.on('request', request => {
        if (request.url().includes('/crm/deals')) chamadas.push(request.url());
      });

      const titulo = await tituloDoPrimeiroCard(atendenteA.page);
      const colunaOriginal = await colunaDoCard(atendenteB.page, titulo);

      await atendenteA.page
        .locator(CARD)
        .first()
        .dragTo(atendenteA.page.locator(COLUNA).nth(1));

      await expect
        .poll(async () => colunaDoCard(atendenteB.page, titulo), {
          timeout: 15_000,
        })
        .not.toBe(colunaOriginal);

      // O patch é incremental: a sessão que só assistiu não pode ter ido
      // buscar a lista de negócios de novo.
      expect(chamadas).toHaveLength(0);
    } finally {
      await atendenteA.context.close();
      await atendenteB.context.close();
    }
  });
});

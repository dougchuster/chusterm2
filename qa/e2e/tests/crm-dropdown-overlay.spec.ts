import { expect, test } from '@playwright/test';

/**
 * Regressao de camadas: a barra de ferramentas do board usa backdrop-filter,
 * que cria um stacking context — o menu "..." das visoes ficava preso atras
 * das colunas do kanban. O DsDropdown agora teleporta o menu para <body> com
 * posicao fixed.
 *
 * `toBeVisible` nao detecta oclusao — um elemento atras de outro continua
 * "visivel". A assercao real e elementFromPoint: o centro do menu tem que
 * resolver para dentro dele.
 */

const accountId = process.env.QA_ACCOUNT_ID ?? '55';

async function expectNotOccluded(locator) {
  const occluded = await locator.evaluate(element => {
    const rect = element.getBoundingClientRect();
    const hit = document.elementFromPoint(
      rect.left + rect.width / 2,
      rect.top + rect.height / 2
    );
    return hit !== element && !element.contains(hit);
  });
  expect(occluded).toBe(false);
}

test.describe('menus do quadro nao abrem atras das colunas', () => {
  test('o menu de visões da toolbar fica acima do kanban', async ({ page }) => {
    await page.goto(`/app/accounts/${accountId}/crm`);
    await expect(
      page.getByRole('heading', { name: 'Pipeline', exact: true })
    ).toBeVisible({ timeout: 20000 });

    await page.getByRole('button', { name: 'Visões' }).click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();
    await expectNotOccluded(menu);
  });

  test('o menu de ações do card fica acima da coluna e da vizinha', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/crm`);
    await expect(
      page.getByRole('heading', { name: 'Pipeline', exact: true })
    ).toBeVisible({ timeout: 20000 });

    // O menu do card abre dentro da coluna rolavel — cenario pior que a
    // toolbar: clipping por overflow alem do stacking context.
    await page
      .getByRole('button', { name: /Mais ações para/ })
      .first()
      .click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();
    await expectNotOccluded(menu);
  });

  test('tooltip e menu da lista de atividades escapam o container rolavel', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/crm/activities`);
    const editButton = page
      .getByRole('button', { name: 'Editar atividade' })
      .first();
    await expect(editButton).toBeVisible({ timeout: 20000 });

    // O tooltip e pointer-events-none — elementFromPoint nunca o resolve.
    // A assercao e geometrica: teleportado para <body> (fixed) e dentro do
    // viewport, nao clipado pelo overflow-y-auto da tabela.
    // Em viewports estreitos a celula de acoes fica alem do scroll horizontal
    // da tabela — o usuario scrolla ate ela antes de passar o mouse.
    await editButton.scrollIntoViewIfNeeded();
    await editButton.hover();
    const tooltip = page.getByRole('tooltip');
    await expect(tooltip).toBeVisible();
    const geometry = await tooltip.evaluate(element => {
      const rect = element.getBoundingClientRect();
      return {
        fixed: getComputedStyle(element).position === 'fixed',
        insideViewport:
          rect.top >= 0 &&
          rect.left >= 0 &&
          rect.bottom <= window.innerHeight &&
          rect.right <= window.innerWidth,
      };
    });
    expect(geometry).toEqual({ fixed: true, insideViewport: true });

    // O dropdown da linha da tabela sofre do mesmo clipping do kanban.
    await page
      .getByRole('button', { name: 'Mais ações da atividade' })
      .first()
      .click();
    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();
    await expectNotOccluded(menu);
  });
});

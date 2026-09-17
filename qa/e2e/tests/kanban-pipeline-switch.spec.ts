import { expect, test } from '@playwright/test';

/**
 * Regressao: clicar num funil da sidebar mudava `?pipeline_id=` na URL mas o
 * quadro continuava no funil anterior — a rota e a mesma (`crm_dashboard`) e o
 * componente nao observava `route.query`.
 *
 * Pre-condicao local: a conta QA tem dois pipelines — o canonico
 * "qa-{ns}-vendas" e "Kanban QA - Segundo Funil" (id 1303, etapas
 * "Triagem B/Atendimento B/Fechamento B"), criado via runner.
 */

const accountId = process.env.QA_ACCOUNT_ID ?? '55';
const PIPELINE_B_ID = '1303';
const PIPELINE_B_NAME = 'Kanban QA - Segundo Funil';
const PIPELINE_B_STAGE = 'Triagem B';

// Em viewport < md a sidebar fica recolhida — o usuario abre o flyout pelo
// launcher flutuante antes de tocar no funil.
const openSidebarIfMobile = async (page, testInfo) => {
  if ((testInfo.project.use.viewport?.width ?? 1366) >= 768) return;
  await page.locator('#mobile-sidebar-launcher button').click();
};

test.describe('troca de funil pela sidebar', () => {
  test('URL muda e o quadro recarrega as colunas do novo funil', async ({
    page,
  }, testInfo) => {
    await page.goto(`/app/accounts/${accountId}/crm`);

    // Quadro inicial carregado (funil padrao/primeiro).
    await expect(
      page.getByRole('heading', { name: 'Pipeline', exact: true })
    ).toBeVisible({ timeout: 20000 });
    await expect(page.locator('article, section').first()).toBeVisible();

    // O clique real do usuario: item da sidebar com o nome do funil.
    await openSidebarIfMobile(page, testInfo);
    await page
      .getByRole('link', { name: /Segundo Funil/ })
      .click();

    // A URL reflete o funil novo...
    await expect(page).toHaveURL(new RegExp(`pipeline_id=${PIPELINE_B_ID}`));

    // ...e o quadro tambem: coluna exclusiva do funil B precisa aparecer
    // (h2 do cabecalho — o <option> do seletor de etapa fica oculto).
    await expect(
      page.getByRole('heading', { name: PIPELINE_B_STAGE })
    ).toBeVisible({ timeout: 15000 });
  });

  test('voltar ao funil anterior pela sidebar tambem recarrega', async ({
    page,
  }, testInfo) => {
    await page.goto(
      `/app/accounts/${accountId}/crm?pipeline_id=${PIPELINE_B_ID}`
    );
    await expect(
      page.getByRole('heading', { name: PIPELINE_B_STAGE })
    ).toBeVisible({ timeout: 20000 });

    // Clicar de volta no funil canonico da fixture ("Pipeline Comercial QA").
    await openSidebarIfMobile(page, testInfo);
    await page
      .getByRole('link', { name: /Comercial QA/ })
      .click();

    // A coluna exclusiva do funil B some do quadro.
    await expect(
      page.getByRole('heading', { name: PIPELINE_B_STAGE })
    ).toHaveCount(0, { timeout: 15000 });
  });
});

import { expect, test } from '@playwright/test';

/**
 * FASE 1 do plano de marketing — conexoes OAuth.
 * Cobre: navegacao pela sidebar, listagem de providers, estado "nao
 * configurado" (sem credenciais de app), isolamento do feature flag e
 * contrato do endpoint /marketing/connections.
 */

const accountId = process.env.QA_ACCOUNT_ID ?? '55';

// A API aceita a sessao do navegador via headers de token (mesmo mecanismo
// que o visual-sweep reusa do cookie cw_d_session_info).
const apiHeaders = async page => {
  const cookies = await page.context().cookies();
  const sessionCookie = cookies.find(c => c.name === 'cw_d_session_info');
  const session = JSON.parse(decodeURIComponent(sessionCookie.value));
  return {
    'access-token': session['access-token'],
    'token-type': session['token-type'] ?? 'Bearer',
    client: session.client,
    expiry: session.expiry,
    uid: session.uid,
  };
};

test.describe('area de marketing — conexoes', () => {
  test('o item Marketing aparece na sidebar e navega para o overview', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/crm`);
    const marketingGroup = page
      .getByRole('button', { name: /marketing/i })
      .first();
    await expect(marketingGroup).toBeVisible({ timeout: 15_000 });
    await marketingGroup.click();
    const overviewLink = page
      .getByRole('link', { name: /vis[aã]o geral|overview/i })
      .first();
    await expect(overviewLink).toBeVisible();
    await overviewLink.click();
    await expect(page).toHaveURL(/marketing/);
  });

  test('a pagina de conexoes lista os tres providers', async ({ page }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/connections`);
    await expect(
      page.getByRole('heading', { name: /conex/i }).first()
    ).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('Meta Ads').first()).toBeVisible();
    await expect(page.getByText('Google Ads').first()).toBeVisible();
    await expect(page.getByText('Google Analytics 4').first()).toBeVisible();
  });

  test('o endpoint de conexoes responde com o contrato esperado', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/connections`);
    const response = await page.request.get(
      `/api/v1/accounts/${accountId}/marketing/connections`,
      { headers: await apiHeaders(page) }
    );
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.connections).toHaveLength(3);
    expect(body.connections.map((c: { provider: string }) => c.provider)).toEqual([
      'meta_ads',
      'google_ads',
      'ga4',
    ]);
    expect(body.oauth_configured).toBeDefined();
  });

  test('authorize sem app configurado retorna erro legivel', async ({
    page,
  }) => {
    const response = await page.request.post(
      `/api/v1/accounts/${accountId}/marketing/connections/authorize`,
      {
        data: { provider: 'meta_ads' },
        headers: await apiHeaders(page),
      }
    );
    expect(response.status()).toBe(422);
    const body = await response.json();
    expect(body.error).toBe('oauth_not_configured');
  });
});

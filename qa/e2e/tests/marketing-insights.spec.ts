import { expect, test } from '@playwright/test';

/**
 * FASE 5 do plano de marketing — Insights IA.
 * Cobre: endpoint /marketing/metrics/insights, renderizacao dos alertas
 * e as perguntas sugeridas com CTA para o Copilot.
 */

const accountId = process.env.QA_ACCOUNT_ID ?? '55';

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

test.describe('area de marketing — insights IA', () => {
  test('o endpoint de insights responde com o contrato esperado', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/insights`);
    const response = await page.request.get(
      `/api/v1/accounts/${accountId}/marketing/metrics/insights`,
      { headers: await apiHeaders(page) }
    );
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body).toHaveProperty('alerts');
    expect(body).toHaveProperty('generated_at');
    expect(Array.isArray(body.alerts)).toBeTruthy();
  });

  test('a pagina renderiza alertas ou estado saudavel', async ({ page }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/insights`);
    await expect(
      page.getByRole('heading', { name: /insights ia|ai insights/i }).first()
    ).toBeVisible({ timeout: 15_000 });

    // Com fixtures: ou alertas aparecem, ou o estado saudavel renderiza.
    const alertList = page.locator('ul li');
    const healthy = page.getByText(/tudo saud|looks healthy/i);
    const hasAlerts = (await alertList.count()) > 0;
    if (!hasAlerts) {
      await expect(healthy.first()).toBeVisible();
    }
  });

  test('a secao de perguntas sugere consultas para o Copilot', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/insights`);
    await expect(
      page.getByText(/quanto gastamos|how much did we spend/i).first()
    ).toBeVisible({ timeout: 15_000 });
    await expect(
      page.getByRole('button', { name: /abrir copilot|open copilot/i }).first()
    ).toBeVisible();
  });
});

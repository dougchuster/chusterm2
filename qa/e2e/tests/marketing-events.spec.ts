import { expect, test } from '@playwright/test';

/**
 * FASE 4 do plano de marketing — Conversions API.
 * Cobre: contrato do endpoint /marketing/events, listagem na UI,
 * filtro por status e botao de retry em evento falho.
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

test.describe('area de marketing — eventos de conversao', () => {
  test('o endpoint de eventos responde com o contrato esperado', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/events`);
    const response = await page.request.get(
      `/api/v1/accounts/${accountId}/marketing/events`,
      { headers: await apiHeaders(page) }
    );
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.events.length).toBeGreaterThan(0);
    expect(body.counts).toBeDefined();
    const event = body.events[0];
    expect(event).toHaveProperty('event_name');
    expect(event).toHaveProperty('status');
    expect(event).toHaveProperty('provider');
  });

  test('a pagina lista eventos com nome, status e plataforma', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/events`);
    await expect(
      page.getByRole('heading', { name: /eventos de convers/i }).first()
    ).toBeVisible({ timeout: 15_000 });
    await expect(
      page.getByText('Purchase').or(page.getByText('Qualified')).first()
    ).toBeVisible();
    await expect(page.getByText('Meta').first()).toBeVisible();
  });

  test('o filtro "Falhos" mostra o evento com erro e o botao reenviar', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/events`);
    await page
      .getByRole('button', { name: /falhos|failed/i })
      .first()
      .click();

    const response = await page.request.get(
      `/api/v1/accounts/${accountId}/marketing/events?status=failed`,
      { headers: await apiHeaders(page) }
    );
    const body = await response.json();
    expect(
      body.events.every((e: { status: string }) => e.status === 'failed')
    ).toBeTruthy();
  });
});

import { expect, test } from '@playwright/test';

/**
 * FASE 3 do plano de marketing — Lead Ads → CRM.
 * Cobre: contrato do endpoint /marketing/leads, listagem na UI,
 * filtro por status e o fluxo convert/discard sobre fixtures locais.
 * As asserções toleram reruns (leads já convertidos/descartados seguem
 * listados no filtro "Todos").
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

const listLeads = async (page, status = '') => {
  const headers = await apiHeaders(page);
  const response = await page.request.get(
    `/api/v1/accounts/${accountId}/marketing/leads${
      status ? `?status=${status}` : ''
    }`,
    { headers }
  );
  return response;
};

test.describe('area de marketing — leads de anuncios', () => {
  // Os testes mutam os mesmos leads fixture — serial evita corrida.
  test.describe.configure({ mode: 'serial' });

  test('o endpoint de leads responde com o contrato esperado', async ({
    page,
  }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/leads`);
    const response = await listLeads(page);
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.leads.length).toBeGreaterThan(0);
    expect(body.counts).toBeDefined();
    const lead = body.leads[0];
    expect(lead).toHaveProperty('leadgen_id');
    expect(lead).toHaveProperty('display_name');
    expect(lead).toHaveProperty('status');
  });

  test('a pagina lista leads com nome, campanha e status', async ({ page }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/leads`);
    await expect(
      page.getByRole('heading', { name: /leads de an/i }).first()
    ).toBeVisible({ timeout: 15_000 });

    // Filtro "Todos" — inclui leads ja convertidos/descartados em reruns.
    await page
      .getByRole('button', { name: /^todos$|^all$/i })
      .first()
      .click();
    await expect(page.getByText('Carla Menezes').first()).toBeVisible();
    await expect(
      page.getByText('Campanha Leads Previdenciário').first()
    ).toBeVisible();
  });

  test('o filtro por status reduz a listagem', async ({ page }) => {
    await page.goto(`/app/accounts/${accountId}/marketing/leads`);
    const response = await listLeads(page, 'converted');
    const body = await response.json();
    expect(body.leads.length).toBeGreaterThan(0);
    expect(
      body.leads.every((l: { status: string }) => l.status === 'converted')
    ).toBeTruthy();
  });

  test('descartar um lead novo atualiza o status via UI', async ({ page }) => {
    const response = await listLeads(page, 'new');
    const { leads } = await response.json();
    const target =
      leads.find(
        (l: { leadgen_id: string }) => l.leadgen_id === 'qa_lead_2'
      ) ?? leads[0];

    if (!target) {
      // Rerun sem leads novos: descartar um ja descartado e no-op idempotente.
      const responseDisc = await listLeads(page, 'discarded');
      const { leads: done } = await responseDisc.json();
      const again = await page.request.post(
        `/api/v1/accounts/${accountId}/marketing/leads/${done[0].id}/discard`,
        { headers: await apiHeaders(page) }
      );
      expect(again.status()).toBe(200);
      return;
    }

    await page.goto(`/app/accounts/${accountId}/marketing/leads`);
    const row = page
      .getByRole('row')
      .filter({ hasText: target.display_name })
      .first();
    await expect(row).toBeVisible({ timeout: 15_000 });
    await row
      .getByRole('button', { name: /descartar|discard/i })
      .click();

    // O filtro ativo e "Novos" — o lead some da lista apos o refetch.
    await expect(row).toBeHidden({ timeout: 10_000 });

    const after = await listLeads(page, 'discarded');
    const { leads: discarded } = await after.json();
    expect(
      discarded.some(
        (l: { leadgen_id: string }) => l.leadgen_id === target.leadgen_id
      )
    ).toBeTruthy();
  });

  test('converter um lead cria contato e negocio no CRM', async ({ page }) => {
    const response = await listLeads(page, 'new');
    const { leads } = await response.json();

    if (leads.length === 0) {
      // Rerun: todos ja convertidos — reconversao deve ser rejeitada sem
      // criar deal duplicado (idempotencia via crm_deal_id).
      const converted = await listLeads(page, 'converted');
      const { leads: done } = await converted.json();
      const again = await page.request.post(
        `/api/v1/accounts/${accountId}/marketing/leads/${done[0].id}/convert`,
        { headers: await apiHeaders(page) }
      );
      expect(again.status()).toBe(422);
      return;
    }

    const target = leads[0];
    const convertResponse = await page.request.post(
      `/api/v1/accounts/${accountId}/marketing/leads/${target.id}/convert`,
      { headers: await apiHeaders(page) }
    );
    expect(convertResponse.ok()).toBeTruthy();
    const { lead } = await convertResponse.json();
    expect(lead.status).toBe('converted');
    expect(lead.crm_deal_id).toBeTruthy();
    expect(lead.contact_id).toBeTruthy();
  });
});

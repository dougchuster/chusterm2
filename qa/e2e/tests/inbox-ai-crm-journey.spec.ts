import { expect, test } from '@playwright/test';

/**
 * CRM-022 — jornada ponta a ponta Inbox → IA → CRM (E2E-P0-00).
 *
 * A fixture canônica (`rake qa:seed`) já amarra o fluxo inteiro: a conversa
 * `qa-<ns>-lead_active` tem mensagens do assistente, `CaptainConversationState`
 * com score/classificação e `crm_deal` vinculado. O teste percorre o que o
 * operador faria: abre a conversa na inbox, confere o controle da IA, segue o
 * link "Abrir negócio no CRM" e encontra o card no quadro.
 *
 * O deep-link `/crm?deal_id=` precisa abrir a ficha do negócio — antes do
 * CRM-022 nada consumia o parâmetro e o link caía no quadro sem contexto.
 *
 * Uso:
 *   QA_FIXTURE_NAMESPACE=f0 QA_FIXTURE_PASSWORD=... \
 *   pnpm exec playwright test tests/inbox-ai-crm-journey.spec.ts --project=chromium-desktop
 *
 * Overrides: QA_JOURNEY_SCENARIO (default `lead_active`), QA_ACCOUNT_ID.
 */

const scenario = process.env.QA_JOURNEY_SCENARIO ?? 'lead_active';

interface ConversationRow {
  id: number;
  inbox_id: number;
  additional_attributes?: { qa_fixture_conversation?: string };
}

// A API /api/v1 não aceita o cookie de sessão direto: o SPA traduz
// `cw_d_session_info` para os headers access-token/client/uid. O teste faz o
// mesmo para consultar estado sem depender de seletor frágil.
const apiHeaders = async (page: any) => {
  const cookies = await page.context().cookies();
  const sessionCookie = cookies.find(c => c.name === 'cw_d_session_info');
  expect(sessionCookie, 'cookie cw_d_session_info ausente').toBeTruthy();
  const session = JSON.parse(decodeURIComponent(sessionCookie!.value));
  return {
    'access-token': session['access-token'],
    'token-type': session['token-type'] ?? 'Bearer',
    client: session.client,
    expiry: session.expiry,
    uid: session.uid,
  };
};

const apiGet = async (page: any, path: string) => {
  const response = await page.request.get(path, {
    headers: await apiHeaders(page),
  });
  return response;
};

const resolveAccountId = async (page: any): Promise<number> => {
  if (process.env.QA_ACCOUNT_ID) return Number(process.env.QA_ACCOUNT_ID);

  const profile = await apiGet(page, '/api/v1/profile');
  expect(profile.ok()).toBeTruthy();
  const { accounts } = await profile.json();
  expect(accounts.length).toBeGreaterThan(0);
  return accounts[0].id;
};

const findFixtureConversation = async (
  page: any,
  accountId: number
): Promise<ConversationRow> => {
  const response = await apiGet(
    page,
    `/api/v1/accounts/${accountId}/conversations?status=all`
  );
  expect(response.ok()).toBeTruthy();
  const body = await response.json();
  const payload: ConversationRow[] = body?.data?.payload ?? [];
  const found = payload.find(
    c => c.additional_attributes?.qa_fixture_conversation === scenario
  );
  expect(
    found,
    `conversa qa_fixture_conversation=${scenario} ausente — rode rake qa:seed`
  ).toBeTruthy();
  return found as ConversationRow;
};

test('jornada Inbox → IA → CRM: triagem visível, ficha aberta e card no quadro', async ({
  page,
}) => {
  const accountId = await resolveAccountId(page);
  const conversation = await findFixtureConversation(page, accountId);

  // Perna da IA no contrato da API: estado do Capitão aponta o deal do CRM.
  const stateResponse = await apiGet(
    page,
    `/api/v1/accounts/${accountId}/captain/conversation_states/${conversation.id}`
  );
  expect(stateResponse.ok()).toBeTruthy();
  const captainState = await stateResponse.json();
  expect(captainState.crm_deal_id).toBeTruthy();
  expect(captainState.ai_mode).toBeTruthy();

  // 1) Inbox: a conversa seedada abre com o painel do Capitão.
  await page.goto(
    `/app/accounts/${accountId}/inbox/${conversation.inbox_id}/conversations/${conversation.id}`
  );
  await page.waitForLoadState('networkidle');

  const captainPanel = page.getByRole('region', {
    name: 'Controle inteligente do Capitão',
  });
  if (!(await captainPanel.isVisible())) {
    await page.locator('button:has(.i-ph-user-bold)').click();
  }
  await expect(captainPanel).toBeVisible({ timeout: 30_000 });
  await expect(
    captainPanel.getByText('Capitão · controle da conversa')
  ).toBeVisible();
  // Exatamente um modo marcado como ativo; na fixture lead_active é "IA ativa".
  await expect(captainPanel.locator('button[aria-pressed="true"]')).toHaveCount(
    1
  );
  await expect(
    captainPanel.locator('button[aria-pressed="true"]')
  ).toHaveAccessibleName(/IA ativa/i);
  // Score e classificação da triagem (a fixture semeia `qualificado`, 64/100).
  await expect(
    captainPanel.getByText(/qualificado|prioridade_alta|nutrir/i).first()
  ).toBeVisible();

  // 2) IA → CRM: o link "Abrir negócio no CRM" deep-linka a ficha.
  const dealLink = captainPanel.getByRole('link', {
    name: /Abrir negócio no CRM/i,
  });
  await expect(dealLink).toBeVisible();
  await dealLink.click();
  await page.waitForURL(/\/crm\?deal_id=\d+/);

  const drawer = page.getByText('Oportunidade jurídica');
  await expect(drawer).toBeVisible({ timeout: 30_000 });
  // A ficha carrega o deal vinculado pelo estado do Capitão — o título real
  // aparece no lugar do placeholder de loading.
  await expect(
    page.locator('h3', { hasNotText: 'Carregando' }).first()
  ).toBeVisible({ timeout: 15_000 });

  // 3) CRM: da ficha à página do negócio — a jornada termina na tela de CRM.
  const dealsResponse = await apiGet(
    page,
    `/api/v1/accounts/${accountId}/crm/deals/${captainState.crm_deal_id}`
  );
  expect(dealsResponse.ok()).toBeTruthy();
  const deal = await dealsResponse.json();
  const dealTitle: string = deal.title || deal.data?.title;
  expect(dealTitle).toBeTruthy();

  await page
    .getByRole('button', { name: /Detalhes/i })
    .first()
    .click();
  await page.waitForURL(/\/crm\/deals\/\d+/);
  await expect(
    page.getByText(dealTitle, { exact: false }).first()
  ).toBeVisible({ timeout: 30_000 });
});

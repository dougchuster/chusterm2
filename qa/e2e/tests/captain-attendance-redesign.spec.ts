import { expect, test } from '@playwright/test';
import { AxeBuilder } from '@axe-core/playwright';

test('atendimento apresenta o centro inteligente do Capitão', async ({
  page,
}, testInfo) => {
  const accountId = process.env.QA_ACCOUNT_ID;
  const inboxId = process.env.QA_INBOX_ID;
  const conversationDisplayId = process.env.QA_CONVERSATION_DISPLAY_ID;

  expect(accountId).toBeTruthy();
  expect(inboxId).toBeTruthy();
  expect(conversationDisplayId).toBeTruthy();

  await page.goto(
    `/app/accounts/${accountId}/inbox/${inboxId}/conversations/${conversationDisplayId}`
  );
  await page.waitForLoadState('networkidle');

  const intelligencePanel = page.getByRole('region', {
    name: 'Controle inteligente do Capitão',
  });
  if (!(await intelligencePanel.isVisible())) {
    await page.locator('button:has(.i-ph-user-bold)').click();
  }
  await expect(intelligencePanel).toBeVisible({ timeout: 30_000 });
  await expect(
    intelligencePanel.getByText('Capitão · controle da conversa')
  ).toBeVisible();
  await expect(
    intelligencePanel.getByText(
      'Score e identificação de Lead/Cliente orientam a equipe, mas não mudam o controle da conversa automaticamente.'
    )
  ).toBeVisible();
  await expect(
    intelligencePanel.getByRole('button', { name: /IA ativa/i })
  ).toBeVisible();
  await expect(intelligencePanel.getByText('Lead', { exact: true })).toBeVisible();

  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth
  );
  expect(overflow).toBeLessThanOrEqual(1);

  const accessibility = await new AxeBuilder({ page })
    .include('section[aria-label="Controle inteligente do Capitão"]')
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  const severeViolations = accessibility.violations.filter(violation =>
    ['critical', 'serious'].includes(violation.impact || '')
  );
  expect(severeViolations).toEqual([]);

  await testInfo.attach('captain-attendance-redesign.png', {
    body: await page.screenshot({ animations: 'disabled', fullPage: true }),
    contentType: 'image/png',
  });
});

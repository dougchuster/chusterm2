import { AxeBuilder } from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

const AXE_ROUTES = [
  '/crm',
  '/marketing',
  '/marketing/leads',
  '/marketing/campaigns',
];

test('CRM e Marketing não possuem violações axe críticas ou sérias', async ({ page }, testInfo) => {
  await page.goto('/app');
  await expect(page).toHaveURL(/\/app\/accounts\/(\d+)\//);
  const accountId = new URL(page.url()).pathname.match(/accounts\/(\d+)/)?.[1];
  expect(accountId).toBeTruthy();

  const allBlocking = [];
  for (const route of AXE_ROUTES) {
    await page.goto(`/app/accounts/${accountId}${route}`);
    await expect(page.locator('body')).toBeVisible();
    // Aguarda o conteúdo principal renderizar antes de medir.
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page }).analyze();
    const blocking = results.violations
      .filter(({ impact }) => impact === 'critical' || impact === 'serious')
      .map(v => ({ route, ...v }));
    allBlocking.push(...blocking);
  }

  const summary = allBlocking.map(({ route, id, impact, nodes }) => ({
    route,
    id,
    impact,
    nodes: nodes.map(({ html, target }) => ({ html, target })),
  }));
  await testInfo.attach('axe-blocking.json', {
    body: Buffer.from(JSON.stringify(summary, null, 2)),
    contentType: 'application/json',
  });
  expect(allBlocking, JSON.stringify(summary, null, 2)).toEqual([]);
});

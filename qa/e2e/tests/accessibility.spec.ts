import { AxeBuilder } from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

test('CRM não possui violações axe críticas ou sérias', async ({ page }, testInfo) => {
  await page.goto('/app');
  await expect(page).toHaveURL(/\/app\/accounts\/(\d+)\//);
  const accountId = new URL(page.url()).pathname.match(/accounts\/(\d+)/)?.[1];
  expect(accountId).toBeTruthy();

  await page.goto(`/app/accounts/${accountId}/crm`);
  await expect(page.locator('body')).toBeVisible();

  const results = await new AxeBuilder({ page }).analyze();
  const blocking = results.violations.filter(({ impact }) => impact === 'critical' || impact === 'serious');
  const summary = blocking.map(({ id, impact, nodes }) => ({
    id,
    impact,
    nodes: nodes.map(({ html, target }) => ({ html, target })),
  }));
  await testInfo.attach('axe-blocking.json', {
    body: Buffer.from(JSON.stringify(summary, null, 2)),
    contentType: 'application/json',
  });
  expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
});

import { expect, test } from '@playwright/test';
import { fixturePassword, personas } from './support/personas.js';

for (const [index, [persona, email]] of Object.entries(personas).entries()) {
  test(`autentica a persona ${persona}`, async ({ page }) => {
    // IPs TEST-NET-3 isolam os buckets do Rack::Attack sem desativar o gate.
    await page.context().setExtraHTTPHeaders({ 'X-Forwarded-For': `203.0.113.${index + 10}` });
    await page.goto('/app/login');
    await page.getByLabel(/e-?mail/i).fill(email);
    await page.getByLabel(/^(senha|password)$/i).fill(fixturePassword());
    await page.getByRole('button', { name: /entrar|sign in|login/i }).click();

    await page.waitForURL(url => !url.pathname.startsWith('/app/login'));
    await expect(page).not.toHaveURL(/\/app\/login/);
    await page.context().storageState({ path: `playwright/.auth/${persona}.json` });
  });
}

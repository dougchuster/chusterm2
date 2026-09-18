import { chromium } from '@playwright/test';
import fs from 'node:fs';

const OUT = 'C:/Users/dougc/AppData/Local/Temp/opencode/shots';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 860 } });
page.on('console', m => {
  if (m.type() === 'error') console.log('[console.error]', m.text().slice(0, 200));
});
page.on('pageerror', e => console.log('[pageerror]', e.message.slice(0, 300)));

await page.goto('http://127.0.0.1:8086/app/login');
await page.getByLabel(/e-?mail/i).fill('qa+f0-admin@chusterm.invalid');
await page.getByLabel(/^(senha|password)$/i).fill('QaPanel2026!x');
await page.getByRole('button', { name: /entrar|sign in|login/i }).click();
await page.waitForURL(u => !u.pathname.startsWith('/app/login'), { timeout: 30000 });
console.log('LOGIN OK ->', page.url());

const accountId = '1';
await page.goto(`http://127.0.0.1:8086/app/accounts/${accountId}/crm`);
await page.waitForTimeout(8000);
await page.screenshot({ path: `${OUT}/panel-kanban.png` });

// Deal com conversa vinculada: "Atendimento #54" (deal 57, conversa 54)
const card = page.locator('[data-testid="crm-board-card"]').filter({ hasText: 'Atendimento #54' }).first();
console.log('CARD FOUND:', await card.count());
if (await card.count()) {
  await card.locator('[data-testid="crm-card-attend"]').click({ force: true });
} else {
  await page.locator('[data-testid="crm-card-attend"]').first().click({ force: true });
}
await page.waitForTimeout(7000);
await page.screenshot({ path: `${OUT}/panel-open.png` });

const panel = page.locator('[data-testid="crm-conversation-panel"]');
console.log('PANEL VISIBLE:', await panel.count());
if (await panel.count()) {
  const box = await panel.boundingBox();
  console.log('PANEL BOX:', JSON.stringify(box));
}
await browser.close();

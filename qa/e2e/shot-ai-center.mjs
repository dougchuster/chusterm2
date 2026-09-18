import { chromium } from '@playwright/test';
import fs from 'node:fs';

const OUT = 'C:/Users/dougc/AppData/Local/Temp/opencode/shots-ai';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 860 } });
page.on('console', m => { if (m.type() === 'error') console.log('[console.error]', m.text().slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', String(e).slice(0, 200)));

await page.goto('http://127.0.0.1:8086/app/login');
await page.getByLabel(/e-?mail/i).fill('qa+f0-admin@chusterm.invalid');
await page.getByLabel(/^(senha|password)$/i).fill('QaF0Admin123!');
await page.getByRole('button', { name: /entrar|sign in|login/i }).click();
await page.waitForURL(u => !u.pathname.startsWith('/app/login'), { timeout: 30000 });
console.log('LOGIN OK ->', page.url());

await page.goto('http://127.0.0.1:8086/app/accounts/55/crm/ai-center');
await page.waitForTimeout(8000);
await page.screenshot({ path: OUT + '/ai-operation.png' });

// aba Assistente
const assistantTab = page.getByRole('tab', { name: /assistente|assistant/i });
if (await assistantTab.count()) {
  await assistantTab.first().click();
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/ai-assistant.png' });
} else {
  console.log('NO ASSISTANT TAB FOUND');
}

await page.goto('http://127.0.0.1:8086/app/accounts/55/crm/settings/segment');
await page.waitForTimeout(6000);
await page.screenshot({ path: OUT + '/segment.png' });

await browser.close();
console.log('DONE ->', OUT);

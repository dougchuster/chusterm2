// Verificação visual da F3 do cofre: checklist "X de Y" na aba do negócio e
// filas "Para análise"/"Vencendo". Uso: node shot-documents-f3.mjs <saida>
import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BASE = process.env.QA_BASE_URL || 'http://127.0.0.1:3010';
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  storageState: 'playwright/.auth/admin.json',
});
const page = await context.newPage();
const errors = [];
page.on('pageerror', e => errors.push(`[pageerror] ${String(e).slice(0, 200)}`));
page.on('response', r => {
  if (r.url().includes('/crm/document') && r.status() >= 400) errors.push(`[http ${r.status()}] ${r.url()}`);
});
const shot = async name => page.screenshot({ path: path.join(OUT, `${name}.png`) });

await page.goto(`${BASE}/app/accounts/55/crm/deals/${process.env.QA_DEAL_ID || 70}`);
await page.waitForTimeout(6000);
if (page.url().includes('/login')) throw new Error('Sessão expirada: regerar playwright/.auth/admin.json');
await page.getByRole('tab', { name: /Arquivos/ }).click();
await page.waitForTimeout(2500);
await page.getByRole('button', { name: /Documentos do caso/ }).click();
await page.waitForTimeout(800);
await shot('f3-1-checklist');

await page.goto(`${BASE}/app/accounts/55/crm/arquivos/triagem`);
await page.waitForTimeout(5000);
await page.getByRole('tab', { name: /Para análise/ }).click();
await page.waitForTimeout(2000);
await shot('f3-2-para-analise');
await page.getByRole('tab', { name: /Vencendo/ }).click();
await page.waitForTimeout(2000);
await shot('f3-3-vencendo');

console.log(errors.length ? errors.join('\n') : 'SEM ERROS');
await browser.close();

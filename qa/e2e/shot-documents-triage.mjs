// Verificação visual da Caixa de Triagem (PROJETO-COFRE-DOCUMENTOS.md §8.3).
// Uso: node shot-documents-triage.mjs <pasta-de-saida>
// Requer o módulo ligado na conta 55 e ao menos um documento na triagem.
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

await page.goto(`${BASE}/app/accounts/55/crm/arquivos/triagem`);
await page.waitForTimeout(7000);
if (page.url().includes('/login')) throw new Error('Sessão expirada: regerar playwright/.auth/admin.json');
await shot('t1-triagem');

const sidebarEntry = await page.getByRole('link', { name: /Triagem de documentos/ }).count();
console.log('item no menu:', sidebarEntry > 0 ? 'sim' : 'não');

await page.keyboard.press('2');
await page.waitForTimeout(600);
await shot('t2-tecla-2');

await page.setViewportSize({ width: 390, height: 844 });
await page.waitForTimeout(1500);
await shot('t3-celular');

console.log(errors.length ? errors.join('\n') : 'SEM ERROS');
await browser.close();

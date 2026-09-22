// Verificação visual do cofre de documentos (PROJETO-COFRE-DOCUMENTOS.md, F1).
// Uso: node shot-documents-vault.mjs <pasta-de-saida> <pasta-de-amostras>
// Requer o módulo ligado na conta 55: Crm::Documents::Feature.enable!(Account.find(55))
import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BASE = process.env.QA_BASE_URL || 'http://127.0.0.1:3010';
const OUT = process.argv[2];
const SAMPLES = process.argv[3];
const DEAL_URL = `${BASE}/app/accounts/55/crm/deals/${process.env.QA_DEAL_ID || 70}`;
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

await page.goto(DEAL_URL);
await page.waitForTimeout(6000);
if (page.url().includes('/login')) throw new Error('Sessão expirada: regerar playwright/.auth/admin.json');
console.log('DEAL ->', page.url());

await page.getByRole('tab', { name: /Arquivos/ }).click();
await page.waitForTimeout(2500);
await shot('01-aba-arquivos');

// Conteúdo único por rodada: o cofre deduplica por checksum dentro do contato.
const runDir = fs.mkdtempSync(path.join(OUT, 'run-'));
const files = fs.readdirSync(SAMPLES).map(name => {
  const target = path.join(runDir, name);
  fs.writeFileSync(target, Buffer.concat([fs.readFileSync(path.join(SAMPLES, name)), Buffer.from(`
%${Date.now()}
`)]));
  return target;
});

await page.getByRole('button', { name: /00 Triagem/ }).click();
await page.waitForTimeout(1500);
await page.locator('section[aria-label="Documentos do cliente"] input[type="file"]').setInputFiles(files);
await page.waitForTimeout(5000);
await shot('02-triagem-apos-envio');

await page.getByRole('button', { name: /^Ações de .*IMG-20260922-WA0012/ }).click();
await page.getByRole('menuitem', { name: /Classificar/ }).click();
await page.waitForTimeout(800);
await page.locator('#crm-doc-type').selectOption('rg');
await page.locator('#crm-doc-description').fill('Frente e verso');
await page.waitForTimeout(400);
await shot('04-modal-classificar');
await page.getByRole('button', { name: 'Salvar' }).click();
await page.waitForTimeout(2500);
await shot('05-apos-classificar');

await page.getByRole('button', { name: /01 Documentos Pessoais/ }).click();
await page.waitForTimeout(2000);
await shot('06-documentos-pessoais');

await page.setViewportSize({ width: 390, height: 844 });
await page.waitForTimeout(1500);
await shot('07-celular');

console.log(errors.length ? errors.join('\n') : 'SEM ERROS');
await browser.close();

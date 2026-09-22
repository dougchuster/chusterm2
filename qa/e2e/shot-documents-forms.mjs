// Verificação visual do cofre universal: configuração (formulários, nomes,
// tipos, pastas), página pública do formulário no celular e fila de envios.
// Uso: node shot-documents-forms.mjs <saida> <url-publica-do-formulario>
import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BASE = process.env.QA_BASE_URL || 'http://127.0.0.1:3010';
const OUT = process.argv[2];
const PUBLIC_URL = process.argv[3];
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const errors = [];
const watch = page => {
  page.on('pageerror', e => errors.push(`[pageerror] ${String(e).slice(0, 200)}`));
  page.on('response', r => {
    if (/\/crm\/document|\/[fl]\//.test(r.url()) && r.status() >= 400 && r.status() !== 422) errors.push(`[http ${r.status()}] ${r.url()}`);
  });
};

// 1. Configuração, logado como administrador
const admin = await browser.newContext({ viewport: { width: 1440, height: 900 }, storageState: 'playwright/.auth/admin.json' });
const page = await admin.newPage();
watch(page);
const shot = async name => page.screenshot({ path: path.join(OUT, `${name}.png`) });
await page.goto(`${BASE}/app/accounts/55/crm/arquivos/configuracoes`);
await page.waitForTimeout(6000);
if (page.url().includes('/login')) throw new Error('Sessão expirada: regerar playwright/.auth/admin.json');
await shot('c1-formularios');
await page.getByRole('button', { name: /Nome completo/ }).first().click();
await page.waitForTimeout(500);
await shot('c2-pergunta-aberta');
for (const [tab, name] of [[/Área e nomes/, 'c3-nomes'], [/Tipos de documento/, 'c4-tipos'], [/Pastas/, 'c5-pastas']]) {
  await page.getByRole('tab', { name: tab }).click();
  await page.waitForTimeout(1500);
  await shot(name);
}

// 2. Página pública no celular, sem login
const phone = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
const pub = await phone.newPage();
watch(pub);
await pub.goto(PUBLIC_URL);
await pub.waitForTimeout(1500);
await pub.screenshot({ path: path.join(OUT, 'p1-formulario.png'), fullPage: true });
await pub.fill('#field-nome', 'Teste Visual QA');
await pub.fill('#field-whatsapp', '11 90000-1234');
const radio = pub.locator('input[type="radio"]').first();
if (await radio.count()) await radio.check();
const relato = pub.locator('textarea').first();
if (await relato.count()) await relato.fill('Teste do formulário pelo roteiro visual.');
const sample = path.join(OUT, 'rg-teste.pdf');
fs.writeFileSync(sample, `%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n%${Date.now()}\n`);
await pub.setInputFiles('#file-identidade', sample);
await pub.check('#consent');
await pub.waitForTimeout(3500); // tempo mínimo de preenchimento
await pub.click('[data-submit]');
await pub.waitForLoadState('load');
await pub.waitForTimeout(1500);
await pub.screenshot({ path: path.join(OUT, 'p2-protocolo.png'), fullPage: true });
console.log('protocolo:', (await pub.locator('.protocol').textContent().catch(() => 'nenhum'))?.trim());

// 3. Fila de novos envios
await page.goto(`${BASE}/app/accounts/55/crm/arquivos/triagem`);
await page.waitForTimeout(5000);
await page.getByRole('tab', { name: /Novos envios/ }).click();
await page.waitForTimeout(2000);
await shot('q1-novos-envios');

console.log(errors.length ? errors.join('\n') : 'SEM ERROS');
await browser.close();

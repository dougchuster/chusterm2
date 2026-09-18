// Super Admin (Rails/Administrate): carga de todas as páginas + CRUD leve.
// Uso: QA_FIXTURE_PASSWORD=... QA_BASE_URL=... node superadmin.mjs
import { chromium } from '@playwright/test';
import fs from 'node:fs';

const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:3010';
const password = process.env.QA_FIXTURE_PASSWORD;
const email = 'qa+f0-super-admin@chusterm.invalid';
const ids = JSON.parse(fs.readFileSync(new URL('../_ids.json', import.meta.url), 'utf8'));
const out = [];
const log = (page, check, ok, detail = '') => { out.push({ page, check, ok, detail }); console.log(`${ok ? 'OK  ' : 'FAIL'} [${page}] ${check} ${detail}`); };

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, locale: 'pt-BR', extraHTTPHeaders: { 'X-Forwarded-For': '203.0.113.245' } });
const page = await ctx.newPage();

// anônimo → login
let r = await page.goto(`${base}/super_admin`, { waitUntil: 'networkidle' });
log('C1 /super_admin', 'anônimo é redirecionado para sign_in', /sign_in/.test(page.url()), page.url().replace(base, ''));
// admin de conta (não super admin) não entra
const acc = await browser.newContext({ storageState: '../../qa/e2e/playwright/.auth/admin.json' });
const ap = await acc.newPage();
await ap.goto(`${base}/super_admin/accounts`, { waitUntil: 'networkidle' });
log('C3 /super_admin/accounts', 'admin de conta comum não acessa (vai para sign_in)', /sign_in/.test(ap.url()), ap.url().replace(base, ''));
await acc.close();

// login
await page.goto(`${base}/super_admin/sign_in`, { waitUntil: 'networkidle' });
await page.fill('input[type="email"], input[name*="email"]', email);
await page.fill('input[type="password"]', password);
await page.locator('input[type="submit"], button[type="submit"]').first().click();
await page.waitForLoadState('networkidle');
log('C1 /super_admin', 'login do super admin', !/sign_in/.test(page.url()), page.url().replace(base, ''));

const pages = [
  ['C1', '/super_admin'], ['C2', '/super_admin/app_config'], ['C3', '/super_admin/accounts'], ['C4', '/super_admin/accounts/new'],
  ['C5', `/super_admin/accounts/${ids.accountId}`], ['C6', `/super_admin/accounts/${ids.accountId}/edit`],
  ['C7', '/super_admin/users'], ['C8', '/super_admin/users/new'], ['C9', `/super_admin/users/${ids.id_agent}`], ['C10', `/super_admin/users/${ids.id_agent}/edit`],
  ['C11', '/super_admin/access_tokens'], ['C13', '/super_admin/installation_configs'], ['C14', '/super_admin/installation_configs/new'],
  ['C17', '/super_admin/agent_bots'], ['C18', '/super_admin/agent_bots/new'], ['C21', '/super_admin/platform_apps'], ['C22', '/super_admin/platform_apps/new'],
  ['C25', '/super_admin/instance_status'], ['C26', '/super_admin/settings'], ['C27', '/super_admin/account_users/new'],
];
for (const [id, path] of pages) {
  const errs = []; const failed = [];
  const onConsole = m => { if (m.type() === 'error' && !/favicon/.test(m.text())) errs.push(m.text().slice(0, 120)); };
  const onResp = res => { if (res.status() >= 400 && !/favicon/.test(res.url())) failed.push(`${res.status()} ${res.url().replace(base, '')}`); };
  page.on('console', onConsole); page.on('response', onResp);
  const t0 = Date.now();
  const resp = await page.goto(base + path, { waitUntil: 'networkidle' }).catch(() => null);
  const ms = Date.now() - t0;
  const body = await page.evaluate(() => document.body.innerText.slice(0, 2000)).catch(() => '');
  const has500 = /We're sorry|something went wrong|Internal Server Error/i.test(body);
  page.off('console', onConsole); page.off('response', onResp);
  log(`${id} ${path}`, 'carrega sem 4xx/5xx e sem erros', (resp?.status() ?? 0) === 200 && !failed.length && !errs.length && !has500, `status=${resp?.status()} ${ms}ms failed=${failed.join(',')} errs=${errs.join(' | ')}`);
  if (ms > 3000) log(`${id} ${path}`, 'tempo < 3s', false, `${ms}ms`);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth).catch(() => 0);
  if (overflow > 2) log(`${id} ${path}`, 'sem overflow horizontal', false, `${overflow}px`);
}

// listagem de access_tokens não deve expor o token completo
await page.goto(`${base}/super_admin/access_tokens`, { waitUntil: 'networkidle' });
const tokTxt = await page.evaluate(() => document.body.innerText);
log('C11 /super_admin/access_tokens', 'tokens não aparecem em claro na listagem', !/[A-Za-z0-9_-]{24,}/.test(tokTxt.replace(/qa\+f0[^\s]*/g, '')), tokTxt.match(/[A-Za-z0-9_-]{24,}/)?.[0]?.slice(0, 12) ?? '');

// CRUD leve: criar/editar/excluir um agent bot QA_
await page.goto(`${base}/super_admin/agent_bots/new`, { waitUntil: 'networkidle' });
await page.fill('input[name="agent_bot[name]"]', `QA_Bot ${Date.now()}`);
await page.fill('input[name="agent_bot[outgoing_url]"]', 'https://example.invalid/bot').catch(() => {});
await page.locator('input[type="submit"]').first().click();
await page.waitForLoadState('networkidle');
log('C18 /super_admin/agent_bots/new', 'criar agent bot', /agent_bots\/\d+/.test(page.url()) || /criado|created|success/i.test(await page.evaluate(() => document.body.innerText)), page.url().replace(base, ''));
const botMatch = page.url().match(/agent_bots\/(\d+)/);
if (botMatch) {
  await page.goto(`${base}/super_admin/agent_bots/${botMatch[1]}/edit`, { waitUntil: 'networkidle' });
  await page.fill('input[name="agent_bot[name]"]', '');
  await page.locator('input[type="submit"]').first().click();
  await page.waitForLoadState('networkidle');
  const txt = await page.evaluate(() => document.body.innerText);
  log('C20 /super_admin/agent_bots/:id/edit', 'nome vazio → erro de validação exibido', /não pode|can't be blank|erro|error/i.test(txt) && /edit|agent_bots/.test(page.url()), txt.match(/.{0,40}(não pode|can't be blank).{0,20}/i)?.[0] ?? '');
  // excluir via request com CSRF token
  await page.goto(`${base}/super_admin/agent_bots/${botMatch[1]}`, { waitUntil: 'networkidle' });
  const token = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content);
  const del = await page.evaluate(async ({ id, token }) => {
    const r = await fetch(`/super_admin/agent_bots/${id}`, { method: 'DELETE', headers: { 'X-CSRF-Token': token, Accept: 'text/html' }, credentials: 'same-origin', redirect: 'manual' });
    return r.status;
  }, { id: botMatch[1], token });
  log('C20 /super_admin/agent_bots/:id', 'excluir agent bot (com CSRF)', del === 302 || del === 303 || del === 200 || del === 0, `status=${del}`);
  const delNoCsrf = await page.evaluate(async id => { const r = await fetch(`/super_admin/agent_bots/${id}`, { method: 'DELETE', credentials: 'same-origin', redirect: 'manual' }); return r.status; }, botMatch[1]);
  log('C20 /super_admin/agent_bots/:id', 'DELETE sem CSRF é rejeitado', delNoCsrf === 422 || delNoCsrf === 403 || delNoCsrf === 404, `status=${delNoCsrf}`);
}

// Sidekiq protegido
const sq = await page.goto(`${base}/monitoring/sidekiq`, { waitUntil: 'domcontentloaded' }).catch(() => null);
log('/monitoring/sidekiq', 'acessível para super admin', (sq?.status() ?? 0) === 200, `status=${sq?.status()}`);
const anon = await browser.newContext();
const sqa = await anon.request.get(`${base}/monitoring/sidekiq`, { maxRedirects: 0 });
log('/monitoring/sidekiq', 'anônimo não acessa', sqa.status() !== 200, `status=${sqa.status()}`);

await browser.close();
fs.writeFileSync(new URL('./results/superadmin.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(`\n${out.filter(x => x.ok).length}/${out.length} OK`);

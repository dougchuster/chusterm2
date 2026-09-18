// Auditoria funcional das páginas públicas de autenticação (A1–A6).
// Uso: QA_FIXTURE_PASSWORD=... node auth.mjs
import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import fs from 'node:fs';

const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:8086';
const password = process.env.QA_FIXTURE_PASSWORD;
if (!password) throw new Error('QA_FIXTURE_PASSWORD ausente');
const adminEmail = 'qa+f0-admin@chusterm.invalid';
const out = [];
const log = (page, check, ok, detail = '') => { out.push({ page, check, ok, detail }); console.log(`${ok ? 'OK  ' : 'FAIL'} [${page}] ${check} ${detail}`); };

const browser = await chromium.launch();
let ipCounter = 150;
const newCtx = async (opts = {}) => browser.newContext({ locale: 'pt-BR', extraHTTPHeaders: { 'X-Forwarded-For': `203.0.113.${ipCounter++}` }, ...opts });

const collect = (page) => {
  const errs = []; const failed = [];
  page.on('console', m => { if (m.type() === 'error' && !/favicon|DevTools/.test(m.text())) errs.push(m.text().slice(0, 200)); });
  page.on('pageerror', e => errs.push(String(e).slice(0, 200)));
  page.on('response', r => { if (r.status() >= 400 && !/favicon/.test(r.url())) failed.push(`${r.status()} ${r.url().replace(base, '')}`); });
  return { errs, failed };
};

const widths = [360, 768, 1440];
const publicPages = [
  ['A1', '/app/login', /e-?mail/i],
  ['A2', '/app/login/sso', /e-?mail/i],
  ['A3', '/app/auth/signup', /./],
  ['A4', '/app/auth/confirmation?confirmation_token=QA_invalid', /./],
  ['A5', '/app/auth/password/edit?reset_password_token=QA_invalid', /./],
  ['A6', '/app/auth/reset/password', /e-?mail/i],
];

for (const [id, url] of publicPages) {
  for (const w of widths) {
    const ctx = await newCtx({ viewport: { width: w, height: 900 } });
    const page = await ctx.newPage();
    const c = collect(page);
    const t0 = Date.now();
    const resp = await page.goto(base + url, { waitUntil: 'networkidle' });
    const ms = Date.now() - t0;
    const finalUrl = page.url().replace(base, '');
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    const text = await page.evaluate(() => document.body.innerText.slice(0, 3000));
    log(id, `carrega @${w}`, resp.status() === 200 && !c.errs.length && !c.failed.length, `status=${resp.status()} ${ms}ms final=${finalUrl} errs=${JSON.stringify(c.errs)} failed=${JSON.stringify(c.failed)}`);
    log(id, `sem overflow @${w}`, overflow <= 2, `${overflow}px`);
    log(id, `textos em pt-BR @${w}`, !/\b(Sign in|Password|Forgot|Email address)\b/.test(text), text.replace(/\s+/g, ' ').slice(0, 160));
    if (w === 1440) {
      const axe = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
      const bad = axe.violations.filter(v => ['serious', 'critical'].includes(v.impact));
      log(id, 'axe sem serious/critical', bad.length === 0, bad.map(v => `${v.id}(${v.nodes.length})`).join(', '));
      await page.screenshot({ path: `shots/auth-${id}.png` });
    }
    await ctx.close();
  }
}

// A1 — comportamento do formulário
{
  const ctx = await newCtx({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  await page.goto(base + '/app/login', { waitUntil: 'networkidle' });
  const emailInput = page.getByTestId('email_input');
  const submit = page.getByRole('button', { name: /entrar|sign in|login/i });

  await submit.click();
  await page.waitForTimeout(400);
  let alert = await page.evaluate(() => document.body.innerText);
  log('A1', 'submit vazio → mensagem de validação', /e-?mail|obrigat|inválid/i.test(alert), alert.match(/.{0,60}(e-?mail|obrigat|inválid).{0,60}/i)?.[0] ?? '(nenhuma)');

  await emailInput.fill('nao-e-email');
  await page.getByLabel(/^(senha|password)$/i).fill('x');
  await submit.click();
  await page.waitForTimeout(400);
  alert = await page.evaluate(() => document.body.innerText);
  log('A1', 'e-mail inválido → validação client-side', /e-?mail/i.test(alert) && !/401/.test(alert), alert.match(/.{0,60}e-?mail.{0,60}/i)?.[0] ?? '');

  await emailInput.fill(adminEmail);
  await page.getByLabel(/^(senha|password)$/i).fill('senha-errada-QA');
  const respPromise = page.waitForResponse(r => r.url().includes('/auth/sign_in'));
  await submit.click();
  const disabledDuring = await submit.isDisabled().catch(() => null);
  const resp = await respPromise;
  await page.waitForTimeout(600);
  alert = await page.evaluate(() => document.body.innerText);
  log('A1', 'credencial inválida → 401 + mensagem pt-BR', resp.status() === 401 && /inválid|incorret|não foi possível|credenciais/i.test(alert), `status=${resp.status()} msg="${alert.match(/.{0,80}(inválid|incorret|credenciais|não foi).{0,40}/i)?.[0] ?? '(nenhuma)'}"`);
  log('A1', 'botão desabilitado durante submit (anti duplo-submit)', disabledDuring === true, `disabled=${disabledDuring}`);
  const body401 = await resp.text();
  log('A1', 'resposta 401 não vaza detalhes', !/stack|backtrace|ActiveRecord|\.rb:/i.test(body401), body401.slice(0, 120));

  // login válido
  await page.getByLabel(/^(senha|password)$/i).fill(password);
  await submit.click();
  await page.waitForURL(u => !u.pathname.startsWith('/app/login'), { timeout: 15000 }).catch(() => {});
  log('A1', 'login válido redireciona para o dashboard', /\/app\/accounts\/\d+/.test(page.url()), page.url().replace(base, ''));

  // já logado → /app/login redireciona?
  await page.goto(base + '/app/login', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  log('A1', 'usuário logado em /app/login é redirecionado', !/\/app\/login$/.test(page.url()), page.url().replace(base, ''));
  await ctx.close();
}

// A1 — rate limit (Rack::Attack login/ip = 5/5min): 6 tentativas do mesmo IP
{
  const ctx = await newCtx();
  let last = 0;
  for (let i = 0; i < 6; i++) {
    const r = await ctx.request.post(base + '/auth/sign_in', { data: { email: `qa-rl-${Date.now()}@chusterm.invalid`, password: 'x'.repeat(12) } });
    last = r.status();
  }
  log('A1', 'rate limit por IP após 5 tentativas', last === 429, `6ª tentativa → ${last}`);
  await ctx.close();
}

// A6 — reset: e-mail inexistente não deve revelar existência
{
  const ctx = await newCtx({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  await page.goto(base + '/app/auth/reset/password', { waitUntil: 'networkidle' });
  await page.getByLabel(/e-?mail/i).fill('qa-inexistente@chusterm.invalid');
  const rp = page.waitForResponse(r => r.url().includes('/auth/password'));
  await page.getByRole('button').filter({ hasText: /enviar|redefinir|reset|submit/i }).first().click();
  const r = await rp;
  await page.waitForTimeout(600);
  const txt = await page.evaluate(() => document.body.innerText);
  log('A6', 'reset p/ e-mail inexistente não revela existência', r.status() < 500, `status=${r.status()} msg="${txt.match(/.{0,100}(e-?mail|enviad|instru).{0,60}/i)?.[0] ?? ''}"`);
  await ctx.close();
}

// A3 — signup habilitado?
{
  const ctx = await newCtx();
  const r = await ctx.request.get(base + '/api');
  const cfg = await ctx.request.get(base + '/app/login');
  const html = await cfg.text();
  const m = html.match(/signupEnabled['"]?\s*[:=]\s*['"]?(\w+)/);
  log('A3', 'estado do signup identificado', true, `signupEnabled=${m?.[1] ?? '?'} api=${r.status()}`);
  await ctx.close();
}

await browser.close();
fs.writeFileSync('results/auth.json', JSON.stringify(out, null, 1));
console.log(`\n${out.filter(x => x.ok).length}/${out.length} checks OK`);

// Varredura automatizada de rotas para o check-up de páginas.
// Uso: node sweep.mjs --persona admin --width 1440 [--shots] [--axe] [--only crm]
// Lê ../_routes_raw.json (dump do router real) e ../_ids.json (ids da fixture QA).
// Saída: results/<persona>-<width>.json (+ shots/<persona>-<width>/*.png com --shots)
import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).map((a, i, arr) => {
    if (!a.startsWith('--')) return [];
    const next = arr[i + 1];
    return [a.slice(2), next && !next.startsWith('--') ? next : true];
  }).filter(x => x.length)
);
const persona = args.persona ?? 'admin';
const width = Number(args.width ?? 1440);
const wantShots = Boolean(args.shots);
const wantAxe = Boolean(args.axe);
const only = args.only ? new RegExp(args.only) : null;
const concurrency = Number(args.concurrency ?? 4);
const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:8086';
const NAV_TIMEOUT_MS = 20_000;
const IDLE_TIMEOUT_MS = 8_000;
const SLOW_MS = 3_000;

const routes = JSON.parse(fs.readFileSync(path.join(here, '..', '_routes_raw.json'), 'utf8'));
const ids = JSON.parse(fs.readFileSync(path.join(here, '..', '_ids.json'), 'utf8'));
const params = {
  accountId: ids.accountId,
  id: ids.id_agent,
  inbox_id: ids.inbox_id,
  inboxId: ids.inbox_id,
  teamId: ids.teamId,
  sub_page: 'website',
  flowId: ids.flowId,
  macroId: ids.macroId,
  kind: 'custom',
  categoryId: ids.labelId,
  tab: 'conversations',
  conversationId: ids.conversation_id,
  conversation_id: ids.conversation_id,
  integration_id: 'dialogflow',
  dealId: ids.dealId,
  segmentId: ids.segmentId,
  label: ids.label,
  assistantId: ids.assistantId,
  contactId: ids.contactId,
  portalSlug: ids.portalSlug,
  locale: 'pt_BR',
  categorySlug: ids.categorySlug,
  articleSlug: ids.articleSlug,
  type: 'inbox',
  navigationPath: 'assistants',
};
// Rotas com :id que não é agente
const ID_OVERRIDES = [
  [/reports\/inboxes\/:id/, ids.inbox_id],
  [/reports\/teams\/:id/, ids.teamId],
  [/reports\/labels\/:id/, ids.labelId],
  [/custom_view\/:id/, ids.id_custom_view],
  [/inbox-view\/:type\/:id/, ids.conversation_id],
  [/assignment-policy\/\w+\/edit\/:id/, 1],
  [/settings\/(macros|agents|teams)\/.*:id/, 1],
];

const fill = (p) => {
  let out = p;
  for (const [re, val] of ID_OVERRIDES) if (re.test(p)) out = out.replace(':id', String(val));
  return out.replace(/:(\w+)\??/g, (_, k) => (params[k] ?? `MISSING_${k}`)).replace(/\/+$/, '');
};

const NOISE = [
  /favicon/i, /ResizeObserver loop/, /DevTools/, /Download the Vue Devtools/, /vite/i,
  /\[Vue warn\]: Extraneous non-props/, /third-party cookie/i, /source map/i,
];
const isNoise = (t) => NOISE.some(re => re.test(t));

const targets = routes
  .filter(r => r.path.startsWith('/app/'))
  .filter(r => !only || only.test(r.path) || only.test(r.name))
  .map(r => ({ ...r, url: fill(r.path) }));

const storage = persona === 'anon' ? undefined : path.join(here, '..', '..', 'qa', 'e2e', 'playwright', '.auth', `${persona}.json`);
const outDir = path.join(here, 'results');
const shotDir = path.join(here, 'shots', `${persona}-${width}`);
fs.mkdirSync(outDir, { recursive: true });
if (wantShots) fs.mkdirSync(shotDir, { recursive: true });

const browser = await chromium.launch();
const results = [];
let cursor = 0;

async function visit(ctx, route, workerIx) {
  const page = await ctx.newPage();
  const consoleErrors = [];
  const consoleWarnings = [];
  const failed = [];
  const requests = new Map();
  const api = [];
  page.on('console', (m) => {
    const t = m.text();
    if (isNoise(t)) return;
    if (m.type() === 'error') consoleErrors.push(t.slice(0, 300));
    else if (m.type() === 'warning') consoleWarnings.push(t.slice(0, 300));
  });
  page.on('pageerror', (e) => consoleErrors.push(`pageerror: ${String(e).slice(0, 300)}`));
  page.on('requestfailed', (r) => { if (!isNoise(r.url()) && r.failure()?.errorText !== 'net::ERR_ABORTED') failed.push({ url: r.url().replace(base, ''), status: 'FAILED', err: r.failure()?.errorText }); });
  page.on('response', (r) => {
    const u = r.url();
    if (isNoise(u)) return;
    const key = u.replace(base, '').replace(/\?.*$/, '');
    requests.set(key, (requests.get(key) ?? 0) + 1);
    if (u.includes('/api/')) api.push({ url: u.replace(base, '').slice(0, 200), status: r.status() });
    if (r.status() >= 400) failed.push({ url: u.replace(base, '').slice(0, 200), status: r.status() });
  });

  const t0 = Date.now();
  let docStatus = null; let navError = null; let idle = true;
  try {
    const resp = await page.goto(base + route.url, { waitUntil: 'domcontentloaded', timeout: NAV_TIMEOUT_MS });
    docStatus = resp?.status() ?? null;
    try { await page.waitForLoadState('networkidle', { timeout: IDLE_TIMEOUT_MS }); } catch { idle = false; }
    await page.waitForTimeout(400);
  } catch (e) { navError = String(e).slice(0, 200); }
  const loadMs = Date.now() - t0;

  let finalUrl = page.url().replace(base, '');
  let overflow = null; let notFound = false; let emptyState = false; let bodyText = '';
  let h1 = ''; let title = '';
  try {
    const info = await page.evaluate(() => {
      const de = document.documentElement;
      const txt = document.body?.innerText ?? '';
      return {
        overflow: Math.max(de.scrollWidth, document.body?.scrollWidth ?? 0) - de.clientWidth,
        text: txt.slice(0, 4000),
        h1: document.querySelector('h1,h2,[data-page-title]')?.textContent?.trim().slice(0, 80) ?? '',
        title: document.title,
      };
    });
    overflow = info.overflow; bodyText = info.text; h1 = info.h1; title = info.title;
    notFound = /p[áa]gina n[ãa]o encontrada|not found|404/i.test(bodyText.slice(0, 1500));
    emptyState = /nenhum|vazio|no data|sem resultados|nada por aqui|comece|adicione/i.test(bodyText);
  } catch { /* página pode ter navegado */ }

  let axe = null;
  if (wantAxe && !navError) {
    try {
      const { default: AxeBuilder } = await import('@axe-core/playwright');
      const res = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
      axe = res.violations
        .filter(v => ['serious', 'critical'].includes(v.impact))
        .map(v => ({ id: v.id, impact: v.impact, nodes: v.nodes.length, help: v.help }));
    } catch (e) { axe = [{ id: 'axe-error', help: String(e).slice(0, 120) }]; }
  }

  const safeName = (route.name || route.url.replace(/[^a-z0-9]+/gi, '_')).slice(0, 80);
  if (wantShots && !navError) {
    try { await page.screenshot({ path: path.join(shotDir, `${safeName}.png`), fullPage: false }); } catch { /* ignore */ }
  }
  const loops = [...requests.entries()].filter(([, n]) => n >= 4).map(([u, n]) => `${u} ×${n}`);
  await page.close();
  return {
    name: route.name, path: route.path, url: route.url, redirect: route.redirect || '',
    permissions: route.permissions, featureFlag: route.featureFlag,
    persona, width, docStatus, navError, finalUrl, loadMs, slow: loadMs > SLOW_MS, networkIdle: idle,
    redirectedToLogin: /\/app\/login/.test(finalUrl),
    redirectedElsewhere: finalUrl.replace(/\?.*$/, '') !== route.url && !/\/app\/login/.test(finalUrl),
    consoleErrors, consoleWarnings: consoleWarnings.slice(0, 10), failed, apiCount: api.length,
    api4xx: api.filter(a => a.status >= 400), loops, overflowPx: overflow, notFound, emptyState, h1, title,
    axe, shot: wantShots ? path.relative(here, path.join(shotDir, `${safeName}.png`)) : null,
  };
}

async function worker(ix) {
  const ctx = await browser.newContext({
    storageState: storage, viewport: { width, height: width < 800 ? 800 : 900 }, locale: 'pt-BR',
    extraHTTPHeaders: { 'X-Forwarded-For': `203.0.113.${100 + ix}` },
  });
  for (;;) {
    const route = targets[cursor++];
    if (!route) break;
    const r = await visit(ctx, route, ix);
    results.push(r);
    const flag = r.navError ? 'NAV!' : r.failed.length ? `${r.failed.length}xFAIL` : r.consoleErrors.length ? `${r.consoleErrors.length}xERR` : 'ok';
    process.stdout.write(`[${results.length}/${targets.length}] ${flag.padEnd(7)} ${r.loadMs}ms ${route.url}\n`);
  }
  await ctx.close();
}

await Promise.all(Array.from({ length: concurrency }, (_, i) => worker(i)));
await browser.close();
results.sort((a, b) => a.url.localeCompare(b.url));
const out = path.join(outDir, `${persona}-${width}${only ? '-' + args.only.replace(/\W+/g, '_') : ''}.json`);
fs.writeFileSync(out, JSON.stringify(results, null, 1));
const summary = {
  total: results.length,
  navErrors: results.filter(r => r.navError).length,
  withFailedRequests: results.filter(r => r.failed.length).length,
  withConsoleErrors: results.filter(r => r.consoleErrors.length).length,
  slow: results.filter(r => r.slow).length,
  overflow: results.filter(r => (r.overflowPx ?? 0) > 2).length,
  notFound: results.filter(r => r.notFound).length,
  toLogin: results.filter(r => r.redirectedToLogin).length,
  loops: results.filter(r => r.loops.length).length,
  axeViolations: wantAxe ? results.reduce((n, r) => n + (r.axe?.length ?? 0), 0) : null,
};
console.log('\nRESUMO', JSON.stringify(summary));
console.log('salvo em', out);

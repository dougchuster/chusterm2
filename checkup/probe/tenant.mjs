// Isolamento de tenant: admin da conta B (56) tentando ler dados da conta A (55).
// Uso: QA_BASE_URL=... node tenant.mjs
import { chromium } from '@playwright/test';
import fs from 'node:fs';

const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:3010';
const A = 55;
const ids = JSON.parse(fs.readFileSync(new URL('../_ids.json', import.meta.url), 'utf8'));
const out = [];
const log = (check, ok, detail) => { out.push({ check, ok, detail }); console.log(`${ok ? 'OK  ' : 'FAIL'} ${check} ${detail}`); };

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '../../qa/e2e/playwright/.auth/admin_b.json', extraHTTPHeaders: { 'X-Forwarded-For': '203.0.113.230' } });
const page = await ctx.newPage();

// 1) navegação SPA: nenhuma resposta 2xx de /api/*/accounts/55/*
const leaks = [];
page.on('response', r => { const u = r.url(); if (u.includes(`/accounts/${A}/`) && u.includes('/api/') && r.status() < 300) leaks.push(`${r.status()} ${u.replace(base, '')}`); });
for (const path of ['crm', 'crm/leads', `crm/deals/${ids.dealId}`, 'contacts', `contacts/${ids.contactId}`, 'conversations/1', 'reports/overview', 'settings/agents/list']) {
  await page.goto(`${base}/app/accounts/${A}/${path}`, { waitUntil: 'networkidle' }).catch(() => {});
}
log('SPA: nenhuma resposta 2xx da conta 55 para admin da conta 56', leaks.length === 0, leaks.slice(0, 5).join(' | ') || `final=${page.url().replace(base, '')}`);

// 2) chamadas diretas à API com o token do admin_b (headers do cookie cw_d_session_info)
const cookies = await ctx.cookies();
const session = cookies.find(c => c.name === 'cw_d_session_info');
const headers = session ? JSON.parse(decodeURIComponent(session.value)) : {};
const auth = { 'access-token': headers['access-token'], client: headers.client, uid: headers.uid, 'token-type': 'Bearer' };
const endpoints = [
  `/api/v1/accounts/${A}/crm/deals?per_page=5`,
  `/api/v1/accounts/${A}/crm/deals/${ids.dealId}`,
  `/api/v1/accounts/${A}/crm/board_views?context=board`,
  `/api/v1/accounts/${A}/contacts`,
  `/api/v1/accounts/${A}/contacts/${ids.contactId}`,
  `/api/v1/accounts/${A}/conversations`,
  `/api/v1/accounts/${A}/conversations/${ids.conversation_id}/messages`,
  `/api/v1/accounts/${A}/inboxes`,
  `/api/v1/accounts/${A}/agents`,
  `/api/v1/accounts/${A}/labels`,
  `/api/v1/accounts/${A}/crm/pipelines`,
  `/api/v1/accounts/${A}/crm/packs`,
  `/api/v1/accounts/${A}/crm/dashboard`,
  `/api/v1/accounts/${A}/crm/metrics/summary`,
  `/api/v2/accounts/${A}/reports/summary?since=1&until=9999999999&type=account`,
  `/api/v1/accounts/${A}/portals`,
  `/api/v1/accounts/${A}/captain/assistants`,
  `/api/v1/accounts/${A}/marketing/leads`,
  `/api/v1/accounts/${A}/companies`,
  `/api/v1/accounts/${A}/custom_filters`,
];
for (const ep of endpoints) {
  const r = await ctx.request.get(base + ep, { headers: auth });
  const body = (await r.text()).slice(0, 120);
  log(`API cross-tenant ${ep.replace(`/api/v1/accounts/${A}`, '…')}`, r.status() >= 400, `status=${r.status()} ${r.status() < 400 ? body : ''}`);
}
// 3) escrita cross-tenant
const w = await ctx.request.post(`${base}/api/v1/accounts/${A}/crm/deals`, { headers: auth, data: { title: 'QA_CROSS_TENANT', contact_id: ids.contactId } });
log('POST cross-tenant crm/deals bloqueado', w.status() >= 400, `status=${w.status()}`);
const d = await ctx.request.delete(`${base}/api/v1/accounts/${A}/crm/deals/${ids.dealId}`, { headers: auth });
log('DELETE cross-tenant crm/deals/:id bloqueado', d.status() >= 400, `status=${d.status()}`);

// 4) anônimo
const anon = await browser.newContext({ extraHTTPHeaders: { 'X-Forwarded-For': '203.0.113.231' } });
for (const ep of endpoints.slice(0, 6)) {
  const r = await anon.request.get(base + ep);
  log(`API anônimo ${ep.replace(`/api/v1/accounts/${A}`, '…')}`, r.status() === 401, `status=${r.status()}`);
}
await browser.close();
fs.writeFileSync(new URL('./results/tenant.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(`\n${out.filter(x => x.ok).length}/${out.length} OK`);

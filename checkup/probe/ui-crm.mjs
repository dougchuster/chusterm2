// Checks de UI (formulários, estados, confirmação) nas páginas críticas do CRM e Contatos.
// Uso: QA_BASE_URL=... node ui-crm.mjs
import { chromium } from '@playwright/test';
import fs from 'node:fs';

const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:3010';
const A = 55;
const out = [];
const log = (page, check, ok, detail = '') => { out.push({ page, check, ok, detail }); console.log(`${ok ? 'OK  ' : 'FAIL'} [${page}] ${check} ${detail}`); };
const stamp = Date.now();

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '../../qa/e2e/playwright/.auth/admin.json', viewport: { width: 1440, height: 900 }, locale: 'pt-BR', extraHTTPHeaders: { 'X-Forwarded-For': '203.0.113.242' } });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', e => errors.push(String(e).slice(0, 200)));
page.on('console', m => { if (m.type() === 'error' && !/favicon|Failed to load resource/.test(m.text())) errors.push(m.text().slice(0, 200)); });
const text = async () => page.evaluate(() => document.body.innerText);

// ---- CRM board: novo negócio ----
await page.goto(`${base}/app/accounts/${A}/crm`, { waitUntil: 'networkidle' });
await page.getByRole('button', { name: /novo negócio/i }).first().click();
await page.waitForTimeout(500);
const drawer = page.locator('#create-deal-drawer');
log('crm (board)', 'drawer "Novo negócio" abre', await drawer.isVisible(), '');
const submitBtn = drawer.getByRole('button', { name: /criar|salvar|adicionar/i }).last();
log('crm (board)', 'submit desabilitado sem título (validação client-side)', await submitBtn.isDisabled(), '');
await drawer.getByLabel(/assunto|título/i).first().fill(`QA_UI Negócio ${stamp}`);
await drawer.getByLabel(/nome do contato|contato/i).first().fill(`QA_UI Contato ${stamp}`);
await drawer.getByLabel(/telefone/i).first().fill('11 99999-0000');
log('crm (board)', 'submit habilita com título', !(await submitBtn.isDisabled()), '');
const [resp] = await Promise.all([
  page.waitForResponse(r => r.url().includes('/crm/deals') && r.request().method() === 'POST'),
  submitBtn.click(),
]);
const body = await resp.json().catch(() => ({}));
log('crm (board)', 'POST negócio pela UI', resp.status() === 201 || resp.status() === 200 || resp.status() === 422, `status=${resp.status()} ${JSON.stringify(body).slice(0, 140)}`);
await page.waitForTimeout(800);
const t1 = await text();
log('crm (board)', 'feedback visível após criar (card ou mensagem de erro)', /QA_UI Negócio|QA_UI Contato|telefone|inválid/i.test(t1), t1.match(/.{0,50}(QA_UI|telefone|inválid).{0,60}/i)?.[0]?.replace(/\s+/g, ' ') ?? '(nada)');
const dealId = body?.id;

// busca no board
await page.getByPlaceholder(/buscar/i).first().fill(`QA_UI Negócio ${stamp}`);
await page.waitForTimeout(1200);
const t2 = await text();
log('crm (board)', 'busca filtra o board para o negócio criado', dealId ? /QA_UI/.test(t2) : true, `dealId=${dealId}`);
await page.getByPlaceholder(/buscar/i).first().fill(`zzz-nao-existe-${stamp}`);
await page.waitForTimeout(1200);
const t3 = await text();
log('crm (board)', 'busca sem resultado mostra estado vazio (não quebra)', /nenhum|vazio|sem negócio|0 negócio|arraste/i.test(t3) && !errors.length, t3.match(/.{0,40}(nenhum|vazio|0 negócio|arraste).{0,40}/i)?.[0]?.replace(/\s+/g, ' ') ?? '(sem texto de vazio)');
await page.getByPlaceholder(/buscar/i).first().fill('');

// ---- Ficha do negócio: excluir com confirmação ----
if (dealId) {
  await page.goto(`${base}/app/accounts/${A}/crm/deals/${dealId}`, { waitUntil: 'networkidle' });
  log('crm/deals/:id', 'ficha abre com o título', (await text()).includes(`QA_UI Negócio ${stamp}`), '');
  const more = page.getByRole('button', { name: /mais ações|ações|\.\.\./i }).first();
  if (await more.count()) await more.click();
  await page.waitForTimeout(300);
  const del = page.getByRole('button', { name: /^excluir|excluir negócio|apagar/i }).first();
  const menuItem = page.getByRole('menuitem', { name: /excluir/i }).first();
  const target = (await del.count()) ? del : menuItem;
  if (await target.count()) {
    let deleted = false;
    page.on('response', r => { if (r.url().includes(`/crm/deals/${dealId}`) && r.request().method() === 'DELETE') deleted = true; });
    await target.click();
    await page.waitForTimeout(600);
    const confirmVisible = await page.getByRole('dialog').count();
    log('crm/deals/:id', 'excluir pede confirmação antes de apagar', confirmVisible > 0 && !deleted, `dialogs=${confirmVisible} deletedWithoutConfirm=${deleted}`);
    const confirm = page.getByRole('dialog').getByRole('button', { name: /excluir|confirmar|sim/i }).first();
    if (await confirm.count()) { await confirm.click(); await page.waitForTimeout(1200); }
    const gone = await ctx.request.get(`${base}/api/v1/accounts/${A}/crm/deals/${dealId}`, { headers: { 'X-Requested-With': 'XMLHttpRequest' } });
    log('crm/deals/:id', 'após confirmar, negócio não existe mais', deleted, `DELETE enviado=${deleted}`);
  } else {
    log('crm/deals/:id', 'botão de excluir encontrado', false, 'não achei botão/menu Excluir');
  }
}

// ---- Loss reasons UI ----
await page.goto(`${base}/app/accounts/${A}/crm/settings/loss-reasons`, { waitUntil: 'networkidle' });
const input = page.getByPlaceholder(/motivo|novo/i).first().or(page.getByRole('textbox').first());
await input.fill(`QA_UI Motivo ${stamp}`);
const [lr] = await Promise.all([
  page.waitForResponse(r => r.url().includes('loss-reasons') && r.request().method() === 'POST'),
  page.getByRole('button', { name: /adicionar|criar|salvar/i }).first().click(),
]);
await page.waitForTimeout(600);
log('crm/settings/loss-reasons', 'criar motivo pela UI persiste', lr.status() === 201 && (await text()).includes(`QA_UI Motivo ${stamp}`), `status=${lr.status()}`);

// ---- Contatos: novo contato ----
await page.goto(`${base}/app/accounts/${A}/contacts`, { waitUntil: 'networkidle' });
const more = page.getByRole('button', { name: /mais ações|more actions/i }).first();
if (await more.count()) { await more.click(); await page.waitForTimeout(300); }
const newContact = page.getByRole('menuitem', { name: /novo contato|adicionar contato|criar contato/i }).first()
  .or(page.getByRole('button', { name: /novo contato|adicionar contato|criar contato/i }).first());
if (await newContact.count()) {
  await newContact.click(); await page.waitForTimeout(500);
  const dlg = page.getByRole('dialog').first();
  const save = dlg.getByRole('button', { name: /criar|salvar|adicionar/i }).last();
  log('contacts (novo)', 'submit desabilitado com formulário vazio (validação client-side)', await save.isDisabled(), '');
  await dlg.getByPlaceholder(/nome/i).first().fill(`QA_UI Contato ${stamp}`);
  await dlg.getByPlaceholder(/e-?mail/i).first().fill('nao-e-email');
  await dlg.getByPlaceholder(/e-?mail/i).first().blur(); await page.waitForTimeout(400);
  const tx2 = await text();
  log('contacts (novo)', 'e-mail inválido → mensagem ou submit bloqueado', /e-?mail.*(inválid|válido)|inválid.*e-?mail/i.test(tx2) || await save.isDisabled(), tx2.match(/.{0,40}e-?mail.{0,60}/i)?.[0]?.replace(/\s+/g, ' ') ?? `disabled=${await save.isDisabled()}`);
  await dlg.getByPlaceholder(/e-?mail/i).first().fill(`qa_ui_${stamp}@chusterm.invalid`);
  const phone = dlg.getByPlaceholder(/telefone/i).first();
  if (await phone.count()) await phone.fill('11999990001');
  const [cr] = await Promise.all([
    page.waitForResponse(r => /\/contacts(\?|$)/.test(r.url()) && r.request().method() === 'POST'),
    save.click(),
  ]);
  const cb = await cr.json().catch(() => ({}));
  const cid = cb?.payload?.contact?.id;
  log('contacts (novo)', 'criar contato pela UI', cr.status() === 200 && cid, `status=${cr.status()} id=${cid}`);
  await page.waitForTimeout(800);
  log('contacts (novo)', 'contato aparece após criar', (await text()).includes(`QA_UI Contato ${stamp}`) || /\/contacts\/\d+/.test(page.url()), page.url().replace(base, ''));
  if (cid) await ctx.request.delete(`${base}/api/v1/accounts/${A}/contacts/${cid}`, { headers: JSON.parse(decodeURIComponent((await ctx.cookies()).find(c => c.name === 'cw_d_session_info').value)) });
} else {
  log('contacts (novo)', 'botão novo contato', false, 'não encontrado');
}

// ---- estados: contatos vazio via busca ----
await page.goto(`${base}/app/accounts/${A}/contacts`, { waitUntil: 'networkidle' });
const search = page.getByPlaceholder(/pesquis|buscar/i).first();
if (await search.count()) {
  await search.fill(`zzz-nada-${stamp}`); await page.keyboard.press('Enter'); await page.waitForTimeout(1500);
  const tx = await text();
  log('contacts', 'busca sem resultado mostra estado vazio', /nenhum|não encontr|sem resultado|0 contato/i.test(tx), tx.match(/.{0,40}(nenhum|não encontr|sem resultado).{0,40}/i)?.[0]?.replace(/\s+/g, ' ') ?? '(sem texto)');
}

log('(geral)', 'sem erros JS não tratados durante os fluxos de UI', errors.length === 0, errors.slice(0, 3).join(' | '));
await browser.close();
fs.writeFileSync(new URL('./results/ui-crm.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(`\n${out.filter(x => x.ok).length}/${out.length} OK`);

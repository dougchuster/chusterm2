// Fecha o ciclo: cruza a regressão final (results/final/*.json) com a lista de
// bloqueios conhecidos e grava o Status de cada linha do inventário.
// Uso: node finalize.mjs   (imprime o resumo usado no relatório)
import fs from 'node:fs';

const here = new URL('.', import.meta.url);
const read = (n) => { try { return JSON.parse(fs.readFileSync(new URL(`./results/final/${n}.json`, here), 'utf8')); } catch { return null; } };
const admin = read('admin-1440'); const mobile = read('admin-360'); const operator = read('operator-1440'); const anon = read('anon-1440');
if (!admin) throw new Error('rode a regressão final antes');
const by = (rows) => Object.fromEntries((rows ?? []).map(r => [r.url, r]));
const M = by(mobile), O = by(operator), AN = by(anon);
const routes = JSON.parse(fs.readFileSync(new URL('../_routes_raw.json', here), 'utf8'));

// Itens abertos que NÃO são defeito da página em si (decisão de design / upstream / regra de negócio).
// Página que só tem isso em aberto fica BLOQUEADO com o motivo abaixo.
const BLOCKED = {
  contrast: 'contraste AA dos tokens n-slate-10/11 e n-brand em texto pequeno — decisão de design system (Fase 4)',
  upstreamA11y: 'a11y de componentes herdados do Chatwoot (button-name/label/select-name/role-img-alt) — corrigir no upstream ou na Fase 4',
};
const UPSTREAM_A11Y = /^(button-name|label|select-name|role-img-alt|nested-interactive|listitem|definition-list|aria-required-children|link-name|image-alt)$/;

const SLOW_MS = 3000;
const rows = [];
for (const r of admin) {
  const id = r.url;
  const m = M[id], o = O[id], a = AN[id];
  const problems = [];
  const blocked = [];
  if (r.navError) problems.push(`navegação: ${r.navError.slice(0, 60)}`);
  const http = (r.failed ?? []).filter(f => !/\/widget\?website_token=/.test(f.url));
  if (http.length) problems.push(`HTTP ${http.map(f => f.status + ' ' + f.url.replace('/api/v1/accounts/55', '')).join(', ').slice(0, 120)}`);
  const cons = r.consoleErrors.filter(e => !/Failed to load resource/.test(e));
  if (cons.length) problems.push(`console: ${cons[0].slice(0, 80)}`);
  if ((r.overflowPx ?? 0) > 2) problems.push(`overflow 1440 ${r.overflowPx}px`);
  if ((m?.overflowPx ?? 0) > 2) problems.push(`overflow 360 ${m.overflowPx}px`);
  if (r.loadMs > SLOW_MS && (m?.loadMs ?? 0) > SLOW_MS) problems.push(`lento ${r.loadMs}ms`);
  if (a && !a.redirectedToLogin) problems.push('anônimo não vai para login');
  if (r.notFound) problems.push('texto de 404 na página');
  const axe = r.axe ?? [];
  const axeContrast = axe.filter(v => v.id === 'color-contrast');
  const axeUpstream = axe.filter(v => UPSTREAM_A11Y.test(v.id));
  const axeOther = axe.filter(v => v.id !== 'color-contrast' && !UPSTREAM_A11Y.test(v.id));
  if (axeOther.length) problems.push(`axe: ${axeOther.map(v => v.id).join(',')}`);
  if (axeContrast.length) blocked.push(BLOCKED.contrast);
  if (axeUpstream.length) blocked.push(`${BLOCKED.upstreamA11y}: ${axeUpstream.map(v => `${v.id}(${v.nodes})`).join(',')}`);
  // agente: rota permitida a agent mas API negou → problema (exceto marketing/captain corrigidos: checa de novo)
  if (o && (r.permissions ?? '').includes('agent')) {
    const denied = (o.api4xx ?? []).filter(x => x.status === 401 || x.status === 403);
    if (denied.length && !o.redirectedToLogin) problems.push(`agente: API negou ${denied.map(d => d.url.replace('/api/v1/accounts/55', '').slice(0, 40)).join(',')}`);
  }
  const status = problems.length ? 'FALHOU' : blocked.length ? 'BLOQUEADO' : 'OK';
  rows.push({ url: id, name: r.name, redirect: !!r.redirect, container: !r.name && !r.redirect, status, problems, blocked });
}

// Containers (rota-pai sem nome) e redirects: OK se o destino carregou
for (const row of rows) if ((row.container || row.redirect) && row.status !== 'FALHOU') row.status = 'OK';

// grava no inventário: casa pela rota (…/path) — o B# não está no dump, então casa pelo path
let inv = fs.readFileSync(new URL('../inventario.md', here), 'utf8');
const pathKey = (u) => u.replace('/app/accounts/55', '…').replace(/\/(\d+|qa-portal|qa-cat|qa-label|pt_BR|custom|website|inbox|assistants|dialogflow|conversations)(?=\/|$)/g, (m0) => m0);
const rawByUrl = new Map(routes.filter(x => x.path.startsWith('/app/')).map(x => [x.path, x]));
// reconstrói url→path usando o mesmo fill do sweep: mais simples, casa por name quando existe, senão por path com params
const invLines = inv.split(/\r?\n/);
const counts = { OK: 0, FALHOU: 0, BLOQUEADO: 0 };
const failing = []; const blockedRows = [];
for (const row of rows) {
  const raw = routes.find(x => (row.name && x.name === row.name) || (!row.name && x.path && fillLike(x.path) === row.url));
  if (!raw) continue;
  const pathCell = '`' + raw.path.replace('/app/accounts/:accountId', '…') + '`';
  const nameCell = raw.name || '—';
  const idx = invLines.findIndex(l => l.startsWith('| B') && l.includes(`| ${pathCell} |`) && l.includes(`| ${nameCell} |`) && !/\| (OK|FALHOU|BLOQUEADO) \|\s*$/.test(l) );
  const idx2 = idx >= 0 ? idx : invLines.findIndex(l => l.startsWith('| B') && l.includes(`| ${pathCell} |`) && l.includes(`| ${nameCell} |`));
  if (idx2 < 0) continue;
  invLines[idx2] = invLines[idx2].replace(/\| (PENDENTE|EM ANDAMENTO|FALHOU|OK|BLOQUEADO) \|\s*$/, `| ${row.status} |`);
  counts[row.status]++;
  if (row.status === 'FALHOU') failing.push(row);
  if (row.status === 'BLOQUEADO') blockedRows.push(row);
}
fs.writeFileSync(new URL('../inventario.md', here), invLines.join('\n'));
fs.writeFileSync(new URL('./results/final/status.json', here), JSON.stringify(rows, null, 1));
console.log('B (dashboard):', counts);
console.log('\nFALHOU:'); for (const f of failing) console.log(' -', f.url.replace('/app/accounts/55', '…'), '→', f.problems.join(' | '));
console.log('\nBLOQUEADO (por motivo):');
const reasons = {}; for (const b of blockedRows) for (const r of b.blocked) { const k = r.split(':')[0]; reasons[k] = (reasons[k] || 0) + 1; }
console.log(reasons);

function fillLike(p) {
  // espelha probe/sweep.mjs::fill para casar URLs de containers
  const ids = JSON.parse(fs.readFileSync(new URL('../_ids.json', here), 'utf8'));
  const params = { accountId: ids.accountId, id: ids.id_agent, inbox_id: ids.inbox_id, inboxId: ids.inbox_id, teamId: ids.teamId, sub_page: 'website', flowId: ids.flowId, macroId: ids.macroId, kind: 'custom', categoryId: ids.labelId, tab: 'conversations', conversationId: ids.conversation_id, conversation_id: ids.conversation_id, integration_id: 'dialogflow', dealId: ids.dealId, segmentId: ids.segmentId, label: ids.label, assistantId: ids.assistantId, contactId: ids.contactId, portalSlug: ids.portalSlug, locale: 'pt_BR', categorySlug: ids.categorySlug, articleSlug: ids.articleSlug, type: 'inbox', navigationPath: 'assistants' };
  const over = [[/reports\/inboxes\/:id/, ids.inbox_id], [/reports\/teams\/:id/, ids.teamId], [/reports\/labels\/:id/, ids.labelId], [/custom_view\/:id/, ids.id_custom_view], [/inbox-view\/:type\/:id/, ids.conversation_id], [/assignment-policy\/\w+\/edit\/:id/, 1], [/settings\/(macros|agents|teams)\/.*:id/, 1]];
  let out = p; for (const [re, v] of over) if (re.test(p)) out = out.replace(':id', String(v));
  return out.replace(/:(\w+)\??/g, (_, k) => params[k] ?? `MISSING_${k}`).replace(/\/+$/, '');
}

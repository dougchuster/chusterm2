// CRUD via API dos módulos fora do CRM (contatos, empresas, settings, portais, notificações, perfil).
// Admin da conta 55; registros QA_ removidos no fim. Uso: QA_BASE_URL=... node core-crud.mjs
import { chromium } from '@playwright/test';
import fs from 'node:fs';

const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:3010';
const A = 55;
const ids = JSON.parse(fs.readFileSync(new URL('../_ids.json', import.meta.url), 'utf8'));
const out = [];
const log = (page, check, ok, detail = '') => { out.push({ page, check, ok, detail }); console.log(`${ok ? 'OK  ' : 'FAIL'} [${page}] ${check} ${detail}`); };
const stamp = Date.now();

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '../../qa/e2e/playwright/.auth/admin.json', extraHTTPHeaders: { 'X-Forwarded-For': '203.0.113.241' } });
const session = (await ctx.cookies()).find(c => c.name === 'cw_d_session_info');
const h = JSON.parse(decodeURIComponent(session.value));
const headers = { 'access-token': h['access-token'], client: h.client, uid: h.uid, 'token-type': 'Bearer', 'Content-Type': 'application/json' };
const api = async (method, path, data, v = 'v1') => {
  const r = await ctx.request.fetch(`${base}/api/${v}/accounts/${A}/${path}`, { method, headers, data });
  let body = null; try { body = await r.json(); } catch { body = await r.text().catch(() => null); }
  return { status: r.status(), body };
};
const cleanup = [];
const s = (o, n = 140) => JSON.stringify(o ?? null).slice(0, n);
const is2xx = (r) => r.status >= 200 && r.status < 300;
const is4xx = (r) => r.status >= 400 && r.status < 500;

// ---------- Contatos ----------
{
  const P = 'contacts';
  let r = await api('POST', 'contacts', { name: `QA_Contato ${stamp}`, email: `qa_${stamp}@chusterm.invalid`, phone_number: `+5511${String(stamp).slice(-9)}` });
  const cid = r.body?.payload?.contact?.id;
  log(P, 'criar contato', is2xx(r) && cid, `status=${r.status} id=${cid}`);
  cleanup.push(() => api('DELETE', `contacts/${cid}`));
  r = await api('POST', 'contacts', { name: 'QA_x', email: 'nao-e-email' });
  log(P, 'e-mail inválido → 4xx', is4xx(r), `status=${r.status} ${s(r.body)}`);
  r = await api('POST', 'contacts', { name: 'QA_x', phone_number: '11999' });
  log(P, 'telefone fora do E.164 → 4xx', is4xx(r), `status=${r.status} ${s(r.body)}`);
  r = await api('POST', 'contacts', { name: 'QA_dup', email: `qa_${stamp}@chusterm.invalid` });
  log(P, 'e-mail duplicado → 4xx (não cria segundo contato)', is4xx(r), `status=${r.status} ${s(r.body)}`);
  r = await api('POST', 'contacts', { name: '' });
  log(P, 'contato sem nenhum dado', true, `status=${r.status} (${is2xx(r) ? 'aceita contato vazio' : 'rejeita'}) ${s(r.body, 80)}`);
  r = await api('PUT', `contacts/${cid}`, { name: `QA_Contato ${stamp} editado`, custom_attributes: { qa_flag: true } });
  const g = await api('GET', `contacts/${cid}`);
  log(P + '/:id', 'editar persiste (nome + custom attr)', is2xx(r) && g.body?.payload?.name === `QA_Contato ${stamp} editado` && g.body?.payload?.custom_attributes?.qa_flag === true, `status=${r.status} name=${g.body?.payload?.name}`);
  r = await api('GET', `contacts/search?q=${encodeURIComponent('QA_Contato ' + stamp)}`);
  log(P, 'busca encontra o contato', r.status === 200 && (r.body?.payload ?? []).some(c => c.id === cid), `n=${(r.body?.payload ?? []).length}`);
  r = await api('GET', 'contacts?page=1&sort=-last_activity_at');
  log(P, 'listagem paginada com meta.count', r.status === 200 && r.body?.meta?.count >= 1, `count=${r.body?.meta?.count} n=${(r.body?.payload ?? []).length}`);
  r = await api('GET', 'contacts?page=99999');
  log(P, 'página além do fim → payload vazio sem erro', r.status === 200 && (r.body?.payload ?? []).length === 0, `status=${r.status}`);
  r = await api('POST', 'contacts/filter', { payload: [{ attribute_key: 'name', filter_operator: 'contains', values: ['QA_Contato'], query_operator: null }] });
  log(P, 'filtro avançado responde', r.status === 200, `status=${r.status} n=${(r.body?.payload ?? []).length}`);
  r = await api('POST', 'contacts/filter', { payload: [{ attribute_key: "name'; DROP TABLE contacts;--", filter_operator: 'equal_to', values: ['x'] }] });
  log(P, 'filtro com chave maliciosa → 4xx (não 500)', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('POST', `contacts/${cid}/labels`, { labels: [ids.label] });
  log(P + '/:id', 'aplicar label', is2xx(r), `status=${r.status}`);
  r = await api('GET', `contacts/${cid}/conversations`);
  log(P + '/:id', 'conversas do contato', r.status === 200, `status=${r.status}`);
  r = await api('GET', `contacts/${cid}/contactable_inboxes`);
  log(P + '/:id', 'contactable_inboxes', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'contacts/999999999');
  log(P + '/:id', 'contato inexistente → 404', r.status === 404, `status=${r.status}`);
  r = await api('POST', 'contacts/export', {});
  log(P, 'export aceita', is2xx(r), `status=${r.status}`);
  r = await api('POST', 'contacts/import', {});
  log(P, 'import sem arquivo → 4xx', is4xx(r), `status=${r.status}`);
  const dup = await api('POST', 'contacts', { name: 'QA_Merge', email: `qa_merge_${stamp}@chusterm.invalid` });
  const did = dup.body?.payload?.contact?.id;
  r = await api('POST', 'actions/contact_merge', { base_contact_id: cid, mergee_contact_id: did });
  const gone = await api('GET', `contacts/${did}`);
  log(P, 'merge remove o contato mesclado', is2xx(r) && gone.status === 404, `status=${r.status} mergee=${gone.status}`);
  if (gone.status !== 404) cleanup.push(() => api('DELETE', `contacts/${did}`));
}

// ---------- Segmentos (custom_filters de contato) ----------
{
  const P = 'contacts/segments';
  let r = await api('POST', 'custom_filters', { custom_filter: { name: `QA_Seg ${stamp}`, filter_type: 'contact', query: { payload: [{ attribute_key: 'name', filter_operator: 'contains', values: ['QA'], query_operator: null }] } } });
  const id = r.body?.id;
  log(P, 'criar segmento', is2xx(r) && id, `status=${r.status}`);
  r = await api('POST', 'custom_filters', { custom_filter: { name: '', filter_type: 'contact', query: {} } });
  log(P, 'segmento sem nome → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('PATCH', `custom_filters/${id}`, { custom_filter: { name: `QA_Seg ${stamp} 2` } });
  const g = await api('GET', `custom_filters/${id}`);
  log(P, 'editar persiste', is2xx(r) && g.body?.name === `QA_Seg ${stamp} 2`, `status=${r.status}`);
  r = await api('DELETE', `custom_filters/${id}`);
  log(P, 'excluir', is2xx(r), `status=${r.status}`);
}

// ---------- Empresas ----------
{
  const P = 'companies';
  let r = await api('POST', 'companies', { company: { name: `QA_Empresa ${stamp}`, domain: `qa-${stamp}.invalid` } });
  const id = r.body?.id ?? r.body?.payload?.id;
  log(P, 'criar empresa', is2xx(r) && id, `status=${r.status} ${s(r.body, 100)}`);
  cleanup.push(() => api('DELETE', `companies/${id}`));
  r = await api('POST', 'companies', { company: { name: '' } });
  log(P, 'sem nome → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('POST', 'companies', { company: { name: 'QA_dup', domain: `qa-${stamp}.invalid` } });
  log(P, 'domínio duplicado', true, `status=${r.status} (${is2xx(r) ? 'aceita duplicado' : 'rejeita'})`);
  if (is2xx(r)) cleanup.push(() => api('DELETE', `companies/${r.body?.id}`));
  r = await api('PATCH', `companies/${id}`, { company: { description: 'QA desc' } });
  const g = await api('GET', `companies/${id}`);
  log(P + '/:id', 'editar persiste', is2xx(r) && (g.body?.description === 'QA desc' || g.body?.payload?.description === 'QA desc'), `status=${r.status} ${s(g.body, 100)}`);
  r = await api('GET', `companies?q=QA_Empresa`);
  log(P, 'busca/listagem', r.status === 200, `status=${r.status} ${s(r.body, 80)}`);
  r = await api('GET', 'companies/999999999');
  log(P + '/:id', 'inexistente → 404', r.status === 404, `status=${r.status}`);
}

// ---------- Settings: labels, canned, teams, agents, macros, custom attrs, automation, inboxes, webhooks ----------
{
  let r = await api('POST', 'labels', { title: `qa-label-${stamp}`, color: '#ff0000', show_on_sidebar: true });
  const lid = r.body?.id;
  log('settings/labels', 'criar label', is2xx(r) && lid, `status=${r.status}`);
  cleanup.push(() => api('DELETE', `labels/${lid}`));
  r = await api('POST', 'labels', { title: 'Com Espaço Maiúsculo', color: '#ff0000' });
  log('settings/labels', 'título com espaço/maiúscula → 4xx (regra do Chatwoot)', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('POST', 'labels', { title: `qa-label-${stamp}`, color: '#00ff00' });
  log('settings/labels', 'label duplicada → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('PATCH', `labels/${lid}`, { color: '#0000ff' });
  const gl = await api('GET', `labels/${lid}`);
  log('settings/labels', 'editar persiste', is2xx(r) && gl.body?.color === '#0000ff', `color=${gl.body?.color}`);

  r = await api('POST', 'canned_responses', { short_code: `qa_${stamp}`, content: 'Olá, QA' });
  const crid = r.body?.id;
  log('settings/canned-response', 'criar resposta pronta', is2xx(r) && crid, `status=${r.status}`);
  cleanup.push(() => api('DELETE', `canned_responses/${crid}`));
  r = await api('POST', 'canned_responses', { short_code: '', content: '' });
  log('settings/canned-response', 'vazio → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('GET', `canned_responses?search=qa_${stamp}`);
  log('settings/canned-response', 'busca por atalho', r.status === 200 && (r.body ?? []).some(c => c.id === crid), `n=${(r.body ?? []).length}`);

  r = await api('POST', 'teams', { name: `QA_Time ${stamp}`, description: 'qa', allow_auto_assign: true });
  const tid = r.body?.id;
  log('settings/teams', 'criar time', is2xx(r) && tid, `status=${r.status}`);
  cleanup.push(() => api('DELETE', `teams/${tid}`));
  r = await api('POST', 'teams', { name: '' });
  log('settings/teams', 'time sem nome → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('POST', `teams/${tid}/team_members`, { user_ids: [ids.id_agent] });
  const m = await api('GET', `teams/${tid}/team_members`);
  log('settings/teams/:id/edit/agents', 'adicionar membro persiste', is2xx(r) && (m.body ?? []).some(u => u.id === ids.id_agent), `status=${r.status} n=${(m.body ?? []).length}`);
  r = await api('DELETE', `teams/${tid}/team_members`, { user_ids: [ids.id_agent] });
  log('settings/teams/:id/edit/agents', 'remover membro', is2xx(r), `status=${r.status}`);

  r = await api('POST', 'agents', { name: 'QA_Agente', email: 'nao-e-email', role: 'agent' });
  log('settings/agents', 'convidar agente com e-mail inválido → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('POST', 'agents', { name: 'QA_Agente', email: `qa+f0-operator@chusterm.invalid`, role: 'agent' });
  log('settings/agents', 'convidar e-mail já na conta → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('POST', 'agents', { name: 'QA_Agente', email: `qa_agent_${stamp}@chusterm.invalid`, role: 'superuser' });
  log('settings/agents', 'role inválido → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  if (is2xx(r)) cleanup.push(() => api('DELETE', `agents/${r.body?.id}`));
  r = await api('GET', 'agents');
  log('settings/agents', 'listagem não expõe hash de senha/tokens', r.status === 200 && !/encrypted_password|access_token|pubsub_token/.test(JSON.stringify(r.body)), `keys=${Object.keys(r.body?.[0] ?? {}).join(',').slice(0, 160)}`);

  r = await api('POST', 'macros', { name: `QA_Macro ${stamp}`, visibility: 'global', actions: [{ action_name: 'add_label', action_params: [ids.label] }] });
  const mid = r.body?.payload?.id ?? r.body?.id;
  log('settings/macros/new', 'criar macro', is2xx(r) && mid, `status=${r.status}`);
  cleanup.push(() => api('DELETE', `macros/${mid}`));
  r = await api('POST', 'macros', { name: '', visibility: 'global', actions: [] });
  log('settings/macros/new', 'macro sem nome/ações → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);

  r = await api('POST', 'custom_attribute_definitions', { custom_attribute: { attribute_display_name: `QA Attr ${stamp}`, attribute_key: `qa_attr_${stamp}`, attribute_display_type: 0, attribute_model: 1 } });
  const caid = r.body?.id;
  log('settings/custom-attributes', 'criar atributo', is2xx(r) && caid, `status=${r.status}`);
  cleanup.push(() => api('DELETE', `custom_attribute_definitions/${caid}`));
  r = await api('POST', 'custom_attribute_definitions', { custom_attribute: { attribute_display_name: 'QA dup', attribute_key: `qa_attr_${stamp}`, attribute_display_type: 0, attribute_model: 1 } });
  log('settings/custom-attributes', 'chave duplicada → 4xx', is4xx(r), `status=${r.status}`);

  r = await api('POST', 'automation_rules', { name: `QA_Auto ${stamp}`, event_name: 'conversation_created', conditions: [{ attribute_key: 'status', filter_operator: 'equal_to', values: ['open'], query_operator: null }], actions: [{ action_name: 'add_label', action_params: [ids.label] }] });
  const arid = r.body?.payload?.id ?? r.body?.id;
  log('settings/automation', 'criar automação', is2xx(r) && arid, `status=${r.status} ${s(r.body, 80)}`);
  cleanup.push(() => api('DELETE', `automation_rules/${arid}`));
  r = await api('POST', 'automation_rules', { name: 'QA_bad', event_name: 'nope', conditions: [], actions: [] });
  log('settings/automation', 'evento inválido → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);

  r = await api('POST', 'inboxes', { name: `QA_Inbox ${stamp}`, channel: { type: 'api', webhook_url: 'https://example.invalid/hook' } });
  const iid = r.body?.id;
  log('settings/inboxes/new', 'criar inbox API', is2xx(r) && iid, `status=${r.status} ${s(r.body, 80)}`);
  cleanup.push(() => api('DELETE', `inboxes/${iid}`));
  r = await api('POST', 'inboxes', { name: `QA_Inbox ${stamp}`, channel: { type: 'api', webhook_url: 'http://127.0.0.1:6379/' } });
  log('settings/inboxes/new', 'webhook para IP interno (SSRF) → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  if (is2xx(r)) cleanup.push(() => api('DELETE', `inboxes/${r.body?.id}`));
  r = await api('PATCH', `inboxes/${iid}`, { name: `QA_Inbox ${stamp} 2`, greeting_enabled: true, greeting_message: 'Olá' });
  const gi = await api('GET', `inboxes/${iid}`);
  log('settings/inboxes/:id', 'editar persiste', is2xx(r) && gi.body?.name === `QA_Inbox ${stamp} 2`, `status=${r.status}`);
  r = await api('POST', `inbox_members`, { inbox_id: iid, user_ids: [ids.id_agent] });
  log('settings/inboxes/:id (colaboradores)', 'adicionar agente à inbox', is2xx(r), `status=${r.status}`);
  r = await api('GET', `inboxes/${iid}/agent_bot`);
  log('settings/inboxes/:id (bots)', 'agent_bot da inbox responde', r.status === 200, `status=${r.status}`);

  r = await api('POST', 'webhooks', { webhook: { url: 'http://localhost/hook', subscriptions: ['message_created'] } });
  log('settings/integrations/webhook', 'URL http://localhost rejeitada', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  if (is2xx(r)) cleanup.push(() => api('DELETE', `webhooks/${r.body?.payload?.webhook?.id}`));
  r = await api('POST', 'webhooks', { webhook: { url: 'https://example.invalid/hook', subscriptions: ['message_created'] } });
  const wid = r.body?.payload?.webhook?.id;
  log('settings/integrations/webhook', 'criar webhook https', is2xx(r) && wid, `status=${r.status} ${s(r.body, 80)}`);
  cleanup.push(() => api('DELETE', `webhooks/${wid}`));
  r = await api('POST', 'webhooks', { webhook: { url: 'not-a-url', subscriptions: [] } });
  log('settings/integrations/webhook', 'URL inválida → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('GET', 'integrations/apps');
  log('settings/integrations', 'apps lista sem segredos', r.status === 200 && !/client_secret|api_key":"[^"]{8,}/.test(JSON.stringify(r.body)), `n=${(r.body?.payload ?? []).length}`);
  r = await api('GET', 'audit_logs');
  log('settings/audit-logs', 'audit logs responde', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'sla_policies');
  log('settings/sla', 'sla policies responde', r.status === 200, `status=${r.status}`);
  r = await api('POST', 'sla_policies', { name: '' });
  log('settings/sla', 'sla sem nome → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('GET', 'custom_roles');
  log('settings/custom-roles', 'custom roles responde', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'agent_bots');
  log('settings/agent-bots', 'agent bots responde', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'assignment_policies');
  log('settings/assignment-policy', 'assignment policies responde', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'agent_capacity_policies');
  log('settings/assignment-policy', 'capacity policies responde', r.status === 200, `status=${r.status}`);
}

// ---------- Portais ----------
{
  const P = 'portals';
  let r = await api('POST', 'portals', { portal: { name: `QA_Portal ${stamp}`, slug: `qa-portal-${stamp}`, config: { allowed_locales: ['pt_BR'], default_locale: 'pt_BR' } } });
  const slug = r.body?.slug;
  log(P + '/new', 'criar portal', is2xx(r) && slug, `status=${r.status} ${s(r.body, 80)}`);
  cleanup.push(() => api('DELETE', `portals/${slug}`));
  r = await api('POST', 'portals', { portal: { name: 'QA', slug: `qa-portal-${stamp}` } });
  log(P + '/new', 'slug duplicado → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('POST', `portals/${slug}/categories`, { category: { name: 'QA_Cat', slug: 'qa-cat', locale: 'pt_BR' } });
  const catId = r.body?.id;
  log(P + '/categories', 'criar categoria', is2xx(r) && catId, `status=${r.status} ${s(r.body, 80)}`);
  r = await api('POST', `portals/${slug}/articles`, { article: { title: 'QA_Artigo', content: 'c', category_id: catId, author_id: ids.id_agent, status: 'draft' } });
  const artId = r.body?.id;
  log(P + '/articles/new', 'criar artigo', is2xx(r) && artId, `status=${r.status} ${s(r.body, 80)}`);
  r = await api('POST', `portals/${slug}/articles`, { article: { title: '', content: '' } });
  log(P + '/articles/new', 'artigo sem título → 4xx', is4xx(r), `status=${r.status}`);
  r = await api('PATCH', `portals/${slug}/articles/${artId}`, { article: { title: 'QA_Artigo 2' } });
  const ga = await api('GET', `portals/${slug}/articles/${artId}`);
  log(P + '/articles/edit', 'editar persiste', is2xx(r) && ga.body?.title === 'QA_Artigo 2', `status=${r.status}`);
  r = await api('DELETE', `portals/${slug}/articles/${artId}`);
  log(P + '/articles', 'excluir artigo', is2xx(r), `status=${r.status}`);
  r = await api('DELETE', `portals/${slug}/categories/${catId}`);
  log(P + '/categories', 'excluir categoria', is2xx(r), `status=${r.status}`);
}

// ---------- Campanhas / Notificações / Perfil / Relatórios ----------
{
  let r = await api('GET', 'campaigns');
  log('campaigns', 'lista campanhas', r.status === 200, `status=${r.status}`);
  r = await api('POST', 'campaigns', { title: '', message: '', inbox_id: ids.inbox_id });
  log('campaigns', 'campanha vazia → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 100)}`);
  r = await api('GET', 'notifications');
  log('notifications', 'lista notificações', r.status === 200, `status=${r.status} meta=${s(r.body?.data?.meta, 80)}`);
  r = await api('POST', 'notifications/read_all', {});
  log('notifications', 'marcar todas como lidas', is2xx(r), `status=${r.status}`);
  r = await api('GET', 'notifications/unread_count');
  log('notifications', 'unread_count', r.status === 200, `status=${r.status}`);
  const prof = await ctx.request.fetch(`${base}/api/v1/profile`, { headers });
  const pj = await prof.json();
  log('profile/settings', 'perfil não expõe encrypted_password', prof.status() === 200 && !/encrypted_password/.test(JSON.stringify(pj)), `keys=${Object.keys(pj).slice(0, 12)}`);
  const pw = await ctx.request.fetch(`${base}/api/v1/profile`, { method: 'PUT', headers, data: { profile: { password: '123', password_confirmation: '123', current_password: 'x' } } });
  log('profile/settings', 'senha fraca/curta → 4xx', pw.status() >= 400 && pw.status() < 500, `status=${pw.status()} ${(await pw.text()).slice(0, 100)}`);
  const pn = await ctx.request.fetch(`${base}/api/v1/profile`, { method: 'PUT', headers, data: { profile: { name: '' } } });
  log('profile/settings', 'nome vazio → 4xx', pn.status() >= 400 && pn.status() < 500, `status=${pn.status()}`);
  const since = Math.floor(Date.now() / 1000) - 30 * 86400, until = Math.floor(Date.now() / 1000);
  for (const rep of [`reports/summary?since=${since}&until=${until}&type=account`, `reports?metric=conversations_count&since=${since}&until=${until}&type=account`, `reports/conversations?type=account`, `reports/agents?since=${since}&until=${until}`, `reports/inboxes?since=${since}&until=${until}`, `reports/labels?since=${since}&until=${until}`, `reports/teams?since=${since}&until=${until}`, `reports/bot_summary?since=${since}&until=${until}`, `reports/bot_metrics?since=${since}&until=${until}`]) {
    r = await api('GET', rep, undefined, 'v2');
    log('reports/*', `v2/${rep.split('?')[0]}`, r.status === 200, `status=${r.status}`);
  }
  r = await api('GET', `reports/summary?since=abc&until=xyz&type=account`, undefined, 'v2');
  log('reports/*', 'datas inválidas não dão 500', r.status !== 500, `status=${r.status}`);
  r = await api('GET', `csat_survey_responses/metrics?since=${since}&until=${until}`);
  log('reports/csat', 'csat metrics', r.status === 200, `status=${r.status}`);
  r = await api('GET', `applied_slas/metrics?since=${since}&until=${until}`);
  log('reports/sla', 'sla metrics', r.status === 200, `status=${r.status}`);
  r = await api('GET', `search?q=QA`);
  log('search', 'busca global', r.status === 200, `status=${r.status} keys=${Object.keys(r.body?.payload ?? {}).join(',')}`);
  r = await api('GET', `search?q=${encodeURIComponent("' OR 1=1 --")}`);
  log('search', 'busca com SQL não dá 500', r.status !== 500, `status=${r.status}`);
  r = await api('GET', `conversations?status=open&page=1`);
  log('conversations', 'lista conversas', r.status === 200, `status=${r.status} n=${(r.body?.data?.payload ?? []).length}`);
  r = await api('GET', `conversations/${ids.conversation_id}/messages`);
  log('conversations/:id', 'mensagens da conversa', r.status === 200, `status=${r.status}`);
  r = await api('POST', `conversations/${ids.conversation_id}/messages`, { content: '', private: true });
  log('conversations/:id', 'mensagem vazia → 4xx', is4xx(r), `status=${r.status} ${s(r.body, 80)}`);
  r = await api('POST', `conversations/${ids.conversation_id}/messages`, { content: 'QA_nota privada do check-up', private: true });
  log('conversations/:id', 'nota privada criada', is2xx(r), `status=${r.status}`);
  r = await api('GET', `conversations/999999999`);
  log('conversations/:id', 'conversa inexistente → 404', r.status === 404, `status=${r.status}`);
}

for (const fn of cleanup.reverse()) { try { await fn(); } catch { /* ignore */ } }
await browser.close();
fs.writeFileSync(new URL('./results/core-crud.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(`\n${out.filter(x => x.ok).length}/${out.length} OK`);

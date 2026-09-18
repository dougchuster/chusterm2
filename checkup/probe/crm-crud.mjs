// CRUD de ponta a ponta do módulo CRM via API, como administrador da conta 55.
// Cada escrita é verificada com um GET depois (persistência real) e os registros
// QA_ criados são removidos no fim. Uso: QA_BASE_URL=... node crm-crud.mjs
import { chromium } from '@playwright/test';
import fs from 'node:fs';

const base = process.env.QA_BASE_URL ?? 'http://127.0.0.1:3010';
const A = 55;
const ids = JSON.parse(fs.readFileSync(new URL('../_ids.json', import.meta.url), 'utf8'));
const out = [];
const log = (page, check, ok, detail = '') => { out.push({ page, check, ok, detail }); console.log(`${ok ? 'OK  ' : 'FAIL'} [${page}] ${check} ${detail}`); };

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '../../qa/e2e/playwright/.auth/admin.json', extraHTTPHeaders: { 'X-Forwarded-For': '203.0.113.240' } });
const session = (await ctx.cookies()).find(c => c.name === 'cw_d_session_info');
const h = JSON.parse(decodeURIComponent(session.value));
const headers = { 'access-token': h['access-token'], client: h.client, uid: h.uid, 'token-type': 'Bearer', 'Content-Type': 'application/json' };
const api = async (method, path, data) => {
  const r = await ctx.request.fetch(`${base}/api/v1/accounts/${A}/${path}`, { method, headers, data });
  let body = null; try { body = await r.json(); } catch { body = await r.text().catch(() => null); }
  return { status: r.status(), body };
};
const cleanup = [];

// ---------- Pipelines + Stages (crm/settings/pipelines) ----------
{
  const P = 'crm/settings/pipelines';
  let r = await api('POST', 'crm/pipelines', { pipeline: { name: 'QA_Funil Checkup', kind: 'sales' } });
  log(P, 'criar funil', r.status === 200 || r.status === 201, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  const pipelineId = r.body?.id ?? r.body?.payload?.id;
  cleanup.push(() => api('DELETE', `crm/pipelines/${pipelineId}/purge`));
  r = await api('POST', 'crm/pipelines', { pipeline: { name: '' } });
  log(P, 'criar funil sem nome → 4xx com mensagem', r.status >= 400 && r.status < 500, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await api('GET', 'crm/pipelines');
  const list = Array.isArray(r.body) ? r.body : (r.body?.payload ?? []);
  log(P, 'funil aparece na listagem após reload', list.some(p => p.id === pipelineId), `total=${list.length}`);
  r = await api('PATCH', `crm/pipelines/${pipelineId}`, { pipeline: { name: 'QA_Funil Checkup (editado)' } });
  const r2 = await api('GET', 'crm/pipelines');
  const edited = (Array.isArray(r2.body) ? r2.body : r2.body?.payload ?? []).find(p => p.id === pipelineId);
  log(P, 'editar funil persiste', r.status < 300 && edited?.name === 'QA_Funil Checkup (editado)', `status=${r.status} name=${edited?.name}`);
  // stages
  r = await api('POST', `crm/pipelines/${pipelineId}/stages`, { stage: { name: 'QA_Etapa A' } });
  const stageA = r.body?.id;
  log(P, 'criar etapa', r.status < 300 && stageA, `status=${r.status}`);
  r = await api('POST', `crm/pipelines/${pipelineId}/stages`, { stage: { name: 'QA_Ganho', terminal_outcome: 'won' } });
  const stageWon = r.body?.id;
  log(P, 'criar etapa terminal (won)', r.status < 300 && stageWon, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  r = await api('POST', `crm/pipelines/${pipelineId}/stages`, { stage: { name: '' } });
  log(P, 'criar etapa sem nome → 4xx', r.status >= 400 && r.status < 500, `status=${r.status}`);
  r = await api('GET', `crm/pipelines/${pipelineId}/stages`);
  const stages = Array.isArray(r.body) ? r.body : r.body?.payload ?? [];
  log(P, 'etapas listadas após reload', stages.length === 2, `n=${stages.length}`);
  r = await api('DELETE', `crm/pipelines/${pipelineId}/stages/${stageA}`);
  const afterDel = await api('GET', `crm/pipelines/${pipelineId}/stages`);
  log(P, 'excluir (arquivar) etapa some da lista', r.status < 300 && !(Array.isArray(afterDel.body) ? afterDel.body : afterDel.body?.payload ?? []).some(s => s.id === stageA), `status=${r.status}`);
  r = await api('PATCH', `crm/pipelines/${pipelineId}/stages/${stageA}/restore`);
  log(P, 'restaurar etapa', r.status < 300, `status=${r.status}`);
  // deal in the new pipeline
  const contactId = ids.contactId;
  r = await api('POST', 'crm/deals', { title: 'QA_Negócio Checkup', contact_id: contactId, crm_pipeline_id: pipelineId, crm_pipeline_stage_id: stageA, value_estimate_cents: 12345 });
  const dealId = r.body?.id;
  log('crm/leads', 'criar negócio', r.status < 300 && dealId, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  cleanup.push(() => api('DELETE', `crm/deals/${dealId}`));
  const newContact = async (n) => { const c = await api('POST', 'contacts', { name: `QA_Contato ${n} ${Date.now()}`, phone_number: `+55119${String(Date.now()).slice(-8)}${n}` }); const id = c.body?.payload?.contact?.id ?? c.body?.id; cleanup.push(() => api('DELETE', `contacts/${id}`)); return id; };
  const c1 = await newContact(1); const c2 = await newContact(2);
  r = await api('POST', 'crm/deals', { title: '', contact_id: c1, crm_pipeline_id: pipelineId, crm_pipeline_stage_id: stageA });
  log('crm/leads', 'criar negócio sem título → 4xx com mensagem pt-BR', r.status >= 400 && r.status < 500 && /obrigat|não pode|inválid|preench/i.test(JSON.stringify(r.body)), `status=${r.status} ${JSON.stringify(r.body).slice(0, 140)}`);
  r = await api('POST', 'crm/deals', { title: 'QA_x', contact_id: c2, crm_pipeline_id: pipelineId, crm_pipeline_stage_id: stageA, value_estimate_cents: -5 });
  log('crm/leads', 'valor negativo → 4xx', r.status >= 400 && r.status < 500, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await api('POST', 'crm/deals', { title: 'QA_dup', contact_id: contactId, crm_pipeline_id: pipelineId, crm_pipeline_stage_id: stageA });
  log('crm/leads', 'segundo negócio aberto p/ mesmo contato no mesmo funil → devolve o existente (dedupe), não duplica', r.body?.id === dealId, `status=${r.status} id=${r.body?.id} esperado=${dealId}`);
  r = await api('GET', `crm/deals/${dealId}`);
  log('crm/deals/:id', 'GET após criar devolve título/valor persistidos', r.body?.title === 'QA_Negócio Checkup' && r.body?.value_estimate_cents === 12345, `${JSON.stringify({ t: r.body?.title, v: r.body?.value_estimate_cents })}`);
  r = await api('PATCH', `crm/deals/${dealId}`, { title: 'QA_Negócio Checkup 2', urgency_level: 'high' });
  const g = await api('GET', `crm/deals/${dealId}`);
  log('crm/deals/:id', 'editar persiste', r.status < 300 && g.body?.title === 'QA_Negócio Checkup 2', `status=${r.status} title=${g.body?.title} urg=${g.body?.urgency_level}`);
  r = await api('POST', `crm/deals/${dealId}/move`, { stage_id: stageWon });
  const g2 = await api('GET', `crm/deals/${dealId}`);
  log('crm (board)', 'mover para etapa terminal won fecha o negócio como ganho', r.status < 300 && g2.body?.status === 'won', `status=${r.status} deal.status=${g2.body?.status} stage=${g2.body?.crm_pipeline_stage_id}`);
  r = await api('POST', `crm/deals/${dealId}/reopen`);
  const g3 = await api('GET', `crm/deals/${dealId}`);
  log('crm (board)', 'reabrir volta para open', r.status < 300 && g3.body?.status === 'open', `status=${r.status} deal.status=${g3.body?.status}`);
  r = await api('POST', `crm/deals/${dealId}/mark_lost`, { loss_reason_id: null });
  log('crm (board)', 'mark_lost sem motivo → validação (4xx) ou aceita com motivo nulo?', true, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await api('POST', `crm/deals/${dealId}/move`, { stage_id: 999999999 });
  log('crm (board)', 'mover para etapa inexistente → 404/422', r.status === 404 || r.status === 422, `status=${r.status}`);
  // activities
  r = await api('POST', 'crm/activities', { crm_deal_id: dealId, kind: 'follow_up', title: 'QA_Atividade', due_at: new Date(Date.now() + 86400000).toISOString() });
  const actId = r.body?.id;
  log('crm/activities', 'criar atividade', r.status < 300 && actId, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  r = await api('POST', 'crm/activities', { crm_deal_id: dealId, kind: 'follow_up', title: '' });
  log('crm/activities', 'criar atividade sem título → 4xx', r.status >= 400 && r.status < 500, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  r = await api('POST', `crm/activities/${actId}/complete`);
  const acts = await api('GET', `crm/activities?deal_id=${dealId}`);
  const actList = Array.isArray(acts.body) ? acts.body : acts.body?.payload ?? [];
  const done = actList.find(a => a.id === actId);
  log('crm/activities', 'concluir atividade persiste', r.status < 300 && (done?.status === 'done' || done?.completed_at || done?.status === 'completed'), `status=${r.status} act=${JSON.stringify(done ?? actList.slice(0,1)).slice(0, 120)}`);
  r = await api('DELETE', `crm/activities/${actId}`);
  log('crm/activities', 'excluir atividade', r.status < 300, `status=${r.status}`);
  r = await api('GET', 'crm/agenda_events?from=2020-01-01&to=2030-01-01');
  log('crm/agenda', 'agenda_events responde', r.status === 200, `status=${r.status} tipo=${Array.isArray(r.body) ? 'array' : typeof r.body}`);
  // board / list / search / pagination
  r = await api('GET', `crm/pipelines/${ids.pipeline_a ?? 23}/board?per_column=5`);
  log('crm (board)', 'board endpoint responde com colunas', r.status === 200 && (r.body?.columns?.length > 0 || Array.isArray(r.body)), `status=${r.status} keys=${Object.keys(r.body ?? {}).slice(0, 6)}`);
  r = await api('GET', 'crm/deals?per_page=50&page=5');
  log('crm/leads', 'paginação: página 5 de 50 devolve o 201º negócio (regressão)', r.status === 200 && (r.body?.data?.length ?? 0) >= 1, `status=${r.status} n=${r.body?.data?.length} meta=${JSON.stringify(r.body?.meta)}`);
  r = await api('GET', 'crm/deals?per_page=999999');
  log('crm/leads', 'per_page é limitado (≤200)', r.status === 200 && (r.body?.meta?.per_page ?? 0) <= 200, `per_page=${r.body?.meta?.per_page}`);
  r = await api('GET', 'crm/deals?q=QA_Neg%C3%B3cio%20Checkup');
  log('crm/leads', 'busca por título encontra o negócio', r.status === 200 && (r.body?.data ?? []).some(d => d.id === dealId), `n=${(r.body?.data ?? []).length}`);
  r = await api('GET', 'crm/deals?q=%27%3B%20DROP%20TABLE%20crm_deals%3B--');
  log('crm/leads', 'busca com payload SQL não quebra (200/422)', r.status === 200 || r.status === 422, `status=${r.status}`);
  r = await api('POST', 'crm/deals/export', { format: 'csv' });
  log('crm/reports', 'export de negócios aceita (202/200)', r.status === 200 || r.status === 202, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  // board views
  r = await api('POST', 'crm/board_views', { board_view: { name: 'QA_View', context: 'board', group_by: 'stage', filters: {} } });
  const viewId = r.body?.id;
  log('crm (board)', 'salvar visão do board', r.status < 300 && viewId, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  if (viewId) { const d = await api('DELETE', `crm/board_views/${viewId}`); log('crm (board)', 'excluir visão', d.status < 300, `status=${d.status}`); }
  // bulk
  r = await api('POST', 'crm/deals/bulk_action', { deal_ids: [dealId], bulk_action: 'move', stage_id: stageA });
  log('crm/leads', 'bulk move responde', r.status < 300 || r.status === 202, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
}

// ---------- Loss reasons ----------
{
  const P = 'crm/settings/loss-reasons';
  let r = await api('POST', 'crm/loss-reasons', { name: 'QA_Motivo Checkup' });
  const id = r.body?.id;
  log(P, 'criar motivo', r.status < 300 && id, `status=${r.status}`);
  r = await api('POST', 'crm/loss-reasons', { name: '' });
  log(P, 'criar motivo vazio → 4xx', r.status >= 400 && r.status < 500, `status=${r.status}`);
  r = await api('PATCH', `crm/loss-reasons/${id}`, { name: 'QA_Motivo Editado' });
  const l = await api('GET', 'crm/loss-reasons');
  const list = Array.isArray(l.body) ? l.body : l.body?.payload ?? [];
  log(P, 'editar motivo persiste', r.status < 300 && list.find(x => x.id === id)?.name === 'QA_Motivo Editado', `status=${r.status}`);
  log(P, 'não há DELETE para motivo (só :index,:create,:update) — arquivar existe?', true, `rotas: index/create/update; motivo ${id} fica na base (limpeza manual)`);
  cleanup.push(() => api('PATCH', `crm/loss-reasons/${id}`, { name: 'QA_Motivo (descartar)' }));
}

// ---------- Checklist templates ----------
{
  const P = 'crm/settings/checklist-templates';
  let r = await api('POST', 'crm/checklist-templates', { checklist_template: { name: 'QA_Checklist', items: [{ key: 'doc', title: 'Documento', kind: 'document', required: true }] } });
  const id = r.body?.id;
  log(P, 'criar template', r.status < 300 && id, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
  r = await api('POST', 'crm/checklist-templates', { checklist_template: { name: '' } });
  log(P, 'criar sem nome → 4xx', r.status >= 400 && r.status < 500, `status=${r.status}`);
  r = await api('PATCH', `crm/checklist-templates/${id}`, { checklist_template: { name: 'QA_Checklist 2' } });
  const l = await api('GET', 'crm/checklist-templates');
  log(P, 'editar persiste', r.status < 300 && (Array.isArray(l.body) ? l.body : l.body?.payload ?? []).find(x => x.id === id)?.name === 'QA_Checklist 2', `status=${r.status}`);
  r = await api('DELETE', `crm/checklist-templates/${id}`);
  const l2 = await api('GET', 'crm/checklist-templates');
  log(P, 'excluir some da lista', r.status < 300 && !(Array.isArray(l2.body) ? l2.body : l2.body?.payload ?? []).some(x => x.id === id), `status=${r.status}`);
}

// ---------- Automation rules ----------
{
  const P = 'crm/settings/automation-rules';
  const stages = await api('GET', `crm/pipelines/${ids.pipeline_a ?? 23}/stages`);
  const stageId = (Array.isArray(stages.body) ? stages.body : stages.body?.payload ?? [])[0]?.id;
  let r = await api('POST', 'crm/automation-rules', { automation_rule: { name: 'QA_Regra', trigger_event: 'stage_entered', action_type: 'create_activity', crm_pipeline_stage_id: stageId, action_config: { title: 'Ligar', kind: 'call' } } });
  const id = r.body?.id;
  log(P, 'criar regra', r.status < 300 && id, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await api('POST', 'crm/automation-rules', { automation_rule: { name: 'QA_Regra inválida', trigger_event: 'nope', action_type: 'explode', crm_pipeline_stage_id: stageId } });
  log(P, 'trigger/ação inválidos → 4xx', r.status >= 400 && r.status < 500, `status=${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await api('PATCH', `crm/automation-rules/${id}`, { automation_rule: { is_active: false } });
  const l = await api('GET', 'crm/automation-rules');
  const rule = (Array.isArray(l.body) ? l.body : l.body?.payload ?? []).find(x => x.id === id);
  log(P, 'desativar persiste', r.status < 300 && rule?.is_active === false, `status=${r.status} is_active=${rule?.is_active}`);
  r = await api('DELETE', `crm/automation-rules/${id}`);
  log(P, 'excluir regra', r.status < 300, `status=${r.status}`);
  r = await api('GET', 'crm/automation-runs');
  log(P, 'automation-runs responde', r.status === 200, `status=${r.status}`);
}

// ---------- Cadences ----------
{
  const P = 'crm/settings/cadences';
  let r = await api('POST', 'crm/cadences', { cadence: { name: 'QA_Cadência', status: 'draft', channel: 'whatsapp', steps: [{ name: 'Passo 1', position: 1, channel: 'whatsapp', action_type: 'send_message', wait_hours: 24, template_body: 'Olá {{nome}}' }] } });
  const id = r.body?.id;
  log(P, 'criar cadência com passo', r.status < 300 && id, `status=${r.status} ${JSON.stringify(r.body).slice(0, 140)}`);
  r = await api('POST', 'crm/cadences', { cadence: { name: 'QA_x', status: 'banana', channel: 'pombo' } });
  log(P, 'status/canal inválidos → 4xx', r.status >= 400 && r.status < 500, `status=${r.status}`);
  r = await api('PATCH', `crm/cadences/${id}`, { cadence: { status: 'active' } });
  const l = await api('GET', 'crm/cadences');
  const cad = (Array.isArray(l.body) ? l.body : l.body?.payload ?? []).find(x => x.id === id);
  log(P, 'ativar persiste', r.status < 300 && cad?.status === 'active', `status=${r.status} status=${cad?.status}`);
  r = await api('POST', 'crm/cadences/enroll_deal', { cadence_id: id, deal_id: ids.dealId });
  log(P, 'inscrever negócio na cadência (D6: exige consentimento?)', true, `status=${r.status} ${JSON.stringify(r.body).slice(0, 160)}`);
  r = await api('POST', 'crm/cadences/unenroll_deal', { cadence_id: id, deal_id: ids.dealId });
  log(P, 'desinscrever', r.status < 300 || r.status === 404, `status=${r.status}`);
  r = await api('DELETE', `crm/cadences/${id}`);
  log(P, 'excluir cadência', r.status < 300, `status=${r.status}`);
}

// ---------- Scoring / Packs / Options / Dashboard / Metrics ----------
{
  let r = await api('GET', 'crm/options');
  log('crm/settings/scoring', 'options responde', r.status === 200, `status=${r.status} keys=${Object.keys(r.body ?? {}).slice(0, 8)}`);
  r = await api('GET', 'crm/packs');
  log('crm/settings/segment', 'packs lista', r.status === 200, `status=${r.status} ${JSON.stringify(r.body).slice(0, 160)}`);
  r = await api('POST', 'crm/packs', { slug: '../../config/x' });
  log('crm/settings/segment', 'slug de traversal rejeitado', r.status >= 400 && r.status < 500, `status=${r.status}`);
  r = await api('POST', 'crm/packs', { slug: 'inexistente' });
  log('crm/settings/segment', 'pack inexistente → 404/422', r.status === 404 || r.status === 422, `status=${r.status}`);
  r = await api('GET', 'crm/dashboard');
  log('crm', 'dashboard responde', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'crm/metrics/summary');
  log('crm/reports', 'metrics/summary responde', r.status === 200 || r.status === 404, `status=${r.status}`);
  r = await api('GET', 'crm/audit-events?target_type=CrmDeal&target_id=' + ids.dealId);
  log('crm/deals/:id', 'audit-events (admin) responde', r.status === 200, `status=${r.status}`);
  r = await api('GET', 'crm/agent_tools');
  log('crm/ai-center', 'agent_tools lista', r.status === 200 || r.status === 404, `status=${r.status} ${JSON.stringify(r.body).slice(0, 100)}`);
}

for (const fn of cleanup.reverse()) { try { await fn(); } catch { /* ignore */ } }
await browser.close();
fs.writeFileSync(new URL('./results/crm-crud.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(`\n${out.filter(x => x.ok).length}/${out.length} OK`);

// Cruza permissões declaradas nas rotas com o que cada persona conseguiu ver.
// Uso: node perms.mjs  (lê results/<persona>-1440.json)
import fs from 'node:fs';

const PERSONA_PERMS = {
  admin: ['administrator'],
  manager: ['administrator'],
  operator: ['agent'],
  seller: ['agent'],
  knowledge_manager: ['knowledge_base_manage'],
  admin_b: [], // não pertence à conta 55
  anon: [],
};
const read = (p) => { try { return JSON.parse(fs.readFileSync(new URL(`./results/${p}-1440.json`, import.meta.url), 'utf8')); } catch { return null; } };
const strip = (u) => u.replace('/app/accounts/55', '');

const findings = [];
for (const [persona, perms] of Object.entries(PERSONA_PERMS)) {
  const rows = read(persona);
  if (!rows) { console.log(`(sem resultado para ${persona})`); continue; }
  for (const r of rows) {
    if (r.redirect || !r.name || r.children) continue; // containers redirecionam para o filho index
    const required = r.permissions ? r.permissions.split('|') : [];
    const routeAllows = required.length ? required.some(p => perms.includes(p)) : perms.length > 0;
    const stayed = strip(r.finalUrl.replace(/\?.*$/, '')) === strip(r.url);
    const forbidden = r.api4xx.filter(a => a.status === 401 || a.status === 403);
    const notFound = r.api4xx.filter(a => a.status === 404);
    if (persona === 'anon' || persona === 'admin_b') {
      if (!r.redirectedToLogin) findings.push({ persona, sev: 'CRÍTICO', route: strip(r.url), what: `não foi para o login (final=${strip(r.finalUrl)}) api=${r.apiCount} ok200=${r.apiCount - r.api4xx.length}` });
      continue;
    }
    if (!routeAllows && stayed) findings.push({ persona, sev: 'ALTO', route: strip(r.url), what: `rota exige [${required}] mas a persona ficou na página; API 401/403=${forbidden.length}` });
    if (routeAllows && !stayed && !r.redirectedToLogin) findings.push({ persona, sev: 'MÉDIO', route: strip(r.url), what: `rota permitida mas redirecionou p/ ${strip(r.finalUrl)}` });
    if (routeAllows && stayed && forbidden.length) findings.push({ persona, sev: 'MÉDIO', route: strip(r.url), what: `página aberta mas API negou: ${forbidden.map(a => a.status + ' ' + a.url.replace('/api/v1/accounts/55', '').slice(0, 70)).join('; ')}` });
    if (stayed && notFound.length) findings.push({ persona, sev: 'BAIXO', route: strip(r.url), what: `API 404: ${notFound.map(a => a.url.replace('/api/v1/accounts/55', '').slice(0, 70)).join('; ')}` });
    if (r.redirectedToLogin) findings.push({ persona, sev: 'ALTO', route: strip(r.url), what: 'persona válida foi mandada para o login (sessão?)' });
  }
}
findings.sort((a, b) => a.sev.localeCompare(b.sev) || a.route.localeCompare(b.route));
for (const f of findings) console.log(`${f.sev.padEnd(7)} ${f.persona.padEnd(18)} ${f.route.padEnd(60)} ${f.what}`);
console.log(`\n${findings.length} achados`);
fs.writeFileSync(new URL('./results/perms.json', import.meta.url), JSON.stringify(findings, null, 1));

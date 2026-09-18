const fs = require('fs');
const rows = require('./_routes_raw.json');
const root = 'C:/Users/dougc/Documents/Projetos/ChusteRM/core/';
const rel = p => p.replace(root, '');
const mod = p => {
  const s = p.replace('/app/accounts/:accountId', '');
  if (s.startsWith('/settings/')) return 'settings/' + s.split('/')[2];
  if (s.startsWith('/captain/')) return 'captain';
  return s.split('/')[1] || 'root';
};
const type = r => {
  if (r.redirect) return 'redirect';
  if (!r.component && r.children) return 'layout';
  const n = (r.name + ' ' + r.path).toLowerCase();
  if (/edit|new|create|finish|add|\/setup|onboarding|wizard/.test(n)) return 'form';
  const tail = r.path.replace('/app/accounts/:accountId', '');
  if (/:\w+/.test(tail)) return 'detalhe';
  if (/dashboard|report|analytics|metrics|overview|billing|ai-center|ai_center|agenda|^\/crm$/.test(tail.toLowerCase())) return 'dashboard';
  return 'lista';
};
const perm = r => r.permissions ? r.permissions.replace(/\|/g, ', ') : '(autenticado, herdado)';
const sorted = rows.slice().sort((a, b) => (mod(a.path) + a.path).localeCompare(mod(b.path) + b.path));
let out = [];
let i = 0;
let lastMod = null;
for (const r of sorted) {
  const m = mod(r.path);
  if (m !== lastMod) { out.push(`\n### ${m}\n`); out.push('| # | Rota | Nome | Arquivo | Perfil de acesso | Flag | Tipo | Status |'); out.push('|---|---|---|---|---|---|---|---|'); lastMod = m; }
  i++;
  const file = r.redirect ? `→ redirect (${r.redirect})` : (r.component ? `\`${rel(r.component)}\`` : '(container)');
  out.push(`| ${i} | \`${r.path.replace('/app/accounts/:accountId', '…')}\` | ${r.name || '—'} | ${file} | ${perm(r)} | ${r.featureFlag || '—'} | ${type(r)} | PENDENTE |`);
}
fs.writeFileSync('_inventory_dashboard.md', out.join('\n'));
console.log(i, 'linhas;', 'tipos:', JSON.stringify(sorted.reduce((a, r) => { a[type(r)] = (a[type(r)] || 0) + 1; return a; }, {})));
console.log('módulos:', [...new Set(sorted.map(r => mod(r.path)))].join(', '));

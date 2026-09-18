// Consolida a evidência automatizada por rota (todas as passadas) em results/sheet.json
// e imprime as rotas com algum sinal ruim.
import fs from 'node:fs';

const load = (n) => { try { return JSON.parse(fs.readFileSync(new URL(`./results/${n}.json`, import.meta.url), 'utf8')); } catch { return []; } };
const passes = {
  a1440: load('admin-1440'), a360: load('admin-360'), a768: load('admin-768'),
  operator: load('operator-1440'), seller: load('seller-1440'), manager: load('manager-1440'),
  km: load('knowledge_manager-1440'), b: load('admin_b-1440'), anon: load('anon-1440'),
};
const staticRows = load('static');
const byUrl = (rows) => Object.fromEntries(rows.map(r => [r.url, r]));
const idx = Object.fromEntries(Object.entries(passes).map(([k, v]) => [k, byUrl(v)]));
const strip = (u) => u.replace('/app/accounts/55', '…');

const sheet = passes.a1440.map(r => {
  const g = (p) => idx[p][r.url];
  const st = staticRows.find(s => s.name === r.name && r.name);
  const httpErrs = (x) => (x?.failed ?? []).filter(f => f.status !== 'FAILED' || true);
  return {
    name: r.name, url: strip(r.url), permissions: r.permissions, flag: r.featureFlag, redirect: !!r.redirect,
    final: strip(r.finalUrl),
    failed1440: httpErrs(r).map(f => `${f.status} ${f.url.replace('/api/v1/accounts/55', '')}`),
    console: r.consoleErrors.filter(e => !/Failed to load resource/.test(e)),
    load: { w1440: r.loadMs, w768: g('a768')?.loadMs, w360: g('a360')?.loadMs },
    overflow: { w1440: r.overflowPx, w768: g('a768')?.overflowPx, w360: g('a360')?.overflowPx },
    loops: r.loops, axe: r.axe ?? [],
    personas: Object.fromEntries(['operator', 'seller', 'manager', 'km'].map(p => {
      const x = g(p); if (!x) return [p, null];
      return [p, { stayed: strip(x.finalUrl.replace(/\?.*$/, '')) === strip(r.url), denied: x.api4xx.filter(a => a.status === 401 || a.status === 403).length, console: x.consoleErrors.filter(e => !/Failed to load resource/.test(e)).length }];
    })),
    anonToLogin: g('anon')?.redirectedToLogin ?? null,
    otherTenant: g('b') ? strip(g('b').finalUrl) : null,
    static: st ? { loading: st.loading, empty: st.empty, errorHandling: st.errorHandling, confirmDelete: st.confirmDelete, hasDelete: st.hasDelete, validation: st.validation, consoleLog: st.consoleLog, juridico: st.hardcodedJuridico, rawText: st.rawText, lines: st.lines } : null,
  };
});
fs.writeFileSync(new URL('./results/sheet.json', import.meta.url), JSON.stringify(sheet, null, 1));

const bad = sheet.filter(s => s.failed1440.length || s.console.length || s.axe.length || Object.values(s.overflow).some(v => (v ?? 0) > 2) || Object.values(s.load).some(v => v > 3000) || s.anonToLogin === false);
console.log(`${sheet.length} rotas; ${bad.length} com algum sinal:`);
for (const s of bad) {
  const bits = [];
  if (s.failed1440.length) bits.push('HTTP:' + s.failed1440.join(','));
  if (s.console.length) bits.push('CONSOLE:' + s.console.length);
  if (s.axe.length) bits.push('AXE:' + s.axe.map(a => `${a.id}(${a.nodes})`).join(','));
  const slow = Object.entries(s.load).filter(([, v]) => v > 3000).map(([k, v]) => `${k}=${v}`); if (slow.length) bits.push('SLOW:' + slow.join(','));
  const ov = Object.entries(s.overflow).filter(([, v]) => (v ?? 0) > 2).map(([k, v]) => `${k}=${v}px`); if (ov.length) bits.push('OVERFLOW:' + ov.join(','));
  if (s.anonToLogin === false) bits.push('ANON-NÃO-LOGIN');
  console.log(`- ${s.url}  ${bits.join('  ')}`);
}

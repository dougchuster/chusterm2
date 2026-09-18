// Análise estática por página: sinais de loading/empty/error/confirm/validação/i18n/console.log.
// Uso: node static.mjs > ../probe/results/static.json
import fs from 'node:fs';
import path from 'node:path';

const root = 'C:/Users/dougc/Documents/Projetos/ChusteRM/core/';
const routes = JSON.parse(fs.readFileSync(new URL('../_routes_raw.json', import.meta.url), 'utf8'));
const seen = new Map();

const read = (f) => { try { return fs.readFileSync(f, 'utf8'); } catch { return null; } };

// resolve imports relativos e aliases 'dashboard/...' / 'components-next/...' / 'shared/...'
const resolveImport = (from, spec) => {
  let p;
  if (spec.startsWith('.')) p = path.resolve(path.dirname(from), spec);
  else if (/^(dashboard|shared|widget|v3|survey|components-next|components|helpers|store|api)\//.test(spec)) p = path.join(root, 'app/javascript', spec.startsWith('components-next') ? 'dashboard/' + spec : spec);
  else return null;
  for (const c of [p, p + '.vue', p + '.js', p + '/index.js', p + '/index.vue']) if (fs.existsSync(c) && fs.statSync(c).isFile()) return c;
  return null;
};

// coleta fonte da página + componentes locais (1 nível, só dentro da mesma pasta de rota/components) para não diluir sinais
const collect = (file, depth = 0, acc = new Set()) => {
  if (!file || acc.has(file) || depth > 2) return acc;
  acc.add(file);
  const src = read(file); if (!src) return acc;
  for (const m of src.matchAll(/import\s+[^'"]*?from\s+['"]([^'"]+)['"]|import\(['"]([^'"]+)['"]\)/g)) {
    const spec = m[1] || m[2];
    const r = resolveImport(file, spec);
    if (!r) continue;
    // só segue componentes do mesmo domínio (rotas/crm, contacts...), não o design system inteiro
    if (/components-next|\/components\/(widgets|ui|base)\//.test(r) && depth >= 1) continue;
    if (r.endsWith('.vue') || /\/(composables|helpers|hooks)\//.test(r)) collect(r, depth + 1, acc);
  }
  return acc;
};

const signals = (src) => ({
  loading: /isLoading|uiFlags\.(isFetching|isCreating|isUpdating|isDeleting|fetching)|isFetching|loading|Spinner|Skeleton|<Loader|CRMSkeleton/i.test(src),
  empty: /EmptyState|empty-state|EMPTY_STATE|NO_RESULTS|isEmpty\b|showEmptyResult|NoRecords|NOTHING_HERE|Nenhum|nenhum/i.test(src),
  errorHandling: /catch\s*\(|\.catch\(|onError|hasError|useAlert\(.*(ERROR|erro)/i.test(src),
  retry: /retry|tentar novamente|TRY_AGAIN|RETRY|refetch|reload/i.test(src),
  confirmDelete: /@confirm=|confirmArchive|confirmDelete|DeleteDialog|ConfirmDialog|confirm-dialog|useConfirm|ConfirmModal|deleteConfirm|showDeleteConfirmation|CONFIRM.*DELETE|DELETE.*CONFIRM|openDeletePopup|n-dialog|<Dialog/i.test(src),
  hasDelete: /delete|destroy|remover|excluir/i.test(src),
  validation: /useVuelidate|v\$\.|required\b|\$error|rules=|validate\(|:has-error|hasError/i.test(src),
  masks: /vue-the-mask|v-mask|maska|formatPhone|formatCurrency|cpf|cnpj|Intl\.NumberFormat|toLocaleString|dayjs|date-fns|formatDate/i.test(src),
  consoleLog: (src.match(/^\s*console\.(log|debug)\(/gm) || []).length,
  rawText: (src.match(/eslint-disable[^\n]*no-raw-text/g) || []).length,
  hardcodedJuridico: (src.match(/jur[ií]dic|INSS|advogad|legal_area|Setor jur/gi) || []).length,
  todoFixme: (src.match(/TODO|FIXME|HACK|XXX/g) || []).length,
  apiCalls: [...new Set([...src.matchAll(/(?:\$store\.dispatch|store\.dispatch|dispatch)\(\s*['"]([\w/]+)['"]/g)].map(m => m[1]))],
  directApi: [...new Set([...src.matchAll(/(?:axios|wootAPI|ApiClient|api)\.(get|post|put|patch|delete)\(\s*[`'"]([^`'"]+)/gi)].map(m => m[2]))],
  slateClasses: (src.match(/\bn-slate-\d+/g) || []).length,
  lines: src.split('\n').length,
});

const out = [];
for (const r of routes) {
  if (!r.component || !r.component.endsWith('.vue')) continue;
  if (r.component.startsWith('/app/')) r.component = root.replace(/\/$/, '') + r.component;
  if (seen.has(r.component)) { out.push({ name: r.name, path: r.path, component: r.component.replace(root, ''), sameAs: seen.get(r.component) }); continue; }
  seen.set(r.component, r.name);
  const files = [...collect(r.component)];
  const src = files.map(read).filter(Boolean).join('\n');
  out.push({ name: r.name, path: r.path, component: r.component.replace(root, ''), files: files.length, ...signals(src) });
}
fs.writeFileSync(new URL('./results/static.json', import.meta.url), JSON.stringify(out, null, 1));
const uniq = out.filter(o => !o.sameAs);
console.log('páginas únicas:', uniq.length);
console.log('sem loading:', uniq.filter(o => !o.loading).map(o => o.name).join(', '));
console.log('sem empty:', uniq.filter(o => !o.empty).map(o => o.name).join(', '));
console.log('sem tratamento de erro:', uniq.filter(o => !o.errorHandling).map(o => o.name).join(', '));
console.log('delete sem confirm:', uniq.filter(o => o.hasDelete && !o.confirmDelete).map(o => o.name).join(', '));
console.log('console.log:', uniq.filter(o => o.consoleLog).map(o => `${o.name}(${o.consoleLog})`).join(', '));
console.log('jurídico hardcoded:', uniq.filter(o => o.hardcodedJuridico).map(o => `${o.name}(${o.hardcodedJuridico})`).join(', '));
console.log('no-raw-text disable:', uniq.filter(o => o.rawText).map(o => `${o.name}(${o.rawText})`).join(', '));

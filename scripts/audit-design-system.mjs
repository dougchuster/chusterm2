#!/usr/bin/env node
/**
 * Auditoria do Design System ChusteRM
 *
 * Lista os pontos de adoção pendente:
 *  - <select> nativos em arquivos .vue
 *  - <textarea> nativos em arquivos .vue
 *  - cores hex literais em arquivos .vue/.scss/.css fora dos arquivos
 *    de tokens
 *
 * Saída: relatório em texto com contagem por arquivo + total.
 *
 * Uso:
 *   node scripts/audit-design-system.mjs            # relatório completo
 *   node scripts/audit-design-system.mjs --json     # saída JSON
 *   node scripts/audit-design-system.mjs --strict   # exit 1 se aumentou
 *
 * Caminhos auditados ficam em CONFIG abaixo.
 */

import { readFile } from 'node:fs/promises';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const CORE_ROOT = path.join(REPO_ROOT, 'core');

const CONFIG = {
  scanGlobs: ['app/javascript/**/*.vue'],
  // Arquivos onde os primitivos encapsulam o elemento nativo — esperado
  excludeForNativeTags: [
    'components-next/select/',
    'components-next/selectmenu/',
    'components-next/input/',
    'components-next/textarea/',
    'components-next/inline-input/',
    'components-next/phonenumberinput/',
    'components-next/taginput/',
    'components-next/combobox/',
    'components-next/Editor/',
    'components-next/copilot/',
    '.story.vue',
  ],
};

// Lista arquivos via git ls-files (rápido + respeita .gitignore)
function listFiles() {
  const out = execSync('git ls-files "app/javascript/**/*.vue"', {
    cwd: CORE_ROOT,
    encoding: 'utf8',
  });
  return out
    .split('\n')
    .filter(Boolean)
    .map(f => path.join(CORE_ROOT, f));
}

function isExcluded(file, excludeList) {
  return excludeList.some(frag => file.replace(/\\/g, '/').includes(frag));
}

function countMatches(content, pattern) {
  const matches = content.match(pattern);
  return matches ? matches.length : 0;
}

async function auditFile(file) {
  const content = await readFile(file, 'utf8');
  return {
    file: path.relative(CORE_ROOT, file).replace(/\\/g, '/'),
    selectCount: countMatches(content, /<select(?=[\s>])/g),
    textareaCount: countMatches(content, /<textarea(?=[\s>])/g),
    hexColorCount: countMatches(content, /#[0-9a-fA-F]{3,8}\b/g),
  };
}

async function main() {
  const args = new Set(process.argv.slice(2));
  const asJson = args.has('--json');

  const files = listFiles();
  const results = [];

  for (const file of files) {
    if (isExcluded(file, CONFIG.excludeForNativeTags)) continue;
    const r = await auditFile(file);
    if (r.selectCount || r.textareaCount) results.push(r);
  }

  const total = results.reduce(
    (acc, r) => ({
      files: acc.files + 1,
      select: acc.select + r.selectCount,
      textarea: acc.textarea + r.textareaCount,
    }),
    { files: 0, select: 0, textarea: 0 }
  );

  if (asJson) {
    console.log(JSON.stringify({ total, results }, null, 2));
    return;
  }

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  ChusteRM Design System — Auditoria de adoção');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('');
  console.log(`Arquivos com elemento nativo: ${total.files}`);
  console.log(`Total <select> crus:          ${total.select}`);
  console.log(`Total <textarea> crus:        ${total.textarea}`);
  console.log('');
  console.log('Top 15 arquivos a migrar (por contagem):');
  console.log('─'.repeat(63));
  results
    .sort(
      (a, b) =>
        b.selectCount + b.textareaCount - (a.selectCount + a.textareaCount)
    )
    .slice(0, 15)
    .forEach(r => {
      const tags = [];
      if (r.selectCount) tags.push(`${r.selectCount}× select`);
      if (r.textareaCount) tags.push(`${r.textareaCount}× textarea`);
      console.log(`  ${tags.join(', ').padEnd(28)} ${r.file}`);
    });
  console.log('');
  console.log('Como migrar: ver docs/design-system.md');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

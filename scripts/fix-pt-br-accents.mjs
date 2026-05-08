#!/usr/bin/env node
/**
 * Normaliza acentuação em pt_BR nas traduções do ChusteRM.
 *
 * Procura por palavras digitadas sem acento (Capitao, Historico, ...)
 * apenas com word-boundary (\b) para não quebrar tokens dentro de outras
 * palavras. Caso/case preservado nas variantes Capitalizado/minúsculo.
 *
 * Uso:
 *   node scripts/fix-pt-br-accents.mjs            # dry-run (mostra mudanças)
 *   node scripts/fix-pt-br-accents.mjs --apply    # aplica alterações
 */

import { readFile, writeFile } from 'node:fs/promises';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const CORE_ROOT = path.join(REPO_ROOT, 'core');
const LOCALE_DIR = 'app/javascript/dashboard/i18n/locale/pt_BR';

const REPLACEMENTS = [
  ['Capitao', 'Capitão'],
  ['Historico', 'Histórico'],
  ['historico', 'histórico'],
  ['Juridico', 'Jurídico'],
  ['juridico', 'jurídico'],
  ['Juridica', 'Jurídica'],
  ['juridica', 'jurídica'],
  ['Unico', 'Único'],
  ['unico', 'único'],
  ['Unica', 'Única'],
  ['unica', 'única'],
  ['Informacoes', 'Informações'],
  ['informacoes', 'informações'],
  ['Configuracoes', 'Configurações'],
  ['configuracoes', 'configurações'],
  ['Permissoes', 'Permissões'],
  ['permissoes', 'permissões'],
  ['Responsavel', 'Responsável'],
  ['responsavel', 'responsável'],
  ['Proxima', 'Próxima'],
  ['proxima', 'próxima'],
  ['Proximas', 'Próximas'],
  ['proximas', 'próximas'],
  ['Proximo', 'Próximo'],
  ['proximo', 'próximo'],
  ['Apos', 'Após'],
  ['Seguranca', 'Segurança'],
  ['seguranca', 'segurança'],
  ['Rastreavel', 'Rastreável'],
  ['rastreavel', 'rastreável'],
  ['Operacoes', 'Operações'],
  ['operacoes', 'operações'],
  ['Acoes', 'Ações'],
  ['acoes', 'ações'],
  ['Atendimentos', 'Atendimentos'], // já correto, sentinela
  ['Status juridico', 'Status jurídico'],
  ['ja existe', 'já existe'],
  ['ja foi', 'já foi'],
  ['servico', 'serviço'],
  ['servicos', 'serviços'],
  ['Servico', 'Serviço'],
  ['Servicos', 'Serviços'],
  ['Pratica', 'Prática'],
  ['pratica', 'prática'],
  ['Praticas', 'Práticas'],
  ['praticas', 'práticas'],
  ['Eletronico', 'Eletrônico'],
  ['eletronico', 'eletrônico'],
  ['Eletronica', 'Eletrônica'],
  ['eletronica', 'eletrônica'],
  ['publico', 'público'],
  ['Publico', 'Público'],
  ['publica', 'pública'],
  ['Publica', 'Pública'],
  ['Codigo', 'Código'],
  ['codigo', 'código'],
  ['ultimo', 'último'],
  ['Ultimo', 'Último'],
  ['ultima', 'última'],
  ['Ultima', 'Última'],
  ['voce', 'você'],
  ['Voce', 'Você'],
  ['ate', 'até'],
  ['ja', 'já'],
  ['so', 'só'],
  ['nao', 'não'],
  ['Nao', 'Não'],
  ['eh', 'é'],
  ['possivel', 'possível'],
  ['Possivel', 'Possível'],
  ['Impossivel', 'Impossível'],
  ['impossivel', 'impossível'],
  ['Titulo', 'Título'],
  ['titulo', 'título'],
  ['Titulos', 'Títulos'],
  ['titulos', 'títulos'],
  ['Usuario', 'Usuário'],
  ['usuario', 'usuário'],
  ['Usuarios', 'Usuários'],
  ['usuarios', 'usuários'],
  ['Automatico', 'Automático'],
  ['automatico', 'automático'],
  ['Automatica', 'Automática'],
  ['automatica', 'automática'],
  ['Necessario', 'Necessário'],
  ['necessario', 'necessário'],
  ['Necessaria', 'Necessária'],
  ['necessaria', 'necessária'],
  ['Obrigatorio', 'Obrigatório'],
  ['obrigatorio', 'obrigatório'],
  ['Obrigatoria', 'Obrigatória'],
  ['obrigatoria', 'obrigatória'],
  ['Disponivel', 'Disponível'],
  ['disponivel', 'disponível'],
  ['Indisponivel', 'Indisponível'],
  ['indisponivel', 'indisponível'],
  ['Valido', 'Válido'],
  ['valido', 'válido'],
  ['Valida', 'Válida'],
  ['valida', 'válida'],
  ['Invalido', 'Inválido'],
  ['invalido', 'inválido'],
  ['Invalida', 'Inválida'],
  ['invalida', 'inválida'],
  ['Util', 'Útil'],
  ['util', 'útil'],
  ['Inutil', 'Inútil'],
  ['inutil', 'inútil'],
  ['Generico', 'Genérico'],
  ['generico', 'genérico'],
  ['Generica', 'Genérica'],
  ['generica', 'genérica'],
  ['Tecnico', 'Técnico'],
  ['tecnico', 'técnico'],
  ['Tecnica', 'Técnica'],
  ['tecnica', 'técnica'],
  ['Periodico', 'Periódico'],
  ['periodico', 'periódico'],
  ['Periodica', 'Periódica'],
  ['periodica', 'periódica'],
  ['Maximo', 'Máximo'],
  ['maximo', 'máximo'],
  ['Maxima', 'Máxima'],
  ['maxima', 'máxima'],
  ['Minimo', 'Mínimo'],
  ['minimo', 'mínimo'],
  ['Minima', 'Mínima'],
  ['minima', 'mínima'],
  ['Otimo', 'Ótimo'],
  ['otimo', 'ótimo'],
  ['Otima', 'Ótima'],
  ['otima', 'ótima'],
];

// Filtra a lista de "ate", "ja", "so", "nao", "eh" para evitar matches
// dentro de palavras (já tem boundary, mas sentinelas falsas existem):
//  - "nao" em "naomi", "Naomi"  -> boundary protege
//  - "ja" em "java", "javascript" -> boundary protege
// Mesmo assim, evitamos substituir dentro de URLs/IDs JSON.
// As chaves (keys) JSON nunca passam pelo regex porque ficam num prefixo
// fora do valor. Mas para garantir, só processamos o valor (após `: "`).

function listFiles() {
  const out = execSync(`git ls-files "${LOCALE_DIR}/*.json"`, {
    cwd: CORE_ROOT,
    encoding: 'utf8',
  });
  return out
    .split('\n')
    .filter(Boolean)
    .map(f => path.join(CORE_ROOT, f));
}

function applyReplacements(content) {
  let changes = 0;
  let result = content;

  for (const [from, to] of REPLACEMENTS) {
    if (from === to) continue;
    // CRÍTICO: \b em JS não respeita Unicode — \bvalida\b casa "valida" em
    // "validação" porque ç não é word-char ASCII. Usamos lookaround com
    // \p{L} (letras Unicode) e \p{N} (dígitos) com flag /u.
    const escaped = from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(
      `(?<![\\p{L}\\p{N}])${escaped}(?![\\p{L}\\p{N}])`,
      'gu'
    );
    const before = result;
    result = result.replace(re, to);
    if (before !== result) {
      const matches = before.match(re);
      changes += matches ? matches.length : 0;
    }
  }

  return { result, changes };
}

async function main() {
  const apply = process.argv.includes('--apply');
  const files = listFiles();
  const summary = [];
  let totalChanges = 0;

  for (const file of files) {
    const original = await readFile(file, 'utf8');
    const { result, changes } = applyReplacements(original);
    if (changes > 0) {
      summary.push({
        file: path.relative(CORE_ROOT, file).replace(/\\/g, '/'),
        changes,
      });
      totalChanges += changes;
      if (apply) {
        await writeFile(file, result, 'utf8');
      }
    }
  }

  console.log('═══════════════════════════════════════════════════════');
  console.log(
    `  Normalização de acentos pt_BR — ${apply ? 'APLICADO' : 'DRY-RUN'}`
  );
  console.log('═══════════════════════════════════════════════════════');
  console.log('');
  console.log(`Arquivos afetados: ${summary.length}`);
  console.log(`Total de substituições: ${totalChanges}`);
  console.log('');
  summary
    .sort((a, b) => b.changes - a.changes)
    .forEach(({ file, changes }) => {
      console.log(`  ${String(changes).padStart(4)}  ${file}`);
    });
  if (!apply) {
    console.log('');
    console.log('Para aplicar: node scripts/fix-pt-br-accents.mjs --apply');
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

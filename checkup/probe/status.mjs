// Atualiza a coluna Status de uma ou mais linhas do inventário: node status.mjs A1=OK B43=FALHOU ...
import fs from 'node:fs';

const file = new URL('../inventario.md', import.meta.url);
const STATUSES = ['PENDENTE', 'EM ANDAMENTO', 'FALHOU', 'OK', 'BLOQUEADO'];
let text = fs.readFileSync(file, 'utf8');

for (const arg of process.argv.slice(2)) {
  const [id, status] = arg.split('=');
  if (!STATUSES.includes(status)) { console.error('status inválido', status); process.exitCode = 1; continue; }
  const re = new RegExp(`^(\\| ${id} \\|.*\\| )(${STATUSES.join('|')})( \\|)\\r?$`, 'm');
  if (!re.test(text)) { console.error('não achei', id); process.exitCode = 1; continue; }
  text = text.replace(re, `$1${status}$3`);
}
fs.writeFileSync(file, text);

// Prévia do nome padrão na tela, antes de confirmar a classificação
// (PROJETO-COFRE-DOCUMENTOS.md §5.3). Espelha Crm::Documents::Naming::FileNamer
// só para exibição — o nome gravado continua sendo o do servidor.

const SEPARATOR = ' — ';
const FORBIDDEN = /[/\\:*?"<>|]/g;

const clean = text =>
  String(text || '')
    .replace(FORBIDDEN, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const pad = value => String(value).padStart(2, '0');

export const localDate = value => {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

export const extensionOf = fileName => {
  const match = /\.([a-z0-9]{1,5})$/i.exec(fileName || '');
  return match ? match[1].toLowerCase() : 'bin';
};

export const previewFileName = ({
  document,
  typeSlug,
  typeLabel,
  description,
}) => {
  const date = document.document_date || localDate(document.created_at);
  const label =
    typeSlug === 'outro' ? clean(description) || 'Documento' : clean(typeLabel);
  const detail = typeSlug === 'outro' ? '' : clean(description);
  const base = [date, label, detail].filter(Boolean).join(SEPARATOR);
  return `${base}.${extensionOf(document.file_name)}`;
};

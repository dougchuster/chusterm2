// Lógica pura do construtor de formulários (espelha o FormSchema do servidor
// só para ajudar quem monta; a validação de verdade é no servidor).

export const FIELD_TYPES = [
  { value: 'text', label: 'Texto curto' },
  { value: 'textarea', label: 'Texto longo' },
  { value: 'phone', label: 'Telefone / WhatsApp' },
  { value: 'email', label: 'E-mail' },
  { value: 'cpf', label: 'CPF' },
  { value: 'cnpj', label: 'CNPJ' },
  { value: 'cpf_cnpj', label: 'CPF ou CNPJ' },
  { value: 'date', label: 'Data' },
  { value: 'number', label: 'Número' },
  { value: 'select', label: 'Lista de opções' },
  { value: 'radio', label: 'Escolha única (botões)' },
  { value: 'checkboxes', label: 'Várias escolhas' },
  { value: 'checkbox', label: 'Caixa de confirmação' },
];

export const CHOICE_TYPES = ['select', 'radio', 'checkboxes'];
export const CONDITION_SOURCE_TYPES = ['select', 'radio', 'checkbox'];

export const MAPS_TO = [
  { value: '', label: 'Não ligar ao cadastro' },
  { value: 'contact_name', label: 'Nome do contato' },
  { value: 'contact_phone', label: 'Telefone do contato' },
  { value: 'contact_email', label: 'E-mail do contato' },
];

// "Carteira de Trabalho (CTPS)" → "carteira_de_trabalho_ctps", único na lista.
export const keyFromLabel = (label, existingKeys = []) => {
  const base =
    String(label || 'campo')
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .replace(/^(\d)/, 'c_$1')
      .slice(0, 36) || 'campo';
  let key = base;
  let suffix = 2;
  while (existingKeys.includes(key)) {
    key = `${base}_${suffix}`;
    suffix += 1;
  }
  return key;
};

export const move = (list, index, step) => {
  const target = index + step;
  if (target < 0 || target >= list.length) return list;
  const copy = [...list];
  [copy[index], copy[target]] = [copy[target], copy[index]];
  return copy;
};

// Campos que podem controlar a condição de um item: os de escolha que vêm
// antes dele (para campos) ou qualquer um do formulário (para documentos).
export const conditionSources = (fields, beforeIndex = fields.length) =>
  fields
    .slice(0, beforeIndex)
    .filter(field => CONDITION_SOURCE_TYPES.includes(field.type));

export const conditionValues = field => {
  if (!field) return [];
  if (field.type === 'checkbox') return ['true'];
  return (field.options || []).filter(Boolean);
};

// Avisos locais antes de salvar (o servidor dá a palavra final).
export const localWarnings = fields => {
  const warnings = [];
  const targets = fields.map(field => field.maps_to).filter(Boolean);
  if (!targets.includes('contact_name'))
    warnings.push('Ligue um campo ao nome do contato.');
  if (!targets.includes('contact_phone') && !targets.includes('contact_email'))
    warnings.push('Ligue um campo ao telefone ou ao e-mail do contato.');
  fields.forEach(field => {
    if (!String(field.label || '').trim())
      warnings.push('Há um campo sem nome.');
    if (CHOICE_TYPES.includes(field.type) && !(field.options || []).length)
      warnings.push(`"${field.label}" precisa de opções.`);
  });
  return [...new Set(warnings)];
};

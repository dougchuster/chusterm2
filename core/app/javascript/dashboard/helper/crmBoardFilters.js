/**
 * Filtros do board — F2.6 do PLANO-KANBAN-CRM-2026.md.
 *
 * A F1.4 entregou 12 critérios no servidor e o board usava três. Este módulo é
 * o contrato entre a barra de pills e o endpoint: traduz estado de tela em
 * parâmetro, e parâmetro em pill legível.
 *
 * Fica fora do componente porque a mesma tradução vale para a lista (`AllLeads`)
 * e para as visões salvas da F2.7 — e porque "false é um filtro, não uma
 * ausência" é uma regra que merece teste, não um `if` escondido no template.
 */

const UNASSIGNED = '__unassigned';

const LIST_KEYS = [
  'stage_id',
  'owner_id',
  'operational_status',
  'ai_mode',
  'label',
];

// Cada faixa é **uma** pill, com dois parâmetros por baixo.
const RANGES = {
  score: { min: 'score_min', max: 'score_max' },
  value: { min: 'value_min', max: 'value_max' },
  created: { min: 'created_after', max: 'created_before' },
};

// `false` aqui é intenção: "negócios **sem** próxima ação" é a pergunta que a
// meta de <10% do plano faz.
const BOOLEAN_KEYS = {
  has_pending_activity: {
    true: 'CRM.FILTERS.HAS_NEXT_ACTION',
    false: 'CRM.FILTERS.NO_NEXT_ACTION',
  },
  stale: {
    true: 'CRM.FILTERS.STALE',
    false: 'CRM.FILTERS.NOT_STALE',
  },
};

export function emptyFilters() {
  return {
    q: '',
    stage_id: [],
    owner_id: [],
    operational_status: [],
    ai_mode: [],
    label: [],
    score_min: null,
    score_max: null,
    value_min: null,
    value_max: null,
    created_after: null,
    created_before: null,
    has_pending_activity: null,
    stale: null,
  };
}

const isSet = value =>
  value !== null && value !== undefined && value !== '' && !Number.isNaN(value);

const money = cents =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(cents || 0) / 100);

export function toRequestParams(filters = {}) {
  const params = {};

  if (filters.q?.trim()) params.q = filters.q.trim();

  LIST_KEYS.forEach(key => {
    const values = (filters[key] || []).filter(isSet);
    if (values.length) params[key] = values;
  });

  Object.values(RANGES).forEach(({ min, max }) => {
    if (isSet(filters[min])) params[min] = filters[min];
    if (isSet(filters[max])) params[max] = filters[max];
  });

  Object.keys(BOOLEAN_KEYS).forEach(key => {
    if (typeof filters[key] === 'boolean') params[key] = filters[key];
  });

  return params;
}

const nameFrom = (collection, id, fallbackKey) => {
  if (String(id) === UNASSIGNED) return fallbackKey;

  const found = (collection || []).find(
    item => String(item.id ?? item.title) === String(id)
  );
  return found?.name || found?.title || String(id);
};

const rangeLabel = (min, max, format = value => String(value)) => {
  if (isSet(min) && isSet(max)) return `${format(min)}–${format(max)}`;
  if (isSet(min)) return `${format(min)}+`;
  return `≤ ${format(max)}`;
};

/**
 * As pills que a barra mostra. Cada uma sabe se remover: `key` é o que volta
 * para `removeFilter`.
 */
export function describeFilters(filters = {}, dictionaries = {}) {
  const pills = [];

  if (filters.q?.trim()) {
    pills.push({
      key: 'q',
      labelKey: 'CRM.FILTERS.SEARCH',
      value: filters.q.trim(),
    });
  }

  const named = {
    stage_id: [dictionaries.stages, 'CRM.FILTERS.STAGE'],
    owner_id: [dictionaries.owners, 'CRM.FILTERS.OWNER'],
    label: [dictionaries.labels, 'CRM.FILTERS.LABEL'],
  };

  LIST_KEYS.forEach(key => {
    const values = (filters[key] || []).filter(isSet);
    if (!values.length) return;

    const [collection, labelKey] = named[key] || [
      null,
      `CRM.FILTERS.${key.toUpperCase()}`,
    ];

    pills.push({
      key,
      labelKey,
      value: values
        .map(value =>
          collection
            ? nameFrom(collection, value, 'CRM.FILTERS.UNASSIGNED')
            : String(value)
        )
        .join(', '),
    });
  });

  if (isSet(filters.score_min) || isSet(filters.score_max)) {
    pills.push({
      key: 'score',
      labelKey: 'CRM.FILTERS.SCORE',
      value: rangeLabel(filters.score_min, filters.score_max),
    });
  }

  if (isSet(filters.value_min) || isSet(filters.value_max)) {
    pills.push({
      key: 'value',
      labelKey: 'CRM.FILTERS.VALUE',
      value: rangeLabel(filters.value_min, filters.value_max, money),
    });
  }

  if (isSet(filters.created_after) || isSet(filters.created_before)) {
    pills.push({
      key: 'created',
      labelKey: 'CRM.FILTERS.CREATED',
      value: rangeLabel(filters.created_after, filters.created_before),
    });
  }

  Object.entries(BOOLEAN_KEYS).forEach(([key, labels]) => {
    if (typeof filters[key] !== 'boolean') return;

    pills.push({ key, labelKey: labels[String(filters[key])], value: '' });
  });

  return pills;
}

export function removeFilter(filters, key) {
  const next = { ...filters };

  if (RANGES[key]) {
    next[RANGES[key].min] = null;
    next[RANGES[key].max] = null;
    return next;
  }

  if (LIST_KEYS.includes(key)) {
    next[key] = [];
    return next;
  }

  next[key] = key === 'q' ? '' : null;
  return next;
}

export function activeFilterCount(filters = {}) {
  return describeFilters(filters).length;
}

import {
  activeFilterCount,
  describeFilters,
  emptyFilters,
  removeFilter,
  toRequestParams,
} from '../crmBoardFilters';

// F2.6 do PLANO-KANBAN-CRM-2026.md — "barra de filtros componível, cada um
// removível, contador de resultados. Suporta os 12 critérios da F1.4".
//
// A F1.4 entregou 12 critérios no servidor e o board usava 3. Este módulo é o
// contrato entre a barra e o endpoint: ele sabe traduzir estado de tela em
// parâmetro, e parâmetro em pill legível.

const dictionaries = {
  stages: [
    { id: 10, name: 'Novo' },
    { id: 20, name: 'Qualificado' },
  ],
  owners: [{ id: 9, name: 'Dra. Paula' }],
  labels: [{ title: 'area_trabalhista' }],
};

describe('toRequestParams', () => {
  it('sends nothing when nothing is filtered', () => {
    expect(toRequestParams(emptyFilters())).toEqual({});
  });

  it('trims the search before sending it', () => {
    expect(toRequestParams({ ...emptyFilters(), q: '  maria  ' })).toEqual({
      q: 'maria',
    });
  });

  it('sends the lists the server expects', () => {
    const params = toRequestParams({
      ...emptyFilters(),
      stage_id: [10, 20],
      owner_id: ['9', '__unassigned'],
      operational_status: ['active'],
      ai_mode: ['auto'],
      label: ['area_trabalhista'],
    });

    expect(params.stage_id).toEqual([10, 20]);
    expect(params.owner_id).toEqual(['9', '__unassigned']);
    expect(params.operational_status).toEqual(['active']);
    expect(params.ai_mode).toEqual(['auto']);
    expect(params.label).toEqual(['area_trabalhista']);
  });

  it('drops an empty list instead of sending it', () => {
    expect(toRequestParams({ ...emptyFilters(), stage_id: [] })).toEqual({});
  });

  it('sends the ranges', () => {
    const params = toRequestParams({
      ...emptyFilters(),
      score_min: 60,
      value_max: 500000,
      created_after: '2026-08-01',
    });

    expect(params).toEqual({
      score_min: 60,
      value_max: 500000,
      created_after: '2026-08-01',
    });
  });

  // A F1.4 aceita `false` de propósito nesses dois: "sem próxima ação" é o
  // estado mais alarmante do board, e é a pergunta que a meta de <10% faz.
  it('sends false, because false is a filter and not an absence', () => {
    const params = toRequestParams({
      ...emptyFilters(),
      has_pending_activity: false,
      stale: false,
    });

    expect(params).toEqual({ has_pending_activity: false, stale: false });
  });

  it('leaves out what was never set', () => {
    const params = toRequestParams({
      ...emptyFilters(),
      has_pending_activity: null,
    });

    expect(params).not.toHaveProperty('has_pending_activity');
  });
});

describe('describeFilters', () => {
  it('says nothing when nothing is filtered', () => {
    expect(describeFilters(emptyFilters(), dictionaries)).toEqual([]);
  });

  it('names the stage instead of showing its id', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), stage_id: [10] },
      dictionaries
    );

    expect(pill.value).toBe('Novo');
    expect(pill.key).toBe('stage_id');
  });

  it('joins several values of the same criterion into one pill', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), stage_id: [10, 20] },
      dictionaries
    );

    expect(pill.value).toBe('Novo, Qualificado');
  });

  it('names the owner, and knows the unassigned pseudo-owner', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), owner_id: ['9', '__unassigned'] },
      dictionaries
    );

    expect(pill.value).toContain('Dra. Paula');
    expect(pill.value).toContain('CRM.FILTERS.UNASSIGNED');
  });

  it('reads the score range as a range', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), score_min: 60, score_max: 79 },
      dictionaries
    );

    expect(pill.key).toBe('score');
    expect(pill.value).toBe('60–79');
  });

  it('reads an open-ended range', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), score_min: 80 },
      dictionaries
    );

    expect(pill.value).toBe('80+');
  });

  it('shows money as money, not as cents', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), value_min: 1_000_000 },
      dictionaries
    );

    expect(pill.value).toContain('10.000,00');
  });

  it('turns the boolean criteria into something a person reads', () => {
    const pills = describeFilters(
      { ...emptyFilters(), has_pending_activity: false, stale: true },
      dictionaries
    );

    expect(pills.map(pill => pill.key)).toEqual([
      'has_pending_activity',
      'stale',
    ]);
    expect(pills[0].labelKey).toBe('CRM.FILTERS.NO_NEXT_ACTION');
    expect(pills[1].labelKey).toBe('CRM.FILTERS.STALE');
  });

  it('keeps the search as its own pill', () => {
    const [pill] = describeFilters(
      { ...emptyFilters(), q: 'maria' },
      dictionaries
    );

    expect(pill.key).toBe('q');
    expect(pill.value).toBe('maria');
  });
});

describe('removeFilter', () => {
  it('clears one criterion and leaves the rest', () => {
    const filters = { ...emptyFilters(), q: 'maria', stage_id: [10] };

    const next = removeFilter(filters, 'q');

    expect(next.q).toBe('');
    expect(next.stage_id).toEqual([10]);
  });

  it('clears both ends of a range at once', () => {
    const filters = { ...emptyFilters(), score_min: 60, score_max: 79 };

    const next = removeFilter(filters, 'score');

    expect(next.score_min).toBeNull();
    expect(next.score_max).toBeNull();
  });

  it('does not touch the object it was given', () => {
    const filters = { ...emptyFilters(), q: 'maria' };

    removeFilter(filters, 'q');

    expect(filters.q).toBe('maria');
  });
});

describe('activeFilterCount', () => {
  it('counts a range as one filter, not two', () => {
    expect(
      activeFilterCount({ ...emptyFilters(), score_min: 60, score_max: 79 })
    ).toBe(1);
  });

  it('counts false as an active filter', () => {
    expect(
      activeFilterCount({ ...emptyFilters(), has_pending_activity: false })
    ).toBe(1);
  });

  it('does not count an empty list', () => {
    expect(activeFilterCount({ ...emptyFilters(), stage_id: [] })).toBe(0);
  });
});

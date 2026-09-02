import {
  nextActionSignal,
  rottingSignal,
  visibleBadges,
} from '../crmCardSignals';

// F2.4 do PLANO-KANBAN-CRM-2026.md, §7 — as regras de hierarquia do card.
//
// Ficam fora do componente de propósito: são regra de negócio, não desenho.
// "Deal aberto sem próxima ação é o estado mais alarmante do board" é uma
// afirmação que precisa de teste, não de CSS.

const AGORA = new Date('2026-08-28T15:00:00Z');

describe('nextActionSignal', () => {
  // Regra 2 da §7: sem próxima ação é o estado mais alarmante do board, e a
  // meta do plano é manter isso abaixo de 10%.
  it('flags an open deal with no next action as the loudest state', () => {
    const signal = nextActionSignal({ status: 'open' }, AGORA);

    expect(signal.tone).toBe('missing');
    expect(signal.actionable).toBe(true);
  });

  // Negócio fechado não precisa de próxima ação: cobrar isso encheria o board
  // de alarme falso.
  it('does not demand a next action from a deal that is already closed', () => {
    const signal = nextActionSignal({ status: 'won' }, AGORA);

    expect(signal.tone).toBe('none');
    expect(signal.actionable).toBe(false);
  });

  it('marks an overdue action as overdue', () => {
    const signal = nextActionSignal(
      { status: 'open', next_activity_due_at: '2026-08-27T14:00:00Z' },
      AGORA
    );

    expect(signal.tone).toBe('overdue');
  });

  it('marks something due later today as today', () => {
    const signal = nextActionSignal(
      { status: 'open', next_activity_due_at: '2026-08-28T18:00:00Z' },
      AGORA
    );

    expect(signal.tone).toBe('today');
  });

  it('leaves a future action quiet', () => {
    const signal = nextActionSignal(
      { status: 'open', next_activity_due_at: '2026-09-02T14:00:00Z' },
      AGORA
    );

    expect(signal.tone).toBe('future');
  });

  // Uma atividade sem data é trabalho combinado sem quando. Não é atraso, mas
  // também não é "tudo certo".
  it('treats a pending activity with no date as scheduled without a date', () => {
    const signal = nextActionSignal(
      { status: 'open', pending_activities_count: 2 },
      AGORA
    );

    expect(signal.tone).toBe('undated');
    expect(signal.actionable).toBe(false);
  });

  it('carries the due date so the card can show it', () => {
    const signal = nextActionSignal(
      { status: 'open', next_activity_due_at: '2026-08-28T18:00:00Z' },
      AGORA
    );

    expect(signal.dueAt).toBe('2026-08-28T18:00:00Z');
  });
});

describe('rottingSignal', () => {
  const stage = { expected_duration_hours: 48 };

  // §7: 0–70% do prazo é normal, 70–100% âmbar, acima do prazo vermelho.
  it('stays quiet while the deal is well inside the expected time', () => {
    const signal = rottingSignal(
      { stage_entered_at: '2026-08-28T03:00:00Z' },
      stage,
      AGORA
    );

    expect(signal.level).toBe('ok');
  });

  it('warns as the deal approaches the expected time', () => {
    const signal = rottingSignal(
      { stage_entered_at: '2026-08-26T21:00:00Z' },
      stage,
      AGORA
    );

    expect(signal.level).toBe('warning');
  });

  it('goes loud once the deal passed the expected time', () => {
    const signal = rottingSignal(
      { stage_entered_at: '2026-08-25T15:00:00Z' },
      stage,
      AGORA
    );

    expect(signal.level).toBe('late');
    expect(signal.daysInStage).toBe(3);
  });

  // Sem prazo configurado não há como dizer que está parado — e inventar um
  // padrão faria o board acusar etapas que ninguém definiu.
  it('says nothing when the stage has no expected duration', () => {
    const signal = rottingSignal(
      { stage_entered_at: '2026-01-01T00:00:00Z' },
      { expected_duration_hours: null },
      AGORA
    );

    expect(signal.level).toBe('unknown');
  });

  // A F1.5 deixou `stage_entered_at` nula de propósito, sem backfill: quem
  // nunca se moveu está na etapa desde que nasceu.
  it('falls back to the creation date for a deal that never moved', () => {
    const signal = rottingSignal(
      { stage_entered_at: null, created_at: '2026-08-25T15:00:00Z' },
      stage,
      AGORA
    );

    expect(signal.level).toBe('late');
    expect(signal.daysInStage).toBe(3);
  });

  it('does not accuse a deal that is already closed', () => {
    const signal = rottingSignal(
      { stage_entered_at: '2026-01-01T00:00:00Z', status: 'won' },
      stage,
      AGORA
    );

    expect(signal.level).toBe('none');
  });
});

describe('visibleBadges', () => {
  // Regra 3 da §7: no máximo 2 badges visíveis + "+N". O resto vive no drawer.
  it('shows at most two badges', () => {
    const { shown, overflow } = visibleBadges(['a', 'b', 'c', 'd']);

    expect(shown).toEqual(['a', 'b']);
    expect(overflow).toBe(2);
  });

  it('does not show a counter when everything fits', () => {
    const { shown, overflow } = visibleBadges(['a']);

    expect(shown).toEqual(['a']);
    expect(overflow).toBe(0);
  });

  it('drops what is empty before counting', () => {
    const { shown, overflow } = visibleBadges(['a', '', null, 'b', 'c']);

    expect(shown).toEqual(['a', 'b']);
    expect(overflow).toBe(1);
  });
});

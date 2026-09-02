import {
  applyDealEvent,
  isUnplaceable,
  createDealEventQueue,
} from '../useBoardRealtime';

// F1.8 do PLANO-KANBAN-CRM-2026.md — o evento de outra sessão vira patch no
// estado local, e não um refetch do board inteiro.
//
// A regra que dá o tom do arquivo: **realtime é aditivo, nunca destrutivo**.
// Um card que o atendente está arrastando ou editando agora não pode saltar
// para outro lugar porque um colega mexeu nele; o evento espera na fila e é
// aplicado quando o card é solto.
//
// O patch é sobre **colunas** desde a F2.2, quando o board passou a consumir o
// endpoint de colunas da F1.5. Na F1.8 ele era sobre a lista plana, que era o
// estado que o board guardava então.

const ACCOUNT_ID = 7;

const card = (id, stageId, position, extra = {}) => ({
  id,
  account_id: ACCOUNT_ID,
  crm_pipeline_stage_id: stageId,
  position,
  title: `Negócio ${id}`,
  ...extra,
});

// F2.8: `id` e a chave do balde e `stage_id` e a etapa. So o agrupamento por
// etapa traz `stage_id` ? e so nele o realtime consegue recolocar o card.
const board = () => [
  { id: '10', stage_id: 10, deals: [card(1, 10, 1000), card(2, 10, 2000)] },
  { id: '20', stage_id: 20, deals: [card(3, 20, 1000)] },
];

const idsIn = (columns, stageId) =>
  columns
    .find(column => column.stage_id === stageId)
    .deals.map(deal => deal.id);

describe('applyDealEvent', () => {
  it('leaves the board untouched for an event from another account', () => {
    const columns = board();

    const next = applyDealEvent(columns, {
      type: 'updated',
      deal: { ...card(1, 20, 500), account_id: 999 },
      accountId: ACCOUNT_ID,
    });

    expect(next).toBe(columns);
  });

  it('does not mutate the columns it was given', () => {
    const columns = board();
    const before = JSON.stringify(columns);

    applyDealEvent(columns, {
      type: 'updated',
      deal: card(1, 20, 500),
      accountId: ACCOUNT_ID,
    });

    expect(JSON.stringify(columns)).toBe(before);
  });

  it('returns the same reference when a delete hits a card the board never had', () => {
    const columns = board();

    const next = applyDealEvent(columns, {
      type: 'deleted',
      deal: card(99, 10, 1000),
      accountId: ACCOUNT_ID,
    });

    expect(next).toBe(columns);
  });

  describe('a card moved by someone else', () => {
    it('takes the card out of the old column and puts it in the new one', () => {
      const next = applyDealEvent(board(), {
        type: 'updated',
        deal: { ...card(1, 20, 1500), previous_stage_id: 10 },
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([2]);
      expect(idsIn(next, 20)).toEqual([3, 1]);
    });

    // Ordenação é do servidor (F1.3): o card entra pela posição que ele
    // decidiu, não no fim por conveniência.
    it('respects the position the server decided, instead of appending', () => {
      const next = applyDealEvent(board(), {
        type: 'updated',
        deal: { ...card(1, 20, 500), previous_stage_id: 10 },
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 20)).toEqual([1, 3]);
    });

    it('finds the old column even when the event does not say where it came from', () => {
      const next = applyDealEvent(board(), {
        type: 'updated',
        deal: card(1, 20, 1500),
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([2]);
      expect(idsIn(next, 20)).toEqual([3, 1]);
    });

    it('keeps the card at the end while its position is still null', () => {
      const next = applyDealEvent(board(), {
        type: 'updated',
        deal: { ...card(1, 20, null), previous_stage_id: 10 },
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 20)).toEqual([3, 1]);
    });
  });

  describe('reordering inside the same column', () => {
    it('moves the card without duplicating it', () => {
      const next = applyDealEvent(board(), {
        type: 'updated',
        deal: card(2, 10, 500),
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([2, 1]);
    });
  });

  describe('the payload is light', () => {
    // O evento carrega o essencial (F1.7). Sobrescrever o card inteiro apagaria
    // o que o board já buscou — contato, score, próxima ação.
    it('merges over the card the board already had, instead of replacing it', () => {
      const columns = [
        {
          id: 10,
          deals: [
            card(1, 10, 1000, { contact_name: 'Maria', latest_score: 84 }),
          ],
        },
      ];

      const next = applyDealEvent(columns, {
        type: 'updated',
        deal: {
          id: 1,
          account_id: ACCOUNT_ID,
          crm_pipeline_stage_id: 10,
          position: 1500,
        },
        accountId: ACCOUNT_ID,
      });

      expect(next[0].deals[0].contact_name).toBe('Maria');
      expect(next[0].deals[0].latest_score).toBe(84);
      expect(next[0].deals[0].position).toBe(1500);
    });
  });

  describe('a card created by someone else', () => {
    it('appears in the right column, in the right place', () => {
      const next = applyDealEvent(board(), {
        type: 'created',
        deal: card(9, 10, 1500),
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([1, 9, 2]);
    });

    it('is ignored when its column is not on the board', () => {
      const next = applyDealEvent(board(), {
        type: 'created',
        deal: card(9, 99, 1000),
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([1, 2]);
      expect(idsIn(next, 20)).toEqual([3]);
    });
  });

  describe('a card deleted by someone else', () => {
    it('disappears from the board', () => {
      const next = applyDealEvent(board(), {
        type: 'deleted',
        deal: card(1, 10, 1000),
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([2]);
    });
  });

  describe('a card that left the filter', () => {
    // Mover para uma etapa que o filtro atual esconde é indistinguível, do
    // ponto de vista do board, de sair do board. Tirar é o comportamento certo:
    // deixar o card na coluna antiga mostraria uma mentira.
    it('is removed instead of being left in the old column', () => {
      const next = applyDealEvent(board(), {
        type: 'updated',
        deal: { ...card(1, 77, 1000), previous_stage_id: 10 },
        accountId: ACCOUNT_ID,
      });

      expect(idsIn(next, 10)).toEqual([2]);
      expect(
        next.some(column => column.deals.some(deal => deal.id === 1))
      ).toBe(false);
    });
  });
});

describe('createDealEventQueue', () => {
  it('applies straight away when nothing is being touched', () => {
    const queue = createDealEventQueue({ isBusy: () => false });
    const applied = [];

    queue.push({ type: 'updated', deal: card(1, 20, 500) }, event =>
      applied.push(event)
    );

    expect(applied).toHaveLength(1);
  });

  // Regra 3 dos princípios inegociáveis do plano: evento de outro usuário nunca
  // sobrescreve edição local em andamento.
  it('holds the event while the card is being dragged or edited', () => {
    const busy = new Set([1]);
    const queue = createDealEventQueue({ isBusy: id => busy.has(id) });
    const applied = [];

    queue.push({ type: 'updated', deal: card(1, 20, 500) }, event =>
      applied.push(event)
    );

    expect(applied).toHaveLength(0);
    expect(queue.pending()).toBe(1);
  });

  it('applies what it held once the card is released', () => {
    const busy = new Set([1]);
    const queue = createDealEventQueue({ isBusy: id => busy.has(id) });
    const applied = [];
    queue.push({ type: 'updated', deal: card(1, 20, 500) }, event =>
      applied.push(event)
    );

    busy.delete(1);
    queue.flush(event => applied.push(event));

    expect(applied).toHaveLength(1);
    expect(queue.pending()).toBe(0);
  });

  it('keeps holding an event whose card is still busy after a flush', () => {
    const busy = new Set([1, 2]);
    const queue = createDealEventQueue({ isBusy: id => busy.has(id) });
    const applied = [];
    queue.push({ type: 'updated', deal: card(1, 20, 500) }, () => {});
    queue.push({ type: 'updated', deal: card(2, 20, 600) }, () => {});

    busy.delete(1);
    queue.flush(event => applied.push(event));

    expect(applied.map(event => event.deal.id)).toEqual([1]);
    expect(queue.pending()).toBe(1);
  });

  // Uma rajada (ação em massa, automação) não pode virar dez saltos do mesmo
  // card quando ele for solto.
  it('keeps only the last event per card while holding', () => {
    const busy = new Set([1]);
    const queue = createDealEventQueue({ isBusy: id => busy.has(id) });
    const applied = [];
    queue.push({ type: 'updated', deal: card(1, 20, 500) }, () => {});
    queue.push({ type: 'updated', deal: card(1, 30, 900) }, () => {});

    busy.delete(1);
    queue.flush(event => applied.push(event));

    expect(applied).toHaveLength(1);
    expect(applied[0].deal.crm_pipeline_stage_id).toBe(30);
  });

  it('lets a delete win over an update that was waiting for the same card', () => {
    const busy = new Set([1]);
    const queue = createDealEventQueue({ isBusy: id => busy.has(id) });
    const applied = [];
    queue.push({ type: 'updated', deal: card(1, 20, 500) }, () => {});
    queue.push({ type: 'deleted', deal: card(1, 20, 500) }, () => {});

    busy.delete(1);
    queue.flush(event => applied.push(event));

    expect(applied).toHaveLength(1);
    expect(applied[0].type).toBe('deleted');
  });

  it('ignores an event with no deal in it', () => {
    const queue = createDealEventQueue({ isBusy: () => true });
    const applied = [];

    queue.push({ type: 'updated' }, event => applied.push(event));

    expect(applied).toHaveLength(0);
    expect(queue.pending()).toBe(0);
  });
});

// A revisao da F2.8 apontou que este ramo — o board agrupado por algo que nao e
// etapa — nao tinha um unico teste. E o ramo em que a coluna nao carrega
// `stage_id`, entao `crm_pipeline_stage_id` nao diz em que coluna o card cai.
describe('quando o board nao esta agrupado por etapa', () => {
  const byOwner = () => [
    {
      id: '3',
      name: 'Ana',
      deals: [
        {
          id: 1,
          account_id: 7,
          owner_id: 3,
          crm_pipeline_stage_id: 10,
          position: 1000,
        },
      ],
    },
    { id: '__unassigned', name: 'Sem responsável', deals: [] },
  ];

  it('updates the card in place instead of moving it', () => {
    const next = applyDealEvent(byOwner(), {
      type: 'updated',
      deal: {
        id: 1,
        account_id: 7,
        crm_pipeline_stage_id: 20,
        score_total: 90,
      },
    });

    expect(next[0].deals[0].score_total).toBe(90);
    expect(next[1].deals).toEqual([]);
  });

  // O payload do realtime continua leve: mesclar, nunca sobrescrever.
  it('keeps what the board already fetched', () => {
    const next = applyDealEvent(byOwner(), {
      type: 'updated',
      deal: { id: 1, account_id: 7, score_total: 90 },
    });

    expect(next[0].deals[0].owner_id).toBe(3);
  });

  it('still takes a deleted card off the board', () => {
    const next = applyDealEvent(byOwner(), {
      type: 'deleted',
      deal: { id: 1, account_id: 7 },
    });

    expect(next[0].deals).toEqual([]);
  });

  it('leaves the board untouched when nothing matches', () => {
    const columns = byOwner();

    expect(
      applyDealEvent(columns, { type: 'updated', deal: { id: 404 } })
    ).toBe(columns);
  });

  describe('um negocio novo', () => {
    // Saber em que balde ele cai exigiria repetir no cliente a regra do
    // servidor. O board pergunta de novo em vez de adivinhar.
    it('is reported as impossible to place', () => {
      expect(
        isUnplaceable(byOwner(), { type: 'created', deal: { id: 99 } })
      ).toBe(true);
    });

    it('is placeable once it is already on the board', () => {
      expect(
        isUnplaceable(byOwner(), { type: 'updated', deal: { id: 1 } })
      ).toBe(false);
    });

    it('is placeable when the board is grouped by stage', () => {
      const columns = [{ id: '10', stage_id: 10, name: 'Novo', deals: [] }];

      expect(
        isUnplaceable(columns, { type: 'created', deal: { id: 99 } })
      ).toBe(false);
    });

    it('does not ask for a reload just to delete a card', () => {
      expect(
        isUnplaceable(byOwner(), { type: 'deleted', deal: { id: 99 } })
      ).toBe(false);
    });
  });
});

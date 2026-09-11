import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';

import CrmIndex from './CrmIndexOperational.vue';

// Achados HIGH da revisão do frontend (F1.8/F2.1/F2.2):
//
// 1. Arrastar entre colunas não tinha **nenhum** teste de integração. É onde a
//    fiação real vive: quem decide `isBusy`, quem chama `moveDeal`, quem
//    desfaz quando o servidor recusa.
// 2. Os agregados do cabeçalho (contagem, R$, WIP) vinham do servidor e ficavam
//    obsoletos depois do arrasto — um escritório podia estourar o limite de WIP
//    arrastando e o indicador continuar verde.
// 3. Descartar não tirava o card do quadro: ficava lá, com aparência de ativo.

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(55) }),
}));

vi.mock('dashboard/components/crm/CRMKanbanChatDrawer.vue', () => ({
  default: { name: 'CRMKanbanChatDrawer', template: '<div />' },
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getBoard: vi.fn(),
    getPipelines: vi.fn(),
    getLossReasons: vi.fn(),
    getColumnPage: vi.fn(),
    moveDeal: vi.fn(),
    discardDeal: vi.fn(),
    markDealBaseClient: vi.fn(),
    recomputeScore: vi.fn(),
    bulkActionDeals: vi.fn(),
    createDeal: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const card = (id, stageId, valueCents = 100_000) => ({
  id,
  account_id: 55,
  title: `Negócio ${id}`,
  status: 'open',
  operational_status: 'active',
  crm_pipeline_stage_id: stageId,
  value_estimate_cents: valueCents,
  position: id * 1000,
});

const mountBoard = async () => {
  CrmAPI.getPipelines.mockResolvedValue({ data: [{ id: 1, name: 'Kanban' }] });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  CrmAPI.getBoard.mockResolvedValue({
    data: {
      pipeline: { id: 1, name: 'Kanban' },
      columns: [
        {
          id: '10',
          stage_id: 10,
          name: 'Novo',
          position: 0,
          count: 3,
          open_count: 3,
          sum_value_cents: 300_000,
          wip_limit: null,
          over_wip: false,
          deals: [card(1, 10), card(2, 10), card(3, 10)],
        },
        {
          id: '20',
          stage_id: 20,
          name: 'Qualificado',
          position: 1,
          count: 1,
          open_count: 1,
          sum_value_cents: 100_000,
          wip_limit: 2,
          over_wip: false,
          deals: [card(9, 20)],
        },
      ],
      meta: { per_column: 25 },
    },
  });

  const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

// `stage_id` e nao `id`: a coluna so e uma etapa no agrupamento por etapa.
const columnOf = (wrapper, id) =>
  wrapper.vm.columns.find(column => column.stage_id === id);

// O evento que o vuedraggable emite quando um card entra numa coluna.
const added = deal => ({ added: { element: deal, newIndex: 0 } });

describe('CrmIndexOperational — arrastar entre colunas', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  it('tells the server where the card landed', async () => {
    CrmAPI.moveDeal.mockResolvedValue({
      data: card(1, 20),
    });
    const wrapper = await mountBoard();

    await wrapper.vm.onDealMoved(
      added(columnOf(wrapper, 10).deals[0]),
      columnOf(wrapper, 20)
    );
    await flushPromises();

    expect(CrmAPI.moveDeal).toHaveBeenCalledWith(1, 20);
  });

  it('moves through the native mouse handle when the library drag does not start', async () => {
    CrmAPI.moveDeal.mockResolvedValue({ data: card(1, 20) });
    const wrapper = await mountBoard();
    const moving = columnOf(wrapper, 10).deals[0];
    const dataTransfer = {
      effectAllowed: '',
      setData: vi.fn(),
    };

    wrapper.vm.onNativeDragStart(moving, { dataTransfer });
    await wrapper.vm.onNativeDrop(columnOf(wrapper, 20));
    await flushPromises();

    expect(dataTransfer.effectAllowed).toBe('move');
    expect(dataTransfer.setData).toHaveBeenCalledWith('text/plain', '1');
    expect(CrmAPI.moveDeal).toHaveBeenCalledWith(1, 20);
    expect(columnOf(wrapper, 20).deals.map(deal => deal.id)).toContain(1);
  });

  describe('os agregados do cabeçalho', () => {
    it('move the count from one column to the other', async () => {
      CrmAPI.moveDeal.mockResolvedValue({ data: card(1, 20) });
      const wrapper = await mountBoard();

      await wrapper.vm.onDealMoved(
        added(columnOf(wrapper, 10).deals[0]),
        columnOf(wrapper, 20)
      );
      await flushPromises();

      expect(columnOf(wrapper, 10).count).toBe(2);
      expect(columnOf(wrapper, 20).count).toBe(2);
    });

    it('moves the money too', async () => {
      CrmAPI.moveDeal.mockResolvedValue({ data: card(1, 20) });
      const wrapper = await mountBoard();

      await wrapper.vm.onDealMoved(
        added(columnOf(wrapper, 10).deals[0]),
        columnOf(wrapper, 20)
      );
      await flushPromises();

      expect(columnOf(wrapper, 10).sum_value_cents).toBe(200_000);
      expect(columnOf(wrapper, 20).sum_value_cents).toBe(200_000);
    });

    // Um escritório podia estourar o limite arrastando e o indicador continuar
    // verde até o próximo reload.
    it('trips the WIP limit as soon as the drop puts the column over it', async () => {
      CrmAPI.moveDeal.mockResolvedValue({ data: card(1, 20) });
      const wrapper = await mountBoard();
      expect(columnOf(wrapper, 20).over_wip).toBe(false);

      await wrapper.vm.onDealMoved(
        added(columnOf(wrapper, 10).deals[0]),
        columnOf(wrapper, 20)
      );
      await wrapper.vm.onDealMoved(
        added(columnOf(wrapper, 10).deals[0]),
        columnOf(wrapper, 20)
      );
      await flushPromises();

      expect(columnOf(wrapper, 20).open_count).toBe(3);
      expect(columnOf(wrapper, 20).over_wip).toBe(true);
    });
  });

  describe('quando o servidor recusa', () => {
    it('puts the card back in the column it came from', async () => {
      CrmAPI.moveDeal.mockRejectedValue({
        response: { data: { message: 'Etapa exige campos obrigatórios.' } },
      });
      const wrapper = await mountBoard();

      await wrapper.vm.onDealMoved(
        added(columnOf(wrapper, 10).deals[0]),
        columnOf(wrapper, 20)
      );
      await flushPromises();

      expect(wrapper.vm.error).toBe('Etapa exige campos obrigatórios.');
      expect(columnOf(wrapper, 10).deals.map(deal => deal.id)).toContain(1);
      expect(columnOf(wrapper, 20).deals.map(deal => deal.id)).not.toContain(1);
    });

    it('gives the count back as well', async () => {
      CrmAPI.moveDeal.mockRejectedValue({ response: { data: {} } });
      const wrapper = await mountBoard();

      await wrapper.vm.onDealMoved(
        added(columnOf(wrapper, 10).deals[0]),
        columnOf(wrapper, 20)
      );
      await flushPromises();

      expect(columnOf(wrapper, 10).count).toBe(3);
      expect(columnOf(wrapper, 20).count).toBe(1);
    });
  });

  // Princípio 3 do plano: evento de outro usuário nunca sobrescreve edição
  // local em andamento.
  describe('o realtime durante o arrasto', () => {
    it('marks the card as busy while it is being dragged', async () => {
      const wrapper = await mountBoard();

      wrapper.vm.onDragStart(columnOf(wrapper, 10).deals[0]);

      expect(wrapper.vm.draggingDealId).toBe(1);
    });

    it('lets go and drains the queue when the card is dropped', async () => {
      const wrapper = await mountBoard();
      wrapper.vm.onDragStart(columnOf(wrapper, 10).deals[0]);

      wrapper.vm.onDragEnd();

      expect(wrapper.vm.draggingDealId).toBe(null);
    });
  });
});

describe('CrmIndexOperational — descartar tira o card do quadro', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  // Descartado deixou o funil. Mesclar `operational_status` e manter o card no
  // quadro mostrava um lead ativo que não existe mais.
  it('removes the discarded deal from the column', async () => {
    CrmAPI.discardDeal.mockResolvedValue({
      data: { ...card(1, 10), operational_status: 'spam', status: 'archived' },
    });
    const wrapper = await mountBoard();

    wrapper.vm.discardTarget = columnOf(wrapper, 10).deals[0];
    await wrapper.vm.discard();
    await flushPromises();

    expect(columnOf(wrapper, 10).deals.map(deal => deal.id)).not.toContain(1);
  });

  it('gives the column count back too', async () => {
    CrmAPI.discardDeal.mockResolvedValue({
      data: { ...card(1, 10), operational_status: 'spam', status: 'archived' },
    });
    const wrapper = await mountBoard();

    wrapper.vm.discardTarget = columnOf(wrapper, 10).deals[0];
    await wrapper.vm.discard();
    await flushPromises();

    expect(columnOf(wrapper, 10).count).toBe(2);
  });

  it('leaves the board alone when the discard fails', async () => {
    CrmAPI.discardDeal.mockRejectedValue({
      response: { data: { message: 'Negócio já encerrado.' } },
    });
    const wrapper = await mountBoard();

    wrapper.vm.discardTarget = columnOf(wrapper, 10).deals[0];
    await wrapper.vm.discard();
    await flushPromises();

    expect(columnOf(wrapper, 10).deals.map(deal => deal.id)).toContain(1);
    expect(columnOf(wrapper, 10).count).toBe(3);
  });
});

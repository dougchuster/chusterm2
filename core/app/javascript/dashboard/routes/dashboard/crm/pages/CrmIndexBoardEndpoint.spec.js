import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';

import CrmIndex from './CrmIndexOperational.vue';

// F2.2 do PLANO-KANBAN-CRM-2026.md, primeira parte.
//
// A lacuna K-01 — "carrega todos os negócios do pipeline e filtra no cliente" —
// continuava viva no board mesmo depois da F1.4 e da F1.5: `fetchAllCrmDeals`
// pagina até esvaziar o pipeline. Com 5.000 negócios são 25 requisições e 5.000
// cards no DOM.
//
// Virtualizar renderizaria menos de um conjunto que continuaria chegando
// inteiro. Consumir o endpoint de colunas ataca a causa: uma requisição, 25
// cards por coluna, e os totais da coluna vindos do servidor — não da contagem
// do que coube na tela.

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
    getColumnPage: vi.fn(),
    getBoardViews: vi.fn(() => Promise.resolve({ data: [] })),
    createBoardView: vi.fn(),
    updateBoardView: vi.fn(),
    deleteBoardView: vi.fn(),
    getDeals: vi.fn(),
    getPipelines: vi.fn(),
    getLossReasons: vi.fn(),
    moveDeal: vi.fn(),
    bulkActionDeals: vi.fn(),
    createDeal: vi.fn(),
    discardDeal: vi.fn(),
    markDealBaseClient: vi.fn(),
    recomputeScore: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const card = (id, stageId) => ({
  id,
  account_id: 55,
  title: `Negócio ${id}`,
  status: 'open',
  crm_pipeline_stage_id: stageId,
  position: id * 1000,
});

const column = (id, name, { count, cards }) => ({
  id: String(id),
  stage_id: id,
  name,
  position: id,
  count,
  open_count: count,
  sum_value_cents: count * 100_000,
  avg_days_in_stage: 3.5,
  wip_limit: null,
  over_wip: false,
  deals: cards,
});

const boardWith = ({ novoCards = 25, novoCount = 1200 } = {}) => ({
  data: {
    pipeline: { id: 1, name: 'Kanban', slug: 'kanban' },
    columns: [
      column(10, 'Novo', {
        count: novoCount,
        cards: Array.from({ length: novoCards }, (_, index) =>
          card(index + 1, 10)
        ),
      }),
      column(20, 'Qualificado', { count: 4, cards: [card(900, 20)] }),
    ],
    meta: { per_column: 25 },
  },
});

const mountBoard = async (board = boardWith()) => {
  CrmAPI.getPipelines.mockResolvedValue({ data: [{ id: 1, name: 'Kanban' }] });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  CrmAPI.getBoard.mockResolvedValue(board);

  const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

describe('CrmIndexOperational — o board pinta com uma requisição', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  it('asks the board endpoint instead of paginating every deal in the pipeline', async () => {
    await mountBoard();

    expect(CrmAPI.getBoard).toHaveBeenCalledTimes(1);
    expect(CrmAPI.getDeals).not.toHaveBeenCalled();
  });

  it('builds the columns from the answer, in the order the server sent', async () => {
    const wrapper = await mountBoard();

    expect(wrapper.vm.columns.map(item => item.name)).toEqual([
      'Novo',
      'Qualificado',
    ]);
  });

  // O cabeçalho tem que dizer quantos negócios a coluna tem, não quantos
  // couberam na primeira página. Contar `deals.length` mostraria 25 de 1.200.
  it('shows the column total the server counted, not the cards it received', async () => {
    const wrapper = await mountBoard();

    const novo = wrapper.vm.columns[0];
    expect(novo.count).toBe(1200);
    expect(novo.deals).toHaveLength(25);
  });

  it('carries the money and the age the server aggregated', async () => {
    const wrapper = await mountBoard();

    expect(wrapper.vm.columns[0].sum_value_cents).toBe(120_000_000);
    expect(wrapper.vm.columns[0].avg_days_in_stage).toBe(3.5);
  });

  // K-01: filtrar deixa de ser trabalho do navegador.
  it('sends the filters to the server instead of sieving in the browser', async () => {
    const wrapper = await mountBoard();
    CrmAPI.getBoard.mockClear();

    wrapper.vm.search = 'maria';
    wrapper.vm.ownerId = '9';
    await wrapper.vm.applyFilters();
    await flushPromises();

    expect(CrmAPI.getBoard).toHaveBeenCalledWith(
      wrapper.vm.pipelineId,
      // F2.6: os criterios viram listas, que e o formato que a F1.4 aceita.
      expect.objectContaining({ q: 'maria', owner_id: ['9'] })
    );
  });

  it('keeps the DOM proportional to what fits on screen, not to the pipeline', async () => {
    const wrapper = await mountBoard();

    // 25 + 1 cards enviados para 1.204 negócios no pipeline.
    const rendered = wrapper.findAll('[data-testid="crm-board-card"]');
    expect(rendered).toHaveLength(26);
  });

  it('reports the failure instead of leaving an empty board with no explanation', async () => {
    CrmAPI.getPipelines.mockResolvedValue({
      data: [{ id: 1, name: 'Kanban' }],
    });
    CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
    CrmAPI.getBoard.mockRejectedValue({
      response: { data: { message: 'Pipeline não encontrado.' } },
    });

    const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
    await flushPromises();

    expect(wrapper.vm.error).toBe('Pipeline não encontrado.');
  });

  // Dívida B-12: com 25 cards por coluna, quem tem 1.200 negócios precisa
  // alcançar o resto. O `getColumnPage` da F1.6 existia sem consumidor.
  describe('alcançar o resto da coluna', () => {
    it('asks for the next page when the column is scrolled', async () => {
      CrmAPI.getColumnPage.mockResolvedValue({
        data: { data: [card(26, 10)], meta: { total: 1200 } },
      });
      const wrapper = await mountBoard();

      await wrapper.vm.loadMoreInColumn(wrapper.vm.columns[0]);

      expect(CrmAPI.getColumnPage).toHaveBeenCalledWith(
        10,
        expect.objectContaining({ page: 2, perPage: 25 })
      );
      expect(wrapper.vm.columns[0].deals).toHaveLength(26);
    });

    it('carries the same filters the board is showing', async () => {
      CrmAPI.getColumnPage.mockResolvedValue({ data: { data: [] } });
      const wrapper = await mountBoard();
      // O filtro **aplicado**, nao o que esta sendo digitado: a pagina da
      // coluna tem que continuar a mesma consulta que pintou o board.
      wrapper.vm.search = 'maria';
      await wrapper.vm.applyFilters();

      await wrapper.vm.loadMoreInColumn(wrapper.vm.columns[0]);

      expect(CrmAPI.getColumnPage).toHaveBeenCalledWith(
        10,
        expect.objectContaining({ q: 'maria' })
      );
    });

    it('does not ask when every deal in the column already arrived', async () => {
      const wrapper = await mountBoard(
        boardWith({ novoCards: 3, novoCount: 3 })
      );

      await wrapper.vm.loadMoreInColumn(wrapper.vm.columns[0]);

      expect(CrmAPI.getColumnPage).not.toHaveBeenCalled();
    });

    // O offset da F1.6 não sobrevive a uma reordenação no meio da rolagem
    // (dívida B-08). Descartar repetidos é mais barato que mostrar o mesmo card
    // duas vezes.
    it('drops a card the column already had, instead of showing it twice', async () => {
      CrmAPI.getColumnPage.mockResolvedValue({
        data: { data: [card(1, 10), card(26, 10)] },
      });
      const wrapper = await mountBoard();

      await wrapper.vm.loadMoreInColumn(wrapper.vm.columns[0]);

      const ids = wrapper.vm.columns[0].deals.map(deal => deal.id);
      expect(ids).toHaveLength(26);
      expect(new Set(ids).size).toBe(26);
    });

    it('reports the failure instead of leaving the column silently short', async () => {
      CrmAPI.getColumnPage.mockRejectedValue({
        response: { data: { message: 'Coluna indisponível.' } },
      });
      const wrapper = await mountBoard();

      await wrapper.vm.loadMoreInColumn(wrapper.vm.columns[0]);

      expect(wrapper.vm.error).toBe('Coluna indisponível.');
    });
  });

  // F2.7 — visões salvas (lacuna K-05).
  describe('aplicar uma visão salva', () => {
    const view = {
      id: 7,
      name: 'Sem próxima ação',
      is_mine: true,
      filters: { has_pending_activity: false, stage_id: [10] },
    };

    // Mesclar deixaria resto de filtro anterior pendurado, e o atendente veria
    // um board que não é o da visão que ele escolheu.
    it('replaces the whole filter state instead of merging', async () => {
      const wrapper = await mountBoard();
      wrapper.vm.search = 'maria';
      await wrapper.vm.applyFilters();
      CrmAPI.getBoard.mockClear();

      await wrapper.vm.applyView(view);

      const [, params] = CrmAPI.getBoard.mock.calls.at(-1);
      expect(params.has_pending_activity).toBe(false);
      expect(params.stage_id).toEqual([10]);
      expect(params).not.toHaveProperty('q');
    });

    it('marks which view is showing', async () => {
      const wrapper = await mountBoard();

      await wrapper.vm.applyView(view);

      expect(wrapper.vm.activeViewId).toBe(7);
    });

    // Mexeu no filtro a mão: o que está na tela não é mais a visão salva, e o
    // menu não pode continuar dizendo que é.
    it('stops claiming a view once the filter is changed by hand', async () => {
      const wrapper = await mountBoard();
      await wrapper.vm.applyView(view);

      wrapper.vm.search = 'maria';
      await wrapper.vm.applyFilters();

      expect(wrapper.vm.activeViewId).toBeNull();
    });

    it('goes back to no filter at all when the view is cleared', async () => {
      const wrapper = await mountBoard();
      await wrapper.vm.applyView(view);

      await wrapper.vm.applyView(null);

      expect(wrapper.vm.filterPills).toEqual([]);
      expect(wrapper.vm.activeViewId).toBeNull();
    });
  });

  describe('salvar e apagar visões', () => {
    it('saves the filter that is on screen', async () => {
      CrmAPI.createBoardView.mockResolvedValue({
        data: { id: 9, name: 'Minha', is_mine: true, filters: { q: 'maria' } },
      });
      const wrapper = await mountBoard();
      wrapper.vm.search = 'maria';
      await wrapper.vm.applyFilters();

      vi.spyOn(window, 'prompt').mockReturnValue('Minha');
      wrapper.vm.promptForViewName();
      await flushPromises();

      expect(CrmAPI.createBoardView).toHaveBeenCalledWith(
        expect.objectContaining({ name: 'Minha', filters: { q: 'maria' } })
      );
      expect(wrapper.vm.boardViews.map(item => item.id)).toContain(9);
    });

    it('refuses to save a view with no name', async () => {
      const wrapper = await mountBoard();

      vi.spyOn(window, 'prompt').mockReturnValue('   ');
      wrapper.vm.promptForViewName();
      await flushPromises();

      expect(CrmAPI.createBoardView).not.toHaveBeenCalled();
    });

    it('drops the view from the menu once it is deleted', async () => {
      CrmAPI.getBoardViews.mockResolvedValue({
        data: [{ id: 7, name: 'Minha', is_mine: true, filters: {} }],
      });
      CrmAPI.deleteBoardView.mockResolvedValue({});
      const wrapper = await mountBoard();

      vi.spyOn(window, 'confirm').mockReturnValue(true);
      wrapper.vm.confirmDeleteView({ id: 7, name: 'Minha' });
      await flushPromises();

      expect(wrapper.vm.boardViews).toEqual([]);
    });

    // Visão salva é conveniência: falhar em carregar não pode derrubar o board.
    it('keeps the board working when the views cannot be loaded', async () => {
      CrmAPI.getBoardViews.mockRejectedValue(new Error('down'));

      const wrapper = await mountBoard();

      expect(wrapper.vm.boardViews).toEqual([]);
      expect(wrapper.vm.columns).toHaveLength(2);
      expect(wrapper.vm.error).toBe('');
    });
  });
});

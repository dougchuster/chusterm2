import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';

import CrmIndex from './CrmIndexOperational.vue';

// F2.1 (d) do PLANO-KANBAN-CRM-2026.md — as últimas ações que só o board Legacy
// alcançava, antes de ele ser apagado.
//
// **Recontagem pelo método corrigido na (b).** O inventário listou 10 lacunas.
// Contando o que o board alcança pelos componentes que renderiza (`CRMDealDrawer`
// e, desde a F2.1-a, o `CRMKanbanChatDrawer`), e descartando o que o próprio
// inventário já classificava como não-lacuna (`createPipeline`,
// `createPipelineStage`, `getHealth`, `purgeOrphanDeals` — utilitários que
// pertencem a outras telas), sobram **três**.
//
// `getActivities` também saiu da lista, e por um motivo que vale registrar: o
// Legacy buscava as atividades numa requisição própria porque era anterior ao
// serializer carregar `next_activity_due_at` no próprio negócio. O board
// Operational já lê esse campo. Portar seria voltar a fazer uma chamada a mais.

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
    moveDeal: vi.fn(),
    bulkActionDeals: vi.fn(),
    createDeal: vi.fn(),
    discardDeal: vi.fn(),
    markDealBaseClient: vi.fn(),
    recomputeScore: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const deal = (overrides = {}) => ({
  id: 4,
  account_id: 55,
  title: 'Maria Souza',
  status: 'open',
  operational_status: 'active',
  crm_pipeline_stage_id: 10,
  ...overrides,
});

const mountBoard = async () => {
  CrmAPI.getPipelines.mockResolvedValue({ data: [{ id: 1, name: 'Kanban' }] });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  CrmAPI.getBoard.mockResolvedValue({
    data: {
      pipeline: { id: 1, name: 'Kanban' },
      columns: [
        { id: 10, name: 'Novo', position: 0, count: 1, deals: [deal()] },
      ],
      meta: { per_column: 25 },
    },
  });

  const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

describe('CrmIndexOperational — ações do card que só o Legacy tinha', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  describe('descartar pelo card', () => {
    it('sends the reason the attendant picked', async () => {
      CrmAPI.discardDeal.mockResolvedValue({
        data: deal({ operational_status: 'spam' }),
      });
      const wrapper = await mountBoard();

      wrapper.vm.discardTarget = wrapper.vm.deals[0];
      wrapper.vm.dispositionReason = 'spam';
      await wrapper.vm.discard();

      expect(CrmAPI.discardDeal).toHaveBeenCalledWith(4, { reason: 'spam' });
      // Descartado deixa o funil: o card sai do quadro, e nao fica com um
      // `operational_status` novo fingindo que continua ativo.
      expect(wrapper.vm.deals.map(item => item.id)).not.toContain(4);
    });

    it('offers the four reasons the backend accepts', async () => {
      const wrapper = await mountBoard();

      expect(wrapper.vm.dispositionOptions.map(item => item.value)).toEqual([
        'invalid',
        'spam',
        'duplicated',
        'no_lead',
      ]);
    });

    it('shows the error instead of leaving the card unchanged and silent', async () => {
      CrmAPI.discardDeal.mockRejectedValue({
        response: { data: { message: 'Negócio já encerrado.' } },
      });
      const wrapper = await mountBoard();
      wrapper.vm.discardTarget = wrapper.vm.deals[0];

      await wrapper.vm.discard();

      expect(wrapper.vm.error).toBe('Negócio já encerrado.');
      expect(wrapper.vm.deals[0].operational_status).toBe('active');
    });
  });

  describe('marcar como cliente da base pelo card', () => {
    // Regra de produto 10: cliente antigo não é lead novo.
    it('applies the answer to the card', async () => {
      CrmAPI.markDealBaseClient.mockResolvedValue({
        data: deal({ operational_status: 'base_client' }),
      });
      const wrapper = await mountBoard();

      await wrapper.vm.markBaseClient(wrapper.vm.deals[0]);

      expect(CrmAPI.markDealBaseClient).toHaveBeenCalledWith(4);
      expect(wrapper.vm.deals[0].operational_status).toBe('base_client');
    });
  });

  describe('recalcular o score pelo card', () => {
    it('asks the server to recompute', async () => {
      CrmAPI.recomputeScore.mockResolvedValue({ data: {} });
      const wrapper = await mountBoard();

      await wrapper.vm.recomputeScore(wrapper.vm.deals[0]);

      expect(CrmAPI.recomputeScore).toHaveBeenCalledWith(4);
    });

    it('surfaces the error', async () => {
      CrmAPI.recomputeScore.mockRejectedValue({
        response: { data: { message: 'Scoring desativado neste pipeline.' } },
      });
      const wrapper = await mountBoard();

      await wrapper.vm.recomputeScore(wrapper.vm.deals[0]);

      expect(wrapper.vm.error).toBe('Scoring desativado neste pipeline.');
    });
  });

  // O board não busca atividades: o negócio já chega com a próxima ação.
  it('does not fetch activities separately, the deal already carries the next action', async () => {
    const wrapper = await mountBoard();

    expect(CrmAPI.getActivities).toBeUndefined();
    expect(wrapper.vm.deals[0]).not.toHaveProperty('activities');
  });
});

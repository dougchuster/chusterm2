import { flushPromises, mount } from '@vue/test-utils';

import CrmAPI from 'dashboard/api/crm';

import AllLeads from './AllLeadsOperational.vue';

// F2.1 (c) do PLANO-KANBAN-CRM-2026.md — a lista de leads precisa alcançar o
// que só o Legacy alcançava, antes de o Legacy ser apagado.
//
// **Recontagem pelo método corrigido na (b):** o inventário da F0.2 listou 7
// lacunas aqui. Três delas — `deleteDeal`, `markDealWon`, `updateDeal` — são
// alcançadas pelo `CRMDealDrawer`, que esta página já renderiza. As lacunas
// reais são quatro.

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getDeals: vi.fn(),
    getPipelines: vi.fn(),
    getPipelineStages: vi.fn(),
    getActivities: vi.fn(),
    bulkActionDeals: vi.fn(),
    createDeal: vi.fn(),
    moveDeal: vi.fn(),
    discardDeal: vi.fn(),
    markDealBaseClient: vi.fn(),
    recomputeScore: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const deal = (overrides = {}) => ({
  id: 4,
  title: 'Lead da lista',
  status: 'open',
  operational_status: 'active',
  crm_pipeline_stage_id: 10,
  score_total: 55,
  ...overrides,
});

const mountPage = async () => {
  CrmAPI.getDeals.mockResolvedValue({
    data: { data: [deal()], meta: { total: 1 } },
  });
  CrmAPI.getPipelines.mockResolvedValue({ data: [{ id: 1, name: 'Kanban' }] });
  CrmAPI.getPipelineStages.mockResolvedValue({
    data: [
      { id: 10, name: 'Novo' },
      { id: 20, name: 'Qualificado' },
    ],
  });
  CrmAPI.getActivities.mockResolvedValue({ data: [] });

  const wrapper = mount(AllLeads, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

describe('AllLeadsOperational — ações que só o Legacy alcançava', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // jsdom nao implementa <dialog>; o DsModal chama showModal ao abrir.
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  describe('mover de etapa pela lista', () => {
    it('sends the move to the server', async () => {
      CrmAPI.moveDeal.mockResolvedValue({
        data: deal({ crm_pipeline_stage_id: 20 }),
      });
      const wrapper = await mountPage();

      await wrapper.vm.moveToStage(wrapper.vm.deals[0], 20);

      expect(CrmAPI.moveDeal).toHaveBeenCalledWith(4, 20);
      expect(wrapper.vm.deals[0].crm_pipeline_stage_id).toBe(20);
    });

    // Otimismo com rollback é princípio 2 do plano: a UI muda na hora, e o erro
    // devolve a linha para onde ela estava.
    it('puts the row back where it was when the server refuses', async () => {
      CrmAPI.moveDeal.mockRejectedValue({
        response: { data: { message: 'Etapa exige campos obrigatórios.' } },
      });
      const wrapper = await mountPage();

      await wrapper.vm.moveToStage(wrapper.vm.deals[0], 20);

      expect(wrapper.vm.deals[0].crm_pipeline_stage_id).toBe(10);
      expect(wrapper.vm.error).toBe('Etapa exige campos obrigatórios.');
    });

    it('does nothing when the stage did not change', async () => {
      const wrapper = await mountPage();

      await wrapper.vm.moveToStage(wrapper.vm.deals[0], 10);

      expect(CrmAPI.moveDeal).not.toHaveBeenCalled();
    });
  });

  describe('descartar pela lista', () => {
    it('sends the reason the attendant picked', async () => {
      CrmAPI.discardDeal.mockResolvedValue({
        data: deal({ operational_status: 'duplicated' }),
      });
      const wrapper = await mountPage();

      wrapper.vm.discardTarget = wrapper.vm.deals[0];
      wrapper.vm.dispositionReason = 'duplicated';
      await wrapper.vm.discard();

      expect(CrmAPI.discardDeal).toHaveBeenCalledWith(4, {
        reason: 'duplicated',
      });
      expect(wrapper.vm.deals[0].operational_status).toBe('duplicated');
    });

    it('offers the four reasons the backend accepts', async () => {
      const wrapper = await mountPage();

      expect(wrapper.vm.dispositionOptions.map(item => item.value)).toEqual([
        'invalid',
        'spam',
        'duplicated',
        'no_lead',
      ]);
    });
  });

  describe('marcar como cliente da base', () => {
    // Regra de produto 10: cliente antigo não é lead novo.
    it('applies the answer to the row', async () => {
      CrmAPI.markDealBaseClient.mockResolvedValue({
        data: deal({ operational_status: 'base_client' }),
      });
      const wrapper = await mountPage();

      await wrapper.vm.markBaseClient(wrapper.vm.deals[0]);

      expect(CrmAPI.markDealBaseClient).toHaveBeenCalledWith(4);
      expect(wrapper.vm.deals[0].operational_status).toBe('base_client');
    });

    it('reports the failure instead of leaving the row lying', async () => {
      CrmAPI.markDealBaseClient.mockRejectedValue({
        response: { data: { message: 'Contato não encontrado.' } },
      });
      const wrapper = await mountPage();

      await wrapper.vm.markBaseClient(wrapper.vm.deals[0]);

      expect(wrapper.vm.error).toBe('Contato não encontrado.');
      expect(wrapper.vm.deals[0].operational_status).toBe('active');
    });
  });

  describe('recalcular o score', () => {
    it('asks the server to recompute', async () => {
      CrmAPI.recomputeScore.mockResolvedValue({ data: {} });
      const wrapper = await mountPage();

      await wrapper.vm.recomputeScore(wrapper.vm.deals[0]);

      expect(CrmAPI.recomputeScore).toHaveBeenCalledWith(4);
    });

    it('surfaces the error', async () => {
      CrmAPI.recomputeScore.mockRejectedValue({
        response: { data: { message: 'Scoring desativado neste pipeline.' } },
      });
      const wrapper = await mountPage();

      await wrapper.vm.recomputeScore(wrapper.vm.deals[0]);

      expect(wrapper.vm.error).toBe('Scoring desativado neste pipeline.');
    });
  });
});

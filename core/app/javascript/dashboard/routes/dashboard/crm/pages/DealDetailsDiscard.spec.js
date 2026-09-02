import { flushPromises, mount } from '@vue/test-utils';

import CrmAPI from 'dashboard/api/crm';

import DealDetails from './DealDetailsOperational.vue';

// F2.1 (b) do PLANO-KANBAN-CRM-2026.md — a ficha do negócio precisa alcançar o
// que só o Legacy alcançava antes de o Legacy ser apagado.
//
// **Correção ao inventário da F0.2:** ele listou duas lacunas aqui,
// `deleteDeal` e `discardDeal`. `deleteDeal` não era lacuna — o
// `CRMDealDrawer`, que esta página já renderiza, exclui o negócio e emite
// `dealDeleted`. O método do inventário (procurar `CrmAPI.` no arquivo da
// página) não enxerga o que a página alcança pelos componentes que renderiza.
// A lacuna real era uma só: descartar.

const push = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55', dealId: '7' } }),
  useRouter: () => ({ push }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getDeal: vi.fn(),
    getAuditEvents: vi.fn(),
    getLossReasons: vi.fn(),
    getPipelineStages: vi.fn(),
    discardDeal: vi.fn(),
    markDealWon: vi.fn(),
    markDealLost: vi.fn(),
    markDealBaseClient: vi.fn(),
    reopenDeal: vi.fn(),
    recomputeScore: vi.fn(),
    moveDeal: vi.fn(),
    updateDeal: vi.fn(),
    createActivity: vi.fn(),
    completeActivity: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const deal = {
  id: 7,
  title: 'Revisão de contrato',
  status: 'open',
  operational_status: 'active',
  crm_pipeline_stage_id: 3,
  contact_id: 11,
};

const mountPage = async () => {
  CrmAPI.getDeal.mockResolvedValue({ data: deal });
  CrmAPI.getAuditEvents.mockResolvedValue({ data: [] });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  CrmAPI.getPipelineStages.mockResolvedValue({ data: [] });

  const wrapper = mount(DealDetails, {
    global: { stubs: { teleport: true } },
  });
  await flushPromises();
  return wrapper;
};

describe('DealDetailsOperational — descartar negócio', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // jsdom nao implementa <dialog>; o DsModal chama showModal ao abrir.
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  it('exposes a discard action, which only the legacy page had', async () => {
    const wrapper = await mountPage();

    expect(wrapper.html()).toContain('Descartar');
  });

  it('sends the reason the attendant picked, not a hardcoded one', async () => {
    CrmAPI.discardDeal.mockResolvedValue({
      data: { ...deal, operational_status: 'spam' },
    });
    const wrapper = await mountPage();

    wrapper.vm.dispositionReason = 'spam';
    await wrapper.vm.discard();

    expect(CrmAPI.discardDeal).toHaveBeenCalledWith(7, { reason: 'spam' });
  });

  it('offers the four reasons the backend accepts', async () => {
    const wrapper = await mountPage();

    expect(wrapper.vm.dispositionOptions.map(option => option.value)).toEqual([
      'invalid',
      'spam',
      'duplicated',
      'no_lead',
    ]);
  });

  it('applies the answer to the deal on screen instead of refetching', async () => {
    CrmAPI.discardDeal.mockResolvedValue({
      data: { ...deal, operational_status: 'duplicated' },
    });
    const wrapper = await mountPage();
    CrmAPI.getDeal.mockClear();

    wrapper.vm.dispositionReason = 'duplicated';
    await wrapper.vm.discard();

    expect(wrapper.vm.deal.operational_status).toBe('duplicated');
    expect(CrmAPI.getDeal).not.toHaveBeenCalled();
  });

  it('shows the error instead of failing silently', async () => {
    CrmAPI.discardDeal.mockRejectedValue({
      response: { data: { message: 'Negócio já encerrado.' } },
    });
    const wrapper = await mountPage();

    await wrapper.vm.discard();

    expect(wrapper.vm.error).toBe('Negócio já encerrado.');
  });

  it('closes the modal once the discard goes through', async () => {
    CrmAPI.discardDeal.mockResolvedValue({ data: deal });
    const wrapper = await mountPage();
    wrapper.vm.showDiscardModal = true;

    await wrapper.vm.discard();

    expect(wrapper.vm.showDiscardModal).toBe(false);
  });
});

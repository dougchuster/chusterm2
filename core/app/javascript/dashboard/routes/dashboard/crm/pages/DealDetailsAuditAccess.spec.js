import { flushPromises, mount } from '@vue/test-utils';

import CrmAPI from 'dashboard/api/crm';

import DealDetails from './DealDetailsOperational.vue';

// Check-up 2026-09-18: CrmAuditEventPolicy#index? só libera administrador.
// Para agente a página pedia audit-events, recebia 401 e a aba "Histórico"
// mostrava "Nenhuma alteração registrada" — não pode nem pedir nem mostrar.

const role = { value: 'agent' };

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55', dealId: '7' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
  useStoreGetters: () => ({ getCurrentRole: role }),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getDeal: vi.fn(),
    getAuditEvents: vi.fn(),
    getLossReasons: vi.fn(),
    getPipelineStages: vi.fn(),
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
  const wrapper = mount(DealDetails, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

const tabLabels = wrapper =>
  wrapper
    .findAll('[role="tab"]')
    .map(tab => tab.text().replace(/\d+$/, '').trim());

describe('DealDetailsOperational — histórico por papel', () => {
  beforeEach(() => vi.clearAllMocks());

  it('agente não pede audit-events nem vê a aba Histórico', async () => {
    role.value = 'agent';

    const wrapper = await mountPage();

    expect(CrmAPI.getAuditEvents).not.toHaveBeenCalled();
    expect(tabLabels(wrapper)).not.toContain('Histórico');
  });

  it('administrador pede audit-events e vê a aba Histórico', async () => {
    role.value = 'administrator';

    const wrapper = await mountPage();

    expect(CrmAPI.getAuditEvents).toHaveBeenCalledWith({
      target_type: 'CrmDeal',
      target_id: 7,
    });
    expect(tabLabels(wrapper)).toContain('Histórico');
  });
});

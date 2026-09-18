import { flushPromises, mount } from '@vue/test-utils';
import { reactive, ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';

import CrmIndex from './CrmIndexOperational.vue';

// Regressao: trocar de funil pela sidebar muda apenas `?pipeline_id=` — a rota
// e a mesma (`crm_dashboard`) e o Vue reutiliza o componente. Sem um watcher
// sobre `route.query`, a URL apontava o funil novo e o quadro continuava
// pintando o anterior.

const route = reactive({
  params: { accountId: '55' },
  query: {},
});

vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(55) }),
}));

vi.mock('dashboard/components/crm/CRMConversationPanel.vue', () => ({
  default: { name: 'CRMConversationPanel', template: '<div />' },
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

const stageColumn = (id, name) => ({
  id: String(id),
  stage_id: id,
  name,
  position: id,
  count: 0,
  open_count: 0,
  sum_value_cents: 0,
  avg_days_in_stage: 0,
  wip_limit: null,
  over_wip: false,
  deals: [],
});

const boardFor = pipelineId => ({
  data: {
    pipeline: { id: pipelineId },
    columns: [
      stageColumn(Number(pipelineId) * 10, `Etapa do funil ${pipelineId}`),
    ],
    meta: { per_column: 25 },
  },
});

const mountBoard = async () => {
  CrmAPI.getPipelines.mockResolvedValue({
    data: [
      { id: 1, name: 'Pipeline Jurídico' },
      { id: 2, name: 'Kanban - Dra. Paula' },
    ],
  });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  CrmAPI.getBoard.mockImplementation(id => Promise.resolve(boardFor(id)));

  const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

describe('CrmIndexOperational — acompanha mudança de query na mesma rota', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    route.query = { pipeline_id: '1' };
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  it('reloads the board when the sidebar swaps pipeline_id', async () => {
    const wrapper = await mountBoard();
    expect(wrapper.vm.pipelineId).toBe('1');
    CrmAPI.getBoard.mockClear();

    route.query = { pipeline_id: '2' };
    await flushPromises();

    expect(wrapper.vm.pipelineId).toBe('2');
    expect(CrmAPI.getBoard).toHaveBeenCalledWith(
      '2',
      expect.objectContaining({ group_by: 'stage' })
    );
    expect(wrapper.vm.columns[0].name).toBe('Etapa do funil 2');
  });

  it('does not reload when the query carries the same values', async () => {
    await mountBoard();
    CrmAPI.getBoard.mockClear();

    // syncQuery re-escreve a mesma query: a comparacao impede o loop.
    route.query = { pipeline_id: '1' };
    await flushPromises();

    expect(CrmAPI.getBoard).not.toHaveBeenCalled();
  });

  it('opens the deal drawer when deal_id appears while already on the board', async () => {
    const wrapper = await mountBoard();
    expect(wrapper.vm.showDealDrawer).toBe(false);

    route.query = { pipeline_id: '1', deal_id: '42' };
    await flushPromises();

    expect(wrapper.vm.selectedDealId).toBe(42);
    expect(wrapper.vm.showDealDrawer).toBe(true);
  });

  it('falls back to the default pipeline when pipeline_id disappears', async () => {
    const wrapper = await mountBoard();
    CrmAPI.getBoard.mockClear();

    route.query = {};
    await flushPromises();

    expect(wrapper.vm.pipelineId).toBe('1');
    expect(CrmAPI.getBoard).toHaveBeenCalledWith('1', expect.anything());
  });
});

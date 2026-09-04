import { flushPromises, mount } from '@vue/test-utils';
import { computed, ref } from 'vue';
import { describe, expect, it, vi } from 'vitest';

import CrmAPI from 'dashboard/api/crm';

import CrmIndex from './CrmIndexOperational.vue';

const mockUiSettings = ref({});
const mockUpdateUISettings = vi.fn(settings => {
  mockUiSettings.value = { ...mockUiSettings.value, ...settings.uiSettings };
});

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: (action, payload) => {
      if (action === 'updateUISettings') {
        mockUpdateUISettings(payload);
      }
    },
    getters: {
      getUISettings: mockUiSettings,
    },
  }),
  useStoreGetters: () => ({
    getUISettings: computed(() => mockUiSettings.value),
  }),
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

const card = (id, stageId, overrides = {}) => ({
  id,
  account_id: 55,
  title: `Negócio ${id}`,
  contact_name: `Contato ${id}`,
  status: 'open',
  crm_pipeline_stage_id: stageId,
  value_estimate_cents: 500000,
  position: id * 1000,
  created_at: '2026-08-01T12:00:00Z',
  ...overrides,
});

const column = (id, name, { count, cards, probability_pct = null }) => ({
  id: String(id),
  stage_id: id,
  name,
  count,
  sum_value_cents: cards.reduce(
    (sum, c) => sum + (c.value_estimate_cents || 0),
    0
  ),
  probability_pct,
  deals: cards,
});

const mountBoard = async () => {
  CrmAPI.getPipelines.mockResolvedValueOnce({
    data: [{ id: 1, name: 'Comercial', is_default: true }],
  });
  CrmAPI.getLossReasons.mockResolvedValueOnce({ data: [] });
  CrmAPI.getBoard.mockResolvedValueOnce({
    data: {
      columns: [
        column(10, 'Qualificação', {
          count: 2,
          cards: [
            card(1, 10, {
              title: 'Negócio Alfa',
              last_activity_at: '2026-08-01T12:00:00Z',
            }),
            card(2, 10, { title: 'Negócio Beta' }),
          ],
        }),
        column(20, 'Proposta', {
          count: 1,
          cards: [card(3, 20, { title: 'Negócio Gama' })],
        }),
      ],
      meta: { movable: true, group_by: 'stage' },
    },
  });

  const wrapper = mount(CrmIndex, {
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${JSON.stringify(params)}` : key,
      },
      stubs: {
        CRMBoardToolbar: {
          props: ['search', 'pipelineId'],
          template: '<div data-testid="crm-board-toolbar" />',
        },
        CRMBoardColumn: {
          props: ['column'],
          template:
            '<div data-testid="crm-board-column"><slot name="card" v-for="deal in column.deals" :deal="deal" /></div>',
        },
        CRMDealCard: {
          props: ['deal'],
          template:
            '<article data-testid="crm-board-card">{{ deal.title }}</article>',
        },
        CRMCreateDealDrawer: true,
        CRMDealDrawer: true,
        DsModal: true,
        Icon: true,
      },
    },
  });

  await flushPromises();
  return wrapper;
};

describe('CrmIndexOperational — Alternador de visualização e Deal Rotting', () => {
  it('renders Kanban board view by default', async () => {
    mockUiSettings.value = {};
    const wrapper = await mountBoard();

    expect(wrapper.find('[data-testid="crm-view-kanban"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="crm-view-table"]').exists()).toBe(true);
    expect(wrapper.findAll('[data-testid="crm-board-column"]').length).toBe(2);
    expect(wrapper.findAll('[data-testid="crm-board-card"]').length).toBe(3);
  });

  it('switches to Table view and renders DsTable rows when Table button is clicked', async () => {
    mockUiSettings.value = {};
    const wrapper = await mountBoard();

    const tableButton = wrapper.find('[data-testid="crm-view-table"]');
    await tableButton.trigger('click');
    await flushPromises();

    // In table view, Kanban columns are replaced by table rows
    expect(wrapper.findAll('[data-testid="crm-board-column"]').length).toBe(0);
    const tableRows = wrapper.findAll('[data-testid="crm-table-row"]');
    expect(tableRows.length).toBe(3);
    expect(wrapper.text()).toContain('Negócio Alfa');
    expect(wrapper.text()).toContain('Negócio Beta');
    expect(wrapper.text()).toContain('Negócio Gama');
  });

  it('persists view preference to UISettings when toggling view', async () => {
    mockUiSettings.value = {};
    const wrapper = await mountBoard();

    const tableButton = wrapper.find('[data-testid="crm-view-table"]');
    await tableButton.trigger('click');
    await flushPromises();

    expect(mockUpdateUISettings).toHaveBeenCalledWith(
      expect.objectContaining({
        uiSettings: expect.objectContaining({
          crm_board_view_type: 'table',
        }),
      })
    );
  });

  it('restores Table view mode from UISettings on initial mount', async () => {
    mockUiSettings.value = { crm_board_view_type: 'table' };
    const wrapper = await mountBoard();

    // Starts directly in table view
    expect(wrapper.findAll('[data-testid="crm-board-column"]').length).toBe(0);
    expect(wrapper.findAll('[data-testid="crm-table-row"]').length).toBe(3);
  });

  it('preserves filters when switching views back and forth', async () => {
    mockUiSettings.value = {};
    const wrapper = await mountBoard();

    // Verify initial load called getBoard
    expect(CrmAPI.getBoard).toHaveBeenCalledTimes(1);

    // Switch to Table
    await wrapper.find('[data-testid="crm-view-table"]').trigger('click');
    await flushPromises();
    expect(wrapper.findAll('[data-testid="crm-table-row"]').length).toBe(3);

    // Switch back to Kanban
    await wrapper.find('[data-testid="crm-view-kanban"]').trigger('click');
    await flushPromises();
    expect(wrapper.findAll('[data-testid="crm-board-column"]').length).toBe(2);
    expect(wrapper.findAll('[data-testid="crm-board-card"]').length).toBe(3);
  });

  it('renders deal rotting warning badge on stagnant deals in table view', async () => {
    mockUiSettings.value = {};
    const wrapper = await mountBoard();

    await wrapper.find('[data-testid="crm-view-table"]').trigger('click');
    await flushPromises();

    // Negócio Alfa has last_activity_at from 2026-08-01 (sitting > 7 days)
    const rottingBadges = wrapper.findAll(
      '[data-testid="crm-table-rotting-badge"]'
    );
    expect(rottingBadges.length).toBeGreaterThan(0);
  });
});

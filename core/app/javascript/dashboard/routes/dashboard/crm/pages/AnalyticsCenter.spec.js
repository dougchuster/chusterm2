import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import SLAReportsAPI from 'dashboard/api/slaReports';
import AnalyticsCenter from './AnalyticsCenter.vue';

const mockRoute = ref({
  params: { accountId: '123' },
  query: { period: '30', tab: 'executive' },
});

const mockRouterReplace = vi.fn();
const mockRouterPush = vi.fn();
const mockUpdateUISettings = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => mockRoute.value,
  useRouter: () => ({
    replace: mockRouterReplace,
    push: mockRouterPush,
  }),
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: ref({ analytics_period: '30' }),
    updateUISettings: mockUpdateUISettings,
  }),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getMetricsOverview: vi.fn(),
    getMetricsStageFunnel: vi.fn(),
    getMetricsWinLossTrend: vi.fn(),
    getMetricsTopLossReasons: vi.fn(),
    getMetricsScoreByStage: vi.fn(),
    getMetricsAreaDistribution: vi.fn(),
    getMetricsTopDeals: vi.fn(),
    getMetricsStaleDeals: vi.fn(),
    getMetricsTimeInStage: vi.fn(),
    getDashboard: vi.fn(),
    askAnalyst: vi.fn(),
    exportDeals: vi.fn(),
  },
}));

vi.mock('dashboard/api/reports', () => ({
  default: {
    getSummary: vi.fn(),
    getInboxReports: vi.fn(),
  },
}));

vi.mock('dashboard/api/csatReports', () => ({
  default: {
    getMetrics: vi.fn(),
  },
}));

vi.mock('dashboard/api/slaReports', () => ({
  default: {
    getMetrics: vi.fn(),
  },
}));

const mockOverviewData = {
  total_deals: 42,
  open_deals: 18,
  won_deals: 15,
  lost_deals: 9,
  win_rate: 62.5,
  avg_score: 78,
  total_value: 35000000,
  won_value: 18500000,
  avg_time_to_close: 14,
};

const mockFunnelData = [
  {
    stage_id: 1,
    stage_name: 'Novo Contato',
    deal_count: 50,
    deal_value: 5000000,
  },
  {
    stage_id: 2,
    stage_name: 'Qualificação',
    deal_count: 35,
    deal_value: 3500000,
  },
  { stage_id: 3, stage_name: 'Proposta', deal_count: 20, deal_value: 2000000 },
  { stage_id: 4, stage_name: 'Fechado', deal_count: 15, deal_value: 1500000 },
];

const mockSupportSummaryData = {
  conversations_count: 128,
  incoming_messages_count: 450,
  outgoing_messages_count: 512,
  avg_first_response_time: 180,
  avg_resolution_time: 3600,
  resolutions_count: 110,
};

const mockCsatData = {
  totalResponseCount: 80,
  totalSentMessagesCount: 100,
  ratingsCount: {
    1: 2,
    2: 3,
    3: 5,
    4: 25,
    5: 45,
  },
};

const mockSlaData = {
  hitRate: '92.5%',
  numberOfSLAMisses: 6,
  numberOfConversations: 80,
};

const mockInboxReportsData = [
  {
    id: 1,
    name: 'WhatsApp Vendas',
    channel_type: 'Channel::Whatsapp',
    conversations_count: 85,
    avg_first_response_time: 120,
    avg_resolution_time: 2400,
  },
];

function setupApiMocks() {
  CrmAPI.getMetricsOverview.mockResolvedValue({ data: mockOverviewData });
  CrmAPI.getMetricsStageFunnel.mockResolvedValue({ data: mockFunnelData });
  CrmAPI.getMetricsWinLossTrend.mockResolvedValue({
    data: [
      { month: 'Jan', won: 10, lost: 4 },
      { month: 'Fev', won: 15, lost: 5 },
    ],
  });
  CrmAPI.getMetricsTopLossReasons.mockResolvedValue({
    data: [{ reason: 'Preço alto', count: 8 }],
  });
  CrmAPI.getMetricsScoreByStage.mockResolvedValue({ data: [] });
  CrmAPI.getMetricsAreaDistribution.mockResolvedValue({
    data: [{ area: 'Trabalhista', count: 12, total_value: 1200000 }],
  });
  CrmAPI.getMetricsTopDeals.mockResolvedValue({
    data: [
      {
        id: 1,
        title: 'Contrato Alpha',
        contact_name: 'João',
        stage_name: 'Proposta',
        score_total: 95,
        urgency_level: 'alta',
      },
    ],
  });
  CrmAPI.getMetricsStaleDeals.mockResolvedValue({
    data: [
      {
        id: 2,
        title: 'Lead Parado',
        stage_name: 'Qualificação',
        days_stale: 10,
      },
    ],
  });
  CrmAPI.getMetricsTimeInStage.mockResolvedValue({
    data: [
      {
        stage_name: 'Qualificação',
        avg_hours: 48,
        deal_count: 10,
        min_hours: 12,
        max_hours: 96,
      },
    ],
  });
  CrmAPI.getDashboard.mockResolvedValue({
    data: {
      overdue_activities: 3,
      priority_deals: 5,
      qualified_deals: 10,
    },
  });

  ReportsAPI.getSummary.mockResolvedValue({ data: mockSupportSummaryData });
  CSATReportsAPI.getMetrics.mockResolvedValue({ data: mockCsatData });
  SLAReportsAPI.getMetrics.mockResolvedValue({ data: mockSlaData });
  ReportsAPI.getInboxReports.mockResolvedValue({ data: mockInboxReportsData });
  CrmAPI.askAnalyst.mockResolvedValue({
    data: { answer: 'O funil apresenta boa conversão em Qualificação.' },
  });
  CrmAPI.exportDeals.mockResolvedValue({
    data: { message: 'Exportação iniciada com sucesso.' },
  });
}

const mountComponent = async () => {
  const wrapper = mount(AnalyticsCenter, {
    global: {
      stubs: {
        Icon: {
          props: ['icon'],
          template: '<span :data-icon="icon" />',
        },
      },
      mocks: {
        $t: (msg, vars) => {
          if (vars && typeof vars === 'object') {
            return `${msg} ${JSON.stringify(vars)}`;
          }
          return msg;
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('AnalyticsCenter.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockRoute.value = {
      params: { accountId: '123' },
      query: { period: '30', tab: 'executive' },
    };
    setupApiMocks();
  });

  it('renders page header and initial executive tab indicators', async () => {
    const wrapper = await mountComponent();

    expect(wrapper.text()).toContain('CRM.ANALYTICS.TITLE');
    expect(
      wrapper.find('[aria-labelledby="tab-executive-heading"]').exists()
    ).toBe(true);
    expect(CrmAPI.getMetricsOverview).toHaveBeenCalled();
    expect(ReportsAPI.getSummary).toHaveBeenCalled();
    expect(CSATReportsAPI.getMetrics).toHaveBeenCalled();
    expect(SLAReportsAPI.getMetrics).toHaveBeenCalled();
  });

  it('switches tabs reactively between Executive, Funnel, and Support', async () => {
    const wrapper = await mountComponent();

    // Default is Executive
    expect(
      wrapper.find('[aria-labelledby="tab-executive-heading"]').exists()
    ).toBe(true);

    // Switch to Funnel
    const tabButtons = wrapper.findAll('button[role="tab"]');
    expect(tabButtons.length).toBe(3);

    await tabButtons[1].trigger('click');
    await flushPromises();

    expect(mockRouterReplace).toHaveBeenCalledWith(
      expect.objectContaining({
        query: expect.objectContaining({ tab: 'funnel' }),
      })
    );
    expect(
      wrapper.find('[aria-labelledby="tab-funnel-heading"]').exists()
    ).toBe(true);

    // Switch to Support
    await tabButtons[2].trigger('click');
    await flushPromises();

    expect(mockRouterReplace).toHaveBeenCalledWith(
      expect.objectContaining({
        query: expect.objectContaining({ tab: 'support' }),
      })
    );
    expect(
      wrapper.find('[aria-labelledby="tab-support-heading"]').exists()
    ).toBe(true);
  });

  it('applies global period filter to all tabs and persists via useUISettings', async () => {
    const wrapper = await mountComponent();

    const select = wrapper.find('select');
    expect(select.exists()).toBe(true);

    // Change period to 7 days
    await select.setValue('7');
    await select.trigger('change');
    await flushPromises();

    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      analytics_period: '7',
    });
    expect(mockRouterReplace).toHaveBeenCalledWith(
      expect.objectContaining({
        query: expect.objectContaining({ period: '7' }),
      })
    );

    // Verifies CRM and Support APIs were called with new period params
    expect(CrmAPI.getMetricsOverview).toHaveBeenLastCalledWith(
      expect.objectContaining({ period_days: 7 })
    );
  });

  it('handles empty state and displays DsEmptyState components gracefully', async () => {
    CrmAPI.getMetricsOverview.mockResolvedValue({ data: {} });
    CrmAPI.getMetricsStageFunnel.mockResolvedValue({ data: [] });
    CrmAPI.getMetricsWinLossTrend.mockResolvedValue({ data: [] });
    CrmAPI.getMetricsTopLossReasons.mockResolvedValue({ data: [] });
    CrmAPI.getMetricsTopDeals.mockResolvedValue({ data: [] });
    CrmAPI.getMetricsStaleDeals.mockResolvedValue({ data: [] });
    ReportsAPI.getInboxReports.mockResolvedValue({ data: [] });
    CSATReportsAPI.getMetrics.mockResolvedValue({
      data: { totalResponseCount: 0 },
    });

    const wrapper = await mountComponent();

    // In executive tab, empty states for trends and top deals
    expect(wrapper.text()).toContain('CRM.ANALYTICS.EXECUTIVE.TRENDS.EMPTY');
    expect(wrapper.text()).toContain('CRM.ANALYTICS.EXECUTIVE.TOP_DEALS.EMPTY');
  });

  it('interacts with the AI analyst assistant', async () => {
    mockRoute.value.query.tab = 'funnel';
    const wrapper = await mountComponent();

    const input = wrapper.find('input[type="text"]');
    expect(input.exists()).toBe(true);

    await input.setValue('Qual o maior gargalo?');
    const askButton = wrapper
      .findAll('button')
      .find(b => b.text().includes('CRM.ANALYTICS.FUNNEL.ANALYST.ASK'));
    expect(askButton).toBeDefined();

    await askButton.trigger('click');
    await flushPromises();

    expect(CrmAPI.askAnalyst).toHaveBeenCalledWith(
      expect.objectContaining({
        question: 'Qual o maior gargalo?',
      })
    );
    expect(wrapper.text()).toContain(
      'O funil apresenta boa conversão em Qualificação.'
    );
  });

  it('triggers CSV export on click', async () => {
    const wrapper = await mountComponent();

    const exportBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('CRM.ANALYTICS.EXPORT.BUTTON'));
    expect(exportBtn).toBeDefined();

    await exportBtn.trigger('click');
    await flushPromises();

    expect(CrmAPI.exportDeals).toHaveBeenCalled();
    expect(wrapper.text()).toContain('Exportação iniciada com sucesso.');
  });
});

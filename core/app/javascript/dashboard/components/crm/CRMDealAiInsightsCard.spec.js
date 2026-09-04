import { mount } from '@vue/test-utils';
import CRMDealAiInsightsCard from './CRMDealAiInsightsCard.vue';
import CrmAPI from 'dashboard/api/crm';

const mockPush = vi.fn();
const mockUseAlert = vi.fn();

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush }),
  useRoute: () => ({ params: { accountId: '1' } }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: msg => mockUseAlert(msg),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    recomputeLeadScore: vi.fn(),
  },
}));

const mockDeal = (overrides = {}) => ({
  id: 42,
  title: 'Inventário Família Silva',
  summary: 'Cliente busca abertura de inventário com 3 herdeiros concordes.',
  next_best_action:
    'Solicitar certidões de óbito e matrícula atualizada dos imóveis.',
  score_total: 88,
  score_classification: 'prioridade_alta',
  score_reason: 'Herdeiros alinhados e patrimônio com liquidez clara.',
  captain_ai_mode: 'auto',
  captain_handoff_reason_code: null,
  conversation_id: 100,
  conversation_display_id: 100,
  ...overrides,
});

const mountCard = (props = {}) =>
  mount(CRMDealAiInsightsCard, {
    props: {
      deal: mockDeal(),
      loading: false,
      ...props,
    },
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${JSON.stringify(params)}` : key,
      },
      stubs: {
        Icon: { template: '<i />' },
        CRMScoreBadge: {
          props: ['score', 'classification'],
          template:
            '<div data-testid="crm-score-badge">{{ score }} - {{ classification }}</div>',
        },
      },
    },
  });

describe('CRMDealAiInsightsCard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders deal AI insights correctly', () => {
    const wrapper = mountCard();

    expect(
      wrapper.find('[data-testid="crm-deal-ai-insights-card"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="deal-next-best-action"]').text()
    ).toContain(
      'Solicitar certidões de óbito e matrícula atualizada dos imóveis.'
    );
    expect(wrapper.find('[data-testid="deal-ai-summary"]').text()).toContain(
      'Cliente busca abertura de inventário com 3 herdeiros concordes.'
    );
    expect(wrapper.find('[data-testid="deal-score-badge"]').text()).toContain(
      '88 - prioridade_alta'
    );
    expect(wrapper.find('[data-testid="deal-score-reason"]').text()).toContain(
      'Herdeiros alinhados e patrimônio com liquidez clara.'
    );
  });

  it('renders AI mode badge when present', () => {
    const wrapper = mountCard({
      deal: mockDeal({ captain_ai_mode: 'auto' }),
    });

    const badge = wrapper.find('[data-testid="ai-mode-badge"]');
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toContain('AI active');
  });

  it('recomputes lead score on button click', async () => {
    const updatedDeal = mockDeal({ score_total: 95 });
    CrmAPI.recomputeLeadScore.mockResolvedValueOnce({ data: updatedDeal });

    const wrapper = mountCard();
    const recomputeBtn = wrapper
      .findAll('button')
      .find(
        b => b.attributes('aria-label') === 'CRM.DEAL_INSIGHTS.RECOMPUTE_SCORE'
      );
    expect(recomputeBtn).toBeDefined();

    await recomputeBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(CrmAPI.recomputeLeadScore).toHaveBeenCalledWith(42);
    expect(mockUseAlert).toHaveBeenCalledWith(
      'Lead score updated successfully.'
    );
    expect(wrapper.emitted('recompute')).toBeTruthy();
  });

  it('shows error alert if score recomputation fails', async () => {
    CrmAPI.recomputeLeadScore.mockRejectedValueOnce(new Error('Network error'));

    const wrapper = mountCard();
    const recomputeBtn = wrapper
      .findAll('button')
      .find(
        b => b.attributes('aria-label') === 'CRM.DEAL_INSIGHTS.RECOMPUTE_SCORE'
      );
    await recomputeBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(mockUseAlert).toHaveBeenCalledWith(
      'Could not recompute score. Please try again.'
    );
  });

  it('navigates to conversation when clicking open conversation', async () => {
    const wrapper = mountCard();
    const openBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('CRM.DEAL_INSIGHTS.OPEN_CONVERSATION'));
    expect(openBtn).toBeDefined();

    await openBtn.trigger('click');

    expect(mockPush).toHaveBeenCalledWith('/app/accounts/1/conversations/100');
  });

  it('displays empty placeholders when summary or next best action are missing', () => {
    const wrapper = mountCard({
      deal: mockDeal({
        summary: null,
        next_best_action: null,
        score_reason: null,
      }),
    });

    expect(
      wrapper.find('[data-testid="deal-next-best-action"]').text()
    ).toContain('CRM.DEAL_INSIGHTS.NO_NEXT_ACTION');
    expect(wrapper.find('[data-testid="deal-ai-summary"]').text()).toContain(
      'CRM.DEAL_INSIGHTS.NO_SUMMARY'
    );
  });

  it('shows skeleton when loading is true', () => {
    const wrapper = mountCard({ loading: true });
    expect(wrapper.find('[data-testid="insights-loading"]').exists()).toBe(
      true
    );
  });
});

import { flushPromises, mount } from '@vue/test-utils';

import AgentsAPI from 'dashboard/api/agents';
import ContactAPI from 'dashboard/api/contacts';
import CrmAPI from 'dashboard/api/crm';

import Activities from './ActivitiesOperational.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' } }),
}));

vi.mock('dashboard/api/agents', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/api/contacts', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getActivities: vi.fn(),
    getDeals: vi.fn(),
    activitiesCalendarUrl: vi.fn(),
  },
}));

const activityFixture = index => ({
  id: index,
  title: `Retornar ao cliente ${index}`,
  description: 'Confirmar os documentos necessários.',
  kind: 'retorno_cliente',
  priority: index % 3 === 0 ? 'alta' : 'normal',
  due_at: '2026-07-24T14:00:00.000Z',
  is_due_today: false,
  is_overdue: index % 5 === 0,
  completed_at: null,
  crm_deal_id: index,
  contact: { id: index, name: `Cliente ${index}` },
  deal: {
    id: index,
    title: `Caso ${index}`,
    stage: { name: 'Qualificação' },
  },
  assignee: { id: 9, name: 'Dra. Paula' },
  calendar_links: {},
});

const mountPage = () =>
  mount(Activities, {
    global: {
      stubs: {
        Icon: {
          props: ['icon'],
          template: '<span :data-icon="icon" />',
        },
        Spinner: {
          template: '<span data-testid="spinner" />',
        },
        RouterLink: {
          props: ['to'],
          template: '<a :href="to"><slot /></a>',
        },
      },
    },
  });

describe('CRM Activities operational pilot', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CrmAPI.getActivities.mockResolvedValue({
      data: Array.from({ length: 120 }, (_, index) =>
        activityFixture(index + 1)
      ),
    });
    CrmAPI.getDeals.mockResolvedValue({ data: [] });
    AgentsAPI.get.mockResolvedValue({ data: [] });
    ContactAPI.get.mockResolvedValue({ data: [] });
  });

  it('uses the compact header and removes decorative KPI cards', async () => {
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.get('h1').text()).toBe('Atividades');
    expect(wrapper.text()).not.toContain('Agenda CRM');
    expect(wrapper.text()).not.toContain(
      'Organize próximas ações, prazos, retornos'
    );
    expect(wrapper.find('.crm-kpi-grid').exists()).toBe(false);
    expect(wrapper.findAll('[role="tab"]')).toHaveLength(5);
    expect(wrapper.get('nav[aria-label="Navegação estrutural"]').exists()).toBe(
      true
    );
  });

  it('limits the rendered list and exposes two actions plus overflow', async () => {
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.findAll('tbody > tr')).toHaveLength(50);
    expect(wrapper.get('nav[aria-label="Paginação"]').text()).toContain(
      '1–50 de 120'
    );

    const firstRow = wrapper.findAll('tbody > tr')[0];
    const actions = firstRow.findAll('td').at(-1);
    const visibleButtons = actions.findAll(':scope > div > button');
    const tooltipButtons = actions.findAll(
      '[aria-label="Concluir atividade"], [aria-label="Editar atividade"]'
    );

    expect(tooltipButtons).toHaveLength(2);
    expect(actions.get('[aria-label="Mais ações da atividade"]').exists()).toBe(
      true
    );
    expect(visibleButtons.length).toBeLessThanOrEqual(1);
  });

  it('reloads the API when the status tab changes', async () => {
    const wrapper = mountPage();
    await flushPromises();

    await wrapper.findAll('[role="tab"]')[1].trigger('click');
    await flushPromises();

    expect(CrmAPI.getActivities).toHaveBeenLastCalledWith({ status: 'today' });
  });
});

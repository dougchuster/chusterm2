import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import { ref } from 'vue';

import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import SLAReportsAPI from 'dashboard/api/slaReports';

import AnalyticsCenter from './AnalyticsCenter.vue';

// Check-up 2026-09-18: ReportPolicy#view? é admin-only. Para agente a aba
// "Atendimento & SLA" não existe e as 4 chamadas de relatório não saem.
vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: { accountId: '55' },
    query: { sub_tab: 'support' },
  }),
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: ref(false) }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings: ref({}), updateUISettings: vi.fn() }),
}));
vi.mock('dashboard/api/crm', () => ({
  default: new Proxy(
    {},
    { get: () => vi.fn(() => Promise.resolve({ data: {} })) }
  ),
}));
vi.mock('dashboard/api/reports', () => ({
  default: { getSummary: vi.fn(), getInboxReports: vi.fn() },
}));
vi.mock('dashboard/api/csatReports', () => ({
  default: { getMetrics: vi.fn() },
}));
vi.mock('dashboard/api/slaReports', () => ({
  default: { getMetrics: vi.fn() },
}));

describe('AnalyticsCenter como agente', () => {
  it('não mostra a aba de atendimento nem chama os relatórios admin-only', async () => {
    const wrapper = mount(AnalyticsCenter, {
      global: { stubs: { teleport: true }, mocks: { $t: k => k } },
    });
    await flushPromises();

    expect(ReportsAPI.getSummary).not.toHaveBeenCalled();
    expect(ReportsAPI.getInboxReports).not.toHaveBeenCalled();
    expect(CSATReportsAPI.getMetrics).not.toHaveBeenCalled();
    expect(SLAReportsAPI.getMetrics).not.toHaveBeenCalled();
    const tabs = wrapper.findAll('[role="tab"]').map(tab => tab.text());
    expect(tabs).toHaveLength(2);
    expect(tabs.join(' ')).not.toMatch(/SUPPORT|Atendimento/);
  });
});

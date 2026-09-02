import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import Activities from './Activities.vue';
import Agenda from './Agenda.vue';
import AllLeads from './AllLeads.vue';
import CrmIndex from './CrmIndex.vue';
import DealDetails from './DealDetails.vue';
import PipelineSettings from './PipelineSettings.vue';

// F2.1 do PLANO-KANBAN-CRM-2026.md — as seis telas nao tem mais um par
// legacy/operational, entao nao tem mais feature flag para escolher entre eles.
// O que este arquivo protege agora e o oposto do que protegia antes: que a
// rota renderize a pagina Operational **sempre**, sem consultar flag nenhuma.
//
// Se alguem reintroduzir a bifurcacao, um destes testes quebra.

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' } }),
}));

// A flag responde `false` de proposito: se a pagina ainda dependesse dela,
// cairia no Legacy — que nao existe mais — e o teste falharia.
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: () => false }),
}));

vi.mock('./ActivitiesOperational.vue', () => ({
  default: { template: '<div data-testid="activities">Atividades</div>' },
}));

vi.mock('./AgendaOperational.vue', () => ({
  default: { template: '<div data-testid="agenda">Agenda</div>' },
}));

vi.mock('./PipelineSettingsOperational.vue', () => ({
  default: { template: '<div data-testid="pipeline-settings">Pipeline</div>' },
}));

vi.mock('./DealDetailsOperational.vue', () => ({
  default: { template: '<div data-testid="deal-details">Ficha</div>' },
}));

vi.mock('./AllLeadsOperational.vue', () => ({
  default: { template: '<div data-testid="all-leads">Leads</div>' },
}));

vi.mock('./CrmIndexOperational.vue', () => ({
  default: { template: '<div data-testid="crm-index">Quadro</div>' },
}));

describe('CRM sem par legacy/operational', () => {
  it.each([
    ['Activities', Activities, 'activities'],
    ['Agenda', Agenda, 'agenda'],
    ['PipelineSettings', PipelineSettings, 'pipeline-settings'],
    ['DealDetails', DealDetails, 'deal-details'],
    ['AllLeads', AllLeads, 'all-leads'],
    ['CrmIndex', CrmIndex, 'crm-index'],
  ])(
    '%s renders the operational page even with crm_v2 turned off',
    (_name, component, testId) => {
      const wrapper = mount(component);

      expect(wrapper.find(`[data-testid="${testId}"]`).exists()).toBe(true);
    }
  );

  it.each([
    ['Activities', Activities],
    ['Agenda', Agenda],
    ['PipelineSettings', PipelineSettings],
    ['DealDetails', DealDetails],
    ['AllLeads', AllLeads],
    ['CrmIndex', CrmIndex],
  ])('%s no longer renders anything called Legacy', (_name, component) => {
    const wrapper = mount(component);

    expect(wrapper.html()).not.toContain('Legacy');
  });
});

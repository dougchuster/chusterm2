import { mount } from '@vue/test-utils';

import CRMFilterPills from './CRMFilterPills.vue';

// F2.6 do PLANO-KANBAN-CRM-2026.md — "barra de filtros componível, cada um
// removível, contador de resultados".
//
// O ponto da barra não é filtrar: é o atendente **ver o que está filtrado**.
// Board com filtro invisível é board que mente sobre o tamanho da fila.

const pills = [
  { key: 'q', labelKey: 'CRM.FILTERS.SEARCH', value: 'maria' },
  { key: 'stage_id', labelKey: 'CRM.FILTERS.STAGE', value: 'Novo' },
  {
    key: 'has_pending_activity',
    labelKey: 'CRM.FILTERS.NO_NEXT_ACTION',
    value: '',
  },
];

const mountBar = (props = {}) =>
  mount(CRMFilterPills, {
    props: { pills, resultCount: 42, ...props },
    global: {
      // O mock devolve chave + params: o contador precisa provar que o numero
      // chega na traducao, nao so que a chave certa foi usada.
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${JSON.stringify(params)}` : key,
      },
      stubs: {
        Icon: { template: '<i />' },
        DsButton: { template: '<button v-bind="$attrs" />' },
      },
    },
  });

describe('CRMFilterPills', () => {
  it('shows one pill per active filter', () => {
    const wrapper = mountBar();

    expect(wrapper.findAll('[data-testid="crm-filter-pill"]')).toHaveLength(3);
  });

  it('reads the criterion and its value together', () => {
    const wrapper = mountBar();

    expect(
      wrapper.findAll('[data-testid="crm-filter-pill"]')[1].text()
    ).toContain('CRM.FILTERS.STAGE');
    expect(
      wrapper.findAll('[data-testid="crm-filter-pill"]')[1].text()
    ).toContain('Novo');
  });

  // Um filtro booleano já diz tudo no rótulo: "sem próxima ação" não precisa de
  // ": true" pendurado.
  it('does not print an empty value', () => {
    const wrapper = mountBar();

    expect(
      wrapper.findAll('[data-testid="crm-filter-pill"]')[2].text()
    ).not.toContain(':');
  });

  it('lets each pill be removed on its own', async () => {
    const wrapper = mountBar();

    await wrapper
      .findAll('[data-testid="crm-filter-remove"]')[1]
      .trigger('click');

    expect(wrapper.emitted('remove')[0]).toEqual(['stage_id']);
  });

  it('offers to clear everything at once', async () => {
    const wrapper = mountBar();

    await wrapper.find('[data-testid="crm-filter-clear"]').trigger('click');

    expect(wrapper.emitted('clear')).toHaveLength(1);
  });

  // O contador é o que responde "o filtro me deixou com quantos?".
  it('shows how many deals survived the filter', () => {
    const wrapper = mountBar();

    expect(wrapper.find('[data-testid="crm-filter-count"]').text()).toContain(
      '42'
    );
  });

  it('disappears entirely when nothing is filtered', () => {
    const wrapper = mountBar({ pills: [] });

    expect(wrapper.find('[data-testid="crm-filter-bar"]').exists()).toBe(false);
  });

  it('says the filter found nothing, instead of just showing zero', () => {
    const wrapper = mountBar({ resultCount: 0 });

    expect(wrapper.find('[data-testid="crm-filter-count"]').text()).toContain(
      'CRM.FILTERS.NO_RESULTS'
    );
  });

  it('names the remove button after the criterion, for the screen reader', () => {
    const wrapper = mountBar();

    expect(
      wrapper
        .findAll('[data-testid="crm-filter-remove"]')[0]
        .attributes('aria-label')
    ).toContain('CRM.FILTERS.REMOVE');
  });
});

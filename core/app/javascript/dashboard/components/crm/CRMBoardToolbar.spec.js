import { mount } from '@vue/test-utils';

import CRMBoardToolbar from './CRMBoardToolbar.vue';

const controlStub = {
  inheritAttrs: false,
  props: ['label', 'modelValue'],
  emits: ['click'],
  template:
    '<button v-bind="$attrs" type="button" @click="$emit(\'click\')">{{ label }}</button>',
};

const mountToolbar = (props = {}) =>
  mount(CRMBoardToolbar, {
    props: {
      pipelineOptions: [{ value: '1', label: 'Comercial' }],
      groupByOptions: [{ value: 'stage', label: 'Etapa' }],
      densityOptions: [{ value: 'normal', label: 'Normal' }],
      ownerOptions: [{ value: '', label: 'Todos' }],
      priorityOptions: [{ value: '', label: 'Todas' }],
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      stubs: {
        DsButton: controlStub,
        DsDropdown: { template: '<div><slot /></div>' },
        DsInput: controlStub,
        DsSelect: controlStub,
        CRMFilterPills: { template: '<div data-testid="filter-pills" />' },
        CRMViewsMenu: { template: '<div />' },
        Icon: { template: '<i />' },
      },
    },
  });

describe('CRMBoardToolbar', () => {
  it('keeps secondary filters collapsed until requested', async () => {
    const wrapper = mountToolbar();

    expect(
      wrapper.find('[data-testid="crm-toolbar-advanced-filters"]').exists()
    ).toBe(false);
    expect(
      wrapper
        .get('[data-testid="crm-toolbar-filter-toggle"]')
        .attributes('aria-expanded')
    ).toBe('false');

    await wrapper
      .get('[data-testid="crm-toolbar-filter-toggle"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="crm-toolbar-advanced-filters"]').exists()
    ).toBe(true);
    expect(
      wrapper
        .get('[data-testid="crm-toolbar-filter-toggle"]')
        .attributes('aria-expanded')
    ).toBe('true');
  });

  it('keeps active filter pills visible while secondary filters are collapsed', () => {
    const wrapper = mountToolbar({
      filterPills: [{ key: 'owner', label: 'Owner: Ana' }],
      hasFilters: true,
    });

    expect(wrapper.find('[data-testid="filter-pills"]').exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="crm-toolbar-advanced-filters"]').exists()
    ).toBe(false);
  });
});

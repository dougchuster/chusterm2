import { mount } from '@vue/test-utils';

import { FEATURE_FLAGS } from '../../../../featureFlags';
import { routes } from '../crm.routes';
import PageTemplatesGallery from './PageTemplatesGallery.vue';

const global = {
  stubs: {
    Icon: {
      props: ['icon'],
      template: '<span :data-icon="icon" />',
    },
    Spinner: {
      template: '<span data-testid="spinner" />',
    },
  },
};

describe('Phase 3 template gallery', () => {
  it('is isolated behind crm_v2 and administrator permission', () => {
    const route = routes.find(item => item.name === 'crm_page_templates');

    expect(route).toBeDefined();
    expect(route.meta).toEqual({
      featureFlag: FEATURE_FLAGS.CRM_V2,
      permissions: ['administrator'],
    });
  });

  it('allows comparing all six archetypes and their states', async () => {
    const wrapper = mount(PageTemplatesGallery, { global });

    expect(wrapper.get('[data-page-template="list"]').exists()).toBe(true);

    const boardTab = wrapper
      .findAll('[role="tab"]')
      .find(tab => tab.text() === 'Quadro');
    await boardTab.trigger('click');
    expect(wrapper.get('[data-page-template="board"]').exists()).toBe(true);

    const loadingTab = wrapper
      .findAll('[role="tab"]')
      .find(tab => tab.text() === 'Carregando');
    await loadingTab.trigger('click');
    expect(
      wrapper.get('[data-page-template="board"]').attributes('aria-busy')
    ).toBe('true');
  });
});

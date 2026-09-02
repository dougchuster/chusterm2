import { mount } from '@vue/test-utils';

import ChatTypeTabs from './ChatTypeTabs.vue';

const items = [
  { key: 'me', name: 'Minhas', shortName: 'Minhas', count: 3 },
  {
    key: 'unassigned',
    name: 'Não atribuídas',
    shortName: 'Sem dono',
    count: 217,
  },
  { key: 'all', name: 'Todos', shortName: 'Todos', count: 219 },
];

describe('ChatTypeTabs', () => {
  it('uses a compact visible label without losing the accessible full name', () => {
    const wrapper = mount(ChatTypeTabs, {
      props: { items, activeTab: 'me' },
    });
    const unassignedTab = wrapper.findAll('[role="tab"]')[1];

    expect(unassignedTab.text()).toContain('Sem dono');
    expect(unassignedTab.text()).not.toContain('Não atribuídas');
    expect(unassignedTab.attributes('title')).toBe('Não atribuídas');
    expect(unassignedTab.attributes('aria-label')).toBe('Não atribuídas: 217');
  });

  it('supports roving focus with arrow keys', async () => {
    const wrapper = mount(ChatTypeTabs, {
      props: { items, activeTab: 'me' },
      attachTo: document.body,
    });
    const tabs = wrapper.findAll('[role="tab"]');

    tabs[0].element.focus();
    await tabs[0].trigger('keydown', { key: 'ArrowRight' });

    expect(wrapper.emitted('chatTabChange')).toEqual([['unassigned']]);
    expect(document.activeElement).toBe(tabs[1].element);

    wrapper.unmount();
  });
});

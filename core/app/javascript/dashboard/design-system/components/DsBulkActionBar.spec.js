import { mount } from '@vue/test-utils';
import { describe, it, expect } from 'vitest';
import DsBulkActionBar from './DsBulkActionBar.vue';

const globalStubs = {
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

describe('DsBulkActionBar.vue', () => {
  const actions = [
    {
      id: 'delete',
      label: 'Delete',
      icon: 'i-lucide-trash',
      variant: 'danger',
    },
    {
      id: 'assign',
      label: 'Assign',
      icon: 'i-lucide-user',
      variant: 'secondary',
    },
    {
      id: 'export',
      label: 'Export',
      icon: 'i-lucide-download',
      variant: 'secondary',
    },
  ];

  it('renders floating action bar when count > 0', () => {
    const wrapper = mount(DsBulkActionBar, {
      global: globalStubs,
      props: {
        count: 5,
        actions,
      },
    });

    expect(wrapper.find('[role="toolbar"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('5 selected');
    expect(wrapper.text()).toContain('Delete');
    expect(wrapper.text()).toContain('Assign');
    expect(wrapper.text()).toContain('Export');
    expect(wrapper.text()).toContain('Clear selection');
  });

  it('does not render toolbar when count is 0', () => {
    const wrapper = mount(DsBulkActionBar, {
      global: globalStubs,
      props: {
        count: 0,
        actions,
      },
    });

    expect(wrapper.find('[role="toolbar"]').exists()).toBe(false);
  });

  it('emits action event with action id when an action button is clicked', async () => {
    const wrapper = mount(DsBulkActionBar, {
      global: globalStubs,
      props: {
        count: 3,
        actions,
      },
    });

    const buttons = wrapper.findAll('button');
    // buttons: [Delete, Assign, Export, Clear selection]
    const deleteBtn = buttons.find(b => b.text().includes('Delete'));
    expect(deleteBtn).toBeDefined();

    await deleteBtn.trigger('click');
    expect(wrapper.emitted('action')).toHaveLength(1);
    expect(wrapper.emitted('action')[0]).toEqual(['delete']);

    const assignBtn = buttons.find(b => b.text().includes('Assign'));
    await assignBtn.trigger('click');
    expect(wrapper.emitted('action')).toHaveLength(2);
    expect(wrapper.emitted('action')[1]).toEqual(['assign']);
  });

  it('emits clear event when clear button is clicked', async () => {
    const wrapper = mount(DsBulkActionBar, {
      global: globalStubs,
      props: {
        count: 2,
        actions,
      },
    });

    const clearBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('Clear selection'));
    expect(clearBtn).toBeDefined();

    await clearBtn.trigger('click');
    expect(wrapper.emitted('clear')).toHaveLength(1);
  });

  it('supports i18n custom translations', () => {
    const customI18nStubs = {
      ...globalStubs,
      mocks: {
        $t: (key, values) => {
          if (key === 'BULK_ACTION_BAR.SELECTED_COUNT') {
            return `${values.count} selecionados`;
          }
          if (key === 'BULK_ACTION_BAR.CLEAR_SELECTION') {
            return 'Limpar seleção';
          }
          return key;
        },
        $te: () => true,
      },
    };

    const wrapper = mount(DsBulkActionBar, {
      global: customI18nStubs,
      props: {
        count: 10,
        actions,
      },
    });

    expect(wrapper.text()).toContain('10 selecionados');
    expect(wrapper.text()).toContain('Limpar seleção');
  });
});

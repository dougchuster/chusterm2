import { mount } from '@vue/test-utils';
import SidebarSubGroup from './SidebarSubGroup.vue';

const isAllowedMock = vi.fn(to => !to?.name?.includes('forbidden'));

vi.mock('./provider', () => ({
  useSidebarContext: () => ({
    isAllowed: isAllowedMock,
  }),
}));

describe('SidebarSubGroup', () => {
  const children = [
    {
      name: 'item-1',
      label: 'Sub Item 1',
      to: { name: 'item_1' },
    },
    {
      name: 'item-2',
      label: 'Sub Item 2',
      to: { name: 'item_2' },
    },
    {
      name: 'item-forbidden',
      label: 'Forbidden Item',
      to: { name: 'forbidden_route' },
    },
  ];

  const mountComponent = (props = {}) =>
    mount(SidebarSubGroup, {
      props: {
        label: 'Sub Group Header',
        icon: 'i-lucide-folder',
        isExpanded: true,
        children,
        ...props,
      },
      global: {
        stubs: {
          Icon: { template: '<span class="icon-stub" />' },
          SidebarGroupSeparator: {
            template: '<div class="separator-stub">{{ label }}</div>',
            props: ['label', 'icon'],
          },
          SidebarGroupLeaf: {
            template:
              '<li class="leaf-stub" :data-active="active">{{ label }}</li>',
            props: ['label', 'to', 'active', 'isNested'],
          },
        },
      },
    });

  it('renders separator and accessible children correctly', () => {
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Sub Group Header');
    expect(wrapper.findAll('.leaf-stub')).toHaveLength(3);
  });

  it('passes active prop to the active child', () => {
    const wrapper = mountComponent({
      activeChild: { name: 'item-2' },
    });
    const activeLeaves = wrapper.findAll('.leaf-stub[data-active="true"]');
    expect(activeLeaves).toHaveLength(1);
    expect(activeLeaves[0].text()).toBe('Sub Item 2');
  });
});

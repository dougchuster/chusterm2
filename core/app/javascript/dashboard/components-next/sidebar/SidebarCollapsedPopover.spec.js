import { mount } from '@vue/test-utils';

import SidebarCollapsedPopover from './SidebarCollapsedPopover.vue';

const mocks = vi.hoisted(() => ({
  routerPush: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.routerPush }),
}));

vi.mock('./provider', () => ({
  useSidebarContext: () => ({
    isAllowed: () => true,
    sidebarWidth: { value: 56 },
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: false }),
}));

const children = [
  {
    name: 'group',
    label: 'Grupo',
    icon: 'i-lucide-folder',
    children: [
      {
        name: 'nested',
        label: 'Item interno',
        to: { name: 'nested' },
      },
    ],
  },
  {
    name: 'direct',
    label: 'Item direto',
    to: { name: 'direct' },
  },
];

const mountPopover = () =>
  mount(SidebarCollapsedPopover, {
    attachTo: document.body,
    props: {
      id: 'sidebar-collapsed-test',
      label: 'Menu de teste',
      children,
      triggerRect: { top: 20, left: 0 },
    },
    global: {
      stubs: {
        Icon: true,
        TeleportWithDirection: {
          template: '<slot />',
        },
      },
    },
  });

describe('SidebarCollapsedPopover', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('focuses the first item and navigates groups with arrow keys', async () => {
    const wrapper = mountPopover();

    await wrapper.vm.focusFirstItem();
    const groupTrigger = wrapper.get('[data-subgroup-trigger="group"]');
    expect(document.activeElement).toBe(groupTrigger.element);

    await groupTrigger.trigger('keydown', { key: 'ArrowRight' });
    await wrapper.vm.$nextTick();

    const nestedItem = wrapper.get('[data-subgroup-parent="group"]');
    expect(document.activeElement).toBe(nestedItem.element);

    await nestedItem.trigger('keydown', { key: 'ArrowLeft' });
    await wrapper.vm.$nextTick();
    expect(document.activeElement).toBe(groupTrigger.element);
  });

  it('supports linear menu navigation and restores through the close event', async () => {
    const wrapper = mountPopover();
    await wrapper.vm.focusFirstItem();

    await wrapper
      .get('[data-subgroup-trigger="group"]')
      .trigger('keydown', { key: 'ArrowDown' });

    expect(document.activeElement).toBe(
      wrapper.get('[role="menuitem"]:not([data-subgroup-trigger])').element
    );

    await wrapper.get('[role="menu"]').trigger('keydown', { key: 'Escape' });
    expect(wrapper.emitted('close')).toEqual([[{ restoreFocus: true }]]);
  });

  it('keeps click navigation and closes the popover', async () => {
    const wrapper = mountPopover();

    await wrapper
      .get('[role="menuitem"]:not([data-subgroup-trigger])')
      .trigger('click');

    expect(mocks.routerPush).toHaveBeenCalledWith({ name: 'direct' });
    expect(wrapper.emitted('close')).toEqual([[]]);
  });
});

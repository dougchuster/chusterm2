import { mount } from '@vue/test-utils';
import SidebarGroupHeader from './SidebarGroupHeader.vue';

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => ({ value: 5 }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

describe('SidebarGroupHeader', () => {
  const mountComponent = (props = {}) =>
    mount(SidebarGroupHeader, {
      props: {
        name: 'test-item',
        label: 'Test Item',
        icon: 'i-lucide-inbox',
        ...props,
      },
      global: {
        stubs: {
          Icon: {
            template: '<span class="icon-stub" />',
          },
          RouterLink: {
            template: '<a :href="to"><slot /></a>',
            props: ['to'],
          },
        },
      },
    });

  it('renders label and icon correctly', () => {
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Test Item');
    expect(wrapper.find('.icon-stub').exists()).toBe(true);
  });

  it('emits toggle event when clicked', async () => {
    const wrapper = mountComponent();
    await wrapper.trigger('click');
    expect(wrapper.emitted('toggle')).toHaveLength(1);
  });

  it('emits togglePin event when pin button is clicked', async () => {
    const wrapper = mountComponent({ canPin: true, isPinned: false });
    const pinBtn = wrapper.find('button[type="button"]');
    expect(pinBtn.exists()).toBe(true);
    await pinBtn.trigger('click');
    expect(wrapper.emitted('togglePin')).toHaveLength(1);
  });

  it('shows pinned icon when isPinned is true', () => {
    const wrapper = mountComponent({ isPinned: true });
    expect(wrapper.find('.i-lucide-pin-off').exists()).toBe(true);
  });

  it('renders expand chevron when expandable is true', async () => {
    const wrapper = mountComponent({ expandable: true, isExpanded: false });
    expect(wrapper.find('.i-lucide-chevron-down').exists()).toBe(true);

    const expandedWrapper = mountComponent({
      expandable: true,
      isExpanded: true,
    });
    expect(expandedWrapper.find('.i-lucide-chevron-up').exists()).toBe(true);
  });
});

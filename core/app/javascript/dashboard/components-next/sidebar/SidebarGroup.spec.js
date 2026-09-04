import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarGroup from './SidebarGroup.vue';

const expandedItemMock = ref(null);
const setExpandedItemMock = vi.fn(name => {
  expandedItemMock.value = name;
});
const isPinnedMock = vi.fn(name => name === 'pinned-group');
const togglePinMock = vi.fn();
const isAllowedMock = vi.fn(() => true);

vi.mock('./provider', () => ({
  useSidebarContext: () => ({
    expandedItem: expandedItemMock,
    setExpandedItem: setExpandedItemMock,
    resolvePath: to => (to?.name ? `/${to.name}` : '/'),
    resolvePermissions: () => [],
    resolveFeatureFlag: () => null,
    isAllowed: isAllowedMock,
    isCollapsed: ref(false),
    isResizing: ref(false),
    isPinned: isPinnedMock,
    togglePin: togglePinMock,
  }),
  usePopoverState: () => ({
    activePopover: ref(null),
    setActivePopover: vi.fn(),
    closeActivePopover: vi.fn(),
    scheduleClose: vi.fn(),
    cancelClose: vi.fn(),
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    path: '/inbox_view',
    name: 'inbox_view',
    query: {},
    params: {},
  }),
  useRouter: () => ({
    push: vi.fn(),
    resolve: to => ({ path: to?.name ? `/${to.name}` : '/' }),
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

describe('SidebarGroup', () => {
  const mountComponent = (props = {}, globalOverrides = {}) =>
    mount(SidebarGroup, {
      props: {
        name: 'test-group',
        label: 'Test Group',
        icon: 'i-lucide-folder',
        ...props,
      },
      global: {
        stubs: {
          Policy: {
            template: '<li class="policy-stub"><slot /></li>',
            props: ['permissions', 'featureFlag', 'as'],
          },
          DsTooltip: {
            template:
              '<div class="ds-tooltip-stub" :data-text="text"><slot /></div>',
            props: ['text', 'placement', 'disabled'],
          },
          SidebarGroupHeader: {
            template: `
              <div class="group-header-stub" @click="$emit('toggle')">
                <span>{{ label }}</span>
                <button type="button" data-testid="pin-btn" @click.stop="$emit('togglePin')">Pin</button>
              </div>
            `,
            props: [
              'icon',
              'name',
              'label',
              'to',
              'getterKeys',
              'isActive',
              'hasActiveChild',
              'expandable',
              'isExpanded',
              'isPinned',
              'canPin',
            ],
            emits: ['toggle', 'togglePin'],
          },
          SidebarGroupLeaf: {
            template: '<div class="leaf-stub">{{ label }}</div>',
            props: ['name', 'label', 'to', 'active'],
          },
          SidebarSubGroup: {
            template: '<div class="subgroup-stub">{{ label }}</div>',
            props: ['label', 'icon', 'children', 'isExpanded', 'activeChild'],
          },
          SidebarCollapsedPopover: {
            template: '<div class="popover-stub" />',
            props: ['id', 'label', 'children', 'activeChild', 'triggerRect'],
          },
        },
        ...globalOverrides,
      },
    });

  beforeEach(() => {
    vi.clearAllMocks();
    expandedItemMock.value = null;
  });

  it('renders header in expanded mode', () => {
    const wrapper = mountComponent();
    expect(wrapper.find('.group-header-stub').exists()).toBe(true);
    expect(wrapper.text()).toContain('Test Group');
  });

  it('handles toggle event by calling setExpandedItem', async () => {
    const wrapper = mountComponent();
    await wrapper.find('.group-header-stub').trigger('click');
    expect(setExpandedItemMock).toHaveBeenCalledWith('test-group');
  });

  it('delegates togglePin to context togglePin', async () => {
    const wrapper = mountComponent({
      to: { name: 'crm_dashboard' },
    });
    await wrapper.find('[data-testid="pin-btn"]').trigger('click');
    expect(togglePinMock).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'test-group',
        name: 'test-group',
        label: 'Test Group',
      })
    );
  });
});

import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import Sidebar from './Sidebar.vue';
import { emitter } from 'shared/helpers/mitt';

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: vi.fn(),
    on: vi.fn(),
    off: vi.fn(),
  },
}));

const dispatchMock = vi.fn();
const routerPushMock = vi.fn();
const routerResolveMock = vi.fn(to => ({
  path: to?.name ? `/${to.name}` : '/',
}));

const currentSidebarWidth = ref(200);
const currentAccount = ref({ settings: {} });

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch: dispatchMock,
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: dispatchMock,
    getters: {},
  }),
  useMapGetter: getter => {
    if (getter === 'getCurrentAccountId') return ref(1);
    if (getter === 'inboxes/getInboxes')
      return ref([{ id: 1, name: 'WhatsApp' }]);
    if (getter === 'teams/getMyTeams') return ref([]);
    if (getter === 'customViews/getContactCustomViews') return ref([]);
    if (getter === 'customViews/getConversationCustomViews') return ref([]);
    if (getter === 'accounts/isRTL') return ref(false);
    if (getter === 'globalConfig/isACustomBrandedInstance') return ref(false);
    if (getter === 'accounts/isFeatureEnabledonAccount') {
      return ref(() => true);
    }
    return ref(null);
  },
  useStoreGetters: () => ({
    getUISettings: ref({ sidebar_width: currentSidebarWidth.value }),
  }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params = {}, query = {}) => ({
      name,
      params,
      query,
    }),
    isOnChusteRMCloud: ref(false),
    currentAccount,
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    fullPath: '/app/accounts/1/inbox_view',
    path: '/app/accounts/1/inbox_view',
    name: 'inbox_view',
    query: {},
    params: { accountId: '1' },
  }),
  useRouter: () => ({
    push: routerPushMock,
    resolve: routerResolveMock,
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getPipelines: vi.fn(() => Promise.resolve({ data: [] })),
  },
}));

vi.mock('@vueuse/core', async importOriginal => {
  const actual = await importOriginal();
  return {
    ...actual,
    useWindowSize: () => ({ width: ref(1200), height: ref(800) }),
  };
});

describe('Sidebar.vue', () => {
  let setItemSpy;

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    currentSidebarWidth.value = 200;
    currentAccount.value = { settings: {} };
    setItemSpy = vi.spyOn(window.localStorage, 'setItem');
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  const mountSidebar = (props = {}) =>
    mount(Sidebar, {
      props: {
        isMobileSidebarOpen: false,
        ...props,
      },
      global: {
        stubs: {
          RouterLink: {
            template: '<a :href="to"><slot /></a>',
            props: ['to'],
          },
          SidebarAccountSwitcher: {
            template: '<div class="account-switcher-stub" />',
            props: ['isCollapsed'],
          },
          SidebarProfileMenu: {
            template: '<div class="profile-menu-stub" />',
            props: ['isCollapsed'],
          },
          SidebarChangelogCard: true,
          SidebarChangelogButton: true,
          SidebarGroup: {
            template: '<li class="sidebar-group-stub">{{ label }}</li>',
            props: [
              'name',
              'label',
              'icon',
              'to',
              'children',
              'activeOn',
              'getterKeys',
            ],
          },
          DsTooltip: {
            template:
              '<div class="ds-tooltip-stub" :data-text="text"><slot /></div>',
            props: ['text', 'placement'],
          },
          Logo: {
            template: '<svg class="logo-stub" />',
          },
        },
      },
    });

  it('renders the 4 main section blocks in expanded mode', () => {
    const wrapper = mountSidebar();

    expect(wrapper.text()).toContain('SIDEBAR.SECTION_MAIN');
    expect(wrapper.text()).toContain('SIDEBAR.SECTION_SALES_CRM');
    expect(wrapper.text()).toContain('SIDEBAR.SECTION_AUTOMATION_AI');
    expect(wrapper.text()).toContain('SIDEBAR.SECTION_MANAGEMENT');
  });

  it('renders all key menu items across the 4 blocks', () => {
    const wrapper = mountSidebar();

    // Bloco 1: Principal
    expect(wrapper.text()).toContain('SIDEBAR.INBOX');
    expect(wrapper.text()).toContain('SIDEBAR.NOTIFICATIONS');
    expect(wrapper.text()).toContain('SIDEBAR.CONVERSATIONS');

    // Bloco 2: Vendas & CRM
    expect(wrapper.text()).toContain('SIDEBAR.CRM');
    expect(wrapper.text()).toContain('SIDEBAR.CONTACTS');
    expect(wrapper.text()).toContain('SIDEBAR.COMPANIES');
    expect(wrapper.text()).toContain('SIDEBAR.CADENCES');

    // Bloco 3: Automação & IA
    expect(wrapper.text()).toContain('SIDEBAR.CAPTAIN');
    expect(wrapper.text()).toContain('SIDEBAR.CAMPAIGNS');
    expect(wrapper.text()).toContain('SIDEBAR.AUTOMATION');

    // Bloco 4: Gestão
    expect(wrapper.text()).toContain('SIDEBAR.REPORTS');
    expect(wrapper.text()).toContain('SIDEBAR.SETTINGS');
    expect(wrapper.text()).toContain('SIDEBAR.HELP_CENTER.TITLE');
  });

  it('mostra Arquivos como item próprio só com o cofre ligado na conta', async () => {
    const wrapper = mountSidebar();
    expect(wrapper.text()).not.toContain('SIDEBAR.DOCUMENTS');

    currentAccount.value = { settings: { crm_documents: true } };
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('SIDEBAR.DOCUMENTS');
  });

  it('toggles section collapse when header button is clicked', async () => {
    const wrapper = mountSidebar();

    const sectionButtons = wrapper.findAll('button.group\\/section-btn');
    expect(sectionButtons.length).toBe(4);

    // Click on Sales & CRM section toggle
    await sectionButtons[1].trigger('click');

    expect(setItemSpy).toHaveBeenCalledWith(
      'chusterm_sidebar_collapsed_sections_v1',
      expect.stringContaining('"sales_crm":true')
    );
  });

  it('loads pinned favorites from localStorage and renders them', async () => {
    localStorage.setItem(
      'chusterm_sidebar_pinned_v1_1',
      JSON.stringify([
        {
          id: 'crm_board',
          name: 'crm_board',
          label: 'Funil Principal',
          icon: 'i-lucide-kanban',
          to: { name: 'crm_dashboard' },
        },
      ])
    );

    const wrapper = mountSidebar();
    expect(wrapper.text()).toContain('SIDEBAR.SECTION_FAVORITES');
    expect(wrapper.text()).toContain('Funil Principal');
  });

  it('allows unpinning a favorite item', async () => {
    localStorage.setItem(
      'chusterm_sidebar_pinned_v1_1',
      JSON.stringify([
        {
          id: 'crm_board',
          name: 'crm_board',
          label: 'Funil Principal',
          icon: 'i-lucide-kanban',
          to: { name: 'crm_dashboard' },
        },
      ])
    );

    const wrapper = mountSidebar();
    const unpinBtn = wrapper.find(
      'button[title="SIDEBAR.UNPIN_FROM_FAVORITES"]'
    );
    expect(unpinBtn.exists()).toBe(true);

    await unpinBtn.trigger('click');
    expect(wrapper.text()).not.toContain('Funil Principal');
  });

  it('renders tooltips for search and collapse actions in collapsed mode', () => {
    currentSidebarWidth.value = 56;
    const wrapper = mountSidebar();

    const tooltips = wrapper.findAll('.ds-tooltip-stub');
    expect(tooltips.length).toBeGreaterThan(0);
  });

  it('triggers command bar opening when visual search is clicked in expanded mode', async () => {
    const wrapper = mountSidebar();
    const searchBtn = wrapper.find(
      'button[aria-label="COMBOBOX.SEARCH_PLACEHOLDER"]'
    );
    expect(searchBtn.exists()).toBe(true);

    await searchBtn.trigger('click');
    expect(emitter.emit).toHaveBeenCalledWith('open-commandbar');
  });

  it('triggers command bar opening when visual search is clicked in collapsed mode', async () => {
    currentSidebarWidth.value = 56;
    const wrapper = mountSidebar();
    const searchBtn = wrapper.find(
      'button[aria-label="COMBOBOX.SEARCH_PLACEHOLDER"]'
    );
    expect(searchBtn.exists()).toBe(true);

    await searchBtn.trigger('click');
    expect(emitter.emit).toHaveBeenCalledWith('open-commandbar');
  });
});

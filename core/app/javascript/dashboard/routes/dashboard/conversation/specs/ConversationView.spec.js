import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { ref } from 'vue';
import ConversationView from '../ConversationView.vue';

let mockUISettings = {
  conversation_display_type: 'condensed',
  is_contact_sidebar_open: true,
  conversation_list_width: 370,
  conversation_sidebar_width: 410,
};

const mockUpdateUISettings = vi.fn();
const mockWindowWidth = ref(1600);

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: ref(mockUISettings),
    updateUISettings: mockUpdateUISettings,
  }),
}));

vi.mock('@vueuse/core', async importOriginal => {
  const actual = await importOriginal();
  return {
    ...actual,
    useWindowSize: () => ({
      width: mockWindowWidth,
      height: ref(900),
    }),
  };
});

describe('ConversationView.vue', () => {
  let store;
  let actions;
  let getters;

  beforeEach(() => {
    mockWindowWidth.value = 1600;
    mockUISettings = {
      conversation_display_type: 'condensed',
      is_contact_sidebar_open: true,
      conversation_list_width: 370,
      conversation_sidebar_width: 410,
    };
    actions = {
      'agents/get': vi.fn(),
      'portals/index': vi.fn(),
      setActiveInbox: vi.fn(),
      clearSelectedState: vi.fn(),
    };
    getters = {
      getAllConversations: () => [{ id: 1, inbox_id: 2 }],
      getSelectedChat: () => ({ id: 1, inbox_id: 2 }),
    };
    store = createStore({
      actions,
      getters,
      state: {
        route: { name: 'inbox_conversation' },
      },
    });
  });

  it('renders three cockpit columns with configured custom widths', () => {
    const wrapper = shallowMount(ConversationView, {
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
          $route: { query: {} },
        },
      },
      props: {
        conversationId: 1,
        inboxId: 2,
      },
    });

    const chatList = wrapper.findComponent({ name: 'ChatList' });
    const conversationSidebar = wrapper.findComponent({
      name: 'ConversationSidebar',
    });

    expect(chatList.exists()).toBe(true);
    expect(chatList.props('customWidth')).toBe(370);

    expect(conversationSidebar.exists()).toBe(true);
    expect(conversationSidebar.props('customWidth')).toBe(410);
  });

  it('renders separators with accessible attributes for list and sidebar resize', () => {
    const wrapper = shallowMount(ConversationView, {
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
          $route: { query: {} },
        },
      },
      props: {
        conversationId: 1,
        inboxId: 2,
      },
    });

    const separators = wrapper.findAll('[role="separator"]');
    expect(separators.length).toBe(2);

    const [listHandle, sidebarHandle] = separators;
    expect(listHandle.attributes('aria-valuenow')).toBe('370');
    expect(sidebarHandle.attributes('aria-valuenow')).toBe('410');
  });

  it('hides list resizer and passes default customWidth on expanded layout', () => {
    mockUISettings = {
      ...mockUISettings,
      conversation_display_type: 'expanded',
    };

    const wrapper = shallowMount(ConversationView, {
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
          $route: { query: {} },
        },
      },
      props: {
        conversationId: 1,
        inboxId: 2,
      },
    });

    const chatList = wrapper.findComponent({ name: 'ChatList' });
    expect(chatList.props('customWidth')).toBe(0);
    const separators = wrapper.findAll('[role="separator"]');
    expect(separators.length).toBe(1);
  });
});

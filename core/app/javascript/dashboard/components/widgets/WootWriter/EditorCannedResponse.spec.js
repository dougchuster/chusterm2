import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { createStore } from 'vuex';
import Editor from './Editor.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountId: ref(1),
    isCloudFeatureEnabled: () => false,
    isOnChusteRMCloud: ref(false),
  }),
}));

describe('Editor.vue - Canned Responses in Private Notes', () => {
  let store;

  beforeEach(() => {
    store = createStore({
      getters: {
        'draftMessages/get': () => () => '',
        'captain/getCaptainEnabled': () => false,
        getCannedResponses: () => [
          { id: 1, short_code: 'nota', content: 'Nota interna padrão' },
        ],
      },
      actions: {
        getCannedResponse: vi.fn(),
      },
    });
  });

  it('renders Editor component with isPrivate true and allows canned responses', () => {
    const wrapper = mount(Editor, {
      global: {
        plugins: [store],
        stubs: {
          CannedResponse: {
            template: '<div class="canned-response-stub" />',
            props: ['searchKey'],
          },
          TagAgents: true,
          VariableList: true,
          KeyboardEmojiSelector: true,
          TagTools: true,
          CopilotMenuBar: true,
        },
      },
      props: {
        isPrivate: true,
        enableCannedResponses: true,
        enableSuggestions: true,
      },
    });

    expect(wrapper.exists()).toBe(true);
  });

  it('shows canned response popup when showCannedMenu is toggled in private mode', async () => {
    const wrapper = mount(Editor, {
      global: {
        plugins: [store],
        stubs: {
          CannedResponse: {
            template: '<div class="canned-response-stub" />',
            props: ['searchKey'],
          },
          TagAgents: true,
          VariableList: true,
          KeyboardEmojiSelector: true,
          TagTools: true,
          CopilotMenuBar: true,
        },
      },
      props: {
        isPrivate: true,
        enableCannedResponses: true,
        enableSuggestions: true,
      },
    });

    expect(wrapper.find('.canned-response-stub').exists()).toBe(false);

    wrapper.vm.showCannedMenu = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.find('.canned-response-stub').exists()).toBe(true);
    expect(wrapper.emitted('toggleCannedMenu')).toEqual([[true]]);
  });
});

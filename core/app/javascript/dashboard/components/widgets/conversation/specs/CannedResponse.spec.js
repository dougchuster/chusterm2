import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import CannedResponse from '../CannedResponse.vue';

describe('CannedResponse.vue', () => {
  let store;
  let actions;
  let getters;

  const mockCannedResponses = [
    { id: 1, short_code: 'ola', content: 'Olá, como posso ajudar?' },
    { id: 2, short_code: 'obrigado', content: 'Muito obrigado pelo contato.' },
    { id: 3, short_code: 'suporte_crm', content: 'Atendimento do CRM.' },
  ];

  beforeEach(() => {
    actions = {
      getCannedResponse: vi.fn(),
    };
    getters = {
      getCannedResponses: () => mockCannedResponses,
    };
    store = createStore({
      actions,
      getters,
    });
  });

  it('renders all items when searchKey is empty', () => {
    const wrapper = shallowMount(CannedResponse, {
      global: {
        plugins: [store],
      },
      props: {
        searchKey: '',
      },
    });

    expect(wrapper.vm.items).toHaveLength(3);
    expect(wrapper.vm.items[0].label).toBe('ola');
    expect(actions.getCannedResponse).toHaveBeenCalledWith(expect.anything(), {
      searchKey: '',
    });
  });

  it('filters items with fuzzy matching when searchKey is provided', async () => {
    const wrapper = shallowMount(CannedResponse, {
      global: {
        plugins: [store],
      },
      props: {
        searchKey: 'obg',
      },
    });

    expect(wrapper.vm.items).toHaveLength(1);
    expect(wrapper.vm.items[0].label).toBe('obrigado');
  });

  it('filters items with accent-insensitivity', async () => {
    const wrapper = shallowMount(CannedResponse, {
      global: {
        plugins: [store],
      },
      props: {
        searchKey: 'ola',
      },
    });

    expect(wrapper.vm.items[0].label).toBe('ola');
  });

  it('emits replace when handleMentionClick is called', () => {
    const wrapper = shallowMount(CannedResponse, {
      global: {
        plugins: [store],
      },
      props: {
        searchKey: '',
      },
    });

    wrapper.vm.handleMentionClick({
      label: 'ola',
      description: 'Olá, como posso ajudar?',
    });

    expect(wrapper.emitted('replace')).toEqual([['Olá, como posso ajudar?']]);
  });
});

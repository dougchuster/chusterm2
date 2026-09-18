import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';
import ConversationApi from 'dashboard/api/inbox/conversation';

import CRMConversationPanel from './CRMConversationPanel.vue';

// 1.1/1.2 do PLANO_17_09 — o painel empurra a conversa do negócio para a store
// global (mesmo cable da caixa de entrada) e compõe MessagesView/ReplyBox
// upstream; a barra de contexto cuida de etapa, situação, dono e resultado.

const dispatch = vi.fn();
const commit = vi.fn();
const selectedChat = ref({});

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch,
    commit,
    getters: { getSelectedChat: selectedChat.value },
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getDeal: vi.fn(),
    moveDeal: vi.fn(),
    updateDeal: vi.fn(),
    markDealWon: vi.fn(),
    markDealLost: vi.fn(),
    reopenDeal: vi.fn(),
  },
}));

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: {
    show: vi.fn(),
  },
}));

vi.mock('dashboard/api/captain/conversationState', () => ({
  default: {
    show: vi.fn(),
    update: vi.fn(),
  },
}));

// As peças upstream e o card do Capitão têm vida própria na store; o contrato
// testado aqui é o do painel, então eles viram stubs leves.
vi.mock(
  'dashboard/components/widgets/conversation/ConversationHeader.vue',
  () => ({
    default: { name: 'ConversationHeader', template: '<div />' },
  })
);
vi.mock('dashboard/components/widgets/conversation/MessagesView.vue', () => ({
  default: {
    name: 'MessagesView',
    template: '<div data-testid="messages-view" />',
  },
}));
vi.mock(
  'dashboard/components/captain/CaptainConversationStateCard.vue',
  () => ({
    default: {
      name: 'CaptainConversationStateCard',
      template: '<div />',
    },
  })
);

const deal = (overrides = {}) => ({
  id: 4,
  account_id: 55,
  title: 'Maria Souza',
  contact_name: 'Maria Souza',
  status: 'open',
  crm_pipeline_stage_id: 10,
  owner_id: 7,
  conversation_display_id: 31,
  ...overrides,
});

const mountPanel = (props = {}) =>
  mount(CRMConversationPanel, {
    props: {
      deal: deal(),
      stages: [
        { id: 10, name: 'Novo' },
        { id: 20, name: 'Qualificado' },
      ],
      agents: [{ id: 7, name: 'Ana' }],
      lossReasons: [],
      accountId: 55,
      show: true,
      ...props,
    },
    global: {
      stubs: {
        'woot-modal': {
          template: '<div><slot /></div>',
          props: ['show'],
        },
      },
    },
  });

describe('CRMConversationPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    selectedChat.value = {};
    CrmAPI.getDeal.mockResolvedValue({ data: deal() });
    ConversationApi.show.mockResolvedValue({
      data: { id: 31, meta: { sender: { id: 9 } } },
    });
    dispatch.mockResolvedValue({});
  });

  it('loads the deal and pushes its conversation into the global store', async () => {
    mountPanel();
    await flushPromises();

    expect(ConversationApi.show).toHaveBeenCalledWith(31);
    expect(dispatch).toHaveBeenCalledWith(
      'updateConversation',
      expect.objectContaining({ id: 31 })
    );
    expect(dispatch).toHaveBeenCalledWith('setActiveChat', {
      data: expect.objectContaining({ id: 31 }),
    });
    expect(CrmAPI.getDeal).toHaveBeenCalledWith(4);
  });

  it('renders the upstream message stack once the chat is active', async () => {
    const wrapper = mountPanel();
    await flushPromises();

    expect(wrapper.find('[data-testid="messages-view"]').exists()).toBe(true);
  });

  it('skips the conversation fetch for deals without one', async () => {
    mountPanel({ deal: deal({ conversation_display_id: null }) });
    await flushPromises();

    expect(ConversationApi.show).not.toHaveBeenCalled();
  });

  it('moves the deal to another stage and echoes it to the board', async () => {
    CrmAPI.moveDeal.mockResolvedValue({
      data: deal({ crm_pipeline_stage_id: 20 }),
    });
    const wrapper = mountPanel();
    await flushPromises();

    const stageSelect = wrapper.findAll('select')[0];
    await stageSelect.setValue('20');

    expect(CrmAPI.moveDeal).toHaveBeenCalledWith(4, '20');
    const updates = wrapper.emitted('dealUpdated');
    expect(updates.at(-1)[0].crm_pipeline_stage_id).toBe(20);
  });

  it('reassigns the owner through the context bar', async () => {
    CrmAPI.updateDeal.mockResolvedValue({ data: deal({ owner_id: 8 }) });
    const wrapper = mountPanel({
      agents: [
        { id: 7, name: 'Ana' },
        { id: 8, name: 'Bruno' },
      ],
    });
    await flushPromises();

    const ownerSelect = wrapper.findAll('select')[2];
    await ownerSelect.setValue('8');

    expect(CrmAPI.updateDeal).toHaveBeenCalledWith(4, { owner_id: '8' });
  });

  it('clears the selected conversation when the panel closes', async () => {
    const wrapper = mountPanel();
    await flushPromises();

    await wrapper.setProps({ show: false });

    expect(dispatch).toHaveBeenCalledWith('clearSelectedState');
  });

  it('surfaces the Captain handoff summary when present', async () => {
    const wrapper = mountPanel({
      deal: deal({
        conversation: {
          display_id: 31,
          handoff_summary: 'Cliente pediu especialista em previdenciário.',
        },
      }),
    });
    await flushPromises();

    const strip = wrapper.find('[data-testid="crm-drawer-handoff-summary"]');
    expect(strip.exists()).toBe(true);
    expect(strip.text()).toContain('especialista');
  });
});

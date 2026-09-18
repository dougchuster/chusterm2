import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';

import CrmIndex from './CrmIndexOperational.vue';

// F2.1-a do PLANO-KANBAN-CRM-2026.md — item nº 2 do goal: responder no WhatsApp
// sem sair do Kanban.
//
// O painel de atendimento é o `CRMConversationPanel` (1.1 do PLANO_17_09):
// compõe MessagesView+ReplyBox upstream. Este arquivo protege o contrato com o
// board: a página monta o painel com o contexto certo e reflete no card o que
// acontece lá dentro, sem refetch do quadro.

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(55) }),
}));

// O painel de verdade compõe MessagesView/ReplyBox e fala com a store; aqui só
// interessa que o board o monte com o contrato certo e reaja ao que ele emite.
vi.mock('dashboard/components/crm/CRMConversationPanel.vue', () => ({
  default: {
    name: 'CRMConversationPanel',
    props: ['deal', 'stages', 'agents', 'lossReasons', 'accountId', 'show'],
    emits: ['dealUpdated', 'openDealDrawer', 'update:show'],
    template: '<div data-testid="chat-drawer" />',
  },
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getBoard: vi.fn(),
    getPipelines: vi.fn(),
    getLossReasons: vi.fn(),
    moveDeal: vi.fn(),
    bulkActionDeals: vi.fn(),
    createDeal: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const deal = (overrides = {}) => ({
  id: 4,
  account_id: 55,
  title: 'Maria Souza',
  status: 'open',
  crm_pipeline_stage_id: 10,
  ...overrides,
});

const mountBoard = async () => {
  CrmAPI.getPipelines.mockResolvedValue({ data: [{ id: 1, name: 'Kanban' }] });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  // Desde a F2.2 o board pinta com uma requisicao, e as etapas sao as
  // proprias colunas da resposta.
  CrmAPI.getBoard.mockResolvedValue({
    data: {
      pipeline: { id: 1, name: 'Kanban' },
      columns: [
        // F2.8: `id` e a chave do balde; `stage_id` e a etapa.
        {
          id: '10',
          stage_id: 10,
          name: 'Novo',
          position: 0,
          count: 1,
          deals: [deal()],
        },
        {
          id: '20',
          stage_id: 20,
          name: 'Qualificado',
          position: 1,
          count: 0,
          deals: [],
        },
      ],
      meta: { per_column: 25 },
    },
  });

  const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
  await flushPromises();
  return wrapper;
};

const chatDrawer = wrapper =>
  wrapper.findComponent({ name: 'CRMConversationPanel' });

describe('CrmIndexOperational — atender sem sair do quadro', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  it('renders the chat drawer, which only the legacy board did', async () => {
    const wrapper = await mountBoard();

    expect(chatDrawer(wrapper).exists()).toBe(true);
  });

  it('opens it on the deal the attendant picked', async () => {
    const wrapper = await mountBoard();

    await wrapper.vm.openAttendance(wrapper.vm.deals[0]);

    expect(wrapper.vm.showChatDrawer).toBe(true);
    expect(chatDrawer(wrapper).props('deal').id).toBe(4);
  });

  it('hands the drawer the context it needs to work', async () => {
    const wrapper = await mountBoard();
    await wrapper.vm.openAttendance(wrapper.vm.deals[0]);

    const props = chatDrawer(wrapper).props();

    expect(props.accountId).toBe(55);
    expect(props.stages.map(stage => stage.id)).toEqual([10, 20]);
    expect(props.lossReasons).toEqual([]);
  });

  // O drawer troca etapa, muda modo da IA e marca ganho/perdido. Recarregar o
  // quadro inteiro a cada uma dessas seria jogar fora o ganho da F1.5.
  it('folds what happened in the chat back into the card, without refetching', async () => {
    const wrapper = await mountBoard();
    await wrapper.vm.openAttendance(wrapper.vm.deals[0]);
    CrmAPI.getBoard.mockClear();

    await chatDrawer(wrapper).vm.$emit('dealUpdated', {
      id: 4,
      crm_pipeline_stage_id: 20,
    });
    await flushPromises();

    // Verificar so a lista achatada mascarava um bug: o campo mudava e o card
    // continuava fisicamente na coluna antiga. Quem manda sao as colunas.
    const [origem, destino] = wrapper.vm.columns;
    expect(origem.deals.map(item => item.id)).toEqual([]);
    expect(destino.deals.map(item => item.id)).toEqual([4]);
    expect(destino.deals[0].title).toBe('Maria Souza');
    expect(CrmAPI.getBoard).not.toHaveBeenCalled();
  });

  it('keeps the open drawer showing the deal it just changed', async () => {
    const wrapper = await mountBoard();
    await wrapper.vm.openAttendance(wrapper.vm.deals[0]);

    await chatDrawer(wrapper).vm.$emit('dealUpdated', {
      id: 4,
      crm_pipeline_stage_id: 20,
    });
    await flushPromises();

    expect(chatDrawer(wrapper).props('deal').crm_pipeline_stage_id).toBe(20);
  });

  it('hands over to the edit drawer when the chat asks for it', async () => {
    const wrapper = await mountBoard();
    await wrapper.vm.openAttendance(wrapper.vm.deals[0]);

    await chatDrawer(wrapper).vm.$emit('openDealDrawer', deal());
    await flushPromises();

    expect(wrapper.vm.showDealDrawer).toBe(true);
    expect(wrapper.vm.showChatDrawer).toBe(false);
  });

  it('lets go of the deal when the drawer closes, so it does not leak into the next one', async () => {
    const wrapper = await mountBoard();
    await wrapper.vm.openAttendance(wrapper.vm.deals[0]);

    wrapper.vm.showChatDrawer = false;
    await flushPromises();

    expect(wrapper.vm.attendanceDeal).toBe(null);
  });
});

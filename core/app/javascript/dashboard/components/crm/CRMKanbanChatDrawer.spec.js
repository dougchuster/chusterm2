import { flushPromises, mount } from '@vue/test-utils';
import { nextTick } from 'vue';

import CRMKanbanChatDrawer from './CRMKanbanChatDrawer.vue';
import CrmAPI from 'dashboard/api/crm';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import ConversationApi from 'dashboard/api/inbox/conversation';
import MessageApi from 'dashboard/api/inbox/message';

vi.mock('dashboard/api/crm', () => ({
  default: {
    getDeal: vi.fn(),
    moveDeal: vi.fn(),
    updateDeal: vi.fn(),
  },
}));

vi.mock('dashboard/api/captain/conversationState', () => ({
  default: {
    show: vi.fn(),
    update: vi.fn(),
  },
}));

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: {
    markMessageRead: vi.fn(),
  },
}));

vi.mock('dashboard/api/inbox/message', () => ({
  default: {
    getPreviousMessages: vi.fn(),
    create: vi.fn(),
  },
}));

const baseDeal = {
  id: 7,
  title: 'Atendimento #55',
  contact_name: 'Maria Cliente',
  conversation_id: 100,
  conversation_display_id: 55,
  crm_pipeline_stage_id: 3,
  operational_status: 'active',
  messages: [],
  activities: [],
};

const mountDrawer = () =>
  mount(CRMKanbanChatDrawer, {
    props: {
      show: true,
      deal: baseDeal,
      stages: [{ id: 3, name: 'Analise' }],
      agents: [],
      accountId: 1,
    },
  });

describe('CRMKanbanChatDrawer', () => {
  beforeEach(() => {
    CrmAPI.getDeal.mockResolvedValue({
      data: {
        ...baseDeal,
        summary: 'Cliente quer avaliar o caso.',
        conversation: { id: 100, display_id: 55 },
      },
    });
    MessageApi.getPreviousMessages.mockResolvedValue({
      data: { payload: [] },
    });
    MessageApi.create.mockResolvedValue({
      data: {
        id: 44,
        content: 'Mensagem enviada',
        message_type: 'outgoing',
        created_at: '2026-05-26T10:01:00.000Z',
      },
    });
    ConversationApi.markMessageRead.mockResolvedValue({});
    CaptainConversationStateAPI.show.mockResolvedValue({
      data: {
        id: 1,
        ai_mode: 'human_only',
        handoff_reason: 'Atendimento assumido',
        handoff_at: '2026-05-26T10:00:00.000Z',
        handoff_by_name: 'Doug',
      },
    });
  });

  it('does not reload context when the parent replaces the same selected deal', async () => {
    const wrapper = mountDrawer();

    await flushPromises();
    await nextTick();

    expect(CrmAPI.getDeal).toHaveBeenCalledTimes(1);
    expect(wrapper.text()).toContain('Humano assumiu');
    expect(wrapper.text()).not.toContain('Carregando IA');

    const updatedDeal = wrapper.emitted('dealUpdated').at(-1)[0];
    await wrapper.setProps({
      deal: {
        ...baseDeal,
        ...updatedDeal,
      },
    });
    await flushPromises();
    await nextTick();

    expect(CrmAPI.getDeal).toHaveBeenCalledTimes(1);
  });

  it('keeps the active AI mode action disabled to avoid duplicate handoff events', async () => {
    const wrapper = mountDrawer();

    await flushPromises();
    await nextTick();

    const assumeButton = wrapper
      .findAll('button')
      .find(button => button.text() === 'Assumir');

    expect(assumeButton.attributes('disabled')).toBeDefined();

    await assumeButton.trigger('click');
    expect(CaptainConversationStateAPI.update).not.toHaveBeenCalled();
  });

  it('allows the operator to write and send a chat message from the drawer', async () => {
    const wrapper = mountDrawer();

    await flushPromises();
    await nextTick();

    const textarea = wrapper.get('textarea[aria-label="Responder ao cliente"]');
    expect(textarea.attributes('disabled')).toBeUndefined();

    await textarea.setValue('Ola, vou assumir seu atendimento.');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Enviar')
      .trigger('click');
    await flushPromises();

    expect(MessageApi.create).toHaveBeenCalledWith({
      conversationId: 55,
      message: 'Ola, vou assumir seu atendimento.',
      private: false,
    });
    expect(wrapper.text()).toContain('Mensagem enviada');
  });
});

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
    markDealWon: vi.fn(),
    markDealLost: vi.fn(),
    reopenDeal: vi.fn(),
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
  contact: {
    id: 9,
    name: 'Maria Cliente',
    thumbnail: 'https://cdn.test/maria.jpg',
  },
  conversation_id: 100,
  conversation_display_id: 55,
  crm_pipeline_stage_id: 3,
  operational_status: 'active',
  status: 'open',
  messages: [],
  activities: [],
};

const longSummary =
  'Cliente relata urgencia no andamento do processo, enviou documentos por imagem e audio, pediu retorno ainda hoje e aguarda validacao do advogado responsavel antes de seguir para contrato.';

const mediaMessages = [
  {
    id: 10,
    content: 'Segue documento e audio.',
    message_type: 'incoming',
    sender_name: 'Maria Cliente',
    created_at: '2026-05-26T09:59:00.000Z',
    attachments: [
      {
        id: 101,
        file_type: 'image',
        data_url: 'https://cdn.test/documento.png',
        fallback_title: 'documento.png',
      },
      {
        id: 102,
        file_type: 'audio',
        data_url: 'https://cdn.test/audio.mp3',
        fallback_title: 'audio.mp3',
      },
    ],
  },
];

const mountDrawer = (deal = baseDeal) =>
  mount(CRMKanbanChatDrawer, {
    props: {
      show: true,
      deal,
      stages: [{ id: 3, name: 'Analise' }],
      agents: [],
      lossReasons: [{ id: 12, name: 'Sem retorno do cliente' }],
      accountId: 1,
    },
  });

describe('CRMKanbanChatDrawer', () => {
  beforeEach(() => {
    CrmAPI.getDeal.mockResolvedValue({
      data: {
        ...baseDeal,
        summary: longSummary,
        conversation: { id: 100, display_id: 55 },
      },
    });
    MessageApi.getPreviousMessages.mockResolvedValue({
      data: { payload: mediaMessages },
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
    CrmAPI.markDealWon.mockResolvedValue({
      data: { ...baseDeal, status: 'won' },
    });
    CrmAPI.markDealLost.mockResolvedValue({
      data: {
        ...baseDeal,
        status: 'lost',
        crm_loss_reason_id: 12,
        loss_reason: { id: 12, name: 'Sem retorno do cliente' },
        lost_reason_note: 'Cliente não respondeu.',
      },
    });
    CrmAPI.reopenDeal.mockResolvedValue({
      data: { ...baseDeal, status: 'open' },
    });
    CaptainConversationStateAPI.show.mockResolvedValue({
      data: {
        id: 1,
        ai_mode: 'human_only',
        handoff_reason: 'Atendimento assumido',
        handoff_at: '2026-05-26T10:00:00.000Z',
        handoff_by_name: 'Doug',
      },
    });
    CaptainConversationStateAPI.update.mockResolvedValue({
      data: { id: 1, ai_mode: 'auto', resume_source: 'manual' },
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

  it('uses only the display ID for Captain when database and display IDs diverge', async () => {
    const wrapper = mountDrawer();
    await flushPromises();

    expect(CaptainConversationStateAPI.show).toHaveBeenCalledWith(55);
    expect(wrapper.text()).toContain('Atendimento #55');
    expect(wrapper.text()).not.toContain('Atendimento #100');

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Retomar')
      .trigger('click');
    await flushPromises();

    expect(CaptainConversationStateAPI.update).toHaveBeenCalledWith(
      55,
      expect.objectContaining({ ai_mode: 'auto', crm_deal_id: 7 })
    );
    expect(CaptainConversationStateAPI.update).not.toHaveBeenCalledWith(
      100,
      expect.anything()
    );
  });

  it('keeps Captain actions unavailable when the explicit display ID is missing', async () => {
    const dealWithoutDisplayId = {
      ...baseDeal,
      conversation_display_id: undefined,
    };
    CrmAPI.getDeal.mockResolvedValueOnce({
      data: {
        ...dealWithoutDisplayId,
        conversation: { id: 100 },
      },
    });

    const wrapper = mountDrawer(dealWithoutDisplayId);
    await flushPromises();

    expect(CaptainConversationStateAPI.show).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Atendimento');
    expect(wrapper.text()).not.toContain('Atendimento #100');
    expect(wrapper.text()).not.toContain('Atendimento #7');
    const resumeButton = wrapper
      .findAll('button')
      .find(button => button.text() === 'Retomar');
    expect(resumeButton.attributes('disabled')).toBeDefined();
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

  it('marks the deal as won from the Kanban drawer', async () => {
    const wrapper = mountDrawer();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Marcar ganho')
      .trigger('click');
    await flushPromises();

    expect(CrmAPI.markDealWon).toHaveBeenCalledWith(7);
    expect(wrapper.get('[data-testid="deal-outcome-status"]').text()).toBe(
      'Ganho'
    );
  });

  it('marks the deal as lost with a required reason and note', async () => {
    const wrapper = mountDrawer();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Marcar perdido')
      .trigger('click');
    await wrapper.get('[data-testid="deal-loss-form"] select').setValue('12');
    await wrapper
      .get('[data-testid="deal-loss-form"] input')
      .setValue('Cliente não respondeu.');
    await wrapper.get('[data-testid="deal-loss-form"]').trigger('submit');
    await flushPromises();

    expect(CrmAPI.markDealLost).toHaveBeenCalledWith(
      7,
      12,
      'Cliente não respondeu.'
    );
    expect(wrapper.get('[data-testid="deal-outcome-status"]').text()).toBe(
      'Perdido'
    );
  });

  it('renders contact avatar, optional summary, direction icons and media attachments', async () => {
    const wrapper = mountDrawer();

    await flushPromises();
    await nextTick();

    const avatar = wrapper.get('img[alt="Maria Cliente"]');
    expect(avatar.attributes('src')).toBe('https://cdn.test/maria.jpg');
    expect(wrapper.text()).toContain('Resumo');
    expect(wrapper.text()).not.toContain('Resumo do atendimento');
    expect(wrapper.text()).not.toContain(longSummary);

    await wrapper.get('button[title="Abrir resumo"]').trigger('click');

    expect(wrapper.text()).toContain('Ver mais');
    expect(wrapper.text()).not.toContain(longSummary);

    expect(wrapper.find('.crm-attendance-message__direction').exists()).toBe(
      true
    );
    expect(wrapper.get('img[alt="documento.png"]').attributes('src')).toBe(
      'https://cdn.test/documento.png'
    );
    expect(wrapper.get('audio').attributes('src')).toBe(
      'https://cdn.test/audio.mp3'
    );

    await wrapper.get('button[title="Ocultar resumo"]').trigger('click');
    expect(wrapper.text()).not.toContain('Resumo do atendimento');
  });

  it('allows only http(s) and app-relative attachment URLs, falling back to # otherwise', async () => {
    MessageApi.getPreviousMessages.mockResolvedValueOnce({
      data: {
        payload: [
          {
            id: 20,
            content: 'Anexos suspeitos.',
            message_type: 'incoming',
            sender_name: 'Maria Cliente',
            created_at: '2026-05-26T10:00:00.000Z',
            attachments: [
              {
                id: 201,
                file_type: 'file',
                // eslint-disable-next-line no-script-url -- payload malicioso proposital: o teste garante que a URL e rejeitada
                external_url: 'javascript:alert(1)',
                fallback_title: 'poisoned.pdf',
              },
              {
                id: 202,
                file_type: 'file',
                data_url: '/rails/active_storage/blobs/xyz/contrato.pdf',
                fallback_title: 'contrato.pdf',
              },
            ],
          },
        ],
      },
    });

    const wrapper = mountDrawer();
    await flushPromises();
    await nextTick();

    const poisoned = wrapper
      .findAll('a.crm-attendance-attachment__file')
      .find(link => link.text().includes('poisoned.pdf'));
    expect(poisoned.attributes('href')).toBe('#');

    const relative = wrapper
      .findAll('a.crm-attendance-attachment__file')
      .find(link => link.text().includes('contrato.pdf'));
    expect(relative.attributes('href')).toBe(
      '/rails/active_storage/blobs/xyz/contrato.pdf'
    );
  });
});

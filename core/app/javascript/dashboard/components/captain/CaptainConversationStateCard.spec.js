import { flushPromises, mount } from '@vue/test-utils';

import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import CaptainConversationStateCard from './CaptainConversationStateCard.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));

vi.mock('dashboard/api/captain/conversationState', () => ({
  default: {
    show: vi.fn(),
    update: vi.fn(),
  },
}));

const createDeferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
};

const stateFixture = (conversationDisplayId, handoffReason = '') => ({
  id: conversationDisplayId,
  conversation_display_id: conversationDisplayId,
  ai_mode: 'auto',
  handoff_reason: handoffReason,
  score_total: 42,
  score_classification: 'Em qualificação',
  relationship: {
    label: `Contato ${conversationDisplayId}`,
    confidence: 0.8,
    evidence: [],
  },
});

const mountCard = conversationDisplayId =>
  mount(CaptainConversationStateCard, {
    props: { conversationDisplayId },
  });

describe('CaptainConversationStateCard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('ignores a stale load response after the conversation changes', async () => {
    const firstLoad = createDeferred();
    const secondLoad = createDeferred();
    CaptainConversationStateAPI.show
      .mockReturnValueOnce(firstLoad.promise)
      .mockReturnValueOnce(secondLoad.promise);

    const wrapper = mountCard(101);
    await wrapper.setProps({ conversationDisplayId: 202 });

    secondLoad.resolve({ data: stateFixture(202, 'Contexto da conversa 202') });
    await flushPromises();

    expect(wrapper.get('[data-testid="captain-reason"]').element.value).toBe(
      'Contexto da conversa 202'
    );

    firstLoad.resolve({ data: stateFixture(101, 'Contexto obsoleto') });
    await flushPromises();

    expect(wrapper.get('[data-testid="captain-reason"]').element.value).toBe(
      'Contexto da conversa 202'
    );
    expect(wrapper.text()).not.toContain('Contexto obsoleto');
    expect(wrapper.attributes('aria-busy')).toBe('false');
  });

  it('clears the previous state while the new conversation loads', async () => {
    const secondLoad = createDeferred();
    CaptainConversationStateAPI.show
      .mockResolvedValueOnce({
        data: stateFixture(101, 'Contexto da conversa anterior'),
      })
      .mockReturnValueOnce(secondLoad.promise);

    const wrapper = mountCard(101);
    await flushPromises();
    expect(wrapper.get('[data-testid="captain-reason"]').element.value).toBe(
      'Contexto da conversa anterior'
    );

    await wrapper.setProps({ conversationDisplayId: 202 });

    expect(wrapper.find('[data-testid="captain-reason"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Contexto da conversa anterior');
    expect(wrapper.attributes('aria-busy')).toBe('true');

    secondLoad.resolve({ data: stateFixture(202) });
    await flushPromises();
  });

  it('marks an edited reason as dirty and saves it explicitly', async () => {
    CaptainConversationStateAPI.show.mockResolvedValue({
      data: stateFixture(101, 'Motivo original'),
    });
    CaptainConversationStateAPI.update.mockResolvedValue({
      data: stateFixture(101, 'Novo contexto humano'),
    });

    const wrapper = mountCard(101);
    await flushPromises();

    const saveButton = wrapper.get('[data-testid="captain-save-reason"]');
    expect(saveButton.attributes('disabled')).toBeDefined();

    await wrapper
      .get('[data-testid="captain-reason"]')
      .setValue('Novo contexto humano');

    expect(wrapper.get('[data-testid="captain-reason-status"]').text()).toBe(
      'Alterações ainda não salvas'
    );
    expect(saveButton.attributes('disabled')).toBeUndefined();

    await saveButton.trigger('click');
    await flushPromises();

    expect(CaptainConversationStateAPI.update).toHaveBeenCalledWith(101, {
      handoff_reason: 'Novo contexto humano',
    });
    expect(wrapper.get('[data-testid="captain-reason-status"]').text()).toBe(
      'Contexto sincronizado'
    );
    expect(saveButton.attributes('disabled')).toBeDefined();
  });

  it('never applies a save response to a different conversation', async () => {
    const firstSave = createDeferred();
    CaptainConversationStateAPI.show
      .mockResolvedValueOnce({
        data: stateFixture(101, 'Contexto da conversa 101'),
      })
      .mockResolvedValueOnce({
        data: stateFixture(202, 'Contexto da conversa 202'),
      });
    CaptainConversationStateAPI.update.mockReturnValue(firstSave.promise);

    const wrapper = mountCard(101);
    await flushPromises();
    await wrapper
      .get('[data-testid="captain-reason"]')
      .setValue('Alteração da conversa 101');
    await wrapper.get('[data-testid="captain-save-reason"]').trigger('click');

    await wrapper.setProps({ conversationDisplayId: 202 });
    await flushPromises();

    firstSave.resolve({
      data: stateFixture(101, 'Alteração da conversa 101'),
    });
    await flushPromises();

    expect(CaptainConversationStateAPI.update).toHaveBeenCalledWith(101, {
      handoff_reason: 'Alteração da conversa 101',
    });
    expect(wrapper.get('[data-testid="captain-reason"]').element.value).toBe(
      'Contexto da conversa 202'
    );
    expect(wrapper.text()).not.toContain('Alteração da conversa 101');
    expect(wrapper.attributes('aria-busy')).toBe('false');
  });
});

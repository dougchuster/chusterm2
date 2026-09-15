import { flushPromises, mount } from '@vue/test-utils';
import CaptainAiCenterAPI from 'dashboard/api/captain/aiCenter';
import CaptainConversationStateAPI from 'dashboard/api/captain/conversationState';
import AiCenter from './AiCenter.vue';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  routerPush: vi.fn(),
}));

vi.mock('dashboard/api/captain/aiCenter', () => ({
  default: {
    get: vi.fn(),
  },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
  useRouter: () => ({ push: mocks.routerPush }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: mocks.alert,
}));

vi.mock('dashboard/helper/crmOptions', () => ({
  AI_HANDOFF_REASON_LABELS: {},
}));

vi.mock('dashboard/api/captain/conversationState', () => ({
  default: {
    update: vi.fn(),
  },
}));

const aiCenterResponse = pausedConversations => ({
  data: {
    summary: {
      auto: 0,
      paused: pausedConversations.length,
      human_only: 0,
      by_reason_code: {},
    },
    metrics: {},
    media: {},
    paused_conversations: pausedConversations,
  },
});

const mountPage = async pausedConversations => {
  CaptainAiCenterAPI.get.mockResolvedValue(
    aiCenterResponse(pausedConversations)
  );
  CaptainConversationStateAPI.update.mockResolvedValue({ data: {} });

  const wrapper = mount(AiCenter);
  await flushPromises();
  return wrapper;
};

describe('AiCenter conversation identifiers', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('resumes Captain with the explicit display ID when IDs diverge', async () => {
    const wrapper = await mountPage([
      {
        id: 7,
        conversation_id: 100,
        conversation_display_id: 55,
        contact_name: 'Maria Cliente',
        ai_mode: 'paused',
      },
    ]);

    // Seletor por ícone: o rótulo é i18n e muda com o locale do teste.
    const resumeButton = wrapper
      .findAll('button')
      .find(button => button.html().includes('i-lucide-play-circle'));
    expect(resumeButton.attributes('disabled')).toBeUndefined();

    await resumeButton.trigger('click');
    await flushPromises();

    expect(CaptainConversationStateAPI.update).toHaveBeenCalledWith(55, {
      ai_mode: 'auto',
    });
    expect(CaptainConversationStateAPI.update).not.toHaveBeenCalledWith(
      100,
      expect.anything()
    );
  });

  it('disables resume and never calls Captain without a display ID', async () => {
    const wrapper = await mountPage([
      {
        id: 8,
        conversation_id: 100,
        contact_name: 'João Cliente',
        ai_mode: 'paused',
      },
    ]);

    const resumeButton = wrapper
      .findAll('button')
      .find(button => button.html().includes('i-lucide-play-circle'));
    expect(resumeButton.attributes('disabled')).toBeDefined();

    await resumeButton.trigger('click');
    await flushPromises();

    expect(CaptainConversationStateAPI.update).not.toHaveBeenCalled();
  });
});

import { mount } from '@vue/test-utils';
import { computed, ref } from 'vue';
import CopilotSidebarPanel from './CopilotSidebarPanel.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

const mockSummarize = vi.fn();
const mockGetReplySuggestion = vi.fn();
const mockRewriteContent = vi.fn();
const mockUpdateUISettings = vi.fn();
const mockUseAlert = vi.fn();
const mockDispatch = vi.fn();

const captainEnabledRef = ref(true);
const captainTasksEnabledRef = ref(true);
const assistantsRef = ref([]);

vi.mock('dashboard/composables/useCaptain', () => ({
  useCaptain: () => ({
    captainEnabled: computed(() => captainEnabledRef.value),
    captainTasksEnabled: computed(() => captainTasksEnabledRef.value),
    summarizeConversation: mockSummarize,
    getReplySuggestion: mockGetReplySuggestion,
    rewriteContent: mockRewriteContent,
  }),
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: ref({
      is_copilot_panel_open: true,
      preferred_captain_assistant_id: null,
    }),
    updateUISettings: mockUpdateUISettings,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: msg => mockUseAlert(msg),
  useTrack: vi.fn(),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: mockDispatch,
    getters: {
      'copilotMessages/getMessagesByThreadId': () => [],
    },
  }),
  useMapGetter: name => {
    if (name === 'captainAssistants/getRecords') return assistantsRef;
    if (name === 'getCurrentUser') return ref({ id: 1, name: 'Agent' });
    if (name === 'getCopilotAssistant') return ref(null);
    if (name === 'getSelectedChat') return ref({ id: 10, inbox_id: 1 });
    return ref(null);
  },
}));

const mountComponent = (props = {}) =>
  mount(CopilotSidebarPanel, {
    props: {
      conversationId: '10',
      ...props,
    },
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${JSON.stringify(params)}` : key,
      },
      stubs: {
        SidebarActionsHeader: {
          props: ['title'],
          template:
            '<div data-testid="sidebar-header"><button data-testid="close-btn" @click="$emit(\'close\')" /></div>',
        },
        Icon: { template: '<i />' },
        Copilot: { template: '<div data-testid="copilot-chat" />' },
      },
    },
  });

describe('CopilotSidebarPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    captainEnabledRef.value = true;
    captainTasksEnabledRef.value = true;
    assistantsRef.value = [];
  });

  it('renders the contextual tools by default', () => {
    const wrapper = mountComponent();
    expect(wrapper.find('[data-testid="copilot-sidebar-panel"]').exists()).toBe(
      true
    );
    expect(wrapper.text()).toContain('COPILOT.SMART_SUMMARY.TITLE');
    expect(wrapper.text()).toContain('COPILOT.REPLY_ASSISTANT.TITLE');
  });

  it('generates a conversation summary when requested', async () => {
    mockSummarize.mockResolvedValueOnce({
      message:
        '1. Customer inquired about case status.\n2. Agent provided next steps.',
    });

    const wrapper = mountComponent();
    const generateBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('COPILOT.SMART_SUMMARY.GENERATE_BUTTON'));
    expect(generateBtn).toBeDefined();

    await generateBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(mockSummarize).toHaveBeenCalled();
    expect(wrapper.find('[data-testid="summary-content"]').text()).toContain(
      '1. Customer inquired about case status.'
    );
  });

  it('handles summary generation error gracefully', async () => {
    mockSummarize.mockRejectedValueOnce(new Error('API failed'));

    const wrapper = mountComponent();
    const generateBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('COPILOT.SMART_SUMMARY.GENERATE_BUTTON'));
    await generateBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(mockUseAlert).toHaveBeenCalledWith(
      'Could not generate summary. Please try again.'
    );
  });

  it('emits insert into editor event when clicking insert button on summary', async () => {
    const emitterSpy = vi.spyOn(emitter, 'emit');
    mockSummarize.mockResolvedValueOnce({
      message: 'Summary text to insert',
    });

    const wrapper = mountComponent();
    const generateBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('COPILOT.SMART_SUMMARY.GENERATE_BUTTON'));
    await generateBtn.trigger('click');
    await wrapper.vm.$nextTick();

    const insertBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('COPILOT.SMART_SUMMARY.INSERT'));
    expect(insertBtn).toBeDefined();
    await insertBtn.trigger('click');

    expect(emitterSpy).toHaveBeenCalledWith(
      BUS_EVENTS.INSERT_INTO_RICH_EDITOR,
      'Summary text to insert'
    );
  });

  it('generates a reply suggestion and allows tone refinement', async () => {
    mockGetReplySuggestion.mockResolvedValueOnce({
      message: 'Hello, your case is being reviewed.',
    });
    mockRewriteContent.mockResolvedValueOnce({
      message: 'Dear client, your case is under formal review.',
    });

    const wrapper = mountComponent();
    const suggestBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('COPILOT.REPLY_ASSISTANT.GENERATE_BUTTON'));
    await suggestBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(mockGetReplySuggestion).toHaveBeenCalled();
    expect(wrapper.find('[data-testid="reply-content"]').text()).toBe(
      'Hello, your case is being reviewed.'
    );

    // Refine with professional tone
    const professionalBtn = wrapper
      .findAll('button')
      .find(b =>
        b.text().includes('COPILOT.REPLY_ASSISTANT.TONE_PROFESSIONAL')
      );
    expect(professionalBtn).toBeDefined();
    await professionalBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(mockRewriteContent).toHaveBeenCalledWith(
      'Hello, your case is being reviewed.',
      'professional'
    );
    expect(wrapper.find('[data-testid="reply-content"]').text()).toBe(
      'Dear client, your case is under formal review.'
    );
  });

  it('closes copilot panel when close is triggered', async () => {
    const wrapper = mountComponent();
    const closeBtn = wrapper.find('[data-testid="close-btn"]');
    await closeBtn.trigger('click');

    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      is_copilot_panel_open: false,
      is_contact_sidebar_open: false,
    });
  });

  it('shows tabs switcher and chat view when assistants are available', async () => {
    assistantsRef.value = [{ id: 1, name: 'Legal Assistant' }];
    const wrapper = mountComponent();

    const tabs = wrapper
      .findAll('button')
      .filter(
        b =>
          b.text().includes('Ask Copilot') ||
          b.text().includes('COPILOT.TABS.CHAT')
      );
    expect(tabs.length).toBeGreaterThan(0);

    await tabs[0].trigger('click');
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[data-testid="copilot-chat"]').exists()).toBe(true);
  });
});

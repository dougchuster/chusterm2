import { ref } from 'vue';
import {
  useCockpitResize,
  DEFAULT_LIST_WIDTH,
  MIN_LIST_WIDTH,
  MAX_LIST_WIDTH,
  DEFAULT_SIDEBAR_WIDTH,
  MIN_SIDEBAR_WIDTH,
  MAX_SIDEBAR_WIDTH,
} from '../useCockpitResize';

let mockUISettings = {};
const mockUpdateUISettings = vi.fn(settings => {
  mockUISettings = { ...mockUISettings, ...settings };
});

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: ref(mockUISettings),
    updateUISettings: mockUpdateUISettings,
  }),
}));

describe('useCockpitResize', () => {
  beforeEach(() => {
    mockUISettings = {
      conversation_list_width: 380,
      conversation_sidebar_width: 420,
    };
    mockUpdateUISettings.mockClear();
  });

  it('initializes widths from UI settings', () => {
    const { conversationListWidth, contactSidebarWidth } = useCockpitResize();
    expect(conversationListWidth.value).toBe(380);
    expect(contactSidebarWidth.value).toBe(420);
  });

  it('falls back to default widths when UI settings are missing', () => {
    mockUISettings = {};
    const { conversationListWidth, contactSidebarWidth } = useCockpitResize();
    expect(conversationListWidth.value).toBe(DEFAULT_LIST_WIDTH);
    expect(contactSidebarWidth.value).toBe(DEFAULT_SIDEBAR_WIDTH);
  });

  it('clamps list width to min and max boundaries', () => {
    const { conversationListWidth, setListWidth } = useCockpitResize();

    setListWidth(MIN_LIST_WIDTH - 50);
    expect(conversationListWidth.value).toBe(MIN_LIST_WIDTH);

    setListWidth(MAX_LIST_WIDTH + 100);
    expect(conversationListWidth.value).toBe(MAX_LIST_WIDTH);

    setListWidth(350);
    expect(conversationListWidth.value).toBe(350);
  });

  it('clamps sidebar width to min and max boundaries', () => {
    const { contactSidebarWidth, setSidebarWidth } = useCockpitResize();

    setSidebarWidth(MIN_SIDEBAR_WIDTH - 50);
    expect(contactSidebarWidth.value).toBe(MIN_SIDEBAR_WIDTH);

    setSidebarWidth(MAX_SIDEBAR_WIDTH + 100);
    expect(contactSidebarWidth.value).toBe(MAX_SIDEBAR_WIDTH);

    setSidebarWidth(450);
    expect(contactSidebarWidth.value).toBe(450);
  });

  it('persists list width with saveListWidth', () => {
    const { setListWidth, saveListWidth } = useCockpitResize();

    setListWidth(410);
    saveListWidth();

    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_list_width: 410,
    });
  });

  it('persists sidebar width with saveSidebarWidth', () => {
    const { setSidebarWidth, saveSidebarWidth } = useCockpitResize();

    setSidebarWidth(480);
    saveSidebarWidth();

    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_sidebar_width: 480,
    });
  });

  it('resets list width to default with resetListWidth', () => {
    const { resetListWidth, conversationListWidth } = useCockpitResize();

    resetListWidth();

    expect(conversationListWidth.value).toBe(DEFAULT_LIST_WIDTH);
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_list_width: DEFAULT_LIST_WIDTH,
    });
  });

  it('resets sidebar width to default with resetSidebarWidth', () => {
    const { resetSidebarWidth, contactSidebarWidth } = useCockpitResize();

    resetSidebarWidth();

    expect(contactSidebarWidth.value).toBe(DEFAULT_SIDEBAR_WIDTH);
    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversation_sidebar_width: DEFAULT_SIDEBAR_WIDTH,
    });
  });

  it('handles keyboard navigation for list resizing', () => {
    const { conversationListWidth, onListResizeKeydown } = useCockpitResize();

    const rightArrowEvent = {
      key: 'ArrowRight',
      shiftKey: false,
      preventDefault: vi.fn(),
    };
    onListResizeKeydown(rightArrowEvent);
    expect(rightArrowEvent.preventDefault).toHaveBeenCalled();
    expect(conversationListWidth.value).toBe(388);

    const shiftLeftEvent = {
      key: 'ArrowLeft',
      shiftKey: true,
      preventDefault: vi.fn(),
    };
    onListResizeKeydown(shiftLeftEvent);
    expect(conversationListWidth.value).toBe(356);

    const homeEvent = {
      key: 'Home',
      preventDefault: vi.fn(),
    };
    onListResizeKeydown(homeEvent);
    expect(conversationListWidth.value).toBe(MIN_LIST_WIDTH);

    const endEvent = {
      key: 'End',
      preventDefault: vi.fn(),
    };
    onListResizeKeydown(endEvent);
    expect(conversationListWidth.value).toBe(MAX_LIST_WIDTH);
  });

  it('handles keyboard navigation for sidebar resizing', () => {
    const { contactSidebarWidth, onSidebarResizeKeydown } = useCockpitResize();

    // In LTR, ArrowLeft increases right sidebar width
    const leftArrowEvent = {
      key: 'ArrowLeft',
      shiftKey: false,
      preventDefault: vi.fn(),
    };
    onSidebarResizeKeydown(leftArrowEvent);
    expect(leftArrowEvent.preventDefault).toHaveBeenCalled();
    expect(contactSidebarWidth.value).toBe(428);

    const rightArrowEvent = {
      key: 'ArrowRight',
      shiftKey: false,
      preventDefault: vi.fn(),
    };
    onSidebarResizeKeydown(rightArrowEvent);
    expect(contactSidebarWidth.value).toBe(420);
  });
});

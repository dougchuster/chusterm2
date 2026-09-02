import { shallowMount } from '@vue/test-utils';

import ReplyBottomPanel from './ReplyBottomPanel.vue';

vi.mock('activestorage', () => ({
  start: vi.fn(),
}));

vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    setSignatureFlagForInbox: vi.fn(),
    fetchSignatureFlagFromUISettings: vi.fn(() => false),
  }),
}));

const mountPanel = props =>
  shallowMount(ReplyBottomPanel, {
    props: {
      conversationId: 42,
      portalSlug: '',
      inbox: {},
      ...props,
    },
    global: {
      mocks: {
        $store: {
          getters: {
            getCurrentAccountId: 1,
            'accounts/isFeatureEnabledonAccount': () => false,
            'integrations/getUIFlags': { isFetching: false },
          },
        },
      },
    },
  });

describe('ReplyBottomPanel', () => {
  it('reflects the emoji picker state in its variant and pressed state', async () => {
    const toggleEmojiPicker = vi.fn();
    const wrapper = mountPanel({
      showEmojiPicker: false,
      toggleEmojiPicker,
    });
    const emojiButton = wrapper.get('button[aria-label="Show emoji selector"]');

    expect(emojiButton.attributes('variant')).toBe('faded');
    expect(emojiButton.attributes('aria-pressed')).toBe('false');

    await emojiButton.trigger('click');

    expect(toggleEmojiPicker).toHaveBeenCalledOnce();

    await wrapper.setProps({ showEmojiPicker: true });

    const pressedEmojiButton = wrapper.get(
      'button[aria-label="Show emoji selector"]'
    );
    expect(pressedEmojiButton.attributes('variant')).toBe('solid');
    expect(pressedEmojiButton.attributes('aria-pressed')).toBe('true');
  });
});

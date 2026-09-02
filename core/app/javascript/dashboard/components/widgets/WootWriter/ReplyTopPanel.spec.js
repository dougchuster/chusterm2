import { shallowMount } from '@vue/test-utils';

import ReplyTopPanel from './ReplyTopPanel.vue';
import EditorModeToggle from './EditorModeToggle.vue';
import { REPLY_EDITOR_MODES } from './constants';

const keyboardEvents = vi.hoisted(() => ({ current: {} }));

vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: events => {
    keyboardEvents.current = events;
  },
}));

vi.mock('dashboard/composables/useCaptain', () => ({
  useCaptain: () => ({
    captainTasksEnabled: false,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useTrack: vi.fn(),
}));

const mountPanel = props =>
  shallowMount(ReplyTopPanel, {
    props,
  });

describe('ReplyTopPanel', () => {
  beforeEach(() => {
    keyboardEvents.current = {};
  });

  it('forwards the explicitly selected editor mode', async () => {
    const wrapper = mountPanel({ mode: REPLY_EDITOR_MODES.REPLY });
    const toggle = wrapper.getComponent(EditorModeToggle);

    expect(toggle.props('mode')).toBe(REPLY_EDITOR_MODES.REPLY);

    toggle.vm.$emit('setMode', REPLY_EDITOR_MODES.NOTE);
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('setReplyMode')).toEqual([
      [REPLY_EDITOR_MODES.NOTE],
    ]);
  });

  it('passes reply restrictions to the mode control', () => {
    const wrapper = mountPanel({
      mode: REPLY_EDITOR_MODES.NOTE,
      isReplyRestricted: true,
    });

    expect(
      wrapper.getComponent(EditorModeToggle).props('isReplyRestricted')
    ).toBe(true);
  });

  it('blocks the reply shortcut but keeps the note shortcut available when restricted', () => {
    const wrapper = mountPanel({
      mode: REPLY_EDITOR_MODES.NOTE,
      isReplyRestricted: true,
    });

    keyboardEvents.current['Alt+KeyL'].action();
    keyboardEvents.current['Alt+KeyP'].action();

    expect(wrapper.emitted('setReplyMode')).toEqual([
      [REPLY_EDITOR_MODES.NOTE],
    ]);
  });

  it('keeps the popout control available without Captain and updates its accessible state', async () => {
    const wrapper = mountPanel({
      popoutReplyBox: false,
    });
    const expandButton = wrapper.get(
      'button[aria-label="Expand message editor"]'
    );

    expect(expandButton.attributes('icon')).toBe('i-lucide-maximize-2');
    expect(expandButton.attributes('aria-pressed')).toBe('false');

    await expandButton.trigger('click');

    expect(wrapper.emitted('togglePopout')).toEqual([[]]);

    await wrapper.setProps({ popoutReplyBox: true });

    const collapseButton = wrapper.get(
      'button[aria-label="Collapse message editor"]'
    );
    expect(collapseButton.attributes('icon')).toBe('i-lucide-minimize-2');
    expect(collapseButton.attributes('aria-pressed')).toBe('true');
  });
});

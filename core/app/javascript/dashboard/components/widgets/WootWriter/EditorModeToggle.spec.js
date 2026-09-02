import { mount } from '@vue/test-utils';

import EditorModeToggle from './EditorModeToggle.vue';
import { REPLY_EDITOR_MODES } from './constants';

const mountToggle = props =>
  mount(EditorModeToggle, {
    props,
  });

describe('EditorModeToggle', () => {
  it('represents each editor mode with an explicit pressed button', async () => {
    const wrapper = mountToggle({ mode: REPLY_EDITOR_MODES.REPLY });
    const [replyButton, noteButton] = wrapper.findAll('button');

    expect(wrapper.get('[role="group"]').attributes('aria-label')).toBeTruthy();
    expect(replyButton.attributes('aria-pressed')).toBe('true');
    expect(noteButton.attributes('aria-pressed')).toBe('false');

    await noteButton.trigger('click');

    expect(wrapper.emitted('setMode')).toEqual([[REPLY_EDITOR_MODES.NOTE]]);

    await wrapper.setProps({ mode: REPLY_EDITOR_MODES.NOTE });

    expect(replyButton.attributes('aria-pressed')).toBe('false');
    expect(noteButton.attributes('aria-pressed')).toBe('true');

    await replyButton.trigger('click');

    expect(wrapper.emitted('setMode')).toEqual([
      [REPLY_EDITOR_MODES.NOTE],
      [REPLY_EDITOR_MODES.REPLY],
    ]);
  });

  it('disables reply and keeps note selected when replies are restricted', async () => {
    const wrapper = mountToggle({
      mode: REPLY_EDITOR_MODES.REPLY,
      isReplyRestricted: true,
    });
    const [replyButton, noteButton] = wrapper.findAll('button');

    expect(replyButton.attributes('disabled')).toBeDefined();
    expect(replyButton.attributes('aria-pressed')).toBe('false');
    expect(noteButton.attributes('aria-pressed')).toBe('true');

    await replyButton.trigger('click');

    expect(wrapper.emitted('setMode')).toBeUndefined();
  });

  it('disables both mode controls when the editor is disabled', () => {
    const wrapper = mountToggle({
      mode: REPLY_EDITOR_MODES.NOTE,
      disabled: true,
    });

    wrapper.findAll('button').forEach(button => {
      expect(button.attributes('disabled')).toBeDefined();
    });
  });
});

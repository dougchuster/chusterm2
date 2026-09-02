import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';

import CopilotMenuBar from './CopilotMenuBar.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('@vueuse/core', () => ({
  useWindowSize: () => ({
    width: { value: 1280 },
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: 'REPLY' }),
}));

vi.mock('dashboard/composables/useCaptain', () => ({
  useCaptain: () => ({
    draftMessage: { value: '' },
  }),
}));

const mountMenu = () =>
  mount(CopilotMenuBar, {
    attachTo: document.body,
    props: {
      conversationId: 42,
      editorContent: 'Mensagem atual',
    },
    global: {
      stubs: {
        Icon: {
          props: ['icon'],
          template: '<span :data-icon="icon" />',
        },
      },
    },
  });

describe('CopilotMenuBar', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('opens a submenu by click and preserves the Copilot action payload', async () => {
    const wrapper = mountMenu();
    const trigger = wrapper.get('[data-copilot-key="change_tone"]');

    expect(trigger.attributes('aria-haspopup')).toBe('menu');
    expect(trigger.attributes('aria-expanded')).toBe('false');
    expect(trigger.attributes('aria-controls')).toBeTruthy();

    await trigger.trigger('click');

    expect(trigger.attributes('aria-expanded')).toBe('true');

    const submenu = wrapper.get('[data-copilot-submenu="change_tone"]');
    expect(submenu.attributes('role')).toBe('menu');
    expect(submenu.attributes('id')).toBe(trigger.attributes('aria-controls'));

    await submenu.findAll('[role="menuitem"]')[0].trigger('click');

    expect(wrapper.emitted('executeCopilotAction')).toEqual([['professional']]);
    expect(wrapper.find('[data-copilot-submenu="change_tone"]').exists()).toBe(
      false
    );
  });

  it('supports Enter, arrow navigation, Escape and focus restoration', async () => {
    const wrapper = mountMenu();
    const trigger = wrapper.get('[data-copilot-key="change_tone"]');

    trigger.element.focus();
    await trigger.trigger('keydown', { key: 'Enter' });
    await nextTick();

    let submenuItems = wrapper
      .get('[data-copilot-submenu="change_tone"]')
      .findAll('[role="menuitem"]');

    expect(document.activeElement).toBe(submenuItems[0].element);

    await submenuItems[0].trigger('keydown', { key: 'ArrowDown' });
    expect(document.activeElement).toBe(submenuItems[1].element);

    await submenuItems[1].trigger('keydown', { key: 'Escape' });
    await nextTick();

    expect(wrapper.find('[data-copilot-submenu="change_tone"]').exists()).toBe(
      false
    );
    expect(document.activeElement).toBe(trigger.element);

    await trigger.trigger('keydown', { key: ' ' });
    await nextTick();
    submenuItems = wrapper
      .get('[data-copilot-submenu="change_tone"]')
      .findAll('[role="menuitem"]');

    expect(document.activeElement).toBe(submenuItems[0].element);
  });

  it('keeps direct menu actions and top-level arrow navigation intact', async () => {
    const wrapper = mountMenu();
    const grammar = wrapper.get('[data-copilot-key="fix_spelling_grammar"]');
    const askCopilot = wrapper.get('[data-copilot-key="ask_copilot"]');

    grammar.element.focus();
    await grammar.trigger('keydown', { key: 'ArrowDown' });
    expect(document.activeElement).toBe(
      wrapper.get('[data-copilot-key="reply_suggestion"]').element
    );

    await askCopilot.trigger('click');
    expect(wrapper.emitted('executeCopilotAction')).toEqual([['ask_copilot']]);
  });
});

import { flushPromises, mount } from '@vue/test-utils';
import { vi } from 'vitest';

import ContactInfoRow from './ContactInfoRow.vue';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('shared/helpers/clipboard', () => ({
  copyTextToClipboard: vi.fn(() => Promise.resolve()),
}));

const mountRow = props =>
  mount(ContactInfoRow, {
    props: {
      icon: 'mail',
      emoji: '✉️',
      title: 'Email address',
      value: 'person@example.com',
      ...props,
    },
    global: {
      mocks: {
        $t: key => key,
      },
      directives: {
        'dompurify-html': {},
      },
      stubs: {
        EmojiOrIcon: true,
        NextButton: {
          inheritAttrs: false,
          template:
            '<button v-bind="$attrs" type="button" @click="$emit(\'click\', $event)" />',
        },
      },
    },
  });

describe('ContactInfoRow', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('keeps the copy control outside the contact link', () => {
    const wrapper = mountRow({
      href: 'mailto:person@example.com',
      showCopy: true,
    });

    expect(wrapper.classes()).toContain('min-h-8');
    expect(wrapper.get('a').attributes('href')).toBe(
      'mailto:person@example.com'
    );
    expect(wrapper.find('a button').exists()).toBe(false);
    expect(wrapper.get('button').attributes('aria-label')).toContain(
      'Email address'
    );
  });

  it('copies the value from its independent action', async () => {
    const wrapper = mountRow({
      href: 'mailto:person@example.com',
      showCopy: true,
    });

    await wrapper.get('button').trigger('click');
    await flushPromises();

    expect(copyTextToClipboard).toHaveBeenCalledWith('person@example.com');
    expect(useAlert).toHaveBeenCalledWith('CONTACT_PANEL.COPY_SUCCESSFUL');
  });
});

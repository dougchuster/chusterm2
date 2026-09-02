import { mount } from '@vue/test-utils';
import { computed, ref } from 'vue';
import { vi } from 'vitest';

import SidepanelSwitch from './SidepanelSwitch.vue';

const updateUISettings = vi.fn();
const uiSettings = ref({
  is_contact_sidebar_open: false,
  is_copilot_panel_open: false,
});

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    if (key === 'getCurrentAccountId') return ref(1);
    return computed(() => () => true);
  },
}));

const mountSwitch = () =>
  mount(SidepanelSwitch, {
    global: {
      mocks: {
        $t: key => key,
      },
    },
  });

describe('SidepanelSwitch', () => {
  beforeEach(() => {
    updateUISettings.mockClear();
    uiSettings.value = {
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    };
  });

  it('labels both icon controls and exposes their pressed state', () => {
    const wrapper = mountSwitch();
    const [contactButton, copilotButton] = wrapper.findAll('button');

    expect(contactButton.attributes('aria-label')).toBe(
      'CONVERSATION.SIDEBAR.CONTACT'
    );
    expect(contactButton.attributes('aria-pressed')).toBe('false');
    expect(copilotButton.attributes('aria-label')).toBe(
      'CONVERSATION.SIDEBAR.COPILOT'
    );
    expect(copilotButton.attributes('aria-pressed')).toBe('false');
  });

  it('preserves the existing panel selection payloads', async () => {
    const wrapper = mountSwitch();
    const [contactButton, copilotButton] = wrapper.findAll('button');

    await contactButton.trigger('click');
    await copilotButton.trigger('click');

    expect(updateUISettings.mock.calls).toEqual([
      [
        {
          is_contact_sidebar_open: true,
          is_copilot_panel_open: false,
        },
      ],
      [
        {
          is_contact_sidebar_open: false,
          is_copilot_panel_open: true,
        },
      ],
    ]);
  });
});

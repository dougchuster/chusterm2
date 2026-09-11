import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import Avatar from './Avatar.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('Avatar', () => {
  it('rounds the outer frame with the same shape as the avatar', () => {
    const wrapper = shallowMount(Avatar, {
      props: {
        name: 'Dra. Paula Matos',
        size: 32,
        roundedFull: true,
      },
      global: {
        stubs: {
          Icon: true,
          ChannelIcon: true,
        },
      },
    });

    expect(wrapper.classes()).toContain('rounded-full');
    expect(wrapper.get('[role="img"]').classes()).toContain('rounded-full');
  });
});

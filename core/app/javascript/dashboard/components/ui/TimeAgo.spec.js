import { mount } from '@vue/test-utils';
import { vi } from 'vitest';

import TimeAgo from './TimeAgo.vue';

vi.mock('shared/helpers/timeHelper', () => ({
  dynamicTime: timestamp => `relative:${timestamp}`,
  dateFormat: timestamp => `date:${timestamp}`,
  shortTimestamp: value => `short:${value}`,
}));

const mountTimeAgo = () =>
  mount(TimeAgo, {
    props: {
      isAutoRefreshEnabled: false,
      createdAtTimestamp: 1000,
      lastActivityTimestamp: 2000,
      conversationId: 1,
    },
    global: {
      mocks: {
        $t: key => key,
      },
    },
  });

describe('TimeAgo', () => {
  it('shows only last activity while exposing creation details accessibly', () => {
    const wrapper = mountTimeAgo();
    const timestamp = wrapper.get('time');
    const visibleValue = timestamp.get('[aria-hidden="true"]');
    const accessibleDetails = timestamp.get('.sr-only');

    expect(visibleValue.text()).toBe('short:relative:2000');
    expect(visibleValue.text()).not.toContain('relative:1000');
    expect(accessibleDetails.text()).toContain('date:1000');
    expect(timestamp.attributes('title')).toContain('date:1000');
    expect(timestamp.attributes('tabindex')).toBe('0');
  });
});

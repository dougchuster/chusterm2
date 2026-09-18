import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import CRMScoreBadge from './CRMScoreBadge.vue';

describe('CRMScoreBadge', () => {
  it.each([
    [95, 'bg-ui-danger-soft', 'text-ui-danger-foreground'],
    [73, 'bg-ui-success-soft', 'text-ui-success-foreground'],
    [49, 'bg-ui-warning-soft', 'text-ui-warning-foreground'],
    [20, 'bg-ui-sunken', 'text-ui-text'],
  ])('uses a readable semantic tone for score %i', (score, bg, text) => {
    const wrapper = mount(CRMScoreBadge, { props: { score } });

    expect(wrapper.classes()).toContain('rounded-full');
    expect(wrapper.classes()).toContain(bg);
    expect(wrapper.classes()).toContain(text);
  });
});

import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import CRMScoreBadge from './CRMScoreBadge.vue';

describe('CRMScoreBadge', () => {
  it.each([
    [95, 'bg-n-ruby-3', 'text-n-ruby-12'],
    [73, 'bg-n-teal-3', 'text-n-teal-12'],
    [49, 'bg-n-amber-3', 'text-n-amber-12'],
    [20, 'bg-n-slate-3', 'text-n-slate-12'],
  ])('uses a readable semantic tone for score %i', (score, bg, text) => {
    const wrapper = mount(CRMScoreBadge, { props: { score } });

    expect(wrapper.classes()).toContain('rounded-full');
    expect(wrapper.classes()).toContain(bg);
    expect(wrapper.classes()).toContain(text);
  });
});

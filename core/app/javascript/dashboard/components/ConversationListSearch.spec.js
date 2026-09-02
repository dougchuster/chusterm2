import { mount } from '@vue/test-utils';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { nextTick } from 'vue';
import ConversationListSearch from './ConversationListSearch.vue';

describe('ConversationListSearch', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('debounces a valid search query', async () => {
    const wrapper = mount(ConversationListSearch);

    await wrapper.get('input[type="search"]').setValue('Douglas');
    expect(wrapper.emitted('search')).toBeUndefined();

    vi.advanceTimersByTime(350);
    await nextTick();

    expect(wrapper.emitted('search')).toEqual([['Douglas']]);
  });

  it('does not send a query shorter than the configured minimum', async () => {
    const wrapper = mount(ConversationListSearch);

    await wrapper.get('input[type="search"]').setValue('Do');
    vi.advanceTimersByTime(350);
    await nextTick();

    expect(wrapper.emitted('search')).toEqual([['']]);
  });

  it('clears an active query and returns focus to the field', async () => {
    const wrapper = mount(ConversationListSearch, {
      props: { modelValue: 'Douglas' },
      attachTo: document.body,
    });

    await wrapper.get('button').trigger('click');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual(['']);
    expect(wrapper.emitted('search').at(-1)).toEqual(['']);
    expect(document.activeElement).toBe(wrapper.get('input').element);

    wrapper.unmount();
  });

  it('exposes the search landmark, label and keyboard shortcut', () => {
    const wrapper = mount(ConversationListSearch);
    const input = wrapper.get('input[type="search"]');

    expect(wrapper.get('form').attributes('role')).toBe('search');
    expect(input.attributes('aria-label')).toBeTruthy();
    expect(input.attributes('aria-keyshortcuts')).toBe('/');
  });
});

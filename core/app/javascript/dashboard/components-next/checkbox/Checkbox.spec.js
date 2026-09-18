import { mount } from '@vue/test-utils';
import Checkbox from './Checkbox.vue';

describe('Checkbox', () => {
  it('encaminha aria-label e id para o <input>, não para o wrapper', () => {
    const wrapper = mount(Checkbox, {
      attrs: { 'aria-label': 'Selecionar todos', id: 'cb-1', class: 'ml-2' },
    });

    const input = wrapper.find('input[type="checkbox"]');
    expect(input.attributes('aria-label')).toBe('Selecionar todos');
    expect(input.attributes('id')).toBe('cb-1');
    expect(wrapper.find('div').classes()).toContain('ml-2');
    expect(wrapper.find('div').attributes('aria-label')).toBeUndefined();
  });

  it('emite change e atualiza o v-model', async () => {
    const wrapper = mount(Checkbox, { props: { modelValue: false } });

    await wrapper.find('input').setValue(true);

    expect(wrapper.emitted('update:modelValue')[0]).toEqual([true]);
    expect(wrapper.emitted('change')).toHaveLength(1);
  });
});

import { mount } from '@vue/test-utils';
import FormInput from './Input.vue';

const mountInput = (props = {}, attrs = {}) =>
  mount(FormInput, {
    props: { name: 'email_address', label: 'E-mail', modelValue: '', ...props },
    attrs,
    global: { stubs: { Button: true, 'fluent-icon': true } },
  });

describe('FormInput', () => {
  it('associa o label ao input via id = name (acessibilidade)', () => {
    const wrapper = mountInput();

    const label = wrapper.find('label');
    const input = wrapper.find('input');
    expect(label.attributes('for')).toBe('email_address');
    expect(input.attributes('id')).toBe('email_address');
  });

  it('respeita um id explícito passado via attrs', () => {
    const wrapper = mountInput({}, { id: 'custom-id' });

    expect(wrapper.find('input').attributes('id')).toBe('custom-id');
  });

  it('não renderiza label quando a prop não é informada', () => {
    const wrapper = mountInput({ label: undefined });

    expect(wrapper.find('label').exists()).toBe(false);
  });
});

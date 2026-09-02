import { mount } from '@vue/test-utils';

import AccordionItem from './AccordionItem.vue';

const mountAccordion = props =>
  mount(AccordionItem, {
    props: {
      title: 'Contact details',
      ...props,
    },
    slots: {
      default: '<p data-testid="accordion-content">Content</p>',
    },
    global: {
      stubs: {
        EmojiOrIcon: true,
      },
    },
  });

describe('AccordionItem', () => {
  it('exposes its expanded state and emits toggle from a semantic button', async () => {
    const wrapper = mountAccordion({ isOpen: false });
    const trigger = wrapper.get('button');

    expect(trigger.attributes('type')).toBe('button');
    expect(trigger.attributes('aria-expanded')).toBe('false');
    expect(wrapper.find('[data-testid="accordion-content"]').exists()).toBe(
      false
    );

    await trigger.trigger('click');

    expect(wrapper.emitted('toggle')).toEqual([[]]);

    await wrapper.setProps({ isOpen: true });

    expect(trigger.attributes('aria-expanded')).toBe('true');
    expect(wrapper.get('[data-testid="accordion-content"]').text()).toBe(
      'Content'
    );
  });

  it('only exposes the drag handle when dragging is enabled', async () => {
    const wrapper = mountAccordion();
    const trigger = wrapper.get('button');

    expect(trigger.classes()).not.toContain('drag-handle');
    expect(trigger.classes()).not.toContain('cursor-grab');

    await wrapper.setProps({ draggable: true });

    expect(trigger.classes()).toContain('drag-handle');
    expect(trigger.classes()).toContain('cursor-grab');
    expect(trigger.classes()).toContain('active:cursor-grabbing');
  });
});

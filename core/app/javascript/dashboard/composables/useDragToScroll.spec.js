import { defineComponent, h, ref } from 'vue';
import { mount } from '@vue/test-utils';

import { useDragToScroll } from './useDragToScroll';

const mountBoard = () => {
  const Comp = defineComponent({
    setup() {
      const scroller = ref(null);
      useDragToScroll(scroller);
      return () =>
        h('div', { ref: scroller, 'data-testid': 'scroller' }, [
          h('article', { 'data-testid': 'crm-board-card' }, 'card'),
          h('div', { 'data-testid': 'empty-area' }, 'empty'),
        ]);
    },
  });
  const wrapper = mount(Comp, { attachTo: document.body });
  return { wrapper, el: wrapper.element };
};

const pointer = (type, opts = {}) => {
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.assign(event, {
    button: 0,
    pointerId: 1,
    pointerType: 'mouse',
    clientX: 0,
    clientY: 0,
    ...opts,
  });
  return event;
};

describe('useDragToScroll', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('pans scrollLeft when dragging empty board space', () => {
    const { el } = mountBoard();
    el.scrollLeft = 100;

    el.querySelector('[data-testid="empty-area"]').dispatchEvent(
      pointer('pointerdown', { clientX: 300 })
    );
    el.dispatchEvent(pointer('pointermove', { clientX: 200 }));
    expect(el.scrollLeft).toBe(200);

    el.dispatchEvent(pointer('pointermove', { clientX: 100 }));
    expect(el.scrollLeft).toBe(300);
  });

  it('ignores drags that start inside a card', () => {
    const { el } = mountBoard();
    el.scrollLeft = 100;

    el.querySelector('[data-testid="crm-board-card"]').dispatchEvent(
      pointer('pointerdown', { clientX: 300 })
    );
    el.dispatchEvent(pointer('pointermove', { clientX: 100 }));
    expect(el.scrollLeft).toBe(100);
  });

  it('does not pan below the threshold and lets the click through', () => {
    const { el } = mountBoard();
    el.scrollLeft = 50;
    const clicks = [];
    el.addEventListener('click', e => clicks.push(e.target));

    const empty = el.querySelector('[data-testid="empty-area"]');
    empty.dispatchEvent(pointer('pointerdown', { clientX: 100 }));
    el.dispatchEvent(pointer('pointermove', { clientX: 103 }));
    el.dispatchEvent(pointer('pointerup', { clientX: 103 }));
    empty.dispatchEvent(
      new Event('click', { bubbles: true, cancelable: true })
    );

    expect(el.scrollLeft).toBe(50);
    expect(clicks).toHaveLength(1);
  });

  it('suppresses the click that follows a real pan', () => {
    const { el } = mountBoard();
    el.scrollLeft = 0;
    const clicks = [];
    el.addEventListener('click', e => clicks.push(e));

    const empty = el.querySelector('[data-testid="empty-area"]');
    empty.dispatchEvent(pointer('pointerdown', { clientX: 300 }));
    el.dispatchEvent(pointer('pointermove', { clientX: 100 }));
    el.dispatchEvent(pointer('pointerup', { clientX: 100 }));
    empty.dispatchEvent(
      new Event('click', { bubbles: true, cancelable: true })
    );

    expect(el.scrollLeft).toBe(200);
    expect(clicks).toHaveLength(0);
  });

  it('ignores touch pointers (native scroll handles them)', () => {
    const { el } = mountBoard();
    el.scrollLeft = 100;

    el.querySelector('[data-testid="empty-area"]').dispatchEvent(
      pointer('pointerdown', { clientX: 300, pointerType: 'touch' })
    );
    el.dispatchEvent(
      pointer('pointermove', { clientX: 100, pointerType: 'touch' })
    );
    expect(el.scrollLeft).toBe(100);
  });
});

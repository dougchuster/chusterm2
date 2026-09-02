import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';

import ContextMenu from './ContextMenu.vue';
import MenuItemWithSubmenu from '../widgets/conversation/contextMenu/menuItemWithSubmenu.vue';

const TeleportStub = {
  template: '<div data-testid="teleport"><slot /></div>',
};

const mountContextMenu = () =>
  mount(ContextMenu, {
    attachTo: document.body,
    props: {
      x: 20,
      y: 20,
    },
    slots: {
      default: `
        <button type="button" role="menuitem" data-testid="first">First</button>
        <button type="button" role="menuitem" data-testid="second">Second</button>
      `,
    },
    global: {
      stubs: {
        TeleportWithDirection: TeleportStub,
      },
    },
  });

describe('ContextMenu', () => {
  it('keeps the menu open when focus moves inside and closes when it leaves', async () => {
    const outsideButton = document.createElement('button');
    document.body.appendChild(outsideButton);
    const wrapper = mountContextMenu();

    await nextTick();
    await nextTick();

    expect(document.activeElement).toBe(
      wrapper.get('[data-testid="first"]').element
    );

    wrapper.get('[data-testid="second"]').element.focus();
    await nextTick();
    expect(wrapper.emitted('close')).toBeUndefined();

    outsideButton.focus();
    await nextTick();
    expect(wrapper.emitted('close')).toHaveLength(1);

    wrapper.unmount();
    outsideButton.remove();
  });

  it('supports arrow navigation and closes with Escape', async () => {
    const wrapper = mountContextMenu();

    await nextTick();
    await nextTick();

    await wrapper.get('[data-testid="first"]').trigger('keydown', {
      key: 'ArrowDown',
    });
    expect(document.activeElement).toBe(
      wrapper.get('[data-testid="second"]').element
    );

    await wrapper.get('[data-testid="second"]').trigger('keydown', {
      key: 'Escape',
    });
    expect(wrapper.emitted('close')).toHaveLength(1);

    wrapper.unmount();
  });

  it('opens a submenu by keyboard and restores focus when it closes', async () => {
    const wrapper = mount(MenuItemWithSubmenu, {
      attachTo: document.body,
      props: {
        option: {
          icon: 'tag',
          label: 'Labels',
        },
      },
      slots: {
        default: `
          <button type="button" role="menuitem" data-testid="child-first">First</button>
          <button type="button" role="menuitem" data-testid="child-second">Second</button>
        `,
      },
    });
    const trigger = wrapper.get('button[aria-haspopup="menu"]');

    trigger.element.focus();
    await trigger.trigger('keydown', { key: 'ArrowDown' });
    await nextTick();

    expect(trigger.attributes('aria-expanded')).toBe('true');
    expect(document.activeElement).toBe(
      wrapper.get('[data-testid="child-first"]').element
    );

    await wrapper.get('[data-testid="child-first"]').trigger('keydown', {
      key: 'Escape',
    });
    await nextTick();

    expect(trigger.attributes('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(trigger.element);

    wrapper.unmount();
  });
});

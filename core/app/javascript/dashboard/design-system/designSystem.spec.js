import { mount } from '@vue/test-utils';

import {
  DsAvatar,
  DsBadge,
  DsButton,
  DsCard,
  DsCheckbox,
  DsDrawer,
  DsDropdown,
  DsEmptyState,
  DsInput,
  DsModal,
  DsPagination,
  DsSelect,
  DsSkeleton,
  DsTable,
  DsTabs,
  DsToast,
  DsTooltip,
} from './components';
import { operationalTokenContract, operationalTokens } from './tokens';

const global = {
  stubs: {
    Icon: {
      props: ['icon'],
      template: '<span :data-icon="icon" />',
    },
    Spinner: {
      template: '<span data-testid="spinner" />',
    },
  },
};

describe('ChusteRM operational design system', () => {
  it('keeps the Phase 2 token contract intentionally small', () => {
    expect(Object.keys(operationalTokens.fontFamily)).toHaveLength(2);
    expect(operationalTokens.fontFamily.heading[0]).toBe('"Manrope Variable"');
    expect(Object.keys(operationalTokens.fontSize)).toHaveLength(6);
    expect(Object.keys(operationalTokens.fontWeight)).toHaveLength(3);
    expect(Object.keys(operationalTokens.borderRadius)).toHaveLength(2);
    expect(Object.keys(operationalTokens.boxShadow)).toHaveLength(2);
    expect(operationalTokenContract).toMatchObject({
      fontFamilies: 2,
      fontSizes: 6,
      fontWeights: 3,
      spacingBase: 4,
      radii: 2,
      shadows: 2,
      iconFamily: 'lucide',
      iconStroke: 2,
    });
  });

  it('exposes actionable, disabled and loading button states', async () => {
    const wrapper = mount(DsButton, {
      props: { label: 'Salvar', variant: 'primary' },
      global,
    });

    await wrapper.trigger('click');
    expect(wrapper.emitted('click')).toHaveLength(1);

    await wrapper.setProps({ loading: true });
    expect(wrapper.attributes('disabled')).toBeDefined();
    expect(wrapper.attributes('aria-busy')).toBe('true');
    expect(wrapper.get('[data-testid="spinner"]').exists()).toBe(true);
  });

  it('provides labelled input, select and checkbox controls', async () => {
    const input = mount(DsInput, {
      props: { label: 'Título', modelValue: '' },
      global,
    });
    await input.get('input').setValue('Retornar ao cliente');
    expect(input.emitted('update:modelValue').at(-1)).toEqual([
      'Retornar ao cliente',
    ]);
    expect(input.get('label').attributes('for')).toBe(
      input.get('input').attributes('id')
    );

    const select = mount(DsSelect, {
      props: {
        label: 'Prioridade',
        modelValue: '',
        options: [{ value: 'alta', label: 'Alta' }],
      },
      global,
    });
    await select.get('select').setValue('alta');
    expect(select.emitted('update:modelValue').at(-1)).toEqual(['alta']);

    const checkbox = mount(DsCheckbox, {
      props: { label: 'Sincronizar', modelValue: false },
      global,
    });
    await checkbox.get('input').setValue(true);
    expect(checkbox.emitted('update:modelValue').at(-1)).toEqual([true]);
  });

  it('renders card, badge, avatar, skeleton and empty states', async () => {
    const card = mount(DsCard, {
      props: { interactive: true },
      slots: { default: 'Conteúdo' },
    });
    expect(card.element.tagName).toBe('BUTTON');
    await card.trigger('click');
    expect(card.emitted('click')).toHaveLength(1);

    const badge = mount(DsBadge, {
      props: { label: 'Vencida', variant: 'danger' },
      global,
    });
    expect(badge.text()).toBe('Vencida');

    const avatar = mount(DsAvatar, {
      props: { name: 'Paula Matos' },
      global,
    });
    expect(avatar.get('[role="img"]').attributes('aria-label')).toBe(
      'Paula Matos'
    );
    expect(avatar.text()).toContain('PM');

    expect(mount(DsSkeleton).attributes('aria-hidden')).toBe('true');

    const emptyState = mount(DsEmptyState, {
      props: { title: 'Nenhum registro', actionLabel: 'Criar' },
      global,
    });
    await emptyState.get('button').trigger('click');
    expect(emptyState.emitted('action')).toHaveLength(1);
  });

  it('supports table, tabs and pagination navigation', async () => {
    const table = mount(DsTable, {
      props: {
        caption: 'Atividades',
        headers: [{ key: 'title', label: 'Título' }],
        items: [{ id: 1, title: 'Retorno' }],
      },
      slots: {
        row: '<tr><td data-testid="row">Retorno</td></tr>',
      },
    });
    expect(table.get('caption').text()).toBe('Atividades');
    expect(table.get('[data-testid="row"]').text()).toBe('Retorno');

    const tabs = mount(DsTabs, {
      attachTo: document.body,
      props: {
        modelValue: 'pending',
        label: 'Situação',
        tabs: [
          { value: 'pending', label: 'Pendentes' },
          { value: 'today', label: 'Hoje' },
        ],
      },
      global,
    });
    await tabs.findAll('[role="tab"]')[0].trigger('keydown', {
      key: 'ArrowRight',
    });
    expect(tabs.emitted('update:modelValue').at(-1)).toEqual(['today']);
    tabs.unmount();

    const pagination = mount(DsPagination, {
      props: { currentPage: 1, totalItems: 120, itemsPerPage: 50 },
      global,
    });
    await pagination.findAll('button')[1].trigger('click');
    expect(pagination.emitted('update:currentPage').at(-1)).toEqual([2]);
  });

  it('provides labelled overlays and status feedback primitives', async () => {
    const tooltip = mount(DsTooltip, {
      props: { text: 'Editar' },
      slots: {
        default:
          '<button v-bind="$attrs" aria-label="Editar atividade">Editar</button>',
      },
    });
    expect(tooltip.get('[role="tooltip"]').text()).toBe('Editar');

    const dropdown = mount(DsDropdown, {
      props: { label: 'Mais ações' },
      slots: { default: '<button role="menuitem">Excluir</button>' },
      global,
    });
    await dropdown.get('button').trigger('click');
    expect(dropdown.get('[role="menu"]').exists()).toBe(true);

    const toast = mount(DsToast, {
      props: { message: 'Atividade salva', variant: 'success' },
      global,
    });
    expect(toast.attributes('role')).toBe('status');

    const modal = mount(DsModal, {
      props: { title: 'Confirmar', open: false },
      global,
    });
    expect(modal.get('dialog').attributes('aria-labelledby')).toBeTruthy();

    const drawer = mount(DsDrawer, {
      props: { title: 'Nova atividade', open: false },
      global,
    });
    expect(drawer.get('dialog').attributes('aria-labelledby')).toBeTruthy();
  });
});

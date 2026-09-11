import { mount } from '@vue/test-utils';

import CRMBoardColumn from './CRMBoardColumn.vue';

// F2.2 do PLANO-KANBAN-CRM-2026.md + dívida B-12.
//
// Depois que o board passou a consumir o endpoint de colunas, quem tem 1.200
// negócios numa coluna via 25 e **não tinha como pedir os outros**: o
// `getColumnPage` da F1.6 não era chamado por ninguém. O board ficou certo e
// incompleto.
//
// A coluna é quem sabe que está sendo rolada, então é ela quem pede mais.

const card = id => ({ id, title: `Negócio ${id}`, status: 'open' });

const mountColumn = (props = {}) =>
  mount(CRMBoardColumn, {
    props: {
      column: {
        // F2.8: `id` e a chave do balde; `stage_id` diz que este balde e uma
        // etapa — e so etapa aceita criar negocio.
        id: '10',
        stage_id: 10,
        name: 'Novo',
        count: 1200,
        sum_value_cents: 12_000_000,
        avg_days_in_stage: 3.5,
        wip_limit: null,
        over_wip: false,
        deals: Array.from({ length: 25 }, (_, index) => card(index + 1)),
      },
      ...props,
    },
    // A coluna nao conhece o card: ele entra por slot. Isso a mantem util para
    // o agrupar-por da F2.8 e a visao de lista da F2.9, que trocam o card.
    slots: {
      card: '<article data-testid="crm-board-card" />',
    },
    global: {
      stubs: {
        DsBadge: { props: ['label'], template: '<span>{{ label }}</span>' },
        DsButton: { template: '<button v-bind="$attrs" />' },
        Draggable: {
          name: 'Draggable',
          props: {
            modelValue: { type: Array, default: () => [] },
            handle: { type: String, default: '' },
          },
          template:
            '<div><template v-for="item in modelValue"><slot name="item" :element="item" /></template></div>',
        },
      },
    },
  });

const scroll = async (wrapper, { scrollTop, clientHeight, scrollHeight }) => {
  const list = wrapper.find('[data-testid="crm-column-scroll"]');
  Object.defineProperties(list.element, {
    scrollTop: { value: scrollTop, configurable: true },
    clientHeight: { value: clientHeight, configurable: true },
    scrollHeight: { value: scrollHeight, configurable: true },
  });
  await list.trigger('scroll');
};

describe('CRMBoardColumn', () => {
  describe('o cabeçalho', () => {
    // Contar `deals.length` mostraria 25 de 1.200 — o cabeçalho mentiria sobre
    // o tamanho da fila.
    it('shows the total the server counted, not the cards it received', () => {
      const wrapper = mountColumn();

      expect(wrapper.find('[data-testid="crm-column-count"]').text()).toContain(
        '1200'
      );
    });

    it('shows the money in the column', () => {
      const wrapper = mountColumn();

      expect(wrapper.text()).toContain('120.000,00');
    });

    it('shows the weighted money when stage has probability defined', () => {
      const wrapper = mountColumn({
        column: {
          id: '10',
          stage_id: 10,
          name: 'Proposta',
          count: 2,
          sum_value_cents: 10000000, // R$ 100.000,00
          probability_pct: 50, // 50% => R$ 50.000,00
          deals: [],
        },
      });

      expect(
        wrapper.find('[data-testid="crm-column-weighted"]').text()
      ).toContain('50.000,00');
    });

    it('says nothing about WIP when the stage has no limit', () => {
      const wrapper = mountColumn();

      expect(wrapper.find('[data-testid="crm-column-wip"]').exists()).toBe(
        false
      );
    });

    it('flags the column that went over its limit', () => {
      const wrapper = mountColumn({
        column: {
          id: 10,
          name: 'Novo',
          count: 12,
          deals: [card(1)],
          wip_limit: 10,
          over_wip: true,
        },
      });

      expect(wrapper.find('[data-testid="crm-column-wip"]').text()).toContain(
        '12/10'
      );
    });
  });

  describe('rolar para alcançar o resto da fila', () => {
    it('asks for more when the scroll gets near the bottom', async () => {
      const wrapper = mountColumn();

      await scroll(wrapper, {
        scrollTop: 700,
        clientHeight: 300,
        scrollHeight: 1000,
      });

      expect(wrapper.emitted('loadMore')).toHaveLength(1);
    });

    it('stays quiet while the scroll is far from the bottom', async () => {
      const wrapper = mountColumn();

      await scroll(wrapper, {
        scrollTop: 0,
        clientHeight: 300,
        scrollHeight: 1000,
      });

      expect(wrapper.emitted('loadMore')).toBeUndefined();
    });

    // Sem isso, uma rolagem contínua dispara uma requisição por evento de
    // scroll — dezenas para a mesma página.
    it('does not ask again while the previous answer has not arrived', async () => {
      const wrapper = mountColumn({ loading: true });

      await scroll(wrapper, {
        scrollTop: 700,
        clientHeight: 300,
        scrollHeight: 1000,
      });

      expect(wrapper.emitted('loadMore')).toBeUndefined();
    });

    it('stops asking once every deal in the column has arrived', async () => {
      const wrapper = mountColumn({
        column: {
          id: 10,
          name: 'Novo',
          count: 2,
          deals: [card(1), card(2)],
        },
      });

      await scroll(wrapper, {
        scrollTop: 700,
        clientHeight: 300,
        scrollHeight: 1000,
      });

      expect(wrapper.emitted('loadMore')).toBeUndefined();
    });
  });

  it('renders one card per deal it was given', () => {
    const wrapper = mountColumn();

    expect(wrapper.findAll('[data-testid="crm-board-card"]')).toHaveLength(25);
  });

  it('uses the visible handle for mouse and touch drag', () => {
    const wrapper = mountColumn();
    const draggable = wrapper.getComponent({ name: 'Draggable' });

    expect(draggable.props('handle')).toBe('.crm-drag-handle');
  });

  it('accepts a native mouse drop anywhere in the target column', async () => {
    const wrapper = mountColumn();

    await wrapper.get('[data-testid="crm-column-scroll"]').trigger('drop');

    expect(wrapper.emitted('nativeDrop')).toHaveLength(1);
  });

  it('asks the board to create a deal in this stage', async () => {
    const wrapper = mountColumn();

    await wrapper.find('[data-testid="crm-column-create"]').trigger('click');

    expect(wrapper.emitted('create')).toHaveLength(1);
  });

  // A coluna de um agrupamento que nao e etapa (responsavel, faixa de score)
  // nao tem etapa em que o negocio possa nascer.
  it('does not offer to create a deal when the column is not a stage', () => {
    const wrapper = mountColumn({
      column: {
        id: '__unassigned',
        name: 'Sem responsável',
        count: 0,
        deals: [],
      },
    });

    expect(wrapper.find('[data-testid="crm-column-create"]').exists()).toBe(
      false
    );
  });
});

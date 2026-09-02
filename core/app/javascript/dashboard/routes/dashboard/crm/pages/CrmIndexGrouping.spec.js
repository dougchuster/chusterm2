import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';
import { emitter } from 'shared/helpers/mitt';
import { CRM_DEAL_EVENT } from 'dashboard/composables/useBoardRealtime';

import CrmIndex from './CrmIndexOperational.vue';

// Achados da revisao da F2.8:
//
// CRITICAL — agrupado por responsavel, `column.id` e o id do usuario. Criar um
// negocio a partir daquela coluna mandava esse id como `crm_pipeline_stage_id`.
// Se existir uma etapa com o mesmo numero — ids de `users` e de
// `crm_pipeline_stages` correm em sequencias independentes e colidem — o
// negocio nasce na etapa errada, em silencio.
//
// HIGH — fora do agrupamento por etapa, um negocio criado por outro atendente
// nao entrava no quadro: o patch de realtime so sabe recolocar por etapa.

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '55' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(55) }),
}));

vi.mock('dashboard/components/crm/CRMKanbanChatDrawer.vue', () => ({
  default: { name: 'CRMKanbanChatDrawer', template: '<div />' },
}));

vi.mock('dashboard/api/crm', () => ({
  default: {
    getBoard: vi.fn(),
    getPipelines: vi.fn(),
    getLossReasons: vi.fn(),
    getColumnPage: vi.fn(),
    moveDeal: vi.fn(),
    createDeal: vi.fn(),
    getOptions: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const card = (id, extra = {}) => ({
  id,
  account_id: 55,
  title: `Negócio ${id}`,
  status: 'open',
  operational_status: 'active',
  crm_pipeline_stage_id: 10,
  position: id * 1000,
  ...extra,
});

// Agrupado por responsavel: `id` e o id do usuario, e `stage_id` nao existe.
const byOwner = {
  pipeline: { id: 1, name: 'Kanban' },
  columns: [
    {
      id: '3',
      name: 'Ana',
      position: 0,
      count: 1,
      open_count: 1,
      deals: [card(1, { owner_id: 3 })],
    },
    {
      id: '__unassigned',
      name: 'Sem responsável',
      position: 1,
      count: 0,
      open_count: 0,
      deals: [],
    },
  ],
  meta: { per_column: 25, group_by: 'owner', movable: false },
};

const byStage = {
  pipeline: { id: 1, name: 'Kanban' },
  columns: [
    {
      id: '10',
      stage_id: 10,
      name: 'Novo',
      position: 0,
      count: 1,
      open_count: 1,
      deals: [card(1)],
    },
  ],
  meta: { per_column: 25, group_by: 'stage', movable: true },
};

// O barramento de eventos e global: um board que nao e desmontado continua
// ouvindo, e o teste seguinte ve o realtime de todos os anteriores.
const mounted = [];

const mountBoard = async (board = byOwner) => {
  CrmAPI.getPipelines.mockResolvedValue({ data: [{ id: 1, name: 'Kanban' }] });
  CrmAPI.getLossReasons.mockResolvedValue({ data: [] });
  CrmAPI.getBoard.mockResolvedValue({ data: board });

  const wrapper = mount(CrmIndex, { global: { stubs: { teleport: true } } });
  await flushPromises();
  mounted.push(wrapper);
  return wrapper;
};

describe('CrmIndexOperational — agrupado por outra coisa que não a etapa', () => {
  afterEach(() => {
    mounted.splice(0).forEach(wrapper => wrapper.unmount());
  });

  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
  });

  describe('o quadro em si', () => {
    it('paints the columns instead of falling into the empty state', async () => {
      const wrapper = await mountBoard();

      expect(
        wrapper.findAllComponents({ name: 'CRMBoardColumn' })
      ).toHaveLength(2);
    });

    // A etapa e que some no agrupamento; o pipeline continua tendo etapas.
    it('does not claim the pipeline has no stages', async () => {
      const wrapper = await mountBoard();

      expect(wrapper.text()).not.toContain('ainda não possui etapas');
    });
  });

  describe('criar negócio a partir da coluna', () => {
    it('never takes the bucket key for a stage id', async () => {
      const wrapper = await mountBoard();

      wrapper.vm.openCreate(wrapper.vm.columns[0]);

      expect(wrapper.vm.createForm.crm_pipeline_stage_id).not.toBe('3');
    });

    // Sem etapa no quadro nao ha etapa para pre-selecionar: o formulario abre
    // vazio e o atendente escolhe.
    it('opens the form with no stage when the column is not a stage', async () => {
      const wrapper = await mountBoard();

      wrapper.vm.openCreate(wrapper.vm.columns[0]);

      expect(wrapper.vm.createForm.crm_pipeline_stage_id).toBe('');
    });

    it('still preselects the stage when grouping by stage', async () => {
      const wrapper = await mountBoard(byStage);

      wrapper.vm.openCreate(wrapper.vm.columns[0]);

      expect(wrapper.vm.createForm.crm_pipeline_stage_id).toBe('10');
    });

    // O botao "+" some: oferecer criar numa coluna que nao e etapa e prometer
    // algo que o servidor nao sabe cumprir.
    it('hides the per-column create button', async () => {
      const wrapper = await mountBoard();

      expect(wrapper.find('[data-testid="crm-column-create"]').exists()).toBe(
        false
      );
    });

    it('keeps it when the column is a stage', async () => {
      const wrapper = await mountBoard(byStage);

      expect(wrapper.find('[data-testid="crm-column-create"]').exists()).toBe(
        true
      );
    });
  });

  describe('o realtime de um negócio novo', () => {
    it('refetches the board, because it cannot know which bucket it lands in', async () => {
      await mountBoard();
      CrmAPI.getBoard.mockClear();

      emitter.emit(CRM_DEAL_EVENT, {
        type: 'created',
        deal: card(99, { account_id: 55, owner_id: 3 }),
      });
      await flushPromises();

      expect(CrmAPI.getBoard).toHaveBeenCalledTimes(1);
    });

    // Card que ja esta no quadro e mesclado no lugar: refetch aqui seria
    // desperdicio, e faria o quadro piscar a cada evento.
    it('does not refetch for a deal already on the board', async () => {
      await mountBoard();
      CrmAPI.getBoard.mockClear();

      emitter.emit(CRM_DEAL_EVENT, {
        type: 'updated',
        deal: { id: 1, account_id: 55, score_total: 90 },
      });
      await flushPromises();

      expect(CrmAPI.getBoard).not.toHaveBeenCalled();
    });

    it('does not refetch when grouping by stage, where it can place the card', async () => {
      const wrapper = await mountBoard(byStage);
      CrmAPI.getBoard.mockClear();

      emitter.emit(CRM_DEAL_EVENT, {
        type: 'created',
        deal: card(99, { account_id: 55 }),
      });
      await flushPromises();

      expect(CrmAPI.getBoard).not.toHaveBeenCalled();
      expect(wrapper.vm.columns[0].deals.map(deal => deal.id)).toContain(99);
    });
  });
});

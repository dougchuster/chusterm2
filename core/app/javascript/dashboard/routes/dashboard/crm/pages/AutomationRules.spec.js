import { mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import CrmAPI from 'dashboard/api/crm';
import AutomationRules from './AutomationRules.vue';

vi.mock('dashboard/api/crm', () => ({
  default: {
    getAutomationRules: vi.fn(),
    getPipelines: vi.fn(),
    createAutomationRule: vi.fn(),
    updateAutomationRule: vi.fn(),
    deleteAutomationRule: vi.fn(),
  },
}));

beforeEach(() => {
  if (typeof HTMLDialogElement !== 'undefined') {
    HTMLDialogElement.prototype.showModal = vi.fn(function mockShowModal() {
      this.open = true;
    });
    HTMLDialogElement.prototype.close = vi.fn(function mockClose() {
      this.open = false;
    });
  }
});

describe('AutomationRules.vue', () => {
  const mockRules = [
    {
      id: 1,
      name: 'Welcome Rule',
      is_active: true,
      crm_pipeline_stage_id: 10,
      action_type: 'create_activity',
      action_config: {
        kind: 'follow_up',
        title: 'Call client',
        priority: 'alta',
        due_in_hours: 8,
        conditions: [
          { field: 'legal_area', operator: 'eq', value: 'trabalhista' },
        ],
      },
    },
    {
      id: 2,
      name: 'Paused Rule',
      is_active: false,
      crm_pipeline_stage_id: 11,
      action_type: 'create_activity',
      action_config: {
        kind: 'reuniao',
        title: 'Meeting task',
        priority: 'critica',
        due_in_hours: 24,
        conditions: [],
      },
    },
  ];

  const mockPipelines = [
    {
      id: 1,
      name: 'Main Pipeline',
      stages: [
        { id: 10, name: 'Stage 1', slug: 'stage-1' },
        { id: 11, name: 'Stage 2', slug: 'stage-2' },
      ],
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    CrmAPI.getAutomationRules.mockResolvedValue({ data: mockRules });
    CrmAPI.getPipelines.mockResolvedValue({ data: mockPipelines });
  });

  const createComponent = () => {
    return mount(AutomationRules, {
      global: {
        stubs: {
          AutomationFlowBuilder: {
            template:
              '<div class="automation-flow-builder-stub"><slot /></div>',
            props: ['initialRule', 'pipelines', 'saving'],
            emits: ['save', 'cancel'],
          },
          DsPageHeader: {
            template: '<header><slot /><slot name="actions" /></header>',
          },
        },
      },
    });
  };

  it('fetches and renders automation rules and summary cards', async () => {
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    expect(CrmAPI.getAutomationRules).toHaveBeenCalled();
    expect(CrmAPI.getPipelines).toHaveBeenCalled();
    expect(wrapper.text()).toContain('Welcome Rule');
    expect(wrapper.text()).toContain('Paused Rule');

    expect(wrapper.vm.summary).toEqual([
      { key: 'total', label: expect.any(String), value: 2 },
      { key: 'active', label: expect.any(String), value: 1 },
      { key: 'paused', label: expect.any(String), value: 1 },
      { key: 'fast', label: expect.any(String), value: 1 },
      { key: 'critical', label: expect.any(String), value: 1 },
    ]);
  });

  it('filters rules by search term', async () => {
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    wrapper.vm.filters.search = 'Welcome';
    expect(wrapper.vm.filteredRules).toHaveLength(1);
    expect(wrapper.vm.filteredRules[0].name).toBe('Welcome Rule');
  });

  it('filters rules by status', async () => {
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    wrapper.vm.filters.status = 'active';
    expect(wrapper.vm.filteredRules).toHaveLength(1);
    expect(wrapper.vm.filteredRules[0].is_active).toBe(true);
  });

  it('opens builder when openNew is called', async () => {
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    wrapper.vm.openNew();
    expect(wrapper.vm.isBuilderOpen).toBe(true);
    expect(wrapper.vm.editingRule).toBeDefined();
  });

  it('opens builder when openEdit is called on a rule', async () => {
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    wrapper.vm.openEdit(mockRules[0]);
    expect(wrapper.vm.isBuilderOpen).toBe(true);
    expect(wrapper.vm.editingRule.id).toBe(1);
    expect(wrapper.vm.editingRule.name).toBe('Welcome Rule');
  });

  it('saves updated rule via API and reloads data', async () => {
    CrmAPI.updateAutomationRule.mockResolvedValue({ data: { id: 1 } });
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    wrapper.vm.openEdit(mockRules[0]);
    await wrapper.vm.handleSaveRule({
      name: 'Updated Rule',
      trigger_event: 'stage_entered',
      crm_pipeline_stage_id: 10,
      action_type: 'create_activity',
      action_config: { title: 'Updated' },
    });

    expect(CrmAPI.updateAutomationRule).toHaveBeenCalledWith(1, {
      name: 'Updated Rule',
      trigger_event: 'stage_entered',
      crm_pipeline_stage_id: 10,
      action_type: 'create_activity',
      action_config: { title: 'Updated' },
    });
    expect(wrapper.vm.isBuilderOpen).toBe(false);
  });

  it('toggles rule active status', async () => {
    CrmAPI.updateAutomationRule.mockResolvedValue({ data: {} });
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    await wrapper.vm.toggleActive(mockRules[0]);
    expect(CrmAPI.updateAutomationRule).toHaveBeenCalledWith(1, {
      is_active: false,
    });
  });

  it('deletes a rule after confirmation', async () => {
    CrmAPI.deleteAutomationRule.mockResolvedValue({});
    const wrapper = createComponent();
    await vi.waitFor(() => {
      expect(wrapper.vm.loading).toBe(false);
    });

    wrapper.vm.requestDelete(mockRules[0]);
    expect(wrapper.vm.deletingRule).toEqual(mockRules[0]);

    await wrapper.vm.confirmDelete();
    expect(CrmAPI.deleteAutomationRule).toHaveBeenCalledWith(1);
    expect(wrapper.vm.deletingRule).toBeNull();
  });
});

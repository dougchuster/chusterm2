import { mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import AutomationFlowBuilder from '../AutomationFlowBuilder.vue';

// Mock VueFlow components/hooks if needed in jsdom
vi.mock('@vue-flow/core', async () => {
  const actual = await vi.importActual('@vue-flow/core');
  return {
    ...actual,
    useVueFlow: () => ({
      fitView: vi.fn(),
      zoomIn: vi.fn(),
      zoomOut: vi.fn(),
      onNodesChange: vi.fn(),
      onEdgesChange: vi.fn(),
      onConnect: vi.fn(),
    }),
  };
});

describe('AutomationFlowBuilder.vue', () => {
  const pipelines = [
    {
      id: 1,
      name: 'Sales Pipeline',
      stages: [
        { id: 10, name: 'Lead In', slug: 'lead-in' },
        { id: 11, name: 'Qualified', slug: 'qualified' },
      ],
    },
  ];

  const initialRule = {
    id: 100,
    name: 'Auto Follow-up Rule',
    trigger_event: 'stage_entered',
    crm_pipeline_stage_id: 10,
    action_type: 'create_activity',
    action_config: {
      kind: 'follow_up',
      title: 'Call prospect',
      description: 'Initial intake call',
      priority: 'alta',
      due_in_hours: 12,
      conditions: [
        { field: 'legal_area', operator: 'eq', value: 'trabalhista' },
      ],
    },
  };

  let wrapper;

  const createComponent = (props = {}) => {
    return mount(AutomationFlowBuilder, {
      props: {
        initialRule,
        pipelines,
        saving: false,
        ...props,
      },
      global: {
        stubs: {
          VueFlow: {
            template: '<div class="vue-flow-stub"><slot /></div>',
          },
        },
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('initializes nodes and edges from initialRule', () => {
    expect(wrapper.vm.nodes).toHaveLength(3);
    expect(wrapper.vm.nodes[0].type).toBe('trigger');
    expect(wrapper.vm.nodes[1].type).toBe('condition');
    expect(wrapper.vm.nodes[2].type).toBe('action');
    expect(wrapper.vm.edges).toHaveLength(2);
  });

  it('updates ruleName and node data reactively', async () => {
    wrapper.vm.ruleName = 'Updated Workflow Name';
    expect(wrapper.vm.nodes[0].data.name).toBe('Updated Workflow Name');
  });

  it('adds a new condition node when addConditionNode is called', async () => {
    const initialCount = wrapper.vm.nodes.length;
    wrapper.vm.addConditionNode();
    expect(wrapper.vm.nodes).toHaveLength(initialCount + 1);
    const lastNode = wrapper.vm.nodes[wrapper.vm.nodes.length - 1];
    expect(lastNode.type).toBe('condition');
  });

  it('deletes a node and connected edges when deleteNode is called', async () => {
    const conditionNode = wrapper.vm.nodes.find(n => n.type === 'condition');
    wrapper.vm.deleteNode(conditionNode.id);

    expect(
      wrapper.vm.nodes.find(n => n.id === conditionNode.id)
    ).toBeUndefined();
    expect(
      wrapper.vm.edges.some(
        e => e.source === conditionNode.id || e.target === conditionNode.id
      )
    ).toBe(false);
  });

  it('emits save with serialized payload when validateAndSave succeeds', async () => {
    wrapper.vm.validateAndSave();

    expect(wrapper.emitted('save')).toBeTruthy();
    const emittedPayload = wrapper.emitted('save')[0][0];

    expect(emittedPayload.name).toBe('Auto Follow-up Rule');
    expect(emittedPayload.trigger_event).toBe('stage_entered');
    expect(emittedPayload.crm_pipeline_stage_id).toBe(10);
    expect(emittedPayload.action_type).toBe('create_activity');
    expect(emittedPayload.action_config.title).toBe('Call prospect');
    expect(emittedPayload.action_config.conditions).toHaveLength(1);
    expect(emittedPayload.action_config.conditions[0]).toEqual({
      field: 'legal_area',
      operator: 'eq',
      value: 'trabalhista',
    });
  });

  it('validates required fields before emitting save', async () => {
    wrapper.vm.nodes[0].data.name = '';
    wrapper.vm.validateAndSave();

    expect(wrapper.emitted('save')).toBeFalsy();
    expect(wrapper.vm.validationError).toBeTruthy();
  });

  it('emits cancel when cancel button is clicked', async () => {
    await wrapper.find('header button').trigger('click');
    expect(wrapper.emitted('cancel')).toBeTruthy();
  });
});

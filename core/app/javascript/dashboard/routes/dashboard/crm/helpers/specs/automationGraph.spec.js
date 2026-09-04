import { describe, expect, it } from 'vitest';
import {
  cleanConditions,
  getOrderedNodes,
  graphToRules,
  rulesToGraph,
} from '../automationGraph';

describe('automationGraph helper', () => {
  describe('cleanConditions', () => {
    it('filters out invalid or incomplete conditions', () => {
      const raw = [
        { field: 'legal_area', operator: 'eq', value: 'civil' },
        { field: '', operator: 'eq', value: 'foo' },
        { field: 'status', operator: '' },
        null,
      ];
      expect(cleanConditions(raw)).toEqual([
        { field: 'legal_area', operator: 'eq', value: 'civil' },
      ]);
    });

    it('sets value to null for present/blank operators', () => {
      const raw = [
        { field: 'has_phone', operator: 'present', value: 'ignored' },
        { field: 'campaign_opt_out', operator: 'blank', value: 'ignored' },
      ];
      expect(cleanConditions(raw)).toEqual([
        { field: 'has_phone', operator: 'present', value: null },
        { field: 'campaign_opt_out', operator: 'blank', value: null },
      ]);
    });
  });

  describe('rulesToGraph', () => {
    it('creates trigger and action nodes connected by an edge when there are no conditions', () => {
      const rule = {
        name: 'Simple Rule',
        trigger_event: 'stage_entered',
        crm_pipeline_stage_id: 12,
        action_type: 'create_activity',
        action_config: {
          kind: 'follow_up',
          title: 'Follow up call',
          description: 'Call client',
          priority: 'alta',
          due_in_hours: 12,
          conditions: [],
        },
      };

      const { nodes, edges } = rulesToGraph(rule);

      expect(nodes).toHaveLength(2);
      expect(nodes[0].type).toBe('trigger');
      expect(nodes[0].data.name).toBe('Simple Rule');
      expect(nodes[0].data.crm_pipeline_stage_id).toBe(12);

      expect(nodes[1].type).toBe('action');
      expect(nodes[1].data.title).toBe('Follow up call');
      expect(nodes[1].data.priority).toBe('alta');

      expect(edges).toHaveLength(1);
      expect(edges[0].source).toBe(nodes[0].id);
      expect(edges[0].target).toBe(nodes[1].id);
    });

    it('chains condition nodes between trigger and action when conditions exist', () => {
      const rule = {
        name: 'Multi Condition Rule',
        trigger_event: 'stage_entered',
        crm_pipeline_stage_id: 5,
        action_type: 'create_activity',
        action_config: {
          kind: 'reuniao',
          title: 'Schedule meeting',
          description: '',
          priority: 'critica',
          due_in_hours: 6,
          conditions: [
            { field: 'legal_area', operator: 'eq', value: 'trabalhista' },
            { field: 'urgency_level', operator: 'gte', value: '3' },
          ],
        },
      };

      const { nodes, edges } = rulesToGraph(rule);

      expect(nodes).toHaveLength(4);
      expect(nodes[0].type).toBe('trigger');
      expect(nodes[1].type).toBe('condition');
      expect(nodes[1].data.field).toBe('legal_area');
      expect(nodes[2].type).toBe('condition');
      expect(nodes[2].data.field).toBe('urgency_level');
      expect(nodes[3].type).toBe('action');

      expect(edges).toHaveLength(3);
      expect(edges[0].source).toBe(nodes[0].id);
      expect(edges[0].target).toBe(nodes[1].id);
      expect(edges[1].source).toBe(nodes[1].id);
      expect(edges[1].target).toBe(nodes[2].id);
      expect(edges[2].source).toBe(nodes[2].id);
      expect(edges[2].target).toBe(nodes[3].id);
    });
  });

  describe('getOrderedNodes', () => {
    it('returns nodes in topological order along edges', () => {
      const nodes = [
        { id: 'act', type: 'action' },
        { id: 'trig', type: 'trigger' },
        { id: 'c1', type: 'condition' },
      ];
      const edges = [
        { source: 'trig', target: 'c1' },
        { source: 'c1', target: 'act' },
      ];

      const ordered = getOrderedNodes(nodes, edges);
      expect(ordered.map(n => n.id)).toEqual(['trig', 'c1', 'act']);
    });
  });

  describe('round-trip serialization (graphToRules(rulesToGraph(rule)) == rule)', () => {
    it('performs exact round-trip for create_activity rule without conditions', () => {
      const rule = {
        name: 'Lead follow up',
        trigger_event: 'stage_entered',
        crm_pipeline_stage_id: 10,
        action_type: 'create_activity',
        action_config: {
          kind: 'ligacao',
          title: 'Initial contact call',
          description: 'Speak with prospect',
          priority: 'normal',
          due_in_hours: 24,
          conditions: [],
        },
      };

      const graph = rulesToGraph(rule);
      const output = graphToRules(graph);

      expect(output).toEqual(rule);
    });

    it('performs exact round-trip for create_activity rule with multiple conditions', () => {
      const rule = {
        name: 'High value legal review',
        trigger_event: 'stage_entered',
        crm_pipeline_stage_id: 8,
        action_type: 'create_activity',
        action_config: {
          kind: 'revisao_juridica',
          title: 'Review corporate contract',
          description: 'Check liability clauses',
          priority: 'critica',
          due_in_hours: 4,
          conditions: [
            { field: 'legal_area', operator: 'eq', value: 'societario' },
            { field: 'score_total', operator: 'gte', value: '80' },
            { field: 'has_phone', operator: 'present', value: null },
          ],
        },
      };

      const graph = rulesToGraph(rule);
      const output = graphToRules(graph);

      expect(output).toEqual(rule);
    });

    it('performs round-trip for set_captain_mode action', () => {
      const rule = {
        name: 'Enable AI Autonomous in triage',
        trigger_event: 'message_received',
        crm_pipeline_stage_id: 2,
        action_type: 'set_captain_mode',
        action_config: {
          ai_mode: 'autonomous',
          reason: 'Auto qualification',
          conditions: [
            { field: 'relationship_status', operator: 'eq', value: 'lead' },
          ],
        },
      };

      const graph = rulesToGraph(rule);
      const output = graphToRules(graph);

      expect(output).toEqual(rule);
    });

    it('performs round-trip for move_to_stage action', () => {
      const rule = {
        name: 'Move high score to proposal',
        trigger_event: 'score_changed',
        crm_pipeline_stage_id: 3,
        action_type: 'move_to_stage',
        action_config: {
          stage_slug: 'proposta-enviada',
          conditions: [{ field: 'score_total', operator: 'gt', value: '90' }],
        },
      };

      const graph = rulesToGraph(rule);
      const output = graphToRules(graph);

      expect(output).toEqual(rule);
    });

    it('performs round-trip for assign_owner action', () => {
      const rule = {
        name: 'Assign partner to complex case',
        trigger_event: 'stage_entered',
        crm_pipeline_stage_id: 4,
        action_type: 'assign_owner',
        action_config: {
          user_id: 42,
          conditions: [
            { field: 'urgency_level', operator: 'eq', value: 'alta' },
          ],
        },
      };

      const graph = rulesToGraph(rule);
      const output = graphToRules(graph);

      expect(output).toEqual(rule);
    });
  });
});

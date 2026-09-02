import { describe, it, beforeEach, expect, vi } from 'vitest';
import ActionCableConnector from '../actionCable';
import { emitter } from 'shared/helpers/mitt';

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: vi.fn(),
  },
}));

vi.mock('dashboard/composables/useImpersonation', () => ({
  useImpersonation: () => ({
    isImpersonating: { value: false },
  }),
}));

global.chustermConfig = {
  websocketURL: 'wss://test.chusterm.com',
};

describe('ActionCableConnector - Copilot Tests', () => {
  let store;
  let actionCable;
  let mockDispatch;

  beforeEach(() => {
    vi.clearAllMocks();
    mockDispatch = vi.fn();
    store = {
      $store: {
        dispatch: mockDispatch,
        getters: {
          getCurrentAccountId: 1,
        },
      },
    };

    actionCable = ActionCableConnector.init(store.$store, 'test-token');
  });
  describe('copilot event handlers', () => {
    it('should register the copilot.message.created event handler', () => {
      expect(Object.keys(actionCable.events)).toContain(
        'copilot.message.created'
      );
      expect(actionCable.events['copilot.message.created']).toBe(
        actionCable.onCopilotMessageCreated
      );
    });

    it('should handle the copilot.message.created event through the ActionCable system', () => {
      const copilotData = {
        id: 2,
        content: 'This is a copilot message from ActionCable',
        conversation_id: 456,
        created_at: '2025-05-27T15:58:04-06:00',
        account_id: 1,
      };
      actionCable.onReceived({
        event: 'copilot.message.created',
        data: copilotData,
      });
      expect(mockDispatch).toHaveBeenCalledWith(
        'copilotMessages/upsert',
        copilotData
      );
    });
  });
});

describe('ActionCableConnector - CRM board realtime (F1.8)', () => {
  let store;
  let actionCable;

  beforeEach(() => {
    vi.clearAllMocks();
    store = {
      $store: {
        dispatch: vi.fn(),
        getters: { getCurrentAccountId: 1 },
      },
    };
    actionCable = ActionCableConnector.init(store.$store, 'test-token');
  });

  // Os tres eventos apontavam para o mesmo handler, que emitia so `data` — o
  // nome do evento se perdia no caminho e o board nao tinha como distinguir uma
  // exclusao de uma atualizacao. Sem isso nao ha patch incremental possivel.
  it.each([
    ['crm_deal.created', 'created'],
    ['crm_deal.updated', 'updated'],
    ['crm_deal.deleted', 'deleted'],
  ])('forwards %s to the bus saying which kind it is', (event, type) => {
    const deal = {
      id: 5,
      account_id: 1,
      crm_pipeline_stage_id: 10,
      position: 1000,
    };

    actionCable.onReceived({ event, data: deal });

    expect(emitter.emit).toHaveBeenCalledWith('crm_deal_changed', {
      type,
      deal,
    });
  });

  it('registers a handler for each of the three events', () => {
    expect(Object.keys(actionCable.events)).toEqual(
      expect.arrayContaining([
        'crm_deal.created',
        'crm_deal.updated',
        'crm_deal.deleted',
      ])
    );
  });
});

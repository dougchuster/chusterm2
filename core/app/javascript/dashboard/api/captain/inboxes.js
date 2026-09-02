/* global axios */
import ApiClient from '../ApiClient';

class CaptainInboxes extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  get({ assistantId } = {}) {
    return axios.get(`${this.url}/${assistantId}/inboxes`);
  }

  create(params = {}) {
    const {
      assistantId,
      inboxId,
      enabled = true,
      autoReplyEnabled = true,
      aiMode = 'auto',
      handoffStrategy = 'human_request',
      routingConfig = {},
    } = params;
    return axios.post(`${this.url}/${assistantId}/inboxes`, {
      inbox: {
        inbox_id: inboxId,
        enabled,
        auto_reply_enabled: autoReplyEnabled,
        ai_mode: aiMode,
        handoff_strategy: handoffStrategy,
        routing_config: routingConfig,
      },
    });
  }

  update(params = {}) {
    const {
      assistantId,
      inboxId,
      enabled,
      autoReplyEnabled,
      aiMode,
      handoffStrategy,
      routingConfig = {},
    } = params;
    return axios.patch(`${this.url}/${assistantId}/inboxes/${inboxId}`, {
      inbox: {
        enabled,
        auto_reply_enabled: autoReplyEnabled,
        ai_mode: aiMode,
        handoff_strategy: handoffStrategy,
        routing_config: routingConfig,
      },
    });
  }

  delete(params = {}) {
    const { assistantId, inboxId } = params;
    return axios.delete(`${this.url}/${assistantId}/inboxes/${inboxId}`);
  }
}

export default new CaptainInboxes();

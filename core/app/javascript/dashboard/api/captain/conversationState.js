import ApiClient from '../ApiClient';

class CaptainConversationStateAPI extends ApiClient {
  constructor() {
    super('captain/conversation_states', { accountScoped: true });
  }

  update(conversationId, data) {
    return super.update(conversationId, { conversation_state: data });
  }
}

export default new CaptainConversationStateAPI();

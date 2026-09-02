import ApiClient from '../ApiClient';

class CaptainConversationStateAPI extends ApiClient {
  constructor() {
    super('captain/conversation_states', { accountScoped: true });
  }

  update(conversationDisplayId, data) {
    return super.update(conversationDisplayId, { conversation_state: data });
  }
}

export default new CaptainConversationStateAPI();

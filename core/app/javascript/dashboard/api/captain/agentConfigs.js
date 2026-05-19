/* global axios */
import ApiClient from '../ApiClient';

class CaptainAgentConfigsAPI extends ApiClient {
  constructor() {
    super('captain/agent_configs', { accountScoped: true });
  }

  show(assistantId) {
    return axios.get(`${this.url}/${assistantId}`);
  }

  update(assistantId, data = {}) {
    return axios.patch(`${this.url}/${assistantId}`, data);
  }
}

export default new CaptainAgentConfigsAPI();

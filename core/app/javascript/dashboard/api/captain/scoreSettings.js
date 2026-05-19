/* global axios */
import ApiClient from '../ApiClient';

class CaptainScoreSettingsAPI extends ApiClient {
  constructor() {
    super('captain/score_settings', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  updateCampaign(campaignId, data) {
    return axios.patch(`${this.url}/${campaignId}`, { score_setting: data });
  }

  updateConversationState(stateId, data) {
    return axios.patch(`${this.url}/conversation_states/${stateId}`, {
      conversation_state: data,
    });
  }
}

export default new CaptainScoreSettingsAPI();

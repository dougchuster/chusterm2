/* global axios */
import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  audienceCount(audience = []) {
    return axios.post(`${this.url}/audience_count`, { audience });
  }

  audiencePreview(audience = []) {
    return axios.post(`${this.url}/audience_preview`, { audience });
  }

  trackEvent(id, payload = {}) {
    return axios.post(`${this.url}/${id}/track_event`, payload);
  }
}

export default new CampaignsAPI();

/* global axios */

const configurationUrl = accountId =>
  `/api/v1/accounts/${accountId}/evolution/configuration`;

const EvolutionAPI = {
  getConfiguration(accountId) {
    return axios.get(configurationUrl(accountId));
  },

  saveConfiguration(accountId, payload) {
    return axios.post(configurationUrl(accountId), payload);
  },

  validateConfiguration(accountId, payload) {
    return axios.post(`${configurationUrl(accountId)}/validate`, payload);
  },

  createInbox(accountId, payload) {
    return axios.post(
      `/api/v1/accounts/${accountId}/channels/evolution/inboxes`,
      payload
    );
  },
};

export default EvolutionAPI;

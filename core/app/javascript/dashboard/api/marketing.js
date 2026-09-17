/* global axios */
/* eslint-disable class-methods-use-this */

const accountIdFromRoute = () => {
  const isInsideAccountScopedURLs =
    window.location.pathname.includes('/app/accounts');

  if (!isInsideAccountScopedURLs) return '';
  return window.location.pathname.split('/')[3];
};

const marketingUrl = path =>
  `/api/v1/accounts/${accountIdFromRoute()}/marketing/${path}`;

const queryString = params => {
  const searchParams = new URLSearchParams();
  Object.entries(params || {}).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.append(key, value);
    }
  });
  return searchParams.toString();
};

class MarketingAPI {
  getConnections() {
    return axios.get(marketingUrl('connections'));
  }

  authorizeConnection(provider, returnTo) {
    return axios.post(marketingUrl('connections/authorize'), {
      provider,
      return_to: returnTo,
    });
  }

  disconnectConnection(connectionId) {
    return axios.delete(marketingUrl(`connections/${connectionId}`));
  }

  syncConnection(connectionId) {
    return axios.post(marketingUrl(`connections/${connectionId}/sync`));
  }

  getOverview(params = {}) {
    const query = queryString(params);
    return axios.get(
      marketingUrl(`metrics/overview${query ? `?${query}` : ''}`)
    );
  }

  getCampaigns(params = {}) {
    const query = queryString(params);
    return axios.get(marketingUrl(`campaigns${query ? `?${query}` : ''}`));
  }

  getLeads(params = {}) {
    const query = queryString(params);
    return axios.get(marketingUrl(`leads${query ? `?${query}` : ''}`));
  }

  convertLead(leadId, payload = {}) {
    return axios.post(marketingUrl(`leads/${leadId}/convert`), payload);
  }

  discardLead(leadId) {
    return axios.post(marketingUrl(`leads/${leadId}/discard`));
  }

  getEvents(params = {}) {
    const query = queryString(params);
    return axios.get(marketingUrl(`events${query ? `?${query}` : ''}`));
  }

  retryEvent(eventId) {
    return axios.post(marketingUrl(`events/${eventId}/retry`));
  }
}

export default new MarketingAPI();

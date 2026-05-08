/* global axios */
import ApiClient from '../ApiClient';

class CaptainFlowsAPI extends ApiClient {
  constructor() {
    super('captain/flows', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, { flow: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { flow: data });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  publish(id) {
    return axios.post(`${this.url}/${id}/publish`);
  }

  saveGraph(id, { nodes, edges }) {
    return axios.put(`${this.url}/${id}/graph`, { flow: { nodes, edges } });
  }
}

export default new CaptainFlowsAPI();

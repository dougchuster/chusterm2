/* global axios */
import ApiClient from '../ApiClient';

class CaptainPlaybooksAPI extends ApiClient {
  constructor() {
    super('captain/playbooks', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, { playbook: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { playbook: data });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new CaptainPlaybooksAPI();

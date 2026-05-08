/* global axios */
import ApiClient from '../ApiClient';

class CaptainDocumentVersionsAPI extends ApiClient {
  constructor() {
    super('captain/document_versions', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }
}

export default new CaptainDocumentVersionsAPI();

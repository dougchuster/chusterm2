/* global axios */
import ApiClient from './ApiClient';

class ContactCategoriesAPI extends ApiClient {
  constructor() {
    super('contact_categories', { accountScoped: true });
  }

  bulkAssign(data) {
    return axios.post(`${this.url}/bulk_assign`, data);
  }

  bulkRemove(data) {
    return axios.post(`${this.url}/bulk_remove`, data);
  }
}

export default new ContactCategoriesAPI();

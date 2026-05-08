/* global axios */
import ApiClient from './ApiClient';

const crmFilterParams = filters => {
  const params = [];
  const pushParam = (key, value) => {
    if (value) params.push(`${key}=${encodeURIComponent(value)}`);
  };
  if (filters?.relationshipStatus) {
    pushParam('relationship_status', filters.relationshipStatus);
  }
  if (filters?.lifecycleStage) {
    pushParam('lifecycle_stage', filters.lifecycleStage);
  }
  if (filters?.crmOwnerId) {
    pushParam('crm_owner_id', filters.crmOwnerId);
  }
  if (filters?.withoutCrmOwner) {
    params.push('without_crm_owner=true');
  }
  if (filters?.sourceList) {
    pushParam('source_list', filters.sourceList);
  }
  if (filters?.legalArea) {
    pushParam('legal_area', filters.legalArea);
  }
  if (filters?.label) {
    pushParam('labels[]', filters.label);
  }
  return params.join('&');
};

export const buildContactParams = (
  page,
  sortAttr,
  label,
  search,
  filters = {}
) => {
  let params = `include_contact_inboxes=false&page=${page}&sort=${sortAttr}`;
  if (search) {
    params = `${params}&q=${search}`;
  }
  if (label) {
    params = `${params}&labels[]=${label}`;
  }
  const crmParams = crmFilterParams(filters);
  if (crmParams) {
    params = `${params}&${crmParams}`;
  }
  return params;
};

class ContactAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  get(page, sortAttr = 'name', label = '', filters = {}) {
    let requestURL = `${this.url}?${buildContactParams(
      page,
      sortAttr,
      label,
      '',
      filters
    )}`;
    return axios.get(requestURL);
  }

  show(id) {
    return axios.get(`${this.url}/${id}?include_contact_inboxes=false`);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}?include_contact_inboxes=false`, data);
  }

  getConversations(contactId) {
    return axios.get(`${this.url}/${contactId}/conversations`);
  }

  getContactableInboxes(contactId) {
    return axios.get(`${this.url}/${contactId}/contactable_inboxes`);
  }

  getContactLabels(contactId) {
    return axios.get(`${this.url}/${contactId}/labels`);
  }

  initiateCall(contactId, inboxId) {
    return axios.post(`${this.url}/${contactId}/call`, {
      inbox_id: inboxId,
    });
  }

  updateContactLabels(contactId, labels) {
    return axios.post(`${this.url}/${contactId}/labels`, { labels });
  }

  search(
    search = '',
    page = 1,
    sortAttr = 'name',
    label = '',
    options = {},
    filters = {}
  ) {
    let requestURL = `${this.url}/search?${buildContactParams(
      page,
      sortAttr,
      label,
      search,
      filters
    )}`;
    return axios.get(requestURL, { signal: options.signal });
  }

  active(page = 1, sortAttr = 'name', filters = {}) {
    let requestURL = `${this.url}/active?${buildContactParams(
      page,
      sortAttr,
      '',
      '',
      filters
    )}`;
    return axios.get(requestURL);
  }

  // eslint-disable-next-line default-param-last
  filter(page = 1, sortAttr = 'name', queryPayload, filters = {}) {
    let requestURL = `${this.url}/filter?${buildContactParams(
      page,
      sortAttr,
      '',
      '',
      filters
    )}`;
    return axios.post(requestURL, queryPayload);
  }

  importContacts(file, options = {}) {
    const formData = new FormData();
    formData.append('import_file', file);
    Object.entries(options).forEach(([key, value]) => {
      if (Array.isArray(value)) {
        value.forEach(item => formData.append(`${key}[]`, item));
      } else if (value && typeof value === 'object') {
        Object.entries(value).forEach(([nestedKey, nestedValue]) => {
          if (nestedValue) {
            formData.append(`${key}[${nestedKey}]`, nestedValue);
          }
        });
      } else if (value) {
        formData.append(key, value);
      }
    });
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  getImports() {
    return axios.get(`${this.url}/imports`);
  }

  destroyCustomAttributes(contactId, customAttributes) {
    return axios.post(`${this.url}/${contactId}/destroy_custom_attributes`, {
      custom_attributes: customAttributes,
    });
  }

  destroyAvatar(contactId) {
    return axios.delete(`${this.url}/${contactId}/avatar`);
  }

  exportContacts(queryPayload) {
    return axios.post(`${this.url}/export`, queryPayload);
  }

  exportContactsCsv(queryPayload) {
    return axios.post(`${this.url}/export_csv`, queryPayload, {
      responseType: 'blob',
    });
  }

  exportContactsGoogleSheet(queryPayload) {
    return axios.post(`${this.url}/export_google_sheet`, queryPayload);
  }

  authorizeGoogleWorkspace() {
    return axios.post(`${this.baseUrl()}/crm/google_authorization`);
  }
}

export default new ContactAPI();

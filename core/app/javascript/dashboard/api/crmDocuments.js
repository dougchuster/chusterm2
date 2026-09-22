/* global axios */

// Cofre de documentos (PROJETO-COFRE-DOCUMENTOS.md). Todas as rotas respondem
// 404 quando o módulo está desligado na conta — quem chama trata isso como
// "módulo indisponível", não como erro.

const accountIdFromRoute = () => {
  if (!window.location.pathname.includes('/app/accounts')) return '';
  return window.location.pathname.split('/')[3];
};

const crmUrl = path => `/api/v1/accounts/${accountIdFromRoute()}/crm/${path}`;

const cleanParams = params =>
  Object.fromEntries(
    Object.entries(params || {}).filter(
      ([, value]) => value !== undefined && value !== null && value !== ''
    )
  );

export default {
  getFolders({ contactId, dealId }) {
    return axios.get(crmUrl('document_folders'), {
      params: cleanParams({ contact_id: contactId, deal_id: dealId }),
    });
  },

  createFolder({ contactId, parentId, name }) {
    return axios.post(crmUrl('document_folders'), {
      contact_id: contactId,
      parent_id: parentId,
      name,
    });
  },

  updateFolder(id, folder) {
    return axios.patch(crmUrl(`document_folders/${id}`), { folder });
  },

  archiveFolder(id) {
    return axios.delete(crmUrl(`document_folders/${id}`));
  },

  getTypes() {
    return axios.get(crmUrl('document_types'));
  },

  // Caixa de Triagem: o que chegou e ainda não foi classificado, de todos os
  // clientes que o usuário atende.
  getTriage({ page } = {}) {
    return axios.get(crmUrl('documents/triage'), {
      params: cleanParams({ page }),
    });
  },

  // "X de Y" de documentos de um negócio.
  getChecklist(dealId) {
    return axios.get(crmUrl('document_checklist'), {
      params: { deal_id: dealId },
    });
  },

  // payload: { template_id } ou { mark: { key, done } }
  updateChecklist(dealId, payload) {
    return axios.patch(crmUrl('document_checklist'), {
      deal_id: dealId,
      ...payload,
    });
  },

  // Filas do escritório: 'review' (para análise) ou 'expiring' (vencendo).
  getQueue(name, { page } = {}) {
    return axios.get(crmUrl('documents/queue'), {
      params: cleanParams({ name, page }),
    });
  },

  getDocuments({ contactId, folderId, dealId, q, archived, page } = {}) {
    return axios.get(crmUrl('documents'), {
      params: cleanParams({
        contact_id: contactId,
        folder_id: folderId,
        deal_id: dealId,
        q,
        archived,
        page,
      }),
    });
  },

  upload({ contactId, folderId, dealId, file, onProgress }) {
    const formData = new FormData();
    formData.append('contact_id', contactId);
    if (folderId) formData.append('folder_id', folderId);
    if (dealId) formData.append('deal_id', dealId);
    formData.append('file', file);
    return axios.post(crmUrl('documents'), formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      onUploadProgress: event => {
        if (!onProgress || !event.total) return;
        onProgress(Math.round((event.loaded / event.total) * 100));
      },
    });
  },

  updateDocument(id, document) {
    return axios.patch(crmUrl(`documents/${id}`), { document });
  },

  archiveDocument(id) {
    return axios.delete(crmUrl(`documents/${id}`));
  },

  restoreDocument(id) {
    return axios.post(crmUrl(`documents/${id}/restore`));
  },

  // Devolve { url, expires_in }: URL assinada de 5 minutos, já auditada.
  getDownloadUrl(id, { inline = false } = {}) {
    return axios.get(crmUrl(`documents/${id}/download`), {
      params: { mode: 'url', disposition: inline ? 'inline' : 'attachment' },
    });
  },
};

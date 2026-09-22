import { flushPromises, mount } from '@vue/test-utils';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import CRMDocumentVault from './CRMDocumentVault.vue';

vi.mock('dashboard/api/crmDocuments', () => ({
  default: {
    getFolders: vi.fn(),
    getTypes: vi.fn(),
    getDocuments: vi.fn(),
    upload: vi.fn(),
    updateDocument: vi.fn(),
    archiveDocument: vi.fn(),
    createFolder: vi.fn(),
    getDownloadUrl: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const folders = [
  {
    id: 1,
    parent_id: null,
    name: '00 Triagem',
    slot: 'triagem',
    position: 0,
    documents_count: 1,
    kind: 'system',
  },
  {
    id: 2,
    parent_id: null,
    name: '01 Documentos Pessoais',
    slot: 'pessoais',
    position: 1,
    documents_count: 0,
    kind: 'system',
  },
];

const triageDocument = {
  id: 50,
  folder_id: 1,
  file_name: '2026-09-22 14h37 — WhatsApp — IMG-WA0012.jpg',
  in_triage: true,
  doc_type: null,
  suggested_doc_type: 'rg',
  suggested_doc_type_label: 'RG',
  caption: 'segue meu rg',
  status: 'received',
  source: 'whatsapp',
  content_type: 'image/jpeg',
  byte_size: 2048,
  created_at: '2026-09-22T17:37:00Z',
  path: 'Clientes/Maria · C000011/00 Triagem/2026-09-22 14h37 — WhatsApp — IMG-WA0012.jpg',
};

const mountVault = async () => {
  const wrapper = mount(CRMDocumentVault, {
    props: { contactId: 11, dealId: 7 },
    global: { stubs: { teleport: true } },
  });
  await flushPromises();
  return wrapper;
};

describe('CRMDocumentVault', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
    CrmDocumentsAPI.getFolders.mockResolvedValue({
      data: {
        folders,
        client_folder_name: 'Maria · C000011',
        case_folder_id: null,
      },
    });
    CrmDocumentsAPI.getTypes.mockResolvedValue({
      data: [{ slug: 'rg', label: 'RG' }],
    });
    CrmDocumentsAPI.getDocuments.mockResolvedValue({
      data: { payload: [triageDocument], meta: { count: 1 } },
    });
  });

  it('abre na triagem quando há algo para classificar e mostra o documento', async () => {
    const wrapper = await mountVault();

    expect(CrmDocumentsAPI.getFolders).toHaveBeenCalledWith({
      contactId: 11,
      dealId: 7,
    });
    expect(CrmDocumentsAPI.getDocuments).toHaveBeenCalledWith({
      contactId: 11,
      folderId: 1,
    });
    expect(wrapper.text()).toContain('IMG-WA0012.jpg');
    expect(wrapper.text()).toContain('A classificar');
    expect(wrapper.text()).toContain('Sugestão: RG');
    expect(wrapper.text()).toContain('segue meu rg');
    expect(wrapper.emitted('count')[0]).toEqual([1]);
  });

  it('avisa que o módulo está indisponível quando a API responde 404', async () => {
    CrmDocumentsAPI.getFolders.mockRejectedValue({ response: { status: 404 } });

    const wrapper = await mountVault();

    expect(wrapper.emitted('unavailable')).toHaveLength(1);
  });

  it('envia os arquivos um por vez para a pasta aberta e recarrega', async () => {
    CrmDocumentsAPI.upload.mockResolvedValue({ data: { duplicate: false } });
    const wrapper = await mountVault();
    const files = [new File(['a'], 'a.pdf'), new File(['b'], 'b.pdf')];
    const input = wrapper.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', { value: files });

    await input.trigger('change');
    await flushPromises();

    expect(CrmDocumentsAPI.upload).toHaveBeenCalledTimes(2);
    expect(CrmDocumentsAPI.upload.mock.calls[0][0]).toMatchObject({
      contactId: 11,
      folderId: 1,
      dealId: 7,
    });
    expect(CrmDocumentsAPI.getFolders).toHaveBeenCalledTimes(2);
  });

  it('classifica com a sugestão já marcada, só confirmando', async () => {
    CrmDocumentsAPI.updateDocument.mockResolvedValue({ data: {} });
    const wrapper = await mountVault();

    await wrapper.find('button[aria-haspopup="menu"]').trigger('click');
    const classify = wrapper
      .findAll('button[role="menuitem"]')
      .find(b => b.text().includes('Classificar'));
    await classify.trigger('click');
    expect(wrapper.find('#crm-doc-type').element.value).toBe('rg');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(CrmDocumentsAPI.updateDocument).toHaveBeenCalledWith(50, {
      doc_type: 'rg',
      description: '',
    });
  });
});

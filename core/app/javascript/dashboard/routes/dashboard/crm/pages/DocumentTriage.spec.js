import { flushPromises, mount } from '@vue/test-utils';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import { useAlert } from 'dashboard/composables';
import DocumentTriage from './DocumentTriage.vue';

vi.mock('dashboard/api/crmDocuments', () => ({
  default: {
    getTriage: vi.fn(),
    getQueue: vi.fn(() =>
      Promise.resolve({ data: { payload: [], meta: { count: 0 } } })
    ),
    getTypes: vi.fn(),
    updateDocument: vi.fn(),
    getDownloadUrl: vi.fn(() => Promise.resolve({ data: { url: 'blob:x' } })),
  },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const types = [
  {
    slug: 'rg',
    label: 'RG',
    target_slot: 'pessoais',
    target_folder_label: '01 Documentos Pessoais',
  },
  {
    slug: 'cpf',
    label: 'CPF',
    target_slot: 'pessoais',
    target_folder_label: '01 Documentos Pessoais',
  },
  {
    slug: 'cnis',
    label: 'CNIS',
    target_slot: 'processo_docs',
    target_folder_label: '01 Documentos do Caso',
  },
];

const row = (id, contactId, name, extra = {}) => ({
  id,
  contact_id: contactId,
  contact_name: name,
  file_name: `2026-09-22 14h37 — WhatsApp — IMG-${id}.jpg`,
  original_filename: `IMG-${id}.jpg`,
  content_type: 'image/jpeg',
  created_at: '2026-09-22T17:37:00Z',
  contact_deals: [],
  discard_folder_id: 900 + contactId,
  ...extra,
});

const mountPage = async () => {
  const wrapper = mount(DocumentTriage, { attachTo: document.body });
  await flushPromises();
  return wrapper;
};

describe('DocumentTriage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CrmDocumentsAPI.getTypes.mockResolvedValue({ data: types });
    CrmDocumentsAPI.getTriage.mockResolvedValue({
      data: {
        payload: [
          row(1, 10, 'Maria da Silva', {
            suggested_doc_type: 'rg',
            suggested_doc_type_label: 'RG',
          }),
          row(2, 10, 'Maria da Silva'),
          row(3, 20, 'João Pereira'),
        ],
        meta: { count: 3 },
      },
    });
    CrmDocumentsAPI.updateDocument.mockResolvedValue({
      data: {
        file_name: '2026-09-22 — RG.jpg',
        path: 'Clientes/Maria · C000010/01 Documentos Pessoais/2026-09-22 — RG.jpg',
      },
    });
  });

  it('agrupa por cliente e abre o primeiro com a sugestão marcada', async () => {
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('Maria da Silva');
    expect(wrapper.text()).toContain('João Pereira');
    expect(wrapper.text()).toContain('3 para classificar');
    expect(wrapper.text()).toContain('Vai para 01 Documentos Pessoais');
    expect(wrapper.text()).toContain('2026-09-22 — RG.jpg');
    wrapper.unmount();
  });

  it('classifica com Enter e segue para o próximo', async () => {
    const wrapper = await mountPage();

    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    await flushPromises();

    expect(CrmDocumentsAPI.updateDocument).toHaveBeenCalledWith(1, {
      doc_type: 'rg',
      description: '',
    });
    expect(useAlert).toHaveBeenCalledWith(
      '2026-09-22 — RG.jpg guardado em 01 Documentos Pessoais.'
    );
    expect(wrapper.text()).toContain('2 para classificar');
    wrapper.unmount();
  });

  it('escolhe o tipo pela tecla numérica', async () => {
    const wrapper = await mountPage();

    window.dispatchEvent(new KeyboardEvent('keydown', { key: '2' }));
    await flushPromises();
    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    await flushPromises();

    expect(CrmDocumentsAPI.updateDocument).toHaveBeenCalledWith(1, {
      doc_type: 'cpf',
      description: '',
    });
    wrapper.unmount();
  });

  it('descarta para 99 Arquivo do próprio cliente', async () => {
    const wrapper = await mountPage();

    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Delete' }));
    await flushPromises();

    expect(CrmDocumentsAPI.updateDocument).toHaveBeenCalledWith(1, {
      crm_document_folder_id: 910,
    });
    wrapper.unmount();
  });

  it('avisa quando o módulo não está ligado na conta', async () => {
    CrmDocumentsAPI.getTriage.mockRejectedValue({ response: { status: 404 } });

    const wrapper = await mountPage();

    expect(wrapper.text()).toContain(
      'O módulo de arquivos não está ligado nesta conta'
    );
    wrapper.unmount();
  });
});

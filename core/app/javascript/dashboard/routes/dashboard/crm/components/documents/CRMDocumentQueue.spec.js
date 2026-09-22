import { flushPromises, mount } from '@vue/test-utils';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import CRMDocumentQueue from './CRMDocumentQueue.vue';

vi.mock('dashboard/api/crmDocuments', () => ({
  default: {
    getQueue: vi.fn(),
    updateDocument: vi.fn(),
    getDownloadUrl: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const doc = extra => ({
  id: 5,
  contact_name: 'Maria da Silva',
  file_name: '2026-09-22 — RG.pdf',
  doc_type_label: 'RG',
  path: 'Clientes/Maria · C000001/01 Documentos Pessoais/2026-09-22 — RG.pdf',
  ...extra,
});

describe('CRMDocumentQueue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();
    CrmDocumentsAPI.updateDocument.mockResolvedValue({ data: {} });
  });

  it('para análise: aprova e recarrega a fila', async () => {
    CrmDocumentsAPI.getQueue.mockResolvedValue({
      data: { payload: [doc()], meta: { count: 1 } },
    });
    const wrapper = mount(CRMDocumentQueue, {
      props: { queue: 'review' },
      global: { stubs: { teleport: true } },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Maria da Silva');
    expect(wrapper.emitted('count')[0]).toEqual([1]);
    await wrapper
      .findAll('button')
      .find(b => b.text().includes('Aprovar'))
      .trigger('click');
    await flushPromises();

    expect(CrmDocumentsAPI.updateDocument).toHaveBeenCalledWith(5, {
      status: 'approved',
    });
    expect(CrmDocumentsAPI.getQueue).toHaveBeenCalledTimes(2);
  });

  it('vencendo: mostra quantos dias faltam ou quando venceu', async () => {
    const past = new Date(Date.now() - 2 * 86400000).toISOString().slice(0, 10);
    CrmDocumentsAPI.getQueue.mockResolvedValue({
      data: { payload: [doc({ expires_on: past })], meta: { count: 1 } },
    });
    const wrapper = mount(CRMDocumentQueue, {
      props: { queue: 'expiring' },
      global: { stubs: { teleport: true } },
    });
    await flushPromises();

    expect(CrmDocumentsAPI.getQueue).toHaveBeenCalledWith('expiring');
    expect(wrapper.text()).toContain('Venceu em');
  });
});

import { flushPromises, mount } from '@vue/test-utils';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import CRMDocumentSubmissions from './CRMDocumentSubmissions.vue';

vi.mock('dashboard/api/crmDocuments', () => ({
  default: { getSubmissions: vi.fn(), reviewSubmission: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const submission = {
  id: 4,
  protocol: '2026-000017',
  created_at: '2026-09-22T17:37:00Z',
  review_status: 'new',
  verified: false,
  match_status: 'new_contact',
  documents_count: 2,
  contact_name: 'Lia Costa',
  form_name: 'Envio de documentos',
  answers: [
    { key: 'nome', label: 'Nome completo', type: 'text', value: 'Lia Costa' },
    { key: 'aceite', label: 'Aceita contato', type: 'checkbox', value: true },
  ],
};

describe('CRMDocumentSubmissions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CrmDocumentsAPI.getSubmissions.mockResolvedValue({
      data: { payload: [submission], meta: { count: 1 } },
    });
    CrmDocumentsAPI.reviewSubmission.mockResolvedValue({ data: {} });
  });

  it('mostra protocolo, identificação, aviso de não verificado e respostas', async () => {
    const wrapper = mount(CRMDocumentSubmissions);
    await flushPromises();

    expect(wrapper.text()).toContain('2026-000017');
    expect(wrapper.text()).toContain('Contato novo criado');
    expect(wrapper.text()).toContain('Não verificado');
    expect(wrapper.text()).toContain('Aceita contato');
    expect(wrapper.text()).toContain('Sim');
    expect(wrapper.emitted('count')[0]).toEqual([1]);
  });

  it('só deixa concluir depois de verificar o envio', async () => {
    CrmDocumentsAPI.getSubmissions
      .mockResolvedValueOnce({
        data: { payload: [submission], meta: { count: 1 } },
      })
      .mockResolvedValue({
        data: {
          payload: [{ ...submission, verified: true }],
          meta: { count: 1 },
        },
      });
    const wrapper = mount(CRMDocumentSubmissions);
    await flushPromises();

    const byText = text =>
      wrapper.findAll('button').find(b => b.text().includes(text));
    expect(byText('Concluir')).toBeUndefined();
    await byText('É este cliente').trigger('click');
    await flushPromises();
    await byText('Concluir').trigger('click');
    await flushPromises();

    expect(CrmDocumentsAPI.reviewSubmission).toHaveBeenNthCalledWith(1, 4, {
      verified: true,
    });
    expect(CrmDocumentsAPI.reviewSubmission).toHaveBeenNthCalledWith(2, 4, {
      review_status: 'done',
    });
  });
});

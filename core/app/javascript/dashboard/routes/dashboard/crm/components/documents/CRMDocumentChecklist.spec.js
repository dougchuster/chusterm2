import { flushPromises, mount } from '@vue/test-utils';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import CRMDocumentChecklist from './CRMDocumentChecklist.vue';

vi.mock('dashboard/api/crmDocuments', () => ({
  default: { getChecklist: vi.fn(), updateChecklist: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const checklist = {
  template_id: 3,
  template_name: 'Divórcio Consensual',
  templates: [{ id: 3, name: 'Divórcio Consensual' }],
  total: 2,
  done: 1,
  items: [
    {
      key: 'certidao_casamento',
      title: 'Certidão de casamento',
      required: true,
      status: 'received',
    },
    {
      key: 'relacao_bens',
      title: 'Relação de bens',
      required: true,
      status: 'missing',
    },
  ],
};

const mountChecklist = async () => {
  const wrapper = mount(CRMDocumentChecklist, { props: { dealId: 7 } });
  await flushPromises();
  return wrapper;
};

describe('CRMDocumentChecklist', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CrmDocumentsAPI.getChecklist.mockResolvedValue({ data: checklist });
    CrmDocumentsAPI.updateChecklist.mockResolvedValue({
      data: { ...checklist, done: 2 },
    });
  });

  it('mostra quanto já chegou e o que falta', async () => {
    const wrapper = await mountChecklist();

    expect(CrmDocumentsAPI.getChecklist).toHaveBeenCalledWith(7);
    expect(wrapper.text()).toContain('1 de 2');
    expect(wrapper.text()).toContain('Faltam: Relação de bens');
  });

  it('marca item entregue em papel', async () => {
    const wrapper = await mountChecklist();

    await wrapper.find('button[aria-expanded]').trigger('click');
    const paper = wrapper
      .findAll('button')
      .find(b => b.text() === 'Entregue em papel');
    await paper.trigger('click');
    await flushPromises();

    expect(CrmDocumentsAPI.updateChecklist).toHaveBeenCalledWith(7, {
      mark: { key: 'relacao_bens', done: true },
    });
    expect(wrapper.text()).toContain('2 de 2');
  });

  it('troca o checklist do negócio', async () => {
    const wrapper = await mountChecklist();

    await wrapper.find('#crm-doc-checklist-template').setValue('');
    await flushPromises();

    expect(CrmDocumentsAPI.updateChecklist).toHaveBeenCalledWith(7, {
      template_id: null,
    });
  });

  it('recarrega quando os documentos mudam', async () => {
    const wrapper = await mountChecklist();

    await wrapper.setProps({ refreshKey: 1 });
    await flushPromises();

    expect(CrmDocumentsAPI.getChecklist).toHaveBeenCalledTimes(2);
  });
});
